import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import TurnoCaja, Venta
from ..schemas import TurnoCajaApertura, TurnoCajaCierre, TurnoCajaOut, TurnoResumenOut

router = APIRouter(prefix="/api/caja", tags=["Cortes de Caja y Turnos"])


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
def abrir_turno(apertura: TurnoCajaApertura, db: Session = Depends(get_db)):
    """Abre un nuevo turno de caja con fondo inicial en efectivo."""
    activo = db.query(TurnoCaja).filter(TurnoCaja.estado == "ABIERTO").first()
    if activo:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un turno activo abierto por '{activo.cajero_nombre}' (ID: {activo.id}). Debe cerrarse antes de abrir uno nuevo.",
        )

    nuevo_turno = TurnoCaja(
        usuario_id=apertura.usuario_id,
        cajero_nombre=apertura.cajero_nombre,
        monto_apertura=round(apertura.monto_apertura, 2),
        fecha_apertura=datetime.datetime.utcnow(),
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
def obtener_resumen_turno_actual(db: Session = Depends(get_db)):
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

    ventas_turno = db.query(Venta).filter(Venta.turno_id == turno.id).all()
    total_tickets = len(ventas_turno)

    efectivo = sum(v.total for v in ventas_turno if v.metodo_pago == "EFECTIVO")
    tarjeta = sum(v.total for v in ventas_turno if v.metodo_pago in ["TARJETA", "TARJETA_CREDITO", "TARJETA_DEBITO"])
    transferencia = sum(v.total for v in ventas_turno if v.metodo_pago == "TRANSFERENCIA")
    total_acumulado = efectivo + tarjeta + transferencia

    # Actualizar valores calculados en el objeto de turno
    turno.ventas_efectivo = round(efectivo, 2)
    turno.ventas_tarjeta = round(tarjeta, 2)
    turno.ventas_transferencia = round(transferencia, 2)
    turno.total_ventas = round(total_acumulado, 2)
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
def cerrar_turno(cierre: TurnoCajaCierre, db: Session = Depends(get_db)):
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

    # Calcular ventas definitivas
    ventas_turno = db.query(Venta).filter(Venta.turno_id == turno.id).all()
    efectivo = sum(v.total for v in ventas_turno if v.metodo_pago == "EFECTIVO")
    tarjeta = sum(v.total for v in ventas_turno if v.metodo_pago in ["TARJETA", "TARJETA_CREDITO", "TARJETA_DEBITO"])
    transferencia = sum(v.total for v in ventas_turno if v.metodo_pago == "TRANSFERENCIA")
    total_acumulado = efectivo + tarjeta + transferencia

    turno.ventas_efectivo = round(efectivo, 2)
    turno.ventas_tarjeta = round(tarjeta, 2)
    turno.ventas_transferencia = round(transferencia, 2)
    turno.total_ventas = round(total_acumulado, 2)

    efectivo_esperado = round(turno.monto_apertura + efectivo, 2)
    diferencia = round(cierre.monto_cierre_efectivo - efectivo_esperado, 2)

    turno.fecha_cierre = datetime.datetime.utcnow()
    turno.monto_cierre_efectivo = round(cierre.monto_cierre_efectivo, 2)
    turno.diferencia_efectivo = diferencia
    turno.estado = "CERRADO"
    if cierre.notas:
        turno.notas = f"{turno.notas or ''} | Cierre: {cierre.notas}".strip(" | ")

    db.commit()
    db.refresh(turno)
    return turno


@router.get("/historial", response_model=List[TurnoCajaOut])
def listar_historial_turnos(limit: int = 30, db: Session = Depends(get_db)):
    """Lista los turnos de caja previos (Cortes Z históricos)."""
    return (
        db.query(TurnoCaja)
        .order_by(TurnoCaja.fecha_apertura.desc())
        .limit(limit)
        .all()
    )
