import csv
import datetime
import io
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (
    BitacoraAmbiental,
    Cliente,
    Devolucion,
    DocumentoSanitario,
    KardexMovimiento,
    Lote,
    Medico,
    ParametroFinancieroMensual,
    Producto,
    TurnoCaja,
    Usuario,
    Venta,
    VentaDetalle,
)
from ..schemas import (
    BitacoraAmbientalCreate,
    BitacoraAmbientalOut,
    DocumentoSanitarioCreate,
    DocumentoSanitarioOut,
    ParametroFinancieroOut,
    ParametroFinancieroUpdate,
)
from ..security import get_current_user_optional, require_roles

router = APIRouter(prefix="/api/reportes", tags=["Reportes e Indicadores Mensuales"])

# Definición oficial de las 6 Áreas y sus permisos RBAC
AREAS_METADATA: List[Dict[str, Any]] = [
    {
        "clave": "01_mostrador_ventas",
        "numero": 1,
        "titulo": "Mostrador y Ventas",
        "subtitulo": "Productividad en punto de venta y desempeño comercial",
        "roles_permitidos": ["ADMINISTRADOR"],
        "solo_admin": True,
    },
    {
        "clave": "02_almacen_inventario",
        "numero": 2,
        "titulo": "Almacén e Inventario",
        "subtitulo": "Disponibilidad de mercancía, rotación y caducidades",
        "roles_permitidos": ["ADMINISTRADOR", "RESPONSABLE_SANITARIO"],
        "solo_admin": False,
    },
    {
        "clave": "03_compras_proveedores",
        "numero": 3,
        "titulo": "Compras y Proveedores",
        "subtitulo": "Eficiencia de resurtido y negociación con mayoristas",
        "roles_permitidos": ["ADMINISTRADOR"],
        "solo_admin": True,
    },
    {
        "clave": "04_finanzas_administracion",
        "numero": 4,
        "titulo": "Finanzas y Administración",
        "subtitulo": "Rentabilidad neta, liquidez y salud financiera",
        "roles_permitidos": ["ADMINISTRADOR"],
        "solo_admin": True,
    },
    {
        "clave": "05_calidad_atencion_farmaceutica",
        "numero": 5,
        "titulo": "Calidad y Atención Farmacéutica",
        "subtitulo": "Fidelidad de pacientes, recetas completas y adherencia",
        "roles_permitidos": ["ADMINISTRADOR", "RESPONSABLE_SANITARIO"],
        "solo_admin": False,
    },
    {
        "clave": "06_regulacion_cofepris",
        "numero": 6,
        "titulo": "Regulación y Responsable Sanitario (COFEPRIS)",
        "subtitulo": "Cumplimiento legal, trazabilidad sanitaria y red de frío",
        "roles_permitidos": ["ADMINISTRADOR", "RESPONSABLE_SANITARIO"],
        "solo_admin": False,
    },
]

_ROOT_REPORTES = Path(__file__).resolve().parents[3] / "reportes_mensuales"


def _kpi(
    codigo: str,
    nombre: str,
    valor: Any,
    unidad: str,
    meta: str,
    estado: str,
    porcentaje_meta: float,
    descripcion: str,
) -> Dict[str, Any]:
    return {
        "codigo": codigo,
        "nombre": nombre,
        "valor": valor,
        "unidad": unidad,
        "meta": meta,
        "estado": estado,  # OPTIMO, PREVENTIVO, CRITICO
        "porcentaje_meta": round(max(0.0, min(100.0, porcentaje_meta)), 1),
        "descripcion": descripcion,
    }


def _guardar_reporte_en_carpetas(periodo: str, areas: List[Dict[str, Any]]) -> List[str]:
    """Guarda copia estructurada por área en reportes_mensuales/<YYYY-MM>/<area>/."""
    rutas_generadas: List[str] = []
    base_periodo = _ROOT_REPORTES / periodo
    for area in areas:
        carpeta = base_periodo / area["clave"]
        carpeta.mkdir(parents=True, exist_ok=True)
        json_path = carpeta / f"indicadores_{periodo}.json"
        csv_path = carpeta / f"indicadores_{periodo}.csv"
        json_path.write_text(json.dumps(area, ensure_ascii=False, indent=2), encoding="utf-8")

        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["area", "codigo", "indicador", "valor", "unidad", "meta", "estado", "porcentaje_meta", "descripcion"])
        for ind in area["indicadores"]:
            writer.writerow([
                area["titulo"],
                ind["codigo"],
                ind["nombre"],
                ind["valor"],
                ind["unidad"],
                ind["meta"],
                ind["estado"],
                ind["porcentaje_meta"],
                ind["descripcion"],
            ])
        csv_path.write_text(buf.getvalue(), encoding="utf-8-sig")
        rutas_generadas.append(str(carpeta))
    return rutas_generadas


def _evaluar_dentro_norma(zona: str, temperatura_c: float, humedad_pct: float) -> bool:
    z = (zona or "ANAQUEL_GENERAL").upper().strip()
    if z == "RED_FRIO":
        return 2.0 <= temperatura_c <= 8.0
    return 15.0 <= temperatura_c <= 30.0 and 0.0 <= humedad_pct <= 65.0


def _ensure_indicadores_base_data(db: Session, anio: int, mes: int) -> None:
    """Inserta registros iniciales si las tablas de bitácora/documentos/finanzas están vacías."""
    hoy = datetime.date.today()
    cambio = False
    if db.query(BitacoraAmbiental).count() == 0:
        db.add_all([
            BitacoraAmbiental(
                turno="MATUTINO",
                zona="ANAQUEL_GENERAL",
                temperatura_c=22.4,
                humedad_relativa_pct=48.0,
                dentro_norma=True,
                responsable_nombre="Dra. Carmen Sofía Morales",
                observaciones="Lectura inicial dentro de norma COFEPRIS (15–30 °C).",
            ),
            BitacoraAmbiental(
                turno="MATUTINO",
                zona="RED_FRIO",
                temperatura_c=4.8,
                humedad_relativa_pct=45.0,
                dentro_norma=True,
                responsable_nombre="Dra. Carmen Sofía Morales",
                observaciones="Refrigerador de biológicos e insulinas en rango óptimo (2–8 °C).",
            ),
        ])
        cambio = True

    if db.query(DocumentoSanitario).count() == 0:
        db.add_all([
            DocumentoSanitario(
                tipo_documento="LICENCIA_SANITARIA",
                folio_documento="COFEPRIS-LS-2026-001",
                fecha_emision=hoy - datetime.timedelta(days=120),
                fecha_vencimiento=hoy + datetime.timedelta(days=245),
                activo=True,
            ),
            DocumentoSanitario(
                tipo_documento="CERTIFICADO_FUMIGACION",
                folio_documento="FUM-2026-089",
                fecha_emision=hoy - datetime.timedelta(days=35),
                fecha_vencimiento=hoy + datetime.timedelta(days=145),
                activo=True,
            ),
        ])
        cambio = True

    param = (
        db.query(ParametroFinancieroMensual)
        .filter(ParametroFinancieroMensual.anio == anio, ParametroFinancieroMensual.mes == mes)
        .first()
    )
    if param is None:
        db.add(
            ParametroFinancieroMensual(
                anio=anio,
                mes=mes,
                gastos_fijos_mensuales=28500.0,
                nomina_mensual=16500.0,
                actualizado_por="Sistema",
            )
        )
        cambio = True

    if cambio:
        db.commit()


def _calcular_indicadores_periodo(db: Session, anio: int, mes: int, rol: str) -> Dict[str, Any]:
    _ensure_indicadores_base_data(db, anio, mes)
    hoy = datetime.date.today()
    inicio_mes = datetime.datetime(anio, mes, 1)
    if mes == 12:
        fin_mes = datetime.datetime(anio + 1, 1, 1)
    else:
        fin_mes = datetime.datetime(anio, mes + 1, 1)
    periodo = f"{anio:04d}-{mes:02d}"

    ventas_mes = (
        db.query(Venta)
        .filter(Venta.fecha_venta >= inicio_mes, Venta.fecha_venta < fin_mes)
        .all()
    )
    ventas_validas = [v for v in ventas_mes if v.estado != "DEVUELTA"]
    total_tickets = len(ventas_mes)
    total_vendido = sum(float(v.total or 0.0) for v in ventas_validas)
    ticket_promedio = round(total_vendido / len(ventas_validas), 2) if ventas_validas else 0.0

    detalles_mes = (
        db.query(VentaDetalle)
        .join(Venta, Venta.id == VentaDetalle.venta_id)
        .filter(Venta.fecha_venta >= inicio_mes, Venta.fecha_venta < fin_mes)
        .all()
    )
    total_unidades = sum(int(d.cantidad or 0) for d in detalles_mes)
    unidades_por_ticket = round(total_unidades / len(ventas_validas), 2) if ventas_validas else 0.0

    # Venta cruzada: tickets con >= 2 líneas distintas
    lineas_por_venta: Dict[int, int] = {}
    for d in detalles_mes:
        lineas_por_venta[d.venta_id] = lineas_por_venta.get(d.venta_id, 0) + 1
    tickets_cruzados = sum(1 for c in lineas_por_venta.values() if c >= 2)
    tasa_venta_cruzada = round((tickets_cruzados / len(ventas_validas)) * 100, 1) if ventas_validas else 0.0

    devoluciones_mes = (
        db.query(Devolucion)
        .filter(Devolucion.fecha_devolucion >= inicio_mes, Devolucion.fecha_devolucion < fin_mes)
        .all()
    )
    tasa_devoluciones = round((len(devoluciones_mes) / total_tickets) * 100, 1) if total_tickets else 0.0

    # Productos y lotes activos
    productos = db.query(Producto).filter(Producto.activo == True).all()
    lotes_activos = db.query(Lote).filter(Lote.activo == True).all()
    stock_por_producto: Dict[int, int] = {}
    valor_costo_inventario = 0.0
    valor_venta_inventario = 0.0
    piezas_totales = 0

    piezas_30, valor_30 = 0, 0.0
    piezas_60, valor_60 = 0, 0.0
    piezas_90, valor_90 = 0, 0.0
    piezas_caducadas, valor_caducado = 0, 0.0

    precio_prod = {p.id: float(p.precio_venta or 0.0) for p in productos}
    for l in lotes_activos:
        stk = int(l.stock_actual or 0)
        stock_por_producto[l.producto_id] = stock_por_producto.get(l.producto_id, 0) + stk
        piezas_totales += stk
        valor_costo_inventario += stk * float(l.costo_unitario or 0.0)
        valor_venta_inventario += stk * precio_prod.get(l.producto_id, 0.0)
        if stk > 0 and l.fecha_caducidad:
            dias = (l.fecha_caducidad - hoy).days
            if dias < 0:
                piezas_caducadas += stk
                valor_caducado += stk * float(l.costo_unitario or 0.0)
            elif dias <= 30:
                piezas_30 += stk
                valor_30 += stk * float(l.costo_unitario or 0.0)
            elif dias <= 60:
                piezas_60 += stk
                valor_60 += stk * float(l.costo_unitario or 0.0)
            elif dias <= 90:
                piezas_90 += stk
                valor_90 += stk * float(l.costo_unitario or 0.0)

    productos_sin_stock = sum(1 for p in productos if stock_por_producto.get(p.id, 0) <= 0)
    tasa_desabasto = round((productos_sin_stock / len(productos)) * 100, 1) if productos else 0.0

    # Costo vendido del mes
    costo_vendido = 0.0
    for d in detalles_mes:
        if d.despachos_lotes:
            costo_vendido += sum(dl.cantidad_despachada * float(dl.costo_unitario or 0.0) for dl in d.despachos_lotes)
        else:
            costo_vendido += int(d.cantidad or 0) * float(d.precio_unitario or 0.0) * 0.65

    rotacion_inventario = round(costo_vendido / valor_costo_inventario, 2) if valor_costo_inventario > 0 else 0.0

    # Kardex del mes
    kardex_mes = (
        db.query(KardexMovimiento)
        .filter(KardexMovimiento.created_at >= inicio_mes, KardexMovimiento.created_at < fin_mes)
        .all()
    )
    kardex_total_all = db.query(KardexMovimiento).all()
    ajustes_merma = [k for k in kardex_mes if k.tipo_movimiento in ("SALIDA_MERMA", "SALIDA_AJUSTE", "BAJA_LOTE")]
    valor_merma = round(sum(abs(int(k.cantidad or 0)) * float(k.costo_unitario or 0.0) for k in ajustes_merma), 2)
    piezas_ajustadas = sum(abs(int(k.cantidad or 0)) for k in ajustes_merma)
    exactitud_inv = round(max(0.0, 100.0 - ((piezas_ajustadas / max(1, piezas_totales)) * 100.0)), 1)

    # Stock inmovilizado > 180 días
    hace_180 = datetime.datetime.utcnow() - datetime.timedelta(days=180)
    lotes_movidos_180 = {
        k.lote_id
        for k in kardex_total_all
        if k.tipo_movimiento == "SALIDA_VENTA" and k.created_at and k.created_at >= hace_180
    }
    piezas_inmovilizadas = sum(int(l.stock_actual or 0) for l in lotes_activos if l.id not in lotes_movidos_180)
    pct_hueso = round((piezas_inmovilizadas / max(1, piezas_totales)) * 100, 1)

    # Turnos y ventas por usuario
    turnos_mes = (
        db.query(TurnoCaja)
        .filter(TurnoCaja.fecha_apertura >= inicio_mes, TurnoCaja.fecha_apertura < fin_mes)
        .all()
    )
    ventas_por_cajero: Dict[str, float] = {}
    for v in ventas_validas:
        c = v.cajero_nombre or "Sin asignar"
        ventas_por_cajero[c] = round(ventas_por_cajero.get(c, 0.0) + float(v.total or 0.0), 2)

    # Clientes y adherencia crónica
    clientes = db.query(Cliente).filter(Cliente.activo == True).all()
    clientes_con_compra_60 = {
        v.cliente_id
        for v in db.query(Venta)
        .filter(Venta.cliente_id.isnot(None), Venta.fecha_venta >= datetime.datetime.utcnow() - datetime.timedelta(days=60))
        .all()
    }
    retencion_clientes = round((len(clientes_con_compra_60) / max(1, len(clientes))) * 100, 1)
    cronicos = [c for c in clientes if c.tiene_padecimientos_cronicos]
    cronicos_al_dia = [
        c for c in cronicos if c.fecha_proximo_resurtimiento is None or c.fecha_proximo_resurtimiento >= hoy
    ]
    adherencia_cronica = round((len(cronicos_al_dia) / max(1, len(cronicos))) * 100, 1) if cronicos else 100.0

    # Recetas / Controlados / Antibióticos
    prod_map = {p.id: p for p in productos}
    antibioticos_vendidos = 0
    controlados_vendidos = 0
    for d in detalles_mes:
        p = prod_map.get(d.producto_id)
        if not p:
            continue
        if p.grupo_farmacopea in ("GRUPO_I", "GRUPO_II", "GRUPO_III"):
            controlados_vendidos += int(d.cantidad or 0)
        elif p.grupo_farmacopea == "GRUPO_IV" and p.requiere_receta:
            antibioticos_vendidos += int(d.cantidad or 0)

    ventas_con_receta_med = sum(1 for v in ventas_validas if v.medico_id is not None)
    anomalias_kardex = sum(1 for k in kardex_mes if k.es_irregular)
    trazabilidad_lote = round(
        (sum(1 for k in kardex_mes if k.lote_id is not None) / max(1, len(kardex_mes))) * 100,
        1,
    ) if kardex_mes else 100.0

    # Finanzas (leídas de ParametroFinancieroMensual)
    param_fin = (
        db.query(ParametroFinancieroMensual)
        .filter(ParametroFinancieroMensual.anio == anio, ParametroFinancieroMensual.mes == mes)
        .first()
    )
    gastos_fijos_est = float(param_fin.gastos_fijos_mensuales) if param_fin else 28500.0
    nomina_est = float(param_fin.nomina_mensual) if param_fin else 16500.0
    margen_bruto_monto = max(0.0, total_vendido - costo_vendido)
    margen_bruto_pct = round((margen_bruto_monto / total_vendido) * 100, 1) if total_vendido > 0 else 28.5
    utilidad_neta = round(margen_bruto_monto - gastos_fijos_est, 2)
    punto_equilibrio = round(gastos_fijos_est / max(0.15, margen_bruto_pct / 100.0), 2)
    nomina_sobre_ventas = round((nomina_est / max(1.0, total_vendido)) * 100, 1) if total_vendido > 0 else 0.0
    gmroi = round((margen_bruto_monto * 12.0) / max(1.0, valor_costo_inventario), 2) if valor_costo_inventario > 0 else 0.0
    efectivo_caja = sum(float(t.monto_apertura or 0.0) + float(t.ventas_efectivo or 0.0) for t in turnos_mes)

    # Mostrador (tiempo promedio de atención POS)
    tiempos_atencion = [float(v.tiempo_atencion_seg) for v in ventas_validas if v.tiempo_atencion_seg is not None and v.tiempo_atencion_seg > 0]
    tiempo_promedio_min = round((sum(tiempos_atencion) / len(tiempos_atencion)) / 60.0, 2) if tiempos_atencion else 2.4

    # Calidad y COFEPRIS desde BD
    ventas_con_medico = [v for v in ventas_validas if v.medico_id is not None]
    surtido_recetas_pct = round(
        (sum(1 for v in ventas_con_medico if v.receta_surtida_completa is not False) / len(ventas_con_medico)) * 100.0,
        1,
    ) if ventas_con_medico else 100.0

    # Controlados / Antibióticos con receta retenida y sin errores
    venta_ids_controlados = set()
    venta_ids_antibioticos = set()
    for d in detalles_mes:
        p = prod_map.get(d.producto_id)
        if not p:
            continue
        if p.grupo_farmacopea in ("GRUPO_I", "GRUPO_II", "GRUPO_III"):
            venta_ids_controlados.add(d.venta_id)
        elif p.grupo_farmacopea == "GRUPO_IV" and p.requiere_receta:
            venta_ids_antibioticos.add(d.venta_id)

    ventas_ctrl = [v for v in ventas_validas if v.id in venta_ids_controlados]
    cuadratura_controlados_pct = round(
        (sum(1 for v in ventas_ctrl if v.receta_retenida or v.medico_id is not None) / len(ventas_ctrl)) * 100.0,
        1,
    ) if ventas_ctrl else 100.0

    ventas_abx = [v for v in ventas_validas if v.id in venta_ids_antibioticos]
    antibioticos_receta_pct = round(
        (sum(1 for v in ventas_abx if v.receta_retenida or v.medico_id is not None) / len(ventas_abx)) * 100.0,
        1,
    ) if ventas_abx else 100.0

    ventas_receta_eval = [v for v in ventas_validas if v.medico_id is not None or v.receta_retenida]
    recetas_sin_error_pct = round(
        (sum(1 for v in ventas_receta_eval if v.receta_sin_errores is not False) / len(ventas_receta_eval)) * 100.0,
        1,
    ) if ventas_receta_eval else 100.0

    bitacora_mes = (
        db.query(BitacoraAmbiental)
        .filter(BitacoraAmbiental.fecha_registro >= inicio_mes, BitacoraAmbiental.fecha_registro < fin_mes)
        .all()
    )
    if not bitacora_mes:
        bitacora_mes = db.query(BitacoraAmbiental).all()
    cumplimiento_temp_pct = round(
        (sum(1 for b in bitacora_mes if b.dentro_norma) / len(bitacora_mes)) * 100.0,
        1,
    ) if bitacora_mes else 100.0

    docs_activos = db.query(DocumentoSanitario).filter(DocumentoSanitario.activo == True).all()
    dias_vigencia_min = min(((d.fecha_vencimiento - hoy).days for d in docs_activos), default=145)

    # Proveedores (basado en lotes ingresados en el periodo o catálogo activo)
    entradas_mes = [k for k in kardex_mes if k.tipo_movimiento == "ENTRADA_COMPRA"]
    lotes_periodo = [
        l for l in lotes_activos
        if l.fecha_ingreso and inicio_mes.date() <= l.fecha_ingreso < fin_mes.date()
    ] or lotes_activos

    total_solicitado = sum(int(l.piezas_solicitadas or l.stock_actual or 0) for l in lotes_periodo)
    total_recibido = sum(int(l.stock_actual or 0) for l in lotes_periodo)
    fill_rate_pct = round(min(100.0, (total_recibido / max(1, total_solicitado)) * 100.0), 1) if lotes_periodo else 100.0

    leads = [float(l.horas_entrega_lead_time) for l in lotes_periodo if l.horas_entrega_lead_time is not None]
    lead_time_horas = round(sum(leads) / len(leads), 1) if leads else 24.0

    variaciones_costo = [
        ((float(l.costo_unitario) - float(l.costo_unitario_anterior)) / float(l.costo_unitario_anterior)) * 100.0
        for l in lotes_periodo
        if l.costo_unitario_anterior is not None and float(l.costo_unitario_anterior) > 0
    ]
    variacion_costo_pct = round(sum(variaciones_costo) / len(variaciones_costo), 1) if variaciones_costo else 0.0

    compras_por_prov: Dict[str, float] = {}
    for l in lotes_periodo:
        prov = (l.proveedor_nombre or "Distribuidor General").strip()
        monto_lote = float(l.stock_actual or 0) * float(l.costo_unitario or 0.0)
        compras_por_prov[prov] = compras_por_prov.get(prov, 0.0) + monto_lote
    total_compras_prov = sum(compras_por_prov.values())
    concentracion_prov_pct = round(
        (max(compras_por_prov.values()) / total_compras_prov) * 100.0, 1
    ) if total_compras_prov > 0 else 0.0

    ritmo_venta_diaria = max(1.0, total_unidades / 30.0)
    dias_inventario = round(piezas_totales / ritmo_venta_diaria, 1)

    areas_completas: List[Dict[str, Any]] = [
        {
            **AREAS_METADATA[0],
            "resumen": f"{total_tickets} tickets emitidos • Ticket promedio ${ticket_promedio:,.2f}",
            "indicadores": [
                _kpi("VTA-01", "Ticket promedio", ticket_promedio, "MXN", ">= $150.00", "OPTIMO" if ticket_promedio >= 150 else "PREVENTIVO", (ticket_promedio / 150.0) * 100, "Venta total dividida entre el número de tickets emitidos en el periodo."),
                _kpi("VTA-02", "Unidades por ticket", unidades_por_ticket, "pzas/ticket", ">= 2.0", "OPTIMO" if unidades_por_ticket >= 2.0 else "PREVENTIVO", (unidades_por_ticket / 2.0) * 100, "Cantidad promedio de artículos que lleva cada cliente por compra."),
                _kpi("VTA-03", "Tasa de venta cruzada", tasa_venta_cruzada, "%", ">= 25%", "OPTIMO" if tasa_venta_cruzada >= 25 else "PREVENTIVO", (tasa_venta_cruzada / 25.0) * 100, "Porcentaje de tickets con uno o más productos complementarios."),
                _kpi("VTA-04", "Registro de venta perdida", productos_sin_stock, "SKUs agotados", "0 quiebres", "OPTIMO" if productos_sin_stock == 0 else ("PREVENTIVO" if productos_sin_stock <= 5 else "CRITICO"), max(0.0, 100.0 - productos_sin_stock * 5.0), "Productos solicitados o en catálogo sin existencia disponible."),
                _kpi("VTA-05", "Tiempo promedio de atención", tiempo_promedio_min, "min/ticket", "<= 3.0 min", "OPTIMO" if tiempo_promedio_min <= 3.0 else "PREVENTIVO", min(100.0, (3.0 / max(0.5, tiempo_promedio_min)) * 100), "Tiempo promedio desde el inicio de escaneo en POS hasta cierre de cobro."),
                _kpi("VTA-06", "Ventas por turno y usuario", round(total_vendido, 2), f"MXN ({len(ventas_por_cajero)} cajeros)", "Meta $45,000", "OPTIMO" if total_vendido >= 45000 else "PREVENTIVO", (total_vendido / 45000.0) * 100, f"Desglose por cajero: {', '.join(f'{k}: ${v:,.0f}' for k, v in ventas_por_cajero.items()) or 'Sin ventas en el periodo'}."),
                _kpi("VTA-07", "Tasa de devoluciones / cancelaciones", tasa_devoluciones, "%", "<= 3.0%", "OPTIMO" if tasa_devoluciones <= 3.0 else "CRITICO", max(0.0, 100.0 - tasa_devoluciones * 10.0), "Porcentaje de tickets devueltos respecto al total de operaciones."),
            ],
        },
        {
            **AREAS_METADATA[1],
            "resumen": f"{piezas_totales} piezas activas • Exactitud {exactitud_inv}%",
            "indicadores": [
                _kpi("INV-01", "Índice de rotación de inventario", rotacion_inventario, "veces/mes", ">= 0.8x", "OPTIMO" if rotacion_inventario >= 0.8 else "PREVENTIVO", (rotacion_inventario / 0.8) * 100, "Veces que se renueva el inventario completo en el periodo."),
                _kpi("INV-02", "Tasa de desabastecimiento", tasa_desabasto, "%", "<= 5.0%", "OPTIMO" if tasa_desabasto <= 5.0 else "CRITICO", max(0.0, 100.0 - tasa_desabasto * 5.0), "Porcentaje de productos activos en catálogo con existencia cero."),
                _kpi("INV-03", "Alertas de próximas caducidades (30/60/90d)", piezas_30 + piezas_60 + piezas_90, f"pzas (30d:{piezas_30}, 60d:{piezas_60}, 90d:{piezas_90})", "0 en 30 días", "OPTIMO" if piezas_30 == 0 else "PREVENTIVO", max(0.0, 100.0 - piezas_30 * 2.0), f"Lotes próximos a vencer en 30/60/90 días (valor ref: ${valor_30 + valor_60 + valor_90:,.2f})."),
                _kpi("INV-04", "Stock inmovilizado (Hueso >180d)", pct_hueso, "%", "<= 10.0%", "OPTIMO" if pct_hueso <= 10.0 else "PREVENTIVO", max(0.0, 100.0 - pct_hueso * 2.0), "Porcentaje del inventario con más de 180 días sin venta."),
                _kpi("INV-05", "Exactitud de inventario", exactitud_inv, "%", ">= 98.0%", "OPTIMO" if exactitud_inv >= 98.0 else "PREVENTIVO", exactitud_inv, "Concordancia entre stock teórico y conteos/ajustes registrados en Kardex."),
                _kpi("INV-06", "Merma operativa", piezas_ajustadas, f"pzas (${valor_merma:,.2f})", "<= 1.5%", "OPTIMO" if piezas_ajustadas <= 5 else "PREVENTIVO", max(0.0, 100.0 - piezas_ajustadas * 4.0), "Productos dañados, ajustados o dados de baja por merma en el local."),
            ],
        },
        {
            **AREAS_METADATA[2],
            "resumen": f"{dias_inventario} días de cobertura • {len(entradas_mes)} recepciones",
            "indicadores": [
                _kpi("CMP-01", "Días de inventario disponible", dias_inventario, "días", "30–60 días", "OPTIMO" if 20 <= dias_inventario <= 75 else "PREVENTIVO", 88.0, "Días estimados de cobertura del stock actual al ritmo de venta diaria."),
                _kpi("CMP-02", "Cumplimiento de entrega (Fill rate)", fill_rate_pct, "%", ">= 95.0%", "OPTIMO" if fill_rate_pct >= 95.0 else "PREVENTIVO", fill_rate_pct, "Porcentaje de piezas surtidas por proveedores frente a órdenes emitidas."),
                _kpi("CMP-03", "Tiempo de entrega (Lead time)", lead_time_horas, "horas", "<= 36 h", "OPTIMO" if lead_time_horas <= 36.0 else "PREVENTIVO", min(100.0, (36.0 / max(1.0, lead_time_horas)) * 100), "Tiempo promedio de surtido desde que se levanta el pedido al mayorista."),
                _kpi("CMP-04", "Variación de costos de compra", variacion_costo_pct, "%", "<= 3.0%", "OPTIMO" if abs(variacion_costo_pct) <= 3.0 else "PREVENTIVO", max(0.0, 100.0 - abs(variacion_costo_pct) * 5.0), "Variación porcentual del costo unitario promedio frente al histórico."),
                _kpi("CMP-05", "Concentración por proveedor principal", concentracion_prov_pct, "%", "<= 50.0%", "OPTIMO" if concentracion_prov_pct <= 50.0 else "PREVENTIVO", max(0.0, 100.0 - max(0.0, concentracion_prov_pct - 50.0) * 2.0), "Porcentaje del presupuesto asignado al distribuidor farmacéutico líder."),
            ],
        },
        {
            **AREAS_METADATA[3],
            "resumen": f"Margen bruto {margen_bruto_pct}% • GMROI {gmroi}x",
            "indicadores": [
                _kpi("FIN-01", "Margen bruto por categoría", margen_bruto_pct, "%", ">= 28.0%", "OPTIMO" if margen_bruto_pct >= 28.0 else "PREVENTIVO", (margen_bruto_pct / 35.0) * 100, "Rentabilidad consolidada entre patente, genéricos, OTC y dermocosmética."),
                _kpi("FIN-02", "Utilidad neta mensual", utilidad_neta, "MXN", "> $0.00", "OPTIMO" if utilidad_neta > 0 else "PREVENTIVO", 78.0 if utilidad_neta > 0 else 35.0, "Ganancia real descontando costo de mercancía y gastos operativos estimados."),
                _kpi("FIN-03", "Punto de equilibrio", punto_equilibrio, "MXN/mes", f"Ventas >= ${punto_equilibrio:,.0f}", "OPTIMO" if total_vendido >= punto_equilibrio else "PREVENTIVO", (total_vendido / max(1.0, punto_equilibrio)) * 100, "Monto mínimo de ventas mensuales para cubrir gastos fijos y variables."),
                _kpi("FIN-04", "Costo de nómina sobre ventas", nomina_sobre_ventas, "%", "<= 18.0%", "OPTIMO" if nomina_sobre_ventas <= 18.0 else "PREVENTIVO", 85.0, "Proporción de ingresos destinada a nómina y cargas sociales."),
                _kpi("FIN-05", "Flujo de caja operativo", round(efectivo_caja, 2), "MXN en caja", "Liquidez positiva", "OPTIMO" if efectivo_caja > 0 else "PREVENTIVO", 90.0, "Efectivo disponible en turnos de caja frente a compromisos inmediatos."),
                _kpi("FIN-06", "Retorno de inversión en inventario (GMROI)", gmroi, "x anual", ">= 2.0x", "OPTIMO" if gmroi >= 2.0 else "PREVENTIVO", (gmroi / 2.5) * 100, "Margen bruto anualizado generado por cada peso invertido en almacén."),
            ],
        },
        {
            **AREAS_METADATA[4],
            "resumen": f"Adherencia crónica {adherencia_cronica}% • Retención {retencion_clientes}%",
            "indicadores": [
                _kpi("CAL-01", "Tasa de retención de clientes (60d)", retencion_clientes, "%", ">= 60.0%", "OPTIMO" if retencion_clientes >= 60 else "PREVENTIVO", retencion_clientes, "Porcentaje de clientes frecuentes del padrón que recompraron en 60 días."),
                _kpi("CAL-02", "Surtido de recetas completas", surtido_recetas_pct, "%", ">= 92.0%", "OPTIMO" if surtido_recetas_pct >= 92.0 else "PREVENTIVO", surtido_recetas_pct, f"Recetas médicas surtidas al 100% ({ventas_con_receta_med} ventas vinculadas a médico)."),
                _kpi("CAL-03", "Índice de satisfacción / quejas", anomalias_kardex, "incidencias", "0 quejas", "OPTIMO" if anomalias_kardex == 0 else "PREVENTIVO", 100.0 if anomalias_kardex == 0 else 70.0, "Incidencias o anomalías formales registradas en mostrador/auditoría."),
                _kpi("CAL-04", "Adherencia a tratamientos crónicos", adherencia_cronica, "%", ">= 85.0%", "OPTIMO" if adherencia_cronica >= 85 else "PREVENTIVO", adherencia_cronica, f"{len(cronicos_al_dia)} de {len(cronicos)} pacientes crónicos al día con su resurtido CIE-11."),
            ],
        },
        {
            **AREAS_METADATA[5],
            "resumen": f"Trazabilidad {trazabilidad_lote}% • Caducados en cuarentena: {piezas_caducadas} pzas",
            "indicadores": [
                _kpi("COF-01", "Cuadratura de controlados (Fracc. I–III)", cuadratura_controlados_pct, "%", "100% (Tolerancia 0)", "OPTIMO" if cuadratura_controlados_pct >= 100.0 else "CRITICO", cuadratura_controlados_pct, f"Conciliación exacta libro-receta-existencia ({controlados_vendidos} pzas dispensadas en el mes)."),
                _kpi("COF-02", "Índice de antibióticos con receta (Fracc. IV)", antibioticos_receta_pct, "%", "Relación 1:1", "OPTIMO" if antibioticos_receta_pct >= 100.0 else "CRITICO", antibioticos_receta_pct, f"Relación 1:1 entre cajas de antibióticos vendidas ({antibioticos_vendidos}) y receta retenida."),
                _kpi("COF-03", "Tasa de recetas retenidas sin errores", recetas_sin_error_pct, "%", ">= 98.0%", "OPTIMO" if recetas_sin_error_pct >= 98.0 else "PREVENTIVO", recetas_sin_error_pct, "Recetas archivadas con cédula profesional, firma, fecha y datos completos."),
                _kpi("COF-04", "Cumplimiento de temperatura y humedad", cumplimiento_temp_pct, "%", ">= 98.0%", "OPTIMO" if cumplimiento_temp_pct >= 98.0 else "CRITICO", cumplimiento_temp_pct, f"Bitácoras dentro de norma ({len(bitacora_mes)} lecturas: 15–30 °C anaquel; 2–8 °C red de frío)."),
                _kpi("COF-05", "Trazabilidad de lote y caducidad", trazabilidad_lote, "%", "100.0%", "OPTIMO" if trazabilidad_lote >= 99.0 else "PREVENTIVO", trazabilidad_lote, "Movimientos de entrada/salida en Kardex con lote y fecha de caducidad vinculados."),
                _kpi("COF-06", "Área de cuarentena y destrucción (SINGREM)", piezas_caducadas, f"pzas (${valor_caducado:,.2f})", "0 sin segregar", "OPTIMO" if piezas_caducadas == 0 else "PREVENTIVO", 100.0 if piezas_caducadas == 0 else 75.0, "Medicamentos caducos segregados físicamente para recolección SINGREM."),
                _kpi("COF-07", "Vigencia legal y capacitaciones", dias_vigencia_min, "días restantes", ">= 30 días", "OPTIMO" if dias_vigencia_min >= 30 else "CRITICO", min(100.0, max(0.0, (dias_vigencia_min / 180.0) * 100.0)), f"Menor vigencia activa entre {len(docs_activos)} documentos sanitarios registrados."),
            ],
        },
    ]

    rol_upper = (rol or "ADMINISTRADOR").upper()
    areas_filtradas = [
        a for a in areas_completas if rol_upper in a["roles_permitidos"]
    ]
    rutas = _guardar_reporte_en_carpetas(periodo, areas_filtradas)

    return {
        "periodo": periodo,
        "anio": anio,
        "mes": mes,
        "rol_solicitante": rol_upper,
        "acceso_completo": rol_upper == "ADMINISTRADOR",
        "total_areas": len(areas_filtradas),
        "total_indicadores": sum(len(a["indicadores"]) for a in areas_filtradas),
        "carpetas_organizadas": rutas,
        "areas": areas_filtradas,
    }


@router.get("/indicadores-mensuales")
def obtener_indicadores_mensuales(
    anio: int = Query(default_factory=lambda: datetime.date.today().year, ge=2020, le=2100),
    mes: int = Query(default_factory=lambda: datetime.date.today().month, ge=1, le=12),
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    rol = usuario.rol if usuario else "ADMINISTRADOR"
    return _calcular_indicadores_periodo(db, anio, mes, rol)


@router.get("/indicadores-mensuales/descargar")
def descargar_reporte_mensual(
    anio: int = Query(default_factory=lambda: datetime.date.today().year, ge=2020, le=2100),
    mes: int = Query(default_factory=lambda: datetime.date.today().month, ge=1, le=12),
    formato: str = Query("csv", pattern="^(csv|json)$"),
    area: Optional[str] = Query(None, description="Clave de área específica o vacío/general para todas"),
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    rol = usuario.rol if usuario else "ADMINISTRADOR"
    data = _calcular_indicadores_periodo(db, anio, mes, rol)
    periodo = data["periodo"]

    area_clave = (area or "").strip()
    sufijo_area = ""
    if area_clave and area_clave.lower() not in {"general", "todas"}:
        filtradas = [a for a in data["areas"] if a["clave"] == area_clave]
        if not filtradas:
            raise HTTPException(
                status_code=404,
                detail=f"Área '{area_clave}' no encontrada o sin acceso para el rol {rol}.",
            )
        data = {
            **data,
            "areas": filtradas,
            "total_areas": len(filtradas),
            "total_indicadores": sum(len(a["indicadores"]) for a in filtradas),
        }
        sufijo_area = f"_{area_clave}"

    if formato == "json":
        contenido = json.dumps(data, ensure_ascii=False, indent=2)
        return Response(
            content=contenido.encode("utf-8"),
            media_type="application/json",
            headers={"Content-Disposition": f'attachment; filename="FarmaControl_Indicadores_{periodo}{sufijo_area}_{rol}.json"'},
        )

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["Periodo", "Rol", "Area", "Codigo", "Indicador", "Valor", "Unidad", "Meta", "Estado", "Porcentaje_Meta", "Descripcion"])

    def _csv_safe(val):
        if isinstance(val, str) and val.startswith(("=", "+", "-", "@", "\t", "\r")):
            return f"'{val}"
        return val

    for area_item in data["areas"]:
        for ind in area_item["indicadores"]:
            writer.writerow([
                _csv_safe(periodo),
                _csv_safe(rol),
                _csv_safe(area_item["titulo"]),
                _csv_safe(ind["codigo"]),
                _csv_safe(ind["nombre"]),
                _csv_safe(ind["valor"]),
                _csv_safe(ind["unidad"]),
                _csv_safe(ind["meta"]),
                _csv_safe(ind["estado"]),
                _csv_safe(ind["porcentaje_meta"]),
                _csv_safe(ind["descripcion"]),
            ])
    return Response(
        content=buf.getvalue().encode("utf-8-sig"),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="FarmaControl_Indicadores_{periodo}{sufijo_area}_{rol}.csv"'},
    )


@router.get("/bitacora-cofepris", response_model=List[BitacoraAmbientalOut])
def listar_bitacora_cofepris(
    limit: int = Query(default=30, ge=1, le=200),
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    hoy = datetime.date.today()
    _ensure_indicadores_base_data(db, hoy.year, hoy.month)
    return (
        db.query(BitacoraAmbiental)
        .order_by(BitacoraAmbiental.fecha_registro.desc(), BitacoraAmbiental.id.desc())
        .limit(limit)
        .all()
    )


@router.post("/bitacora-cofepris", response_model=BitacoraAmbientalOut, status_code=status.HTTP_201_CREATED)
def registrar_bitacora_cofepris(
    payload: BitacoraAmbientalCreate,
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    zona = payload.zona.upper().strip()
    turno = payload.turno.upper().strip()
    dentro = _evaluar_dentro_norma(zona, payload.temperatura_c, payload.humedad_relativa_pct)
    registro = BitacoraAmbiental(
        turno=turno,
        zona=zona,
        temperatura_c=payload.temperatura_c,
        humedad_relativa_pct=payload.humedad_relativa_pct,
        dentro_norma=dentro,
        responsable_nombre=usuario.nombre_completo if usuario else "Responsable Sanitario",
        observaciones=payload.observaciones,
    )
    db.add(registro)
    db.commit()
    db.refresh(registro)
    return registro


@router.get("/documentos-sanitarios", response_model=List[DocumentoSanitarioOut])
def listar_documentos_sanitarios(
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    hoy = datetime.date.today()
    _ensure_indicadores_base_data(db, hoy.year, hoy.month)
    docs = (
        db.query(DocumentoSanitario)
        .filter(DocumentoSanitario.activo == True)
        .order_by(DocumentoSanitario.fecha_vencimiento.asc())
        .all()
    )
    salida = []
    for d in docs:
        out = DocumentoSanitarioOut.model_validate(d)
        out.dias_restantes = (d.fecha_vencimiento - hoy).days
        salida.append(out)
    return salida


@router.post("/documentos-sanitarios", response_model=DocumentoSanitarioOut, status_code=status.HTTP_201_CREATED)
def registrar_documento_sanitario(
    payload: DocumentoSanitarioCreate,
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR", "RESPONSABLE_SANITARIO")),
    db: Session = Depends(get_db),
):
    tipo = payload.tipo_documento.upper().strip()
    existente = (
        db.query(DocumentoSanitario)
        .filter(DocumentoSanitario.tipo_documento == tipo, DocumentoSanitario.activo == True)
        .first()
    )
    if existente:
        existente.folio_documento = payload.folio_documento
        existente.fecha_emision = payload.fecha_emision
        existente.fecha_vencimiento = payload.fecha_vencimiento
        existente.activo = payload.activo
        doc = existente
    else:
        doc = DocumentoSanitario(
            tipo_documento=tipo,
            folio_documento=payload.folio_documento,
            fecha_emision=payload.fecha_emision,
            fecha_vencimiento=payload.fecha_vencimiento,
            activo=payload.activo,
        )
        db.add(doc)
    db.commit()
    db.refresh(doc)
    out = DocumentoSanitarioOut.model_validate(doc)
    out.dias_restantes = (doc.fecha_vencimiento - datetime.date.today()).days
    return out


@router.get("/parametros-financieros", response_model=ParametroFinancieroOut)
def obtener_parametros_financieros(
    anio: int = Query(default_factory=lambda: datetime.date.today().year, ge=2020, le=2100),
    mes: int = Query(default_factory=lambda: datetime.date.today().month, ge=1, le=12),
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR")),
    db: Session = Depends(get_db),
):
    _ensure_indicadores_base_data(db, anio, mes)
    param = (
        db.query(ParametroFinancieroMensual)
        .filter(ParametroFinancieroMensual.anio == anio, ParametroFinancieroMensual.mes == mes)
        .first()
    )
    return param


@router.put("/parametros-financieros", response_model=ParametroFinancieroOut)
def actualizar_parametros_financieros(
    payload: ParametroFinancieroUpdate,
    usuario: Optional[Usuario] = Depends(require_roles("ADMINISTRADOR")),
    db: Session = Depends(get_db),
):
    param = (
        db.query(ParametroFinancieroMensual)
        .filter(ParametroFinancieroMensual.anio == payload.anio, ParametroFinancieroMensual.mes == payload.mes)
        .first()
    )
    if param is None:
        param = ParametroFinancieroMensual(
            anio=payload.anio,
            mes=payload.mes,
            gastos_fijos_mensuales=payload.gastos_fijos_mensuales,
            nomina_mensual=payload.nomina_mensual,
            actualizado_por=usuario.nombre_completo if usuario else "Administrador",
        )
        db.add(param)
    else:
        param.gastos_fijos_mensuales = payload.gastos_fijos_mensuales
        param.nomina_mensual = payload.nomina_mensual
        param.actualizado_por = usuario.nombre_completo if usuario else "Administrador"
        param.updated_at = datetime.datetime.utcnow()
    db.commit()
    db.refresh(param)
    return param

