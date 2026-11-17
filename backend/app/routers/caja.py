from typing import List, Optional, Tuple
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db, utc_now
from ..models import Devolucion, TurnoCaja, Usuario, Venta
from ..schemas import TurnoCajaApertura, TurnoCajaCierre, TurnoCajaOut, TurnoResumenOut
from ..security import get_current_user_optional

router = APIRouter(prefix="/api/caja", tags=["Cortes de Caja y Turnos"])


def _calcular_totales_turno(db: Session, turno: TurnoCaja) -> Tuple[int, float, float, float, float]:
    """Calcula ventas netas del turno descontando reembolsos de devoluciones."""
    ventas_turno = db.query(Venta).filter(Venta.turno_id == turno.id).all()
    efectivo = sum(float(v.total or 0.0) for v in ventas_turno if v.metodo_pago == "EFECTIVO")
    tarjeta = sum(
        float(v.total or 0.0)
        for v in ventas_turno
        if v.metodo_pago in ["TARJETA", "TARJETA_CREDITO", "TARJETA_DEBITO"]
    )
    transferencia = sum(float(v.total or 0.0) for v in ventas_turno if v.metodo_pago == "TRANSFERENCIA")

    venta_ids = [v.id for v in ventas_turno]
    if venta_ids:
        devs = db.query(Devolucion).filter(Devolucion.venta_id.in_(venta_ids)).all()
        for d in devs:
            monto = float(d.total_reembolsado or 0.0)
            met = (d.metodo_reembolso or "EFECTIVO").upper()
            if met == "EFECTIVO":
                efectivo -= monto
            elif met in ("TARJETA", "TARJETA_CREDITO", "TARJETA_DEBITO"):
                tarjeta -= monto
            elif met == "TRANSFERENCIA":
                transferencia -= monto

    efectivo = round(efectivo, 2)
    tarjeta = round(tarjeta, 2)
    transferencia = round(transferencia, 2)
    total_acumulado = round(efectivo + tarjeta + transferencia, 2)

    turno.ventas_efectivo = efectivo
    turno.ventas_tarjeta = tarjeta
    turno.ventas_transferencia = transferencia
    turno.total_ventas = total_acumulado
    return len(ventas_turno), efectivo, tarjeta, transferencia, total_acumulado


def _verificar_acceso_turno(turno: TurnoCaja, usuario: Optional[Usuario]) -> None:
    if usuario and (usuario.rol or "").upper() == "CAJERO":
        if turno.usuario_id is not None and turno.usuario_id != usuario.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No puedes consultar ni cerrar el turno de otro usuario.",
            )


@router.get("/turno-activo", response_model=Optional[TurnoCajaOut])
def obtener_turno_activo(db: Session = Depends(get_db)):
    """Retorna el turno de caja actualmente abierto o null si no hay ninguno."""
    turno = (
        db.query(TurnoCaja)
        .filter(TurnoCaja.estado == "ABIERTO")
        .order_by(TurnoCaja.fecha_apertura.desc())
        .first()
    )
    return turno


@router.post("/abrir", response_model=TurnoCajaOut, status_code=status.HTTP_201_CREATED)
def abrir_turno(
    apertura: TurnoCajaApertura,
    usuario: Optional[Usuario] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Abre un nuevo turno de caja con fondo inicial en efectivo."""
    activo = db.query(TurnoCaja).filter(TurnoCaja.estado == "ABIERTO").first()
    if activo:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un turno activo abierto por '{activo.cajero_nombre}' (ID: {activo.id}). Debe cerrarse antes de abrir uno nuevo.",
        )

    nuevo_turno = TurnoCaja(
        usuario_id=usuario.id if usuario else apertura.usuario_id,
        cajero_nombre=usuario.nombre_completo if usuario else apertura.cajero_nombre,
        monto_apertura=round(apertura.monto_apertura, 2),
        fecha_apertura=utc_now(),
        ventas_efectivo=0.0,
        ventas_tarjeta=0.0,
        ventas_transferencia=0.0,
        total_ventas=0.0,
        estado="ABIERTO",
        notas=apertura.notas,
    )
    db.add(nuevo_turno)
    db.commit()
    db.refresh(nuevo_turno)
    return nuevo_turno


@router.get("/resumen", response_model=TurnoResumenOut)
def obtener_resumen_turno_actual(
    usuario: Optional[Usuario] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Genera el arqueo en tiempo real del turno abierto para verificar balances."""
    turno = (
        db.query(TurnoCaja)
        .filter(TurnoCaja.estado == "ABIERTO")
        .order_by(TurnoCaja.fecha_apertura.desc())
        .first()
    )
    if not turno:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No hay ningún turno de caja abierto en este momento",
        )
    _verificar_acceso_turno(turno, usuario)

    total_tickets, efectivo, tarjeta, transferencia, _ = _calcular_totales_turno(db, turno)
    db.commit()

    efectivo_esperado = round(turno.monto_apertura + efectivo, 2)

    return TurnoResumenOut(
        turno=turno,
        total_tickets=total_tickets,
        efectivo_esperado_en_caja=efectivo_esperado,
        ventas_por_metodo={
            "EFECTIVO": efectivo,
            "TARJETA": tarjeta,
            "TRANSFERENCIA": transferencia,
        },
    )


@router.post("/cerrar", response_model=TurnoCajaOut)
def cerrar_turno(
    cierre: TurnoCajaCierre,
    usuario: Optional[Usuario] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """
    Cierra el turno de caja actual (Corte Z):
    Compara el dinero físico contado contra el dinero esperado (fondo inicial + ventas en efectivo)
    y calcula el Sobrante (+) o Faltante (-).
    """
    turno = (
        db.query(TurnoCaja)
        .filter(TurnoCaja.estado == "ABIERTO")
        .order_by(TurnoCaja.fecha_apertura.desc())
        .first()
    )
    if not turno:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No hay ningún turno de caja abierto para cerrar",
        )
    _verificar_acceso_turno(turno, usuario)

    # Calcular ventas netas definitivas descontando devoluciones
    _, efectivo, _, _, _ = _calcular_totales_turno(db, turno)

    efectivo_esperado = round(turno.monto_apertura + efectivo, 2)
    diferencia = round(cierre.monto_cierre_efectivo - efectivo_esperado, 2)

    turno.fecha_cierre = utc_now()
    turno.monto_cierre_efectivo = round(cierre.monto_cierre_efectivo, 2)
    turno.diferencia_efectivo = diferencia
    turno.estado = "CERRADO"
    if cierre.notas:
        turno.notas = f"{turno.notas or ''} | Cierre: {cierre.notas}".strip(" | ")

    db.commit()
    db.refresh(turno)
    return turno


@router.get("/historial", response_model=List[TurnoCajaOut])
def listar_historial_turnos(
    limit: int = 30,
    usuario: Optional[Usuario] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Lista los turnos de caja previos (Cortes Z históricos, con RLS para cajero)."""
    query = db.query(TurnoCaja)
    if usuario and (usuario.rol or "").upper() == "CAJERO":
        query = query.filter((TurnoCaja.usuario_id == usuario.id) | (TurnoCaja.cajero_nombre == usuario.nombre_completo))
    return (
        query.order_by(TurnoCaja.fecha_apertura.desc())
        .limit(limit)
        .all()
    )
