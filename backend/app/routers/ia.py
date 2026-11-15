import datetime
import json
import re
from typing import Dict, List, Optional, Tuple
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (
    ParSustitucion,
    Producto,
    Sustancia,
    TareaClasificacionFarmaceutica,
    Usuario,
)
from ..schemas import IaConsultaInput, IaConsultaOut, SustitutoSugeridoOut
from ..security import get_current_user_optional, rate_limiter, require_roles
from ..utils.presentacion_parser import (
    normalizar_sustancia_exacta,
    parsear_presentacion,
    quitar_acentos,
)

router = APIRouter(prefix="/api/ia", tags=["Consulta IA de Medicamentos & Sustitutos"])

AVISO_SANITARIO_OBLIGATORIO = (
    "Esta sugerencia es apoyo orientativo para el mostrador. "
    "Un profesional farmacéutico debe tomar la decisión final junto con el médico."
)

# Marcas comunes corregidas (sin Melox->Meloxicam, sin Ranitidina, con combinaciones exactas)
MARCAS_A_SUSTANCIA: Dict[str, str] = {
    "TEMPRA": "PARACETAMOL",
    "TYLENOL": "PARACETAMOL",
    "MOTRIN": "IBUPROFENO",
    "ADVIL": "IBUPROFENO",
    "ACTRON": "IBUPROFENO",
    "FLANAX": "NAPROXENO",
    "DAFLOXEN": "NAPROXENO",
    "DOLAC": "KETOROLACO",
    "VOLTAREN": "DICLOFENACO",
    "CATAFLAM": "DICLOFENACO",
    "CELEBREX": "CELECOXIB",
    "MELOX": "DIMETICONA + MAGALDRATO",
    "AMOXIL": "AMOXICILINA",
    "AUGMENTIN": "ACIDO CLAVULANICO + AMOXICILINA",
    "CLAVULIN": "ACIDO CLAVULANICO + AMOXICILINA",
    "CLARITYNE": "LORATADINA",
    "ZYRTEC": "CETIRIZINA",
    "ALLEGRA": "FEXOFENADINA",
    "LOSEC": "OMEPRAZOL",
    "ULSEN": "OMEPRAZOL",
    "PANTOZOL": "PANTOPRAZOL",
    "NEXIUM": "ESOMEPRAZOL",
    "COZAAR": "LOSARTAN",
    "GLUCOPHAGE": "METFORMINA",
    "KEFLEX": "CEFALEXINA",
}

_STOPWORDS = {
    "PARA", "COMO", "TIENE", "TIENEN", "TIENES", "BUSCO", "QUIERO", "NECESITO",
    "ALGO", "ALGUN", "ALGUNA", "ALGUNOS", "MEDICAMENTO", "MEDICINA", "PASTILLA",
    "PASTILLAS", "RECOMIENDAS", "RECOMIENDA", "SIRVE", "SUSTITUTO", "SUSTITUTOS",
    "ALTERNATIVA", "ALTERNATIVAS", "EQUIVALENTE", "GENERICO", "PRECIO", "STOCK",
    "HAY", "CON", "SIN", "DEL", "LAS", "LOS", "UNA", "UNO", "POR", "QUE",
}

_GRUPOS_CONTROLADOS = {"GRUPO_I", "GRUPO_II", "GRUPO_III"}


class SustanciaClasificarInput(BaseModel):
    codigo_atc: Optional[str] = Field(None, max_length=20)
    grupo_farmacopea: str = Field(default="GRUPO_VI", max_length=20)
    requiere_receta_por_defecto: bool = False
    clasificado_por: str = Field(..., min_length=2, max_length=150)


class ParSustitucionCreateInput(BaseModel):
    sustancia_origen: str = Field(..., min_length=2, max_length=200)
    sustancia_alternativa: str = Field(..., min_length=2, max_length=200)
    advertencias: List[str] = Field(default_factory=list)
    validado_por: Optional[str] = Field(None, max_length=150)


def _norm(texto: str) -> str:
    return re.sub(r"\s+", " ", quitar_acentos(texto or "").upper()).strip()


def _extraer_consulta_estructurada(consulta: str) -> Tuple[Optional[float], Optional[str], Optional[str], Optional[str]]:
    """Extrae concentración, forma y vía solicitadas en la consulta."""
    texto = _norm(consulta)
    conc_val: Optional[float] = None
    conc_unit: Optional[str] = None

    m = re.search(r"(\d+(?:\.\d+)?)\s*(MG/5ML|MG/ML|MCG|MG|ML|UI|G|%)\b", texto)
    if m:
        conc_val = float(m.group(1))
        conc_unit = m.group(2).lower()
    else:
        m_num = re.search(r"\bDE\s+(\d+(?:\.\d+)?)\b", texto)
        if m_num:
            conc_val = float(m_num.group(1))

    _, _, forma, via, _ = parsear_presentacion(texto)
    return conc_val, conc_unit, forma, via


def _asegurar_datos_estructurados(db: Session) -> None:
    """Completa campos estructurados y catálogo de sustancias para productos heredados."""
    productos = db.query(Producto).all()
    cambio = False
    for p in productos:
        if p.concentracion_valor is None or p.forma_farmaceutica is None or p.via_administracion is None:
            c_val, c_unit, forma, via, req_rev = parsear_presentacion(p.presentacion)
            if p.concentracion_valor is None:
                p.concentracion_valor = c_val
            if p.concentracion_unidad is None:
                p.concentracion_unidad = c_unit
            if p.forma_farmaceutica is None:
                p.forma_farmaceutica = forma
            if p.via_administracion is None:
                p.via_administracion = via
            p.requiere_revision_manual = req_rev
            cambio = True

        if p.sustancia_id is None:
            sust_norm = normalizar_sustancia_exacta(p.sustancia_activa)
            if sust_norm:
                sust = db.query(Sustancia).filter(Sustancia.nombre_normalizado == sust_norm).first()
                if not sust:
                    sust = Sustancia(
                        nombre_normalizado=sust_norm,
                        estado_clasificacion="CLASIFICADA",
                        requiere_receta_por_defecto=bool(p.requiere_receta),
                        grupo_farmacopea=p.grupo_farmacopea or "GRUPO_VI",
                        clasificado_por="Migración Catálogo Base",
                        fecha_clasificacion=datetime.datetime.utcnow(),
                    )
                    db.add(sust)
                    db.flush()
                p.sustancia_id = sust.id
                cambio = True
    if cambio:
        db.commit()


def _stock_producto(p: Producto) -> int:
    hoy = datetime.date.today()
    return sum(
        l.stock_actual
        for l in p.lotes
        if l.activo and l.stock_actual > 0 and l.fecha_caducidad >= hoy
    )


def _coincide_palabra_o_subcadena(termino: str, texto_objetivo: str) -> bool:
    """Exige mínimo 3 caracteres para subcadena y prioriza palabra completa."""
    t = _norm(termino)
    obj = _norm(texto_objetivo)
    if len(t) < 3:
        return False
    if re.search(rf"\b{re.escape(t)}\b", obj):
        return True
    return t in obj


def _construir_sustituto(
    p: Producto,
    stock: int,
    tipo: str,
    accion: str,
    motivo: str,
    advertencias: Optional[List[str]] = None,
    visible_para_cajero: bool = True,
) -> SustitutoSugeridoOut:
    return SustitutoSugeridoOut(
        producto_id=p.id,
        codigo_barras=p.codigo_barras,
        nombre_comercial=p.nombre_comercial,
        sustancia_activa=p.sustancia_activa,
        presentacion=p.presentacion,
        laboratorio=p.laboratorio,
        precio_venta=p.precio_venta,
        stock_disponible=stock,
        tipo_sustitucion=tipo,
        accion_requerida=accion,
        advertencias=advertencias or [],
        visible_para_cajero=visible_para_cajero,
        motivo_sugerencia=motivo,
        requiere_receta=p.requiere_receta,
        grupo_farmacopea=p.grupo_farmacopea,
        familia_terapeutica=p.familia_terapeutica,
        indicacion_terapeutica=p.indicacion_terapeutica,
        concentracion_valor=p.concentracion_valor,
        concentracion_unidad=p.concentracion_unidad,
        forma_farmaceutica=p.forma_farmaceutica,
        via_administracion=p.via_administracion,
        es_generico_intercambiable=bool(p.es_generico_intercambiable),
    )


def _clasificar_misma_sustancia(
    p_cand: Producto,
    conc_ref: Optional[float],
    unit_ref: Optional[str],
    forma_ref: Optional[str],
    via_ref: Optional[str],
) -> Tuple[str, str, str, List[str], bool]:
    """Devuelve (tipo_sustitucion, accion_requerida, motivo, advertencias, visible_para_cajero)."""
    adv: List[str] = []
    if p_cand.concentracion_valor is None or p_cand.forma_farmaceutica is None or p_cand.via_administracion is None:
        adv.append("Verificar presentación física antes de entregar.")
        accion = "CONSULTAR_MEDICO" if p_cand.requiere_receta else "CONFIRMAR_FARMACEUTICO"
        return (
            "MISMA_SUSTANCIA_OTRA_PRESENTACION",
            accion,
            f"Misma sustancia activa ({p_cand.sustancia_activa}); verificar presentación ({p_cand.presentacion}).",
            adv,
            True,
        )

    # Cambio de vía -> siempre CONSULTAR_MEDICO y oculto/bloqueado para cajero
    if via_ref and p_cand.via_administracion != via_ref:
        adv.append(f"Cambio de vía de administración ({via_ref} → {p_cand.via_administracion}).")
        return (
            "CONSULTAR_MEDICO",
            "CONSULTAR_MEDICO",
            f"Misma sustancia ({p_cand.sustancia_activa}) pero distinta vía ({p_cand.via_administracion}).",
            adv,
            False,
        )

    misma_conc = (
        conc_ref is not None
        and p_cand.concentracion_valor == conc_ref
        and (unit_ref is None or (p_cand.concentracion_unidad or "").lower() == unit_ref.lower())
    )
    misma_forma = forma_ref is None or p_cand.forma_farmaceutica == forma_ref

    if conc_ref is not None and misma_conc and misma_forma and (via_ref is None or p_cand.via_administracion == via_ref):
        nota_bio = " (genérico intercambiable bioequivalente)" if p_cand.es_generico_intercambiable else ""
        return (
            "INTERCAMBIABLE",
            "OFRECER_AL_CLIENTE",
            f"Misma sustancia, concentración y presentación{nota_bio}.",
            adv,
            True,
        )

    accion = "CONSULTAR_MEDICO" if p_cand.requiere_receta else "CONFIRMAR_FARMACEUTICO"
    if p_cand.requiere_receta:
        adv.append("Medicamento con receta: confirmar cambio de dosis o forma con el médico.")
    return (
        "MISMA_SUSTANCIA_OTRA_PRESENTACION",
        accion,
        f"Misma sustancia ({p_cand.sustancia_activa}) en distinta concentración o forma ({p_cand.presentacion}).",
        adv,
        True,
    )


def _ejecutar_consulta_ia(
    payload: IaConsultaInput,
    usuario: Optional[Usuario],
    db: Session,
) -> IaConsultaOut:
    _asegurar_datos_estructurados(db)
    consulta_raw = payload.consulta.strip()
    consulta_norm = _norm(consulta_raw)
    rol_usuario = (usuario.rol if usuario else "ADMINISTRADOR").upper()

    productos_activos = db.query(Producto).filter(Producto.activo == True).all()
    stock_cache = {p.id: _stock_producto(p) for p in productos_activos}

    conc_pedida, unit_pedida, forma_pedida, via_pedida = _extraer_consulta_estructurada(consulta_raw)

    # Extraer tokens de texto (>= 3 chars, sin números sueltos ni stopwords)
    tokens_texto = [
        t for t in re.findall(r"[A-Z]+", consulta_norm)
        if len(t) >= 3 and t not in _STOPWORDS
    ]

    # 1. Identificar marca comercial conocida o producto coincidente
    sustancia_objetivo_norm: Optional[str] = None
    for marca, sust in MARCAS_A_SUSTANCIA.items():
        if re.search(rf"\b{re.escape(marca)}\b", consulta_norm):
            sustancia_objetivo_norm = normalizar_sustancia_exacta(sust)
            break

    productos_coincidentes: List[Producto] = []
    if len(consulta_norm) >= 3:
        for p in productos_activos:
            nom_norm = _norm(p.nombre_comercial)
            sust_p_norm = normalizar_sustancia_exacta(p.sustancia_activa)
            match_nombre = any(_coincide_palabra_o_subcadena(tok, nom_norm) for tok in tokens_texto) or _coincide_palabra_o_subcadena(consulta_norm, nom_norm)
            match_sust = (
                sustancia_objetivo_norm is not None and sust_p_norm == sustancia_objetivo_norm
            ) or any(_coincide_palabra_o_subcadena(tok, sust_p_norm) for tok in tokens_texto)

            if match_nombre or match_sust:
                productos_coincidentes.append(p)

    # Afinar si se pidió concentración o forma/vía específica
    exactos_solicitados: List[Producto] = []
    for p in productos_coincidentes:
        ok_conc = conc_pedida is None or p.concentracion_valor == conc_pedida
        ok_via = via_pedida is None or p.via_administracion == via_pedida
        ok_forma = forma_pedida is None or p.forma_farmaceutica == forma_pedida
        if ok_conc and ok_via and ok_forma:
            exactos_solicitados.append(p)

    # Si no hubo coincidencia en productos, verificar si se buscó una marca conocida sin registro en catálogo
    if not productos_coincidentes and not sustancia_objetivo_norm:
        # Búsqueda por indicación o texto sin sustancia reconocida: NO generar sustitutos automáticos
        informativos = [
            p for p in productos_activos
            if stock_cache[p.id] > 0
            and p.sustancia_rel is not None
            and p.sustancia_rel.estado_clasificacion == "CLASIFICADA"
            and any(_coincide_palabra_o_subcadena(tok, p.indicacion_terapeutica or "") for tok in tokens_texto)
        ]
        if informativos:
            lista_inf = ", ".join(f"{p.nombre_comercial} ({p.sustancia_activa})" for p in informativos[:5])
            msg = (
                "Búsqueda descriptiva: no se generan sustituciones automáticas por texto libre de indicación. "
                f"Productos clasificados disponibles solo como referencia informativa para el farmacéutico: {lista_inf}."
            )
        else:
            msg = (
                f"No se identificó un medicamento o sustancia exacta para '{consulta_raw}'. "
                "Solicite el nombre comercial o principio activo exacto."
            )
        return IaConsultaOut(
            pregunta=consulta_raw,
            respuesta_ia=msg,
            producto_consultado=None,
            disponible_en_stock=False,
            sustitutos_en_stock=[],
            aviso_sanitario=AVISO_SANITARIO_OBLIGATORIO,
        )

    # Determinar producto/sustancia de referencia
    ref_prod: Optional[Producto] = (
        exactos_solicitados[0] if exactos_solicitados else (productos_coincidentes[0] if productos_coincidentes else None)
    )
    if sustancia_objetivo_norm is None and ref_prod is not None:
        sustancia_objetivo_norm = normalizar_sustancia_exacta(ref_prod.sustancia_activa)

    # Incrementar contador de consultas de la sustancia si existe
    sust_obj: Optional[Sustancia] = None
    if sustancia_objetivo_norm:
        sust_obj = db.query(Sustancia).filter(Sustancia.nombre_normalizado == sustancia_objetivo_norm).first()
        if sust_obj:
            sust_obj.consultas_recibidas = (sust_obj.consultas_recibidas or 0) + 1
            db.commit()

    # Verificar disponibilidad del producto exacto solicitado
    disponibles_exactos = [p for p in exactos_solicitados if stock_cache[p.id] > 0]
    nombre_ref = ref_prod.nombre_comercial if ref_prod else sustancia_objetivo_norm

    conc_ref = conc_pedida if conc_pedida is not None else (ref_prod.concentracion_valor if ref_prod else None)
    unit_ref = unit_pedida if unit_pedida is not None else (ref_prod.concentracion_unidad if ref_prod else None)
    forma_ref = forma_pedida if forma_pedida is not None else (ref_prod.forma_farmaceutica if ref_prod else None)
    via_ref = via_pedida if via_pedida is not None else (ref_prod.via_administracion if ref_prod else None)

    sugerencias: List[SustitutoSugeridoOut] = []
    ids_agregados = set()

    # A) Productos con la MISMA sustancia exacta en stock
    for p in productos_activos:
        stk = stock_cache[p.id]
        if stk <= 0:
            continue
        if normalizar_sustancia_exacta(p.sustancia_activa) != sustancia_objetivo_norm:
            continue

        # Si es controlado y no coincide presentación exacta, solo informar misma presentación
        if p.grupo_farmacopea in _GRUPOS_CONTROLADOS and ref_prod and p.id != ref_prod.id:
            if p.concentracion_valor != conc_ref or p.forma_farmaceutica != forma_ref or p.via_administracion != via_ref:
                continue

        tipo, accion, motivo, adv, visible_cajero = _clasificar_misma_sustancia(
            p, conc_ref, unit_ref, forma_ref, via_ref
        )
        sugerencias.append(_construir_sustituto(p, stk, tipo, accion, motivo, adv, visible_cajero))
        ids_agregados.add(p.id)

    # B) Si la sustancia está PENDIENTE o es CONTROLADA: NO sugerir otras sustancias
    es_pendiente = sust_obj is not None and sust_obj.estado_clasificacion == "PENDIENTE"
    es_controlado = (
        (ref_prod is not None and ref_prod.grupo_farmacopea in _GRUPOS_CONTROLADOS)
        or (sust_obj is not None and sust_obj.grupo_farmacopea in _GRUPOS_CONTROLADOS)
    )

    if not es_pendiente and not es_controlado and sustancia_objetivo_norm:
        # Buscar únicamente pares validados (validado_por != None y no vacío)
        pares_validados = (
            db.query(ParSustitucion)
            .filter(
                ParSustitucion.sustancia_origen == sustancia_objetivo_norm,
                ParSustitucion.validado_por.isnot(None),
                ParSustitucion.validado_por != "",
            )
            .all()
        )
        for par in pares_validados:
            alt_norm = normalizar_sustancia_exacta(par.sustancia_alternativa)
            sust_alt = db.query(Sustancia).filter(Sustancia.nombre_normalizado == alt_norm).first()
            # Nunca ofrecer una sustancia PENDIENTE como alternativa
            if sust_alt and sust_alt.estado_clasificacion == "PENDIENTE":
                continue

            adv_par: List[str] = []
            if par.advertencias:
                try:
                    adv_par = json.loads(par.advertencias)
                except Exception:
                    adv_par = [par.advertencias]
            adv_par.append(f"Par validado por: {par.validado_por}")

            for p in productos_activos:
                if p.id in ids_agregados:
                    continue
                stk = stock_cache[p.id]
                if stk <= 0:
                    continue
                if normalizar_sustancia_exacta(p.sustancia_activa) != alt_norm:
                    continue
                if p.grupo_farmacopea in _GRUPOS_CONTROLADOS:
                    continue
                sugerencias.append(
                    _construir_sustituto(
                        p,
                        stk,
                        "CONSULTAR_MEDICO",
                        "CONSULTAR_MEDICO",
                        f"Alternativa terapéutica validada de {sustancia_objetivo_norm}; requiere autorización médica.",
                        adv_par,
                        visible_para_cajero=False,
                    )
                )
                ids_agregados.add(p.id)

    # Ordenar por nivel (INTERCAMBIABLE -> MISMA_SUSTANCIA_OTRA_PRESENTACION -> CONSULTAR_MEDICO) y mayor stock
    prioridad_orden = {
        "INTERCAMBIABLE": 1,
        "MISMA_SUSTANCIA_OTRA_PRESENTACION": 2,
        "CONSULTAR_MEDICO": 3,
    }
    sugerencias.sort(key=lambda x: (prioridad_orden.get(x.tipo_sustitucion, 9), -x.stock_disponible))

    # Filtrar para cajero si corresponde
    if rol_usuario == "CAJERO":
        sugerencias = [s for s in sugerencias if s.visible_para_cajero]

    # Redactar respuesta clara por nivel
    if es_pendiente:
        if disponibles_exactos:
            respuesta = (
                f"Existencia disponible de {nombre_ref} ({disponibles_exactos[0].presentacion}). "
                "Sustancia de reciente registro, sin alternativas validadas. Consulte al farmacéutico."
            )
        else:
            respuesta = (
                f"Sin existencia de {nombre_ref}. "
                "Sustancia de reciente registro, sin alternativas validadas. Consulte al farmacéutico."
            )
    elif disponibles_exactos and any(s.tipo_sustitucion == "INTERCAMBIABLE" for s in sugerencias):
        top = next(s for s in sugerencias if s.tipo_sustitucion == "INTERCAMBIABLE")
        respuesta = f"🟢 Tenemos el mismo medicamento intercambiable: {top.nombre_comercial} ({top.presentacion}) con {top.stock_disponible} pzas en stock."
    elif any(s.tipo_sustitucion == "MISMA_SUSTANCIA_OTRA_PRESENTACION" for s in sugerencias):
        top = next(s for s in sugerencias if s.tipo_sustitucion == "MISMA_SUSTANCIA_OTRA_PRESENTACION")
        respuesta = (
            f"🟡 No hay existencia exacta de lo solicitado; contamos con {top.nombre_comercial} ({top.presentacion}) "
            f"de la misma sustancia ({top.sustancia_activa}). El farmacéutico debe confirmar la dosis/presentación."
        )
    elif sugerencias:
        respuesta = (
            f"🔴 No hay existencia de {nombre_ref} en la vía o presentación solicitada. "
            "Sugiera al cliente consultar a su médico antes de cambiar de vía o sustancia."
        )
    else:
        respuesta = f"No contamos con existencia ni alternativas validadas en inventario para '{consulta_raw}'."

    return IaConsultaOut(
        pregunta=consulta_raw,
        respuesta_ia=respuesta,
        producto_consultado=nombre_ref,
        disponible_en_stock=len(disponibles_exactos) > 0,
        sustitutos_en_stock=sugerencias,
        aviso_sanitario=AVISO_SANITARIO_OBLIGATORIO,
    )


@router.post("/consulta-medicamento", response_model=IaConsultaOut)
@router.post("/v2/consulta-medicamento", response_model=IaConsultaOut)
def consultar_medicamento_ia(
    payload: IaConsultaInput,
    request: Request,
    usuario: Optional[Usuario] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    client_ip = request.client.host if request.client else "unknown"
    rate_limiter.check_endpoint(f"ia:{client_ip}", max_requests=30, window_sec=60)
    return _ejecutar_consulta_ia(payload, usuario, db)


@router.get("/pendientes")
def listar_pendientes_clasificacion(
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    """Panel del farmacéutico: sustancias PENDIENTE y pares sin validar."""
    _asegurar_datos_estructurados(db)
    pendientes = (
        db.query(Sustancia)
        .filter(Sustancia.estado_clasificacion == "PENDIENTE")
        .order_by(Sustancia.consultas_recibidas.desc(), Sustancia.created_at.asc())
        .all()
    )
    todas = db.query(Sustancia).all()
    pares_sin_validar = (
        db.query(ParSustitucion)
        .filter((ParSustitucion.validado_por.is_(None)) | (ParSustitucion.validado_por == ""))
        .all()
    )

    salida_pendientes = []
    for s in pendientes:
        candidatas_atc = []
        if s.codigo_atc and len(s.codigo_atc) >= 5:
            prefijo = s.codigo_atc[:5]
            candidatas_atc = [
                o.nombre_normalizado
                for o in todas
                if o.id != s.id and o.codigo_atc and o.codigo_atc.startswith(prefijo)
            ]
        salida_pendientes.append({
            "id": s.id,
            "nombre_normalizado": s.nombre_normalizado,
            "codigo_atc": s.codigo_atc,
            "consultas_recibidas": s.consultas_recibidas,
            "candidatas_mismo_atc_nivel4": candidatas_atc,
            "created_at": s.created_at.isoformat(),
        })

    return {
        "sustancias_pendientes": salida_pendientes,
        "pares_sin_validar": [
            {
                "id": p.id,
                "sustancia_origen": p.sustancia_origen,
                "sustancia_alternativa": p.sustancia_alternativa,
            }
            for p in pares_sin_validar
        ],
    }


@router.post("/sustancias/{sustancia_id}/clasificar")
def clasificar_sustancia(
    sustancia_id: int,
    payload: SustanciaClasificarInput,
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    sust = db.query(Sustancia).filter(Sustancia.id == sustancia_id).first()
    if not sust:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sustancia no encontrada")
    sust.codigo_atc = payload.codigo_atc
    sust.grupo_farmacopea = payload.grupo_farmacopea
    sust.requiere_receta_por_defecto = payload.requiere_receta_por_defecto
    sust.estado_clasificacion = "CLASIFICADA"
    sust.clasificado_por = payload.clasificado_por
    sust.fecha_clasificacion = datetime.datetime.utcnow()

    for tarea in sust.tareas:
        tarea.estado = "COMPLETADA"

    db.commit()
    return {"id": sust.id, "nombre_normalizado": sust.nombre_normalizado, "estado_clasificacion": sust.estado_clasificacion}


@router.post("/pares", status_code=status.HTTP_201_CREATED)
def crear_par_sustitucion(
    payload: ParSustitucionCreateInput,
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    orig = normalizar_sustancia_exacta(payload.sustancia_origen)
    alt = normalizar_sustancia_exacta(payload.sustancia_alternativa)
    par = ParSustitucion(
        sustancia_origen=orig,
        sustancia_alternativa=alt,
        nivel="CONSULTAR_MEDICO",
        advertencias=json.dumps(payload.advertencias, ensure_ascii=False),
        validado_por=payload.validado_por,
        fecha_validacion=datetime.datetime.utcnow() if payload.validado_por else None,
    )
    db.add(par)
    db.commit()
    db.refresh(par)
    return {
        "id": par.id,
        "sustancia_origen": par.sustancia_origen,
        "sustancia_alternativa": par.sustancia_alternativa,
        "validado_por": par.validado_por,
    }
