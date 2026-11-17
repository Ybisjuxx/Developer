import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from ..database import DATABASE_URL, get_db, utc_now
from ..models import (
    Devolucion,
    DevolucionDetalle,
    KardexMovimiento,
    Lote,
    Producto,
    Usuario,
    Venta,
    VentaDetalle,
    VentaDetalleLote,
)
from ..schemas import DevolucionCreate, DevolucionOut, MermaOut
from ..security import get_current_user_optional

router = APIRouter(prefix="/api/devoluciones", tags=["Devoluciones y Mermas Sanitarias"])


@router.post("/", response_model=DevolucionOut, status_code=status.HTTP_201_CREATED)
def procesar_devolucion(
    dev_in: DevolucionCreate,
    usuario: Optional[Usuario] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """
    Procesa la devolución de productos de una venta:
    1. Si el producto está en BUEN_ESTADO: Se reintegra al lote original con Kardex 'ENTRADA_DEVOLUCION'.
    2. Si el producto está DAÑADO: No vuelve a stock para venta; se audita en Kardex como 'SALIDA_MERMA'.
    3. Calcula el monto reembolsado y actualiza el estado de la venta.
    """
    if DATABASE_URL.startswith("sqlite") and not db.in_transaction():
        db.connection().exec_driver_sql("BEGIN IMMEDIATE")

    venta = db.query(Venta).filter(Venta.id == dev_in.venta_id).first()
    if not venta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"La venta con ID {dev_in.venta_id} no existe",
        )

    if venta.estado == "DEVUELTA":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La venta {venta.folio_ticket} ya fue devuelta en su totalidad",
        )

    estados_validos = {"BUEN_ESTADO", "DANADO"}
    for item in dev_in.items:
        if item.estado_producto.upper() not in estados_validos:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"estado_producto inválido '{item.estado_producto}'. Use BUEN_ESTADO o DANADO",
            )

    # Factor para prorratear el descuento de la venta original en el reembolso
    factor_neto = (venta.total / venta.subtotal) if venta.subtotal else 1.0
    pedidas_por_lote: dict = {}

    ahora = utc_now()
    folio_dev = f"DEV-{ahora.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

    nueva_devolucion = Devolucion(
        folio_devolucion=folio_dev,
        venta_id=venta.id,
        fecha_devolucion=ahora,
        motivo=dev_in.motivo,
        total_reembolsado=0.0,
        metodo_reembolso=dev_in.metodo_reembolso,
        cajero_nombre=usuario.nombre_completo if usuario else (dev_in.cajero_nombre or "Cajero Principal"),
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

        # Cantidad ya devuelta de este lote/producto en devoluciones previas de la misma venta
        ya_devuelto = (
            db.query(func.coalesce(func.sum(DevolucionDetalle.cantidad), 0))
            .join(Devolucion)
            .filter(
                Devolucion.venta_id == venta.id,
                DevolucionDetalle.producto_id == producto.id,
                DevolucionDetalle.lote_id == lote.id,
            )
            .scalar()
        ) or 0
        clave = (producto.id, lote.id)
        pedidas_por_lote[clave] = pedidas_por_lote.get(clave, 0) + item.cantidad
        disponible_devolver = despacho_original.cantidad_despachada - ya_devuelto

        if pedidas_por_lote[clave] > disponible_devolver:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"No puedes devolver {pedidas_por_lote[clave]} unidades del lote {lote.numero_lote}. "
                    f"Vendidas: {despacho_original.cantidad_despachada}, ya devueltas: {ya_devuelto}, "
                    f"disponibles para devolución: {max(0, disponible_devolver)}."
                ),
            )

        # Reembolso al precio cobrado en el ticket (no al precio actual) y con descuento prorrateado
        precio_cobrado = despacho_original.venta_detalle.precio_unitario
        monto_item = round(item.cantidad * precio_cobrado * factor_neto, 2)
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

    # Actualizar estado de la venta según piezas vendidas vs. devueltas acumuladas
    db.flush()
    vendidas = sum(d.cantidad for d in venta.detalles)
    devueltas = (
        db.query(func.coalesce(func.sum(DevolucionDetalle.cantidad), 0))
        .join(Devolucion)
        .filter(Devolucion.venta_id == venta.id)
        .scalar()
    ) or 0
    venta.estado = "DEVUELTA" if devueltas >= vendidas else "DEVOLUCION_PARCIAL"

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
        .options(joinedload(KardexMovimiento.lote).joinedload(Lote.producto))
        .filter(KardexMovimiento.tipo_movimiento.in_(["SALIDA_MERMA", "MERMA_CADUCIDAD"]))
        .order_by(KardexMovimiento.created_at.desc())
        .all()
    )

    resultado = []
    for m in movs:
        lote = m.lote
        prod = lote.producto if lote else None
        costo_tot = round(abs(m.cantidad) * float(m.costo_unitario or 0.0), 2)
        resultado.append(
            MermaOut(
                id=m.id,
                devolucion_id=0,
                folio_devolucion="MERMA-KARDEX",
                fecha_merma=m.created_at,
                fecha=m.created_at,
                producto_id=prod.id if prod else 0,
                producto_nombre=prod.nombre_comercial if prod else "Desconocido",
                producto_codigo=prod.codigo_barras if prod else "",
                lote_id=lote.id if lote else 0,
                numero_lote=lote.numero_lote if lote else "N/A",
                cantidad=abs(m.cantidad),
                monto_merma=costo_tot,
                costo_total=costo_tot,
                motivo=m.motivo or "Merma de inventario",
                cajero_nombre=m.usuario_auditor or "Sistema",
            )
        )
    return resultado
