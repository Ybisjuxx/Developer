import os
import re
from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Producto
from ..schemas import IaConsultaInput, IaConsultaOut, SustitutoSugeridoOut

router = APIRouter(prefix="/api/ia", tags=["Consulta IA de Medicamentos & Sustitutos"])

# Mapeo de Familias Terapéuticas y Sustituciones Clínicas
FAMILIAS_TERAPEUTICAS = {
    "ANALGESICO_AINE": {
        "nombre": "Analgésicos y Antiinflamatorios No Esteroides (AINEs)",
        "sustancias": [
            "PARACETAMOL", "ACETAMINOFEN", "IBUPROFENO", "NAPROXENO",
            "KETOROLACO", "DICLOFENACO", "MELOXICAM", "CELECOXIB",
            "ACIDO ACETILSALICILICO", "ASPIRINA", "CLONIXINATO DE LISINA"
        ],
        "marcas_comunes": {
            "TEMPRA": "PARACETAMOL", "TYLENOL": "PARACETAMOL",
            "MOTRIN": "IBUPROFENO", "ADVIL": "IBUPROFENO", "ACTRON": "IBUPROFENO",
            "FLANAX": "NAPROXENO", "DAFLOXEN": "NAPROXENO",
            "DOLAC": "KETOROLACO", "VOLTAREN": "DICLOFENACO", "CATAFLAM": "DICLOFENACO",
            "CELEBREX": "CELECOXIB", "MELOX": "MELOXICAM"
        }
    },
    "ANTIBIOTICO": {
        "nombre": "Antibióticos y Antimicrobianos Sistémicos",
        "sustancias": [
            "AMOXICILINA", "AMPICILINA", "CIPROFLOXACINO", "AZITROMICINA",
            "CEFALEXINA", "CEFTRIAXONA", "CLARITROMICINA", "LEVOFLOXACINO",
            "TRIMETOPRIMA", "SULFAMETOXAZOL", "DOXICICLINA", "PENICILINA"
        ],
        "marcas_comunes": {
            "AMOXIL": "AMOXICILINA", "AUGMENTIN": "AMOXICILINA", "CLAVULIN": "AMOXICILINA",
            "CIPRO": "CIPROFLOXACINO", "CIPROXINA": "CIPROFLOXACINO",
            "ZITHROMAX": "AZITROMICINA", "AZITROCIN": "AZITROMICINA",
            "KEFLEX": "CEFALEXINA", "ROCEPHIN": "CEFTRIAXONA",
            "BACTRIM": "TRIMETOPRIMA", "KLAX": "CLARITROMICINA"
        }
    },
    "ANTIHISTAMINICO": {
        "nombre": "Antihistamínicos y Antialérgicos",
        "sustancias": [
            "LORATADINA", "CETIRIZINA", "CLORFENAMINA", "FEXOFENADINA",
            "DESLORATADINA", "LEVOCETIRIZINA", "MONTELUKAST"
        ],
        "marcas_comunes": {
            "CLARITYNE": "LORATADINA", "ZYRTEC": "CETIRIZINA", "VIRLIX": "CETIRIZINA",
            "ALLEGRA": "FEXOFENADINA", "DESALEX": "DESLORATADINA",
            "SINGULAIR": "MONTELUKAST", "HISTIACIL": "CLORFENAMINA"
        }
    },
    "ANTIACIDO_GASTRO": {
        "nombre": "Antiácidos e Inhibidores de Bomba de Protones (Gastroprotectores)",
        "sustancias": [
            "OMEPRAZOL", "PANTOPRAZOL", "ESOMEPRAZOL", "LANSOPRAZOL",
            "RANITIDINA", "SUCRALFATO", "MAGALDRATO", "DIMETICONA"
        ],
        "marcas_comunes": {
            "LOSEC": "OMEPRAZOL", "PRILOSEX": "OMEPRAZOL", "PANTOZOL": "PANTOPRAZOL",
            "NEXIUM": "ESOMEPRAZOL", "RIOPAN": "MAGALDRATO", "MELOX PLUS": "MAGALDRATO"
        }
    },
    "ANTIHIPERTENSIVO": {
        "nombre": "Antihipertensivos y Cardiovasculares",
        "sustancias": [
            "LOSARTAN", "TELMISARTAN", "ENALAPRIL", "CAPTOPRIL",
            "AMLODIPINO", "METOPROLOL", "HIDROCLOROTIAZIDA", "CANDESARTAN"
        ],
        "marcas_comunes": {
            "COZAAR": "LOSARTAN", "MICARDIS": "TELMISARTAN", "VASOTEC": "ENALAPRIL",
            "NORVASC": "AMLODIPINO", "LOPRESSOR": "METOPROLOL"
        }
    },
    "HIPOGLUCEMIANTE": {
        "nombre": "Hipoglucemiantes Orales (Antidiabéticos)",
        "sustancias": [
            "METFORMINA", "GLIBENCLAMIDA", "EMPAGLIFLOZINA", "SITAGLIPTINA",
            "DAPAGLIFLOZINA", "LINAGLIPTINA"
        ],
        "marcas_comunes": {
            "GLUCOPHAGE": "METFORMINA", "DAONIL": "GLIBENCLAMIDA", "JARDIANCE": "EMPAGLIFLOZINA",
            "JANUVIA": "SITAGLIPTINA", "FORXIGA": "DAPAGLIFLOZINA", "TRAYENTA": "LINAGLIPTINA"
        }
    },
    "RESPIRATORIO": {
        "nombre": "Broncodilatadores y Antitusivos",
        "sustancias": [
            "SALBUTAMOL", "AMBROXOL", "DEXTROMETORFANO", "GUAIFENESINA", "BROMHEXINA"
        ],
        "marcas_comunes": {
            "VENTOLIN": "SALBUTAMOL", "MUCOSOLVAN": "AMBROXOL", "BISOLVON": "BROMHEXINA"
        }
    },
    "ANTIESPASMODICO": {
        "nombre": "Antiespasmódicos y Reguladores Digestivos",
        "sustancias": [
            "BUTILHIOSCINA", "HIOSCINA", "TRIMEBUTINA", "METOCLOPRAMIDA", "DIMETICONA"
        ],
        "marcas_comunes": {
            "BUSCAPINA": "BUTILHIOSCINA", "DEBRIDAT": "TRIMEBUTINA", "CARNOTPRIM": "METOCLOPRAMIDA"
        }
    }
}


def normalizar_texto(texto: str) -> str:
    """Remueve acentos y caracteres especiales para comparaciones limpias."""
    texto = texto.upper()
    reemplazos = (
        ("Á", "A"), ("É", "E"), ("Í", "I"), ("Ó", "O"), ("Ú", "U"),
        ("Ü", "U"), ("Ñ", "N")
    )
    for a, b in reemplazos:
        texto = texto.replace(a, b)
    return re.sub(r"[^\w\s]", " ", texto).strip()


@router.post("/consulta-medicamento", response_model=IaConsultaOut)
def consultar_medicamento_ia(consulta_in: IaConsultaInput, db: Session = Depends(get_db)):
    """
    Analiza una consulta farmacéutica usando IA clínica:
    1. Identifica el fármaco consultado y su principio activo.
    2. Verifica disponibilidad y stock actual en la farmacia.
    3. Si está agotado o se solicitan equivalentes, sugiere opciones en existencia
       (bioequivalentes directos o de la misma familia terapéutica).
    4. Provee justificación farmacológica y advertencias regulatorias COFEPRIS.
    """
    texto_consulta = consulta_in.consulta.strip()
    texto_norm = normalizar_texto(texto_consulta)

    # 1. Cargar todos los productos con su stock acumulado
    productos_db = db.query(Producto).filter(Producto.activo == True).all()
    for p in productos_db:
        p.stock_total = sum(lote.stock_actual for lote in p.lotes if lote.activo)

    # 2. Identificar qué medicamento o principio activo se menciona
    producto_coincidente = None
    sustancia_identificada = None
    familia_identificada = None

    # Primero: comprobar si coincide con algún producto en la base de datos
    for p in productos_db:
        nombre_norm = normalizar_texto(p.nombre_comercial)
        sustancia_norm = normalizar_texto(p.sustancia_activa)

        if nombre_norm in texto_norm or texto_norm in nombre_norm:
            producto_coincidente = p
            sustancia_identificada = p.sustancia_activa
            break
        if sustancia_norm in texto_norm or texto_norm in sustancia_norm:
            producto_coincidente = p
            sustancia_identificada = p.sustancia_activa
            break

    # Si no hubo coincidencia directa, buscar en el diccionario de marcas comunes y familias
    if not sustancia_identificada:
        for fam_key, fam_info in FAMILIAS_TERAPEUTICAS.items():
            for marca, sust in fam_info.get("marcas_comunes", {}).items():
                if marca in texto_norm:
                    sustancia_identificada = sust
                    familia_identificada = fam_key
                    break
            if sustancia_identificada:
                break

            for sust in fam_info["sustancias"]:
                if sust in texto_norm:
                    sustancia_identificada = sust
                    familia_identificada = fam_key
                    break
            if sustancia_identificada:
                break

    # Determinar familia terapéutica si no fue identificada
    if sustancia_identificada and not familia_identificada:
        sust_norm = normalizar_texto(sustancia_identificada)
        for fam_key, fam_info in FAMILIAS_TERAPEUTICAS.items():
            if any(s in sust_norm for s in fam_info["sustancias"]):
                familia_identificada = fam_key
                break

    # 3. Analizar disponibilidad y buscar sustitutos en stock
    disponible = False
    if producto_coincidente and producto_coincidente.stock_total > 0:
        disponible = True

    sustitutos: List[SustitutoSugeridoOut] = []

    # Prioridad 1: Mismo principio activo (Bioequivalente / Genérico) con stock > 0
    if sustancia_identificada:
        sust_norm = normalizar_texto(sustancia_identificada)
        for p in productos_db:
            if p.stock_total > 0 and (not producto_coincidente or p.id != producto_coincidente.id):
                p_sust_norm = normalizar_texto(p.sustancia_activa)
                if sust_norm in p_sust_norm or p_sust_norm in sust_norm:
                    sustitutos.append(
                        SustitutoSugeridoOut(
                            producto_id=p.id,
                            codigo_barras=p.codigo_barras,
                            nombre_comercial=p.nombre_comercial,
                            sustancia_activa=p.sustancia_activa,
                            presentacion=p.presentacion,
                            laboratorio=p.laboratorio,
                            precio_venta=p.precio_venta,
                            stock_disponible=p.stock_total,
                            tipo_sustitucion="BIOEQUIVALENTE_DIRECTO",
                            motivo_sugerencia=f"Mismo principio activo ({p.sustancia_activa}). Intercambio directo bioequivalente.",
                            requiere_receta=p.requiere_receta,
                            grupo_farmacopea=p.grupo_farmacopea,
                        )
                    )

    # Prioridad 2: Misma familia terapéutica con stock > 0
    if len(sustitutos) < 4 and familia_identificada:
        fam_info = FAMILIAS_TERAPEUTICAS[familia_identificada]
        sustancias_familia = [s for s in fam_info["sustancias"]]

        for p in productos_db:
            if p.stock_total > 0:
                # Evitar duplicados ya agregados
                if any(s.producto_id == p.id for s in sustitutos):
                    continue
                if producto_coincidente and p.id == producto_coincidente.id:
                    continue

                p_sust_norm = normalizar_texto(p.sustancia_activa)
                if any(sf in p_sust_norm for sf in sustancias_familia):
                    sustitutos.append(
                        SustitutoSugeridoOut(
                            producto_id=p.id,
                            codigo_barras=p.codigo_barras,
                            nombre_comercial=p.nombre_comercial,
                            sustancia_activa=p.sustancia_activa,
                            presentacion=p.presentacion,
                            laboratorio=p.laboratorio,
                            precio_venta=p.precio_venta,
                            stock_disponible=p.stock_total,
                            tipo_sustitucion="MISMA_FAMILIA_TERAPEUTICA",
                            motivo_sugerencia=f"Alternativa clínica en la categoría de {fam_info['nombre']}.",
                            requiere_receta=p.requiere_receta,
                            grupo_farmacopea=p.grupo_farmacopea,
                        )
                    )

    # Si aún no hay sustitutos y no se encontró medicamento específico, devolver los productos con mayor stock
    if not sustitutos and not disponible:
        for p in sorted(productos_db, key=lambda x: x.stock_total, reverse=True)[:3]:
            if p.stock_total > 0:
                sustitutos.append(
                    SustitutoSugeridoOut(
                        producto_id=p.id,
                        codigo_barras=p.codigo_barras,
                        nombre_comercial=p.nombre_comercial,
                        sustancia_activa=p.sustancia_activa,
                        presentacion=p.presentacion,
                        laboratorio=p.laboratorio,
                        precio_venta=p.precio_venta,
                        stock_disponible=p.stock_total,
                        tipo_sustitucion="ALTERNATIVA_CLINICA",
                        motivo_sugerencia="Opción destacada en stock disponible en mostrador.",
                        requiere_receta=p.requiere_receta,
                        grupo_farmacopea=p.grupo_farmacopea,
                    )
                )

    # 4. Redactar respuesta de la IA
    nombre_prod = producto_coincidente.nombre_comercial if producto_coincidente else (sustancia_identificada or "Fármaco consultado")
    
    lineas_ia = []
    lineas_ia.append(f"### 🤖 Análisis Farmacéutico: **{nombre_prod}**\n")

    if disponible and producto_coincidente:
        lineas_ia.append(
            f"✅ **¡Tenemos existencias en la farmacia!**\n"
            f"- **Producto:** {producto_coincidente.nombre_comercial} ({producto_coincidente.sustancia_activa})\n"
            f"- **Presentación:** {producto_coincidente.presentacion} • Laboratorio {producto_coincidente.laboratorio}\n"
            f"- **Stock Actual:** {producto_coincidente.stock_total} piezas listas para entrega.\n"
            f"- **Precio:** ${producto_coincidente.precio_venta:.2f} MXN\n"
            f"- **Regulación:** {'Requiere Receta Médica (Grupo IV o Controlado)' if producto_coincidente.requiere_receta else 'Venta Libre (Grupo VI)'}\n"
        )
        if sustitutos:
            lineas_ia.append("\n💡 **Opciones equivalentes o genéricas adicionales disponibles:**")
    elif producto_coincidente and not disponible:
        lineas_ia.append(
            f"⚠️ **Agotado actualmente en mostrador:** El producto **{producto_coincidente.nombre_comercial}** "
            f"({producto_coincidente.sustancia_activa}) se encuentra sin existencias inmediatas.\n\n"
            f"Sin embargo, el motor de bioequivalencia de FarmaControl ha localizado **{len(sustitutos)} sustitutos terapéuticos con stock inmediato**:"
        )
    else:
        lineas_ia.append(
            f"ℹ️ Hemos analizado tu consulta sobre **{sustancia_identificada or texto_consulta}**.\n\n"
            f"En nuestro inventario físico contamos con las siguientes alternativas terapéuticas recomendadas con existencias confirmadas:"
        )

    for i, s in enumerate(sustitutos, 1):
        tipo_label = "Mismo principio activo (Bioequivalente)" if s.tipo_sustitucion == "BIOEQUIVALENTE_DIRECTO" else "Misma familia terapéutica"
        lineas_ia.append(
            f"\n{i}. **{s.nombre_comercial}** — *{s.sustancia_activa}*\n"
            f"   - **Forma / Presentación:** {s.presentacion} ({s.laboratorio})\n"
            f"   - **Existencia:** `{s.stock_disponible} pzas` | **Precio:** `${s.precio_venta:.2f} MXN`\n"
            f"   - **Criterio:** {tipo_label} — {s.motivo_sugerencia}\n"
            f"   - **Prescripción:** {'Requiere Receta' if s.requiere_receta else 'Venta Libre'}"
        )

    aviso_sanitario = (
        "⚖️ **Normativa Sanitaria COFEPRIS:** Si el fármaco pertenece al Grupo IV (Antibióticos) "
        "o Grupos I-III (Controlados), la sustitución debe realizarse respetando la sustancia activa "
        "y concentración prescrita por el médico con cédula profesional. Los medicamentos del Grupo VI "
        "(Venta Libre) pueden intercambiarse libremente por genéricos bioequivalentes."
    )

    return IaConsultaOut(
        pregunta=texto_consulta,
        respuesta_ia="\n".join(lineas_ia),
        producto_consultado=nombre_prod,
        disponible_en_stock=disponible,
        sustitutos_en_stock=sustitutos,
        aviso_sanitario=aviso_sanitario,
    )
