import datetime
import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (
    Devolucion,
    DevolucionDetalle,
    KardexMovimiento,
    Lote,
    Producto,
    Venta,
    VentaDetalle,
    VentaDetalleLote,
)
from ..schemas import DevolucionCreate, DevolucionOut, MermaOut

router = APIRouter(prefix="/api/devoluciones", tags=["Devoluciones y Mermas Sanitarias"])


@router.post("/", response_model=DevolucionOut, status_code=status.HTTP_201_CREATED)
def procesar_devolucion(dev_in: DevolucionCreate, db: Session = Depends(get_db)):
    """
    Procesa la devolución de productos de una venta:
    1. Si el producto está en BUEN_ESTADO: Se reintegra al lote original con Kardex 'ENTRADA_DEVOLUCION'.
    2. Si el producto está DAÑADO: No vuelve a stock para venta; se audita en Kardex como 'SALIDA_MERMA'.
    3. Calcula el monto reembolsado y actualiza el estado de la venta.
    """
    venta = db.query(Venta).filter(Venta.id == dev_in.venta_id).first()
    if not venta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"La venta con ID {dev_in.venta_id} no existe",
        )

    folio_dev = f"DEV-{datetime.datetime.utcnow().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

    nueva_devolucion = Devolucion(
        folio_devolucion=folio_dev,
        venta_id=venta.id,
        fecha_devolucion=datetime.datetime.utcnow(),
        motivo=dev_in.motivo,
        total_reembolsado=0.0,
        metodo_reembolso=dev_in.metodo_reembolso,
        cajero_nombre=dev_in.cajero_nombre or "Cajero Principal",
        notas=dev_in.notas,
    )
    db.add(nueva_devolucion)
    db.flush()

    total_reembolso = 0.0

    for item in dev_in.items:
        producto = db.query(Producto).filter(Producto.id == item.producto_id).first()
        lote = db.query(Lote).filter(Lote.id == item.lote_id).first()

        if not producto or not lote:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Producto {item.producto_id} o Lote {item.lote_id} no encontrado",
            )

        # Buscar el despacho original de este lote en la venta
        despacho_original = (
            db.query(VentaDetalleLote)
            .join(VentaDetalle)
            .filter(
                VentaDetalle.venta_id == venta.id,
                VentaDetalle.producto_id == producto.id,
                VentaDetalleLote.lote_id == lote.id,
            )
            .first()
        )

        if not despacho_original:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El lote '{lote.numero_lote}' no fue despachado en la venta {venta.folio_ticket}",
            )

        if item.cantidad > despacho_original.cantidad_despachada:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"No puedes devolver {item.cantidad} unidades del lote {lote.numero_lote}. "
                    f"Solo se vendieron {despacho_original.cantidad_despachada} unidades en este ticket."
                ),
            )

        monto_item = round(item.cantidad * producto.precio_venta, 2)
        total_reembolso += monto_item

        det_dev = DevolucionDetalle(
            devolucion_id=nueva_devolucion.id,
            producto_id=producto.id,
            lote_id=lote.id,
            cantidad=item.cantidad,
            estado_producto=item.estado_producto.upper(),
            monto_reembolsado=monto_item,
        )
        db.add(det_dev)

        stock_anterior = lote.stock_actual

        if item.estado_producto.upper() == "BUEN_ESTADO":
            # Reingresa automáticamente al lote disponible
            lote.stock_actual += item.cantidad
            stock_posterior = lote.stock_actual

            # Kardex Inmutable: Reingreso
            kardex = KardexMovimiento(
                lote_id=lote.id,
                tipo_movimiento="ENTRADA_DEVOLUCION",
                cantidad=item.cantidad,
                stock_anterior=stock_anterior,
                stock_posterior=stock_posterior,
                costo_unitario=lote.costo_unitario,
                referencia_tipo="DEVOLUCION",
                referencia_id=nueva_devolucion.folio_devolucion,
                motivo=f"Reingreso por devolución ticket {venta.folio_ticket}: {dev_in.motivo}",
            )
            db.add(kardex)
        else:
            # Producto DAÑADO: No vuelve al stock para venta (Merma/Cuarentena)
            # Kardex Inmutable: Merma
            kardex = KardexMovimiento(
                lote_id=lote.id,
                tipo_movimiento="SALIDA_MERMA",
                cantidad=-item.cantidad,
                stock_anterior=stock_anterior,
                stock_posterior=stock_anterior,  # El stock vendible no cambia porque no reingresó
                costo_unitario=lote.costo_unitario,
                referencia_tipo="MERMA_SANITARIA",
                referencia_id=nueva_devolucion.folio_devolucion,
                motivo=f"Merma por producto dañado en devolución de venta {venta.folio_ticket}: {dev_in.motivo}",
            )
            db.add(kardex)

    nueva_devolucion.total_reembolsado = round(total_reembolso, 2)

    # Actualizar estado de la venta
    venta.estado = "DEVOLUCION_PARCIAL"
    if round(total_reembolso, 2) >= round(venta.total, 2):
        venta.estado = "DEVUELTA"

    db.commit()
    db.refresh(nueva_devolucion)
    return nueva_devolucion


@router.get("/", response_model=List[DevolucionOut])
def listar_devoluciones(limit: int = 50, db: Session = Depends(get_db)):
    """Lista el historial de todas las devoluciones y reembolsos procesados."""
    return (
        db.query(Devolucion)
        .order_by(Devolucion.fecha_devolucion.desc())
        .limit(limit)
        .all()
    )


@router.get("/mermas", response_model=List[MermaOut])
def listar_mermas_sanitarias(db: Session = Depends(get_db)):
    """Lista todos los productos declarados en merma (dañados o vencidos) para auditoría sanitaria."""
    movs = (
        db.query(KardexMovimiento)
        .filter(KardexMovimiento.tipo_movimiento.in_(["SALIDA_MERMA", "MERMA_CADUCIDAD"]))
        .order_by(KardexMovimiento.created_at.desc())
        .all()
    )

    resultado = []
    for m in movs:
        lote = db.query(Lote).filter(Lote.id == m.lote_id).first()
        prod = lote.producto if lote else None
        resultado.append(
            MermaOut(
                id=m.id,
                producto_id=prod.id if prod else 0,
                producto_nombre=prod.nombre_comercial if prod else "Desconocido",
                lote_id=lote.id if lote else 0,
                numero_lote=lote.numero_lote if lote else "N/A",
                cantidad=abs(m.cantidad),
                motivo=m.motivo or "Merma de inventario",
                fecha=m.created_at,
                costo_total=round(abs(m.cantidad) * m.costo_unitario, 2),
            )
        )
    return resultado
