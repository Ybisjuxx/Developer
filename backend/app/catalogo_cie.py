"""
Catálogo Oficial CIE-10 (Clasificación Internacional de Enfermedades - OMS/OPS)
Incluye los diagnósticos más frecuentes en medicina general, urgencias, pediatría y farmacia comunitaria en México.
Soporta búsqueda híbrida local y consulta a API pública externa con fallback inmediato.
"""

import urllib.parse
import urllib.request
import json
from typing import List, Dict, Any, Optional

# Catálogo exhaustivo de diagnósticos frecuentes CIE-10 con categoría y notas clínicas
CIE10_DIAGNOSTICOS = [
    # Cap. I: Ciertas enfermedades infecciosas y parasitarias (A00-B99)
    {"codigo": "A09", "descripcion": "Gastroenteritis y colitis de origen infeccioso", "categoria": "Infecciones gastrointestinales", "nota": "Priorizar suero oral y reposición hidroelectrolítica."},
    {"codigo": "A00", "descripcion": "Cólera", "categoria": "Infecciones gastrointestinales", "nota": "Notificación epidemiológica inmediata obligatoria."},
    {"codigo": "A01", "descripcion": "Fiebres tifoidea y paratifoidea", "categoria": "Infecciones gastrointestinales", "nota": "Requiere terapia con antibiótico específico."},
    {"codigo": "A06", "descripcion": "Amebiasis intestinal", "categoria": "Infecciones parasitarias", "nota": "Tratamiento con metronidazol o nitazoxanida."},
    {"codigo": "A08", "descripcion": "Infecciones intestinales víricas (Rotavirus / Norovirus)", "categoria": "Infecciones gastrointestinales", "nota": "Autolimitada; evitar antibióticos innecesarios."},
    {"codigo": "B34.9", "descripcion": "Infección viral no especificada", "categoria": "Infecciones virales", "nota": "Manejo sintomático con analgésicos y reposo."},
    {"codigo": "B35", "descripcion": "Dermatofitosis (Tiña / Pie de atleta)", "categoria": "Micosis superficiales", "nota": "Antimicótico tópico (clotrimazol/miconazol) por 2 a 4 semanas."},
    {"codigo": "B37", "descripcion": "Candidiasis (oral / mucocutánea / vaginal)", "categoria": "Micosis", "nota": "Tratamiento con nistatina, miconazol o fluconazol."},
    {"codigo": "B01", "descripcion": "Varicela sin complicaciones", "categoria": "Infecciones virales", "nota": "Aislamiento y sintomáticos; evitar aspirina."},
    {"codigo": "B00", "descripcion": "Infecciones por el virus del herpes simple", "categoria": "Infecciones virales", "nota": "Aciclovir tópico u oral temprano."},
    {"codigo": "B20", "descripcion": "Enfermedad por virus de la inmunodeficiencia humana (VIH)", "categoria": "Enfermedades por retrovirus", "nota": "Seguimiento especializado en CAPASITS."},
    {"codigo": "A60", "descripcion": "Infección anogenital por virus del herpes simple", "categoria": "Infecciones de transmisión sexual", "nota": "Antivirales orales y consejería preventiva."},
    {"codigo": "A54", "descripcion": "Infección gonocócica (Gonorrea)", "categoria": "Infecciones de transmisión sexual", "nota": "Ceftriaxona + Azitromicina (manejo de pareja)."},
    {"codigo": "A53", "descripcion": "Sífilis no especificada", "categoria": "Infecciones de transmisión sexual", "nota": "Penicilina G benzatínica según estadio clínico."},
    {"codigo": "B82", "descripcion": "Parasitosis intestinal sin otra especificación", "categoria": "Parasitosis", "nota": "Desparasitación familiar recomendada (Albendazol)."},

    # Cap. II: Neoplasias (C00-D48)
    {"codigo": "C50", "descripcion": "Tumor maligno de la mama", "categoria": "Neoplasias malignas", "nota": "Manejo oncológico multidisciplinario."},
    {"codigo": "C53", "descripcion": "Tumor maligno del cuello del útero", "categoria": "Neoplasias malignas", "nota": "Detección precoz mediante citología cervical / Papanicolaou."},
    {"codigo": "C61", "descripcion": "Tumor maligno de la próstata", "categoria": "Neoplasias malignas", "nota": "Vigilancia de antígeno prostático específico (APE)."},
    {"codigo": "D12", "descripcion": "Tumor benigno del colon, del recto y del ano", "categoria": "Neoplasias benignas", "nota": "Seguimiento colonoscópico."},

    # Cap. III: Enfermedades de la sangre (D50-D89)
    {"codigo": "D50", "descripcion": "Anemia por deficiencia de hierro (ferropénica)", "categoria": "Enfermedades de la sangre", "nota": "Suplementación con sulfato ferroso y vitamina C."},
    {"codigo": "D53", "descripcion": "Otras anemias nutricionales (déficit B12 / folatos)", "categoria": "Enfermedades de la sangre", "nota": "Complejo B y ácido fólico."},

    # Cap. IV: Enfermedades endocrinas, nutricionales y metabólicas (E00-E90)
    {"codigo": "E11", "descripcion": "Diabetes mellitus tipo 2 (no insulinodependiente)", "categoria": "Endocrino y metabólico", "nota": "Control glucémico con metformina y estilo de vida."},
    {"codigo": "E10", "descripcion": "Diabetes mellitus tipo 1 (insulinodependiente)", "categoria": "Endocrino y metabólico", "nota": "Insulinoterapia basal-bolo obligatoria."},
    {"codigo": "E03.9", "descripcion": "Hipotiroidismo no especificado", "categoria": "Endocrino y metabólico", "nota": "Levotiroxina en ayunas con control periódico de TSH."},
    {"codigo": "E05", "descripcion": "Tirotoxicosis (hipertiroidismo)", "categoria": "Endocrino y metabólico", "nota": "Antitiroideos (tiamazol) y betabloqueadores."},
    {"codigo": "E66", "descripcion": "Obesidad debida a exceso de calorías", "categoria": "Endocrino y metabólico", "nota": "Plan nutricional integral y ejercicio cardiovascular."},
    {"codigo": "E78.0", "descripcion": "Hipercolesterolemia pura", "categoria": "Trastornos lipídicos", "nota": "Estatina (Atorvastatina / Rosuvastatina) y dieta."},
    {"codigo": "E78.1", "descripcion": "Hipertrigliceridemia pura", "categoria": "Trastornos lipídicos", "nota": "Fibratos (Bezafibrato) y restricción de azúcares simples."},
    {"codigo": "E78.2", "descripcion": "Hiperlipidemia mixta", "categoria": "Trastornos lipídicos", "nota": "Manejo combinado de riesgo cardiovascular."},
    {"codigo": "E79.0", "descripcion": "Hiperuricemia sin signos de artritis / gota", "categoria": "Metabolismo de purinas", "nota": "Alopurinol e hidratación abundante."},

    # Cap. V: Trastornos mentales y del comportamiento (F00-F99)
    {"codigo": "F41.1", "descripcion": "Trastorno de ansiedad generalizada", "categoria": "Salud mental", "nota": "Terapia psicológica y fármacos controlados bajo prescripción."},
    {"codigo": "F41.0", "descripcion": "Trastorno de pánico (ansiedad episódica paroxística)", "categoria": "Salud mental", "nota": "Manejo agudo con ansiolíticos y preventivo con ISRS."},
    {"codigo": "F32", "descripcion": "Episodio depresivo moderado a severo", "categoria": "Salud mental", "nota": "Antidepresivos (ISRS) y acompañamiento psicoterapéutico."},
    {"codigo": "F51.0", "descripcion": "Insomnio no orgánico", "categoria": "Trastornos del sueño", "nota": "Higiene del sueño antes de prescribir inductores."},
    {"codigo": "F90", "descripcion": "Trastorno por déficit de atención e hiperactividad (TDAH)", "categoria": "Salud mental infantil", "nota": "Medicamento controlado (Metilfenidato) requiere receta especial."},

    # Cap. VI: Enfermedades del sistema nervioso (G00-G99)
    {"codigo": "G43", "descripcion": "Migraña (con o sin aura)", "categoria": "Sistema nervioso", "nota": "Triptanes, AINEs en fase aguda; profilaxis con betabloqueador."},
    {"codigo": "G44.2", "descripcion": "Cefalea tensional", "categoria": "Sistema nervioso", "nota": "Paracetamol, AINEs y técnicas de relajación."},
    {"codigo": "G40", "descripcion": "Epilepsia y síndromes epilépticos", "categoria": "Sistema nervioso", "nota": "Anticonvulsivantes continuos; no suspender abruptamente."},
    {"codigo": "G47", "descripcion": "Trastornos del inicio y mantenimiento del sueño", "categoria": "Sistema nervioso", "nota": "Evaluar apnea obstructiva o estrés."},
    {"codigo": "G20", "descripcion": "Enfermedad de Parkinson", "categoria": "Enfermedades neurodegenerativas", "nota": "Levodopa / Carbidopa con horario estricto."},
    {"codigo": "G30", "descripcion": "Enfermedad de Alzheimer", "categoria": "Enfermedades neurodegenerativas", "nota": "Inhibidores de acetilcolinesterasa y soporte familiar."},

    # Cap. VII: Enfermedades del ojo (H00-H59)
    {"codigo": "H10", "descripcion": "Conjuntivitis aguda (bacteriana / viral / alérgica)", "categoria": "Oftalmología", "nota": "Colirios específicos según etiología y lavado con solución salina."},
    {"codigo": "H00", "descripcion": "Orzuelo y calacio", "categoria": "Oftalmología", "nota": "Compresas tibias y ungüento oftálmico con antibiótico."},
    {"codigo": "H40", "descripcion": "Glaucoma de ángulo abierto", "categoria": "Oftalmología", "nota": "Gotas hipotensoras oculares diarias."},

    # Cap. VIII: Oído y apófisis mastoides (H60-H95)
    {"codigo": "H60", "descripcion": "Otitis externa (oído de nadador)", "categoria": "Otorrinolaringología", "nota": "Gotas óticas con antibiótico y antiinflamatorio."},
    {"codigo": "H65", "descripcion": "Otitis media no supurativa (serosa)", "categoria": "Otorrinolaringología", "nota": "Descongestionantes y antihistamínicos."},
    {"codigo": "H66", "descripcion": "Otitis media supurativa y la no especificada", "categoria": "Otorrinolaringología", "nota": "Amoxicilina con clavulánico y analgesia."},
    {"codigo": "H81.1", "descripcion": "Vértigo posicional paroxístico benigno", "categoria": "Otorrinolaringología", "nota": "Maniobras de reposicionamiento (Epley) y dimenhidrinato."},

    # Cap. IX: Enfermedades del sistema circulatorio (I00-I99)
    {"codigo": "I10", "descripcion": "Hipertensión esencial (primaria)", "categoria": "Cardiovascular", "nota": "Monitoreo tensional y adherencia a antihipertensivos."},
    {"codigo": "I20", "descripcion": "Angina de pecho (estable / inestable)", "categoria": "Cardiovascular", "nota": "Nitroglicerina sublingual y valoración cardiológica inmediata."},
    {"codigo": "I21", "descripcion": "Infarto agudo de miocardio", "categoria": "Cardiovascular", "nota": "URGENCIA MÉDICA ABSOLUTA: Código infarto."},
    {"codigo": "I50", "descripcion": "Insuficiencia cardíaca congestiva", "categoria": "Cardiovascular", "nota": "Diuréticos, IECA/ARA-II y betabloqueadores."},
    {"codigo": "I83", "descripcion": "Venas varicosas de los miembros inferiores", "categoria": "Vascular periférico", "nota": "Flebotónicos (diosmina/hesperidina) y medias de compresión."},
    {"codigo": "I84", "descripcion": "Hemorroides (internas / externas)", "categoria": "Vascular", "nota": "Fibra dietética, pomadas antihemorroidales y baños de asiento."},

    # Cap. X: Enfermedades del sistema respiratorio (J00-J99)
    {"codigo": "J00", "descripcion": "Rinofaringitis aguda (resfriado común)", "categoria": "Infecciones respiratorias", "nota": "Sintomático: hidratación, analgésico y descongestionante."},
    {"codigo": "J02", "descripcion": "Faringitis aguda estreptocócica", "categoria": "Infecciones respiratorias", "nota": "Requiere antibiótico (Penicilina o Amoxicilina) por 7-10 días."},
    {"codigo": "J03", "descripcion": "Amigdalitis aguda", "categoria": "Infecciones respiratorias", "nota": "Diferenciar viral vs bacteriana antes de dar antibiótico."},
    {"codigo": "J01", "descripcion": "Sinusitis aguda bacteriana", "categoria": "Infecciones respiratorias", "nota": "Lavados nasales con solución salina y antibiótico oral."},
    {"codigo": "J04", "descripcion": "Laringitis y traqueítis agudas", "categoria": "Infecciones respiratorias", "nota": "Reposo de voz, humidificación y corticoide si hay estridor."},
    {"codigo": "J10", "descripcion": "Influenza debida a virus de la influenza identificado", "categoria": "Infecciones virales respiratorias", "nota": "Oseltamivir en las primeras 48h de inicio de síntomas."},
    {"codigo": "J18", "descripcion": "Neumonía, organismo no especificado", "categoria": "Infecciones respiratorias bajas", "nota": "Manejo antibiótico temprano; valorar oximetría."},
    {"codigo": "J20", "descripcion": "Bronquitis aguda", "categoria": "Infecciones respiratorias", "nota": "Mayoría de causa viral; broncodilatador si hay sibilancias."},
    {"codigo": "J45", "descripcion": "Asma bronquial (alérgica / no alérgica)", "categoria": "Enfermedades respiratorias crónicas", "nota": "Salbutamol para rescate y corticoide inhalado de control."},
    {"codigo": "J44", "descripcion": "Enfermedad pulmonar obstructiva crónica (EPOC)", "categoria": "Enfermedades respiratorias crónicas", "nota": "Broncodilatadores de larga acción y cese de tabaquismo."},
    {"codigo": "J30", "descripcion": "Rinitis alérgica y vasomotora", "categoria": "Alergias respiratorias", "nota": "Antihistamínicos orales (Loratadina/Cetirizina) y spray nasal."},

    # Cap. XI: Enfermedades del sistema digestivo (K00-K93)
    {"codigo": "K21", "descripcion": "Enfermedad por reflujo gastroesofágico (ERGE)", "categoria": "Digestivo", "nota": "Inhibidor de bomba de protones (Omeprazol) antes del desayuno."},
    {"codigo": "K29", "descripcion": "Gastritis y duodenitis", "categoria": "Digestivo", "nota": "Antiácidos y dieta blanda; investigar Helicobacter pylori."},
    {"codigo": "K25", "descripcion": "Úlcera gástrica", "categoria": "Digestivo", "nota": "IBP en dosis plenas y supresión de AINEs."},
    {"codigo": "K58", "descripcion": "Síndrome del intestino irritable (colon irritable)", "categoria": "Digestivo", "nota": "Antiespasmódicos (Butilhioscina), probióticos y fibra."},
    {"codigo": "K59.0", "descripcion": "Constipación / Estreñimiento funcional", "categoria": "Digestivo", "nota": "Incremento de agua, fibra vegetal y laxantes osmóticos."},
    {"codigo": "K80", "descripcion": "Colelitiasis (cálculos biliares)", "categoria": "Digestivo", "nota": "Dieta baja en grasas; valoración quirúrgica para colecistectomía."},
    {"codigo": "K35", "descripcion": "Apendicitis aguda", "categoria": "Urgencias quirúrgicas", "nota": "QUIRÚRGICO DE URGENCIA: No administrar laxantes ni analgésicos fuertes."},

    # Cap. XII: Enfermedades de la piel (L00-L99)
    {"codigo": "L20", "descripcion": "Dermatitis atópica", "categoria": "Dermatología", "nota": "Emolientes diarios y corticoides tópicos leves en brotes."},
    {"codigo": "L23", "descripcion": "Dermatitis alérgica de contacto", "categoria": "Dermatología", "nota": "Retirar alérgeno y aplicar crema con hidrocortisona."},
    {"codigo": "L70", "descripcion": "Acné vulgar", "categoria": "Dermatología", "nota": "Peróxido de benzoilo, retinoides tópicos o antibiótico oral."},
    {"codigo": "L50", "descripcion": "Urticaria aguda", "categoria": "Alergias cutáneas", "nota": "Antihistamínicos de 2da generación (Cetirizina)."},
    {"codigo": "L03", "descripcion": "Celulitis bacteriana dérmica", "categoria": "Infecciones de la piel", "nota": "Dicloxacilina o cefalexina oral y reposo de la extremidad."},

    # Cap. XIII: Sistema osteomuscular y tejido conjuntivo (M00-M99)
    {"codigo": "M54.5", "descripcion": "Lumbago no especificado (Lumbalgia mecánica)", "categoria": "Osteomuscular", "nota": "Reposo relativo, calor local, AINE y relajante muscular."},
    {"codigo": "M54.2", "descripcion": "Cervicalgia (dolor de cuello)", "categoria": "Osteomuscular", "nota": "Postura adecuada, fisioterapia y analgésicos orales."},
    {"codigo": "M15", "descripcion": "Poliartrosis / Osteoartritis degenerativa", "categoria": "Reumatología", "nota": "Paracetamol como base, glucosamina y ejercicio sin impacto."},
    {"codigo": "M79.1", "descripcion": "Mialgia (dolor muscular generalizado)", "categoria": "Osteomuscular", "nota": "Analgésicos de venta libre y estiramientos suaves."},
    {"codigo": "M10", "descripcion": "Gota articular aguda", "categoria": "Reumatología", "nota": "Colquicina, AINEs en crisis; alopurinol preventivo posterior."},

    # Cap. XIV: Sistema genitourinario (N00-N99)
    {"codigo": "N39.0", "descripcion": "Infección de vías urinarias (cistitis no especificada)", "categoria": "Nefrología y Urología", "nota": "Nitrofurantoína o Fosfomicina con urocultivo de control."},
    {"codigo": "N30", "descripcion": "Cistitis aguda", "categoria": "Urología", "nota": "Hidratación abundante y analgésico urinario (Fenazopiridina)."},
    {"codigo": "N20", "descripcion": "Cálculo del riñón y del uréter (Litiasis renal)", "categoria": "Urología", "nota": "Analgesia potente (AINEs / antiespasmódicos) e imágenes."},
    {"codigo": "N40", "descripcion": "Hiperplasia benigna de la próstata", "categoria": "Urología", "nota": "Alfa-bloqueadores (Tamsulosina) e inhibidores de 5-alfa reductasa."},
    {"codigo": "N76", "descripcion": "Vaginitis y vulvitis agudas", "categoria": "Ginecología", "nota": "Óvulos combinados o metronidazol según frotis vaginal."},

    # Cap. XVIII: Síntomas, signos y hallazgos anormales (R00-R99)
    {"codigo": "R50", "descripcion": "Fiebre de origen desconocido o no especificada", "categoria": "Síntomas generales", "nota": "Medios físicos, Paracetamol y vigilancia de signos de alarma."},
    {"codigo": "R51", "descripcion": "Cefalea (dolor de cabeza no especificado)", "categoria": "Síntomas generales", "nota": "Descartar hipertensión o signos meníngeos."},
    {"codigo": "R05", "descripcion": "Tos (seca o con expectoración)", "categoria": "Síntomas respiratorios", "nota": "Identificar causa desencadenante antes de sedar la tos."},
    {"codigo": "R10", "descripcion": "Dolor abdominal y pélvico", "categoria": "Síntomas digestivos", "nota": "Evaluar datos de abdomen agudo."},
    {"codigo": "R11", "descripcion": "Náusea y vómito", "categoria": "Síntomas digestivos", "nota": "Antieméticos (Metoclopramida/Ondansetrón) e hidratación oral."},
    {"codigo": "R53", "descripcion": "Malestar general y fatiga / astenia", "categoria": "Síntomas generales", "nota": "Investigar anemia, tiroides o proceso viral prodrómico."},

    # Cap. XIX: Traumatismos y heridas (S00-T98)
    {"codigo": "S93.4", "descripcion": "Esguince y torcedura del tobillo", "categoria": "Traumatología", "nota": "Protocolo RICE: Reposo, Hielo, Compresión y Elevación + AINE."},
    {"codigo": "T14.0", "descripcion": "Traumatismo superficial (contusión / raspadura)", "categoria": "Traumatología", "nota": "Lavado con agua y jabón, antiséptico local."},

    # Cap. XXII: Códigos para situaciones especiales
    {"codigo": "U07.1", "descripcion": "COVID-19, virus identificado", "categoria": "Infecciones respiratorias emergentes", "nota": "Monitoreo de saturación de O2, aislamiento y sintomáticos."},
    {"codigo": "U07.2", "descripcion": "COVID-19, virus no identificado (sospecha clínica)", "categoria": "Infecciones respiratorias emergentes", "nota": "Prueba confirmatoria y medidas de bioseguridad."},
]


def buscar_en_catalogo_cie_local(query: str, limit: int = 30) -> List[Dict[str, Any]]:
    """Busca en el catálogo maestro integrado de diagnósticos CIE-10."""
    q_norm = query.strip().lower()
    resultados = []
    
    # Prioridad 1: Coincidencia exacta o inicial en código CIE
    for diag in CIE10_DIAGNOSTICOS:
        if diag["codigo"].lower().startswith(q_norm):
            resultados.append(diag)
            
    # Prioridad 2: Coincidencia en descripción o categoría
    for diag in CIE10_DIAGNOSTICOS:
        if diag not in resultados:
            if (q_norm in diag["codigo"].lower() or 
                q_norm in diag["descripcion"].lower() or 
                q_norm in diag["categoria"].lower()):
                resultados.append(diag)
                
    return resultados[:limit]


def consultar_api_cie_externa(query: str, limit: int = 15) -> List[Dict[str, Any]]:
    """
    Consulta a la API pública oficial de NIH Clinical Tables Search Service para ICD-10.
    Si hay falla de conexión o límite de tiempo, retorna lista vacía sin bloquear el sistema.
    """
    if not query or len(query.strip()) < 2:
        return []
        
    url = (
        f"https://clinicaltables.nlm.nih.gov/api/icd10cm/v3/search?"
        f"terms={urllib.parse.quote(query.strip())}&sf=code,name&maxList={limit}"
    )
    
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "FarmaControl-POS-CIE/1.0"}
        )
        with urllib.request.urlopen(req, timeout=2.5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                # La API de NIH devuelve: [total_count, [codes], null, [[code, name], ...]]
                items = []
                if len(data) >= 4 and data[3]:
                    for row in data[3]:
                        code = row[0]
                        name = row[1]
                        items.append({
                            "codigo": code,
                            "descripcion": name,
                            "categoria": "Catálogo Internacional ICD-10",
                            "nota": "Obtenido desde servicio de terminología médica NIH/WHO."
                        })
                return items
    except Exception:
        # Falla silenciosa: el catálogo local garantiza disponibilidad offline
        pass
        
    return []
