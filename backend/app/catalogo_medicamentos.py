"""
Catálogo Maestro de 100 Medicamentos para FarmaControl
Clasificación Regulatoria Mexicana: FEUM / COFEPRIS / Art. 226 Ley General de Salud
Grupos:
- GRUPO_II / GRUPO_III: Medicamentos Controlados / Psicotrópicos (Requieren receta médica especial/retenida)
- GRUPO_IV: Antibióticos (Requieren receta médica obligatoria con registro de lote y médico)
- GRUPO_V: Medicamentos que requieren receta para su venta continua (Antihipertensivos, hipoglucemiantes, etc.)
- GRUPO_VI: Medicamentos de Venta Libre (OTC - Analgésicos, antiácidos, antihistamínicos, etc.)
"""

import json
from pathlib import Path
from typing import Any, Dict, List

_DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "medicamentos_100.json"


def _cargar_medicamentos() -> List[Dict[str, Any]]:
    with _DATA_FILE.open("r", encoding="utf-8") as fh:
        return json.load(fh)


MEDICAMENTOS_100: List[Dict[str, Any]] = _cargar_medicamentos()
