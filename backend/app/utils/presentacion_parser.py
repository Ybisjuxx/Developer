import re
import unicodedata
from typing import Optional, Tuple


def quitar_acentos(texto: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", texto or "")
        if unicodedata.category(c) != "Mn"
    )


def normalizar_sustancia_exacta(sustancia: str) -> str:
    """Normaliza una sustancia o combinación a tokens ordenados separados por ' + '."""
    if not sustancia:
        return ""
    limpio = quitar_acentos(sustancia).upper().strip()
    # Separar combinaciones por +, /, , o ' CON '
    partes = re.split(r"\s*(?:\+|/|,|\bCON\b|\bY\b)\s*", limpio)
    tokens = sorted({re.sub(r"\s+", " ", p).strip() for p in partes if p and p.strip()})
    return " + ".join(tokens)


_FORMA_MAP = [
    (r"\b(SOLUCION INYECTABLE|INYECTABLE|INYEC\w*|AMPOLLETA|AMPULA|VIAL|JERINGA)\b", "SOLUCION_INYECTABLE", "INTRAMUSCULAR"),
    (r"\b(CAPSULA|CAPSULAS|CAP)\b", "CAPSULA", "ORAL"),
    (r"\b(TABLETA|TABLETAS|TAB|COMPRIMIDO|COMPRIMIDOS|GRAGEA|GRAGEAS)\b", "TABLETA", "ORAL"),
    (r"\b(SUSPENSION|SUSP)\b", "SUSPENSION", "ORAL"),
    (r"\b(JARABE|JBE)\b", "JARABE", "ORAL"),
    (r"\b(SOLUCION OFTALMICA|GOTAS OFTALMICAS|COLIRIO)\b", "SOLUCION_OFTALMICA", "OFTALMICA"),
    (r"\b(GOTAS|SOLUCION ORAL)\b", "GOTAS", "ORAL"),
    (r"\b(CREMA|POMADA|UNGUENTO|GEL)\b", "CREMA", "TOPICA"),
    (r"\b(AEROSOL|INHALADOR|SPRAY NASAL)\b", "INHALADOR", "INHALATORIA"),
    (r"\b(SUPOSITORIO)\b", "SUPOSITORIO", "RECTAL"),
    (r"\b(OVULO)\b", "OVULO", "VAGINAL"),
    (r"\b(SOBRE|POLVO)\b", "POLVO", "ORAL"),
]


def parsear_presentacion(presentacion: str) -> Tuple[Optional[float], Optional[str], Optional[str], Optional[str], bool]:
    """Extrae (concentracion_valor, concentracion_unidad, forma_farmaceutica, via_administracion, requiere_revision_manual)."""
    texto = quitar_acentos(presentacion or "").upper()
    conc_val: Optional[float] = None
    conc_unit: Optional[str] = None

    # Formato estructurado "Forma | 400 | mg" o libre "Tabletas 400 mg", "250 mg/5ml"
    m = re.search(r"(\d+(?:\.\d+)?)\s*\|?\s*(MG/5ML|MG/ML|MCG|MG|ML|UI|G|%)", texto)
    if m:
        try:
            conc_val = float(m.group(1))
            conc_unit = m.group(2).lower()
        except ValueError:
            conc_val = None

    forma: Optional[str] = None
    via: Optional[str] = None
    for patron, f_norm, v_norm in _FORMA_MAP:
        if re.search(patron, texto):
            forma = f_norm
            via = v_norm
            break

    # Sobrescribir vía si se menciona explícitamente
    if re.search(r"\b(INTRAVENOSA|IV)\b", texto):
        via = "INTRAVENOSA"
    elif re.search(r"\b(INTRAMUSCULAR|IM)\b", texto):
        via = "INTRAMUSCULAR"
    elif re.search(r"\b(TOPICA|CUTANEA)\b", texto):
        via = "TOPICA"
    elif re.search(r"\b(OFTALMICA)\b", texto):
        via = "OFTALMICA"
    elif re.search(r"\b(ORAL)\b", texto) and not via:
        via = "ORAL"

    requiere_revision = conc_val is None or conc_unit is None or forma is None or via is None
    return conc_val, conc_unit, forma, via, requiere_revision
