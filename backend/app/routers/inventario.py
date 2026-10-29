import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import KardexMovimiento, Lote, Producto
from ..schemas import (
    KardexMovimientoOut,
    KardexObservacionInput,
    LoteAjusteInput,
    LoteBajaInput,
    LoteCaducidadAlertaOut,
    LoteCreate,
    LoteOut,
    ProductoCreate,
    ProductoOut,
)

router = APIRouter(prefix="/api/inventario", tags=["Inventario y Lotes"])

ROLES_PERMITIDOS_AJUSTE = {"ADMINISTRADOR", "RESPONSABLE_SANITARIO"}


@router.post("/productos", response_model=ProductoOut, status_code=status.HTTP_201_CREATED)
def crear_producto(prod_in: ProductoCreate, db: Session = Depends(get_db)):
    """Crea un nuevo producto farmacéutico."""
    codigo_limpio = prod_in.codigo_barras.strip()
    existente = db.query(Producto).filter(Producto.codigo_barras == codigo_limpio).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un producto con el código de barras '{codigo_limpio}'"
        )
    
    nuevo_prod = Producto(**prod_in.model_dump())
    nuevo_prod.codigo_barras = codigo_limpio
    db.add(nuevo_prod)
    db.commit()
    db.refresh(nuevo_prod)
    
    # Calcular stock inicial
    nuevo_prod.stock_total = 0
    return nuevo_prod


@router.get("/productos", response_model=List[ProductoOut])
def listar_productos(
    buscar: Optional[str] = Query(None, description="Búsqueda por código, nombre o sustancia"),
    solo_activos: bool = True,
    db: Session = Depends(get_db)
):
    """Lista todos los productos junto con sus lotes y stock acumulado."""
    query = db.query(Producto)
    if solo_activos:
        query = query.filter(Producto.activo == True)
    if buscar:
        termino = f"%{buscar.strip()}%"
        query = query.filter(
            (Producto.codigo_barras.ilike(termino)) |
            (Producto.nombre_comercial.ilike(termino)) |
            (Producto.sustancia_activa.ilike(termino)) |
            (Producto.laboratorio.ilike(termino))
        )
    
    productos = query.all()
    for p in productos:
        p.stock_total = sum(lote.stock_actual for lote in p.lotes if lote.activo)
    return productos


@router.get("/productos/buscar-codigo/{codigo_barras}", response_model=ProductoOut)
def buscar_producto_por_codigo(codigo_barras: str, db: Session = Depends(get_db)):
    """
    Busca si un código de barras ya se encuentra previamente registrado en el inventario.
    Permite el autocompletado en registro únicamente para códigos existentes.
    """
    cod = codigo_barras.strip()
    prod = db.query(Producto).filter(Producto.codigo_barras == cod).first()
    if not prod:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"El código de barras '{codigo_barras}' no está dado de alta en el sistema."
        )
    prod.stock_total = sum(lote.stock_actual for lote in prod.lotes if lote.activo)
    return prod


@router.post("/lotes", response_model=LoteOut, status_code=status.HTTP_201_CREATED)
def registrar_lote(lote_in: LoteCreate, db: Session = Depends(get_db)):
    """
    Registra un lote con fecha de caducidad, datos de fabricación y stock inicial.
    Genera automáticamente el movimiento inmutable en el Kardex.
    """
    producto = db.query(Producto).filter(Producto.id == lote_in.producto_id).first()
    if not producto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Producto no encontrado")

    numero_limpio = lote_in.numero_lote.strip().upper()
    existente = db.query(Lote).filter(
        Lote.producto_id == lote_in.producto_id,
        Lote.numero_lote == numero_limpio
    ).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El lote '{numero_limpio}' ya existe para este producto"
        )

    datos = lote_in.model_dump()
    datos["numero_lote"] = numero_limpio
    if not datos.get("laboratorio_fabricante"):
        datos["laboratorio_fabricante"] = producto.laboratorio
    if not datos.get("fecha_ingreso"):
        datos["fecha_ingreso"] = datetime.date.today()

    # Dosis separada de la dosificación: Tableta | 100 | mg
    d_valor = (datos.get("dosis_valor") or "").strip()
    d_unidad = (datos.get("dosis_unidad") or "").strip()
    forma = (datos.get("forma_farmaceutica") or "").strip()
    if d_valor and d_unidad:
        datos["dosificacion"] = f"{forma} | {d_valor} | {d_unidad}".strip(" |")

    nuevo_lote = Lote(**datos)
    db.add(nuevo_lote)
    db.flush()

    # Si entra con stock inicial > 0, registramos la entrada en el Kardex
    if nuevo_lote.stock_actual > 0:
        movimiento = KardexMovimiento(
            lote_id=nuevo_lote.id,
            tipo_movimiento="ENTRADA_COMPRA",
            cantidad=nuevo_lote.stock_actual,
            stock_anterior=0,
            stock_posterior=nuevo_lote.stock_actual,
            costo_unitario=nuevo_lote.costo_unitario,
            referencia_tipo="ALTA_INICIAL_COMPRA",
            referencia_id=str(nuevo_lote.id),
            motivo=f"Recepción y alta inicial de lote {numero_limpio} en inventario"
        )
        db.add(movimiento)

    db.commit()
    db.refresh(nuevo_lote)
    return nuevo_lote


@router.get("/lotes", response_model=List[LoteOut])
def listar_lotes(producto_id: Optional[int] = None, solo_activos: bool = True, db: Session = Depends(get_db)):
    """Lista lotes ordenados por fecha de caducidad (FEFO)."""
    query = db.query(Lote)
    if producto_id:
        query = query.filter(Lote.producto_id == producto_id)
    if solo_activos:
        query = query.filter(Lote.activo == True)
    return query.order_by(Lote.fecha_caducidad.asc()).all()


@router.get("/lotes/caducidades", response_model=List[LoteCaducidadAlertaOut])
def listar_lotes_proximos_caducar(
    dias: int = Query(90, ge=1, le=730, description="Días máximos hacia adelante para alertar"),
    incluir_caducados: bool = True,
    db: Session = Depends(get_db)
):
    """
    Obtiene todos los lotes con existencia física que están próximos a caducar
    o ya caducaron, cruzados con la información de su medicamento y clasificados
    por nivel de urgencia sanitaria (CRITICA, PREVENTIVA, CADUCADO).
    """
    hoy = datetime.date.today()
    limite = hoy + datetime.timedelta(days=dias)

    query = db.query(Lote, Producto).join(Producto, Lote.producto_id == Producto.id)\
        .filter(Lote.activo == True, Lote.stock_actual > 0, Producto.activo == True)

    if not incluir_caducados:
        query = query.filter(Lote.fecha_caducidad >= hoy)

    query = query.filter(Lote.fecha_caducidad <= limite)
    resultados = query.order_by(Lote.fecha_caducidad.asc()).all()

    alertas = []
    for lote, prod in resultados:
        dias_restantes = (lote.fecha_caducidad - hoy).days
        if dias_restantes < 0:
            urgencia = "CADUCADO"
        elif dias_restantes <= 30:
            urgencia = "CRITICA"
        else:
            urgencia = "PREVENTIVA"

        alertas.append(
            LoteCaducidadAlertaOut(
                lote_id=lote.id,
                numero_lote=lote.numero_lote,
                fecha_caducidad=lote.fecha_caducidad,
                dias_restantes=dias_restantes,
                urgencia=urgencia,
                stock_actual=lote.stock_actual,
                costo_unitario=lote.costo_unitario,
                laboratorio_fabricante=lote.laboratorio_fabricante or prod.laboratorio,
                forma_farmaceutica=lote.forma_farmaceutica,
                dosificacion=lote.dosificacion,
                fecha_ingreso=lote.fecha_ingreso,
                producto_id=prod.id,
                nombre_comercial=prod.nombre_comercial,
                sustancia_activa=prod.sustancia_activa,
                presentacion=prod.presentacion,
                laboratorio_producto=prod.laboratorio,
                precio_venta=prod.precio_venta,
                codigo_barras=prod.codigo_barras,
                grupo_farmacopea=prod.grupo_farmacopea,
                requiere_receta=prod.requiere_receta,
            )
        )
    return alertas


@router.post("/lotes/{lote_id}/ajuste", response_model=LoteOut)
def ajustar_stock_lote(lote_id: int, ajuste_in: LoteAjusteInput, db: Session = Depends(get_db)):
    """
    Ajusta manualmente las piezas de un lote en inventario.
    RESTRINGIDO: Solo accesible para ADMINISTRADOR y RESPONSABLE_SANITARIO.
    Registra el movimiento correspondiente en Kardex (ENTRADA_AJUSTE o SALIDA_AJUSTE).
    """
    rol = (ajuste_in.rol_usuario or "").upper().strip()
    if rol not in ROLES_PERMITIDOS_AJUSTE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Permiso denegado: El rol '{ajuste_in.rol_usuario}' no está autorizado para ajustar inventario. Se requiere Administrador o Responsable Sanitario."
        )

    lote = db.query(Lote).filter(Lote.id == lote_id).first()
    if not lote:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lote no encontrado")

    stock_anterior = lote.stock_actual
    nuevo_stock = ajuste_in.nuevo_stock
    diferencia = nuevo_stock - stock_anterior

    if diferencia == 0:
        return lote

    tipo_movimiento = "ENTRADA_AJUSTE" if diferencia > 0 else "SALIDA_AJUSTE"
    cantidad_mov = abs(diferencia)

    lote.stock_actual = nuevo_stock
    if nuevo_stock > 0 and not lote.activo:
        lote.activo = True

    movimiento = KardexMovimiento(
        lote_id=lote.id,
        tipo_movimiento=tipo_movimiento,
        cantidad=cantidad_mov,
        stock_anterior=stock_anterior,
        stock_posterior=nuevo_stock,
        costo_unitario=lote.costo_unitario,
        referencia_tipo="AJUSTE_INVENTARIO",
        referencia_id=str(lote.id),
        motivo=f"Ajuste realizado por {ajuste_in.usuario} ({rol}): {ajuste_in.motivo}",
    )
    db.add(movimiento)
    db.commit()
    db.refresh(lote)
    return lote


@router.post("/lotes/{lote_id}/baja", response_model=LoteOut)
@router.delete("/lotes/{lote_id}", response_model=LoteOut)
def dar_de_baja_lote(lote_id: int, baja_in: LoteBajaInput, db: Session = Depends(get_db)):
    """
    Elimina/desactiva un lote del inventario y pone su stock en cero.
    RESTRINGIDO: Solo accesible para ADMINISTRADOR y RESPONSABLE_SANITARIO.
    Registra la salida total en Kardex como BAJA_LOTE con motivo y auditoría.
    """
    rol = (baja_in.rol_usuario or "").upper().strip()
    if rol not in ROLES_PERMITIDOS_AJUSTE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Permiso denegado: El rol '{baja_in.rol_usuario}' no está autorizado para dar de baja lotes. Se requiere Administrador o Responsable Sanitario."
        )

    lote = db.query(Lote).filter(Lote.id == lote_id).first()
    if not lote:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lote no encontrado")

    stock_previo = lote.stock_actual
    lote.activo = False
    lote.stock_actual = 0

    if stock_previo > 0:
        movimiento = KardexMovimiento(
            lote_id=lote.id,
            tipo_movimiento="BAJA_LOTE",
            cantidad=stock_previo,
            stock_anterior=stock_previo,
            stock_posterior=0,
            costo_unitario=lote.costo_unitario,
            referencia_tipo="BAJA_ADMINISTRATIVA",
            referencia_id=str(lote.id),
            motivo=f"Baja de lote por {baja_in.usuario} ({rol}): {baja_in.motivo}",
        )
        db.add(movimiento)

    db.commit()
    db.refresh(lote)
    return lote


@router.get("/kardex", response_model=List[KardexMovimientoOut])
def consultar_kardex(
    lote_id: Optional[int] = None,
    solo_irregulares: bool = False,
    limit: int = 150,
    db: Session = Depends(get_db)
):
    """Consulta los movimientos inmutables del Kardex con filtro opcional de irregularidades."""
    query = db.query(KardexMovimiento)
    if lote_id:
        query = query.filter(KardexMovimiento.lote_id == lote_id)
    if solo_irregulares:
        query = query.filter(KardexMovimiento.es_irregular == True)
    return query.order_by(KardexMovimiento.created_at.desc()).limit(limit).all()


@router.post("/kardex/{movimiento_id}/observaciones", response_model=KardexMovimientoOut)
def agregar_observacion_kardex(
    movimiento_id: int,
    obs_in: KardexObservacionInput,
    db: Session = Depends(get_db)
):
    """
    Permite a los usuarios y auditores registrar observaciones o marcar movimientos del Kardex
    como irregulares ('fuera de lugar') para investigaciones o aclaraciones internas.
    """
    movimiento = db.query(KardexMovimiento).filter(KardexMovimiento.id == movimiento_id).first()
    if not movimiento:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movimiento de Kardex no encontrado")

    movimiento.observaciones_auditoria = obs_in.observaciones
    movimiento.es_irregular = obs_in.es_irregular
    if obs_in.usuario_auditor:
        movimiento.usuario_auditor = obs_in.usuario_auditor

    db.commit()
    db.refresh(movimiento)
    return movimiento
