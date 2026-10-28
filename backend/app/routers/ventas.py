import datetime
import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (
    Cliente,
    KardexMovimiento,
    Lote,
    Medico,
    Producto,
    TurnoCaja,
    Venta,
    VentaDetalle,
    VentaDetalleLote,
)
from ..schemas import VentaCreate, VentaOut

router = APIRouter(prefix="/api/ventas", tags=["Ventas y Despacho FEFO"])



@router.post("/", response_model=VentaOut, status_code=status.HTTP_201_CREATED)
def registrar_venta(venta_in: VentaCreate, db: Session = Depends(get_db)):
    """
    Registra una venta de contado y actualiza el stock aplicando FEFO:
    1. Valida existencia de productos y médicos (si el producto es controlado/requiere receta).
    2. Selecciona lotes con stock ordenados por fecha de caducidad ascendente (FEFO).
    3. Descuenta el stock de cada lote.
    4. Registra el movimiento inmutable en el Kardex.
    5. Guarda el detalle del ticket con los lotes específicos despachados.
    6. Asocia la venta al turno de caja activo para corte contable.
    """
    # 1. Si se especificó médico, verificar vigencia
    if venta_in.medico_id:
        medico = db.query(Medico).filter(Medico.id == venta_in.medico_id).first()
        if not medico:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El médico especificado no existe")
        if not medico.vigente:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El médico {medico.nombres} {medico.apellidos} no cuenta con cédula vigente"
            )

    # 2. Asociar a turno de caja activo
    turno_id = venta_in.turno_id
    if not turno_id:
        turno_activo = db.query(TurnoCaja).filter(TurnoCaja.estado == "ABIERTO").first()
        if turno_activo:
            turno_id = turno_activo.id

    # 3. Generar Folio Único
    hoy_str = datetime.datetime.utcnow().strftime("%Y%m%d")
    folio = f"TK-{hoy_str}-{uuid.uuid4().hex[:6].upper()}"

    comprador = venta_in.comprador_nombre or "Público General"
    if venta_in.cliente_id:
        cli = db.query(Cliente).filter(Cliente.id == venta_in.cliente_id).first()
        if cli and (not venta_in.comprador_nombre or venta_in.comprador_nombre == "Público General"):
            comprador = cli.nombre_completo

    nueva_venta = Venta(
        folio_ticket=folio,
        cliente_id=venta_in.cliente_id,
        comprador_nombre=comprador,
        comprador_identificacion=venta_in.comprador_identificacion,
        medico_id=venta_in.medico_id,
        descuento=venta_in.descuento,
        metodo_pago=venta_in.metodo_pago.upper() if venta_in.metodo_pago else "EFECTIVO",
        monto_recibido=round(venta_in.monto_recibido, 2),
        cambio=0.0,
        turno_id=turno_id,
        cajero_nombre=venta_in.cajero_nombre or "Cajero Principal",
        subtotal=0.0,
        total=0.0,
        estado="COMPLETADA",
    )
    db.add(nueva_venta)
    db.flush()


    subtotal_acumulado = 0.0

    # 4. Procesar cada producto solicitado
    for item in venta_in.items:
        producto = db.query(Producto).filter(Producto.id == item.producto_id, Producto.activo == True).first()
        if not producto:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Producto con ID {item.producto_id} no encontrado o inactivo"
            )

        # Regulación: si requiere receta, el médico es obligatorio
        if producto.requiere_receta and not venta_in.medico_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El producto '{producto.nombre_comercial}' pertenece al {producto.grupo_farmacopea} y requiere receta médica obligatoria"
            )

        # Despacho FEFO (First-Expired, First-Out)
        lotes_candidatos = (
            db.query(Lote)
            .filter(
                Lote.producto_id == producto.id,
                Lote.stock_actual > 0,
                Lote.activo == True
            )
            .order_by(Lote.fecha_caducidad.asc())
            .all()
        )

        stock_disponible = sum(l.stock_actual for l in lotes_candidatos)
        if stock_disponible < item.cantidad:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Stock insuficiente para '{producto.nombre_comercial}'. "
                    f"Requerido: {item.cantidad}, Disponible: {stock_disponible}"
                )
            )

        # Crear detalle de venta
        renglon_subtotal = round(item.cantidad * producto.precio_venta, 2)
        subtotal_acumulado += renglon_subtotal

        detalle_venta = VentaDetalle(
            venta_id=nueva_venta.id,
            producto_id=producto.id,
            cantidad=item.cantidad,
            precio_unitario=producto.precio_venta,
            subtotal=renglon_subtotal,
        )
        db.add(detalle_venta)
        db.flush()

        # Descontar lotes en orden FEFO y auditar en Kardex
        por_despachar = item.cantidad
        for lote in lotes_candidatos:
            if por_despachar == 0:
                break

            tomar = min(lote.stock_actual, por_despachar)
            stock_previo = lote.stock_actual
            lote.stock_actual -= tomar
            stock_nuevo = lote.stock_actual
            por_despachar -= tomar

            # Registrar detalle de qué lote se entregó
            despacho_lote = VentaDetalleLote(
                venta_detalle_id=detalle_venta.id,
                lote_id=lote.id,
                cantidad_despachada=tomar,
                costo_unitario=lote.costo_unitario,
            )
            db.add(despacho_lote)

            # Kardex Inmutable
            movimiento = KardexMovimiento(
                lote_id=lote.id,
                tipo_movimiento="SALIDA_VENTA",
                cantidad=-tomar,
                stock_anterior=stock_previo,
                stock_posterior=stock_nuevo,
                costo_unitario=lote.costo_unitario,
                referencia_tipo="TICKET_VENTA",
                referencia_id=nueva_venta.folio_ticket,
                motivo=f"Despacho por venta {nueva_venta.folio_ticket} a {nueva_venta.comprador_nombre}"
            )
            db.add(movimiento)

    # 5. Calcular totales finales y cambio en efectivo
    nueva_venta.subtotal = round(subtotal_acumulado, 2)

    # Si se asoció cliente y no se ingresó descuento manual, aplicar descuento de cliente
    if venta_in.cliente_id and venta_in.descuento == 0.0:
        cli = db.query(Cliente).filter(Cliente.id == venta_in.cliente_id).first()
        if cli and cli.descuento_porcentaje > 0:
            nueva_venta.descuento = round(subtotal_acumulado * (cli.descuento_porcentaje / 100.0), 2)

    nueva_venta.total = max(0.0, round(nueva_venta.subtotal - nueva_venta.descuento, 2))

    if nueva_venta.metodo_pago == "EFECTIVO" and nueva_venta.monto_recibido >= nueva_venta.total:
        nueva_venta.cambio = round(nueva_venta.monto_recibido - nueva_venta.total, 2)
    else:
        nueva_venta.cambio = 0.0


    # 6. Actualizar acumulados del turno de caja
    if turno_id:
        turno = db.query(TurnoCaja).filter(TurnoCaja.id == turno_id).first()
        if turno and turno.estado == "ABIERTO":
            if nueva_venta.metodo_pago == "EFECTIVO":
                turno.ventas_efectivo = round(turno.ventas_efectivo + nueva_venta.total, 2)
            elif nueva_venta.metodo_pago in ["TARJETA", "TARJETA_CREDITO", "TARJETA_DEBITO"]:
                turno.ventas_tarjeta = round(turno.ventas_tarjeta + nueva_venta.total, 2)
            elif nueva_venta.metodo_pago == "TRANSFERENCIA":
                turno.ventas_transferencia = round(turno.ventas_transferencia + nueva_venta.total, 2)
            turno.total_ventas = round(turno.total_ventas + nueva_venta.total, 2)

    db.commit()
    db.refresh(nueva_venta)
    return nueva_venta


@router.get("/", response_model=List[VentaOut])
def listar_ventas(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    """Lista las ventas históricas con sus detalles de lotes despachados y devoluciones."""
    return db.query(Venta).order_by(Venta.fecha_venta.desc()).offset(skip).limit(limit).all()


@router.get("/{venta_id}", response_model=VentaOut)
def obtener_venta(venta_id: int, db: Session = Depends(get_db)):
    """Obtiene el detalle completo de un ticket de venta."""
    venta = db.query(Venta).filter(Venta.id == venta_id).first()
    if not venta:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Venta no encontrada")
    return venta
