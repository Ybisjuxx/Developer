"""
Catálogo Oficial CIE-11 (Clasificación Internacional de Enfermedades 11.ª Revisión - OMS/OPS)
Catálogo ampliado con patologías frecuentes de consulta médica, medicina general, especialidades,
urgencias, pediatría y farmacia comunitaria en México y Latinoamérica bajo el estándar vigente CIE-11.
Soporta búsqueda inteligente normalizada (sin acentos, tokens múltiples, códigos alfanuméricos con o sin punto)
e integración bilingüe en tiempo real con la API oficial de terminología médica ICD-11 de NIH / OMS.
"""

import json
import re
import unicodedata
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional


def normalizar_texto(texto: str) -> str:
    """Elimina acentos, diacríticos y convierte a minúsculas para comparaciones robustas."""
    if not texto:
        return ""
    nfkd = unicodedata.normalize('NFKD', texto)
    sin_tildes = "".join([c for c in nfkd if not unicodedata.combining(c)])
    return sin_tildes.lower().strip()


# Nombres oficiales de capítulos en la linearización MMS de la CIE-11 (OMS)
CAPITULOS_CIE11: Dict[str, str] = {
    "01": "Ciertas enfermedades infecciosas o parasitarias",
    "02": "Neoplasias",
    "03": "Enfermedades de la sangre o de los órganos hematopoyéticos",
    "04": "Enfermedades del sistema inmunitario",
    "05": "Enfermedades endocrinas, nutricionales o metabólicas",
    "06": "Trastornos mentales, del comportamiento o del neurodesarrollo",
    "07": "Trastornos del sueño y de la vigilia",
    "08": "Enfermedades del sistema nervioso",
    "09": "Enfermedades del sistema visual",
    "10": "Enfermedades del oído o de la apófisis mastoides",
    "11": "Enfermedades del sistema circulatorio",
    "12": "Enfermedades del sistema respiratorio",
    "13": "Enfermedades del sistema digestivo",
    "14": "Enfermedades de la piel",
    "15": "Enfermedades del sistema musculoesquelético o del tejido conectivo",
    "16": "Enfermedades del sistema genitourinario",
    "17": "Condiciones relacionadas con la salud sexual",
    "18": "Embarazo, parto o puerperio",
    "19": "Ciertas afecciones originadas en el período perinatal",
    "20": "Anomalías del desarrollo",
    "21": "Síntomas, signos o hallazgos clínicos no clasificados en otra parte",
    "22": "Traumatismos, envenenamientos o ciertas otras consecuencias de causas externas",
    "23": "Causas externas de morbilidad o mortalidad",
    "24": "Factores que influyen en el estado de salud o el contacto con servicios de salud",
    "25": "Códigos para propósitos especiales (ej. COVID-19)",
    "26": "Condiciones de la medicina tradicional",
}


# Catálogo exhaustivo y enriquecido de diagnósticos frecuentes CIE-11 oficial (OMS / México)
CIE11_DIAGNOSTICOS: List[Dict[str, str]] = [
    # -------------------------------------------------------------------------
    # Cap. 01: Ciertas enfermedades infecciosas y parasitarias (1A00-1H0Z)
    # -------------------------------------------------------------------------
    {"codigo": "1A00", "descripcion": "Cólera", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Notificación epidemiológica inmediata obligatoria ante Jurisdicción Sanitaria."},
    {"codigo": "1A07", "descripcion": "Fiebres tifoidea y paratifoidea (Salmonella typhi)", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Ceftriaxona, Azitromicina o Ciprofloxacino. Evitar automedicación."},
    {"codigo": "1A08", "descripcion": "Otras infecciones por Salmonella (Salmonelosis / enteritis)", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Rehidratación oral intensiva; antibióticos en casos graves o ancianos."},
    {"codigo": "1A10", "descripcion": "Shigelosis (Disentería bacilar)", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Heces con moco y sangre. Hidratación y fluoroquinolonas si procede."},
    {"codigo": "1A20", "descripcion": "Otras infecciones intestinales bacterianas (E. coli, Campylobacter)", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Manejo hidroelectrolítico y coprocultivo."},
    {"codigo": "1A70", "descripcion": "Amebiasis intestinal (Entamoeba histolytica)", "categoria": "Infecciones parasitarias", "nota": "CIE-11. Metronidazol oral por 7 a 10 días o Nitazoxanida."},
    {"codigo": "1A71", "descripcion": "Giardiasis (infección por Giardia lamblia)", "categoria": "Infecciones parasitarias", "nota": "CIE-11. Tinidazol dosis única o Metronidazol por 5 días."},
    {"codigo": "1A23", "descripcion": "Infecciones intestinales víricas (Rotavirus / Norovirus)", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Autolimitada; hidratación con suero oral, evitar antidiarreicos en pediatría."},
    {"codigo": "1A40", "descripcion": "Gastroenteritis y colitis de origen infeccioso no especificada", "categoria": "Infecciones gastrointestinales", "nota": "CIE-11. Priorizar suero oral (Vida Suero Oral / Electrolit) y probióticos."},
    {"codigo": "1B10", "descripcion": "Tuberculosis respiratoria confirmada bacteriológicamente", "categoria": "Infecciones respiratorias crónicas", "nota": "CIE-11. Tratamiento TAES normado obligatorio por Secretaría de Salud."},
    {"codigo": "1B20", "descripcion": "Faringitis y amigdalitis estreptocócica (Escarlatina)", "categoria": "Infecciones bacterianas", "nota": "CIE-11. Fiebre y exudado purulento; Penicilina o Amoxicilina."},
    {"codigo": "1B70", "descripcion": "Erisipela", "categoria": "Infecciones de la piel", "nota": "CIE-11. Placa eritematosa bien delimitada; antibiótico antiestreptocócico sistémico."},
    {"codigo": "1B90", "descripcion": "Infección bacteriana de sitio no especificado", "categoria": "Infecciones bacterianas", "nota": "CIE-11. Valoración médica clínica para antibioticoterapia guiada."},
    {"codigo": "1C10", "descripcion": "Sífilis no especificada", "categoria": "Infecciones de transmisión sexual", "nota": "CIE-11. Penicilina G benzatínica según estadio clínico."},
    {"codigo": "1C11", "descripcion": "Infección gonocócica (Gonorrea)", "categoria": "Infecciones de transmisión sexual", "nota": "CIE-11. Ceftriaxona intramuscular + Azitromicina oral (manejo de pareja)."},
    {"codigo": "1C80", "descripcion": "Infección por el virus de la inmunodeficiencia humana (VIH)", "categoria": "Enfermedades por retrovirus", "nota": "CIE-11. Tratamiento antirretroviral triterapia en CAPASITS / centros especializados."},
    {"codigo": "1E50", "descripcion": "Varicela sin complicaciones", "categoria": "Infecciones virales", "nota": "CIE-11. Aislamiento y sintomáticos; evitar Aspirina por riesgo de Sd. de Reye."},
    {"codigo": "1E91", "descripcion": "Herpes zóster (Fuego de San Antonio / Neuralgia posherpética)", "categoria": "Infecciones virales", "nota": "CIE-11. Valaciclovir / Aciclovir antes de 72h y neuromoduladores (Pregabalina)."},
    {"codigo": "1F00", "descripcion": "Infecciones por virus del herpes simple (Herpes labial / facial)", "categoria": "Infecciones virales", "nota": "CIE-11. Aciclovir tópico u oral en fase de pródromos o vesículas."},
    {"codigo": "1D20", "descripcion": "Dengue (con o sin signos de alarma)", "categoria": "Infecciones virales transmitidas por vectores", "nota": "CIE-11. Monitoreo de plaquetas y hematocrito; contraindicado el uso de AINEs o aspirina."},
    {"codigo": "1D22", "descripcion": "Infección por virus del Zika", "categoria": "Infecciones virales transmitidas por vectores", "nota": "CIE-11. Exantema, fiebre leve y conjuntivitis no purulenta; vigilancia teratogénica."},
    {"codigo": "1D23", "descripcion": "Fiebre de Chikungunya", "categoria": "Infecciones virales transmitidas por vectores", "nota": "CIE-11. Poliartralgias incapacitantes severas y fiebre alta; analgesia con Paracetamol."},
    {"codigo": "1E00", "descripcion": "Sarampión", "categoria": "Infecciones virales", "nota": "CIE-11. Enfermedad prevenible por vacunación; notificación inmediata obligatoria."},
    {"codigo": "1E01", "descripcion": "Rubeola", "categoria": "Infecciones virales", "nota": "CIE-11. Riesgo teratogénico severo en embarazadas; prevención con triple viral."},
    {"codigo": "1E51", "descripcion": "Parotiditis infecciosa (Paperas)", "categoria": "Infecciones virales", "nota": "CIE-11. Afectación de glándulas salivales parótidas; reposo y antiinflamatorios."},
    {"codigo": "1E80", "descripcion": "Mononucleosis infecciosa (Virus de Epstein-Barr)", "categoria": "Infecciones virales", "nota": "CIE-11. Fiebre, odinofagia y adenopatías; evitar ampicilina por exantema reactivo."},
    {"codigo": "1B9Z", "descripcion": "Infección viral aguda no especificada (Síndrome viral)", "categoria": "Infecciones virales", "nota": "CIE-11. Manejo sintomático con analgésicos, hidratación oral y reposo."},
    {"codigo": "1F27", "descripcion": "Dermatofitosis (Tiña pedis / Pie de atleta / Tiña corporis)", "categoria": "Micosis superficiales", "nota": "CIE-11. Antimicótico tópico (Clotrimazol, Terbinafina) por 2 a 4 semanas."},
    {"codigo": "1F28", "descripcion": "Tiña de las uñas (Onicomicosis)", "categoria": "Micosis superficiales", "nota": "CIE-11. Itraconazol o Terbinafina oral por periodos prolongados bajo vigilancia hepática."},
    {"codigo": "1F23", "descripcion": "Candidiasis oral / mucocutánea (Muguet oral)", "categoria": "Micosis", "nota": "CIE-11. Nistatina en suspensión oral o Fluconazol en cápsulas."},
    {"codigo": "1F23.1", "descripcion": "Candidiasis vulvovaginal", "categoria": "Micosis ginecológicas", "nota": "CIE-11. Óvulos de Miconazol/Clotrimazol o Fluconazol 150mg dosis única."},
    {"codigo": "1G03", "descripcion": "Escabiosis (Sarna humana)", "categoria": "Parasitosis cutáneas", "nota": "CIE-11. Permetrina crema al 5% o Ivermectina oral; tratar a todos los contactos del hogar."},
    {"codigo": "1G00", "descripcion": "Pediculosis de la cabeza (Piojos)", "categoria": "Parasitosis cutáneas", "nota": "CIE-11. Permetrina tópica al 1% o Dimeticona y remoción mecánica de liendres."},
    {"codigo": "1F90", "descripcion": "Parasitosis intestinal sin otra especificación", "categoria": "Parasitosis", "nota": "CIE-11. Desparasitación familiar semestral con Albendazol 400mg o Mebendazol."},

    # -------------------------------------------------------------------------
    # Cap. 02: Neoplasias (2A00-2F9Z)
    # -------------------------------------------------------------------------
    {"codigo": "2B60", "descripcion": "Tumor maligno de la mama (Cáncer de mama)", "categoria": "Neoplasias malignas", "nota": "CIE-11. Detección temprana con mastografía anual en mujeres >40 años."},
    {"codigo": "2C20", "descripcion": "Tumor maligno del cuello del útero (Cáncer cervicouterino)", "categoria": "Neoplasias malignas", "nota": "CIE-11. Tamizaje periódico con Papanicolaou y prueba molecular de VPH."},
    {"codigo": "2C00", "descripcion": "Tumor maligno de la próstata (Cáncer de próstata)", "categoria": "Neoplasias malignas", "nota": "CIE-11. Vigilancia de antígeno prostático específico (APE) en varones >45 años."},
    {"codigo": "2C50", "descripcion": "Tumor maligno de bronquios y pulmón", "categoria": "Neoplasias malignas", "nota": "CIE-11. Fuerte correlación causal con tabaquismo activo o pasivo y humo de leña."},
    {"codigo": "2B90", "descripcion": "Tumor maligno del colon y recto", "categoria": "Neoplasias malignas", "nota": "CIE-11. Detección con sangre oculta en heces y colonoscopia preventiva."},
    {"codigo": "2E90", "descripcion": "Leiomioma del útero (Miomatosis uterina)", "categoria": "Neoplasias benignas", "nota": "CIE-11. Causa común de menorragia y dolor pélvico crónico."},
    {"codigo": "2E80", "descripcion": "Pólipo benigno adenomatoso del colon", "categoria": "Neoplasias benignas", "nota": "CIE-11. Lesión premaligna resecable endoscópicamente."},

    # -------------------------------------------------------------------------
    # Cap. 03: Enfermedades de la sangre y órganos hematopoyéticos (3A00-3C0Z)
    # -------------------------------------------------------------------------
    {"codigo": "3A00", "descripcion": "Anemia por deficiencia de hierro (ferropénica)", "categoria": "Enfermedades de la sangre", "nota": "CIE-11. Suplementación con Sulfato Ferroso y Vitamina C con estómago vacío."},
    {"codigo": "3A01", "descripcion": "Anemia por deficiencia de vitamina B12 (megaloblástica)", "categoria": "Enfermedades de la sangre", "nota": "CIE-11. Cianocobalamina intramuscular o sublingual."},
    {"codigo": "3A02", "descripcion": "Anemia por deficiencia de ácido fólico", "categoria": "Enfermedades de la sangre", "nota": "CIE-11. Ácido fólico 5mg diario en pacientes desnutridos o gestantes."},
    {"codigo": "3A70", "descripcion": "Trombocitopenia no especificada", "categoria": "Enfermedades hematológicas", "nota": "CIE-11. Requiere investigación etiológica y biometría hemática completa seriada."},

    # -------------------------------------------------------------------------
    # Cap. 04: Enfermedades del sistema inmunitario (4A00-4B4Z)
    # -------------------------------------------------------------------------
    {"codigo": "4A80", "descripcion": "Lupus eritematoso sistémico", "categoria": "Enfermedades autoinmunes", "nota": "CIE-11. Manejo multidisciplinario con Hidroxicloroquina y corticoterapia."},
    {"codigo": "4A84", "descripcion": "Síndrome de Sjögren", "categoria": "Enfermedades autoinmunes", "nota": "CIE-11. Sequedad ocular y bucal; lágrimas artificiales y saliva sustituta."},

    # -------------------------------------------------------------------------
    # Cap. 05: Enfermedades endocrinas, nutricionales y metabólicas (5A00-5D46)
    # -------------------------------------------------------------------------
    {"codigo": "5A00", "descripcion": "Hipotiroidismo primario o no especificado", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Levotiroxina en ayunas 30-60 min antes de alimentos; control con TSH sérica."},
    {"codigo": "5A02", "descripcion": "Tirotoxicosis (Hipertiroidismo)", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Tiamazol y Propranolol para control adrenérgico sintomático."},
    {"codigo": "5A03", "descripcion": "Tiroiditis crónica autoinmune (de Hashimoto)", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Anticuerpos anti-TPO positivos; reemplazo hormonal tiroideo."},
    {"codigo": "5A10", "descripcion": "Diabetes mellitus tipo 1 (insulinodependiente)", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Insulinoterapia basal-bolo obligatoria y monitoreo capilar continuo."},
    {"codigo": "5A11", "descripcion": "Diabetes mellitus tipo 2", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Metformina, inhibidores SGLT2/GLP-1, cambios de estilo de vida y meta HbA1c <7%."},
    {"codigo": "5A11.0", "descripcion": "Diabetes mellitus tipo 2 con complicaciones microvasculares", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Retinopatía, nefropatía y neuropatía diabética."},
    {"codigo": "5A11.1", "descripcion": "Diabetes mellitus tipo 2 con complicaciones de pie diabético", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Cuidado podológico riguroso, desbridamiento, calzado terapéutico y antibióticos si hay úlcera."},
    {"codigo": "5A14", "descripcion": "Diabetes mellitus de tipo no especificado", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Diagnóstico provisional requiriendo confirmación bioquímica."},
    {"codigo": "5A40", "descripcion": "Hipoglucemia sintomática no especificada", "categoria": "Endocrino y emergencias", "nota": "CIE-11. Administración inmediata de carbohidratos de absorción rápida o dextrosa I.V."},
    {"codigo": "5B81", "descripcion": "Obesidad debida a exceso calórico (IMC > 30)", "categoria": "Endocrino y metabólico", "nota": "CIE-11. Terapia nutricional integral, actividad física regular y valoración médica metabólica."},
    {"codigo": "5C80", "descripcion": "Hipercolesterolemia pura (Colesterol elevado)", "categoria": "Trastornos lipídicos", "nota": "CIE-11. Estatinas (Atorvastatina 20-40mg / Rosuvastatina) y dieta cardioprotectora."},
    {"codigo": "5C81", "descripcion": "Hipertrigliceridemia pura (Triglicéridos elevados)", "categoria": "Trastornos lipídicos", "nota": "CIE-11. Fibratos (Bezafibrato 200mg / Fenofibrato) y reducción drástica de azúcares simples."},
    {"codigo": "5C82", "descripcion": "Hiperlipidemia mixta (Dislipidemia combinada)", "categoria": "Trastornos lipídicos", "nota": "CIE-11. Manejo del alto riesgo cardiovascular aterogénico."},
    {"codigo": "5C50", "descripcion": "Hiperuricemia asintomática sin signos de artritis", "categoria": "Metabolismo de purinas", "nota": "CIE-11. Alopurinol, hidratación abundante y reducción de carnes rojas y cerveza."},
    {"codigo": "5B50", "descripcion": "Depleción del volumen extracelular (Deshidratación)", "categoria": "Trastornos hidroelectrolíticos", "nota": "CIE-11. Reposición con sales de rehidratación oral de baja osmolaridad."},

    # -------------------------------------------------------------------------
    # Cap. 06: Trastornos mentales, del comportamiento y del neurodesarrollo (6A00-6E8Z)
    # -------------------------------------------------------------------------
    {"codigo": "6A70", "descripcion": "Episodio depresivo único (Depresión mayor)", "categoria": "Salud mental", "nota": "CIE-11. Inhibidores selectivos de la recaptación de serotonina (ISRS) y psicoterapia."},
    {"codigo": "6A71", "descripcion": "Trastorno depresivo recurrente", "categoria": "Salud mental", "nota": "CIE-11. Tratamiento antidepresivo de mantenimiento y acompañamiento psiquiátrico."},
    {"codigo": "6B00", "descripcion": "Trastorno de ansiedad generalizada (TAG)", "categoria": "Salud mental", "nota": "CIE-11. ISRS / IRSN (Sertralina, Escitalopram); ansiolíticos solo por periodos breves."},
    {"codigo": "6B01", "descripcion": "Trastorno de pánico (Crisis de angustia)", "categoria": "Salud mental", "nota": "CIE-11. Episodios recurrentes de angustia aguda intensa con palpitaciones y disnea."},
    {"codigo": "7A00", "descripcion": "Trastorno de insomnio crónico", "categoria": "Trastornos del sueño", "nota": "CIE-11. Higiene del sueño rigurosa, melatonina o inductores del sueño bajo prescripción."},
    {"codigo": "6A02", "descripcion": "Trastorno del espectro autista", "categoria": "Trastornos del neurodesarrollo", "nota": "CIE-11. Intervención temprana multidisciplinaria, terapia del lenguaje y conductual."},
    {"codigo": "6A05", "descripcion": "Trastorno por déficit de atención con hiperactividad (TDAH)", "categoria": "Trastornos del neurodesarrollo", "nota": "CIE-11. Psicoeducación y fármacos estimulantes o no estimulantes regulados."},

    # -------------------------------------------------------------------------
    # Cap. 08: Enfermedades del sistema nervioso (8A00-8E7Z)
    # -------------------------------------------------------------------------
    {"codigo": "8A00", "descripcion": "Enfermedad de Parkinson", "categoria": "Enfermedades neurodegenerativas", "nota": "CIE-11. Levodopa / Carbidopa con horarios estrictos de toma."},
    {"codigo": "8A20", "descripcion": "Enfermedad de Alzheimer", "categoria": "Enfermedades neurodegenerativas", "nota": "CIE-11. Donepezilo, Memantina y soporte al cuidador primario."},
    {"codigo": "8A60", "descripcion": "Epilepsia y síndromes epilépticos", "categoria": "Neurología", "nota": "CIE-11. Anticonvulsivantes (Ácido Valproico, Levetiracetam, Carbamazepina) con apego estricto."},
    {"codigo": "8A80", "descripcion": "Migraña (con o sin aura)", "categoria": "Cefaleas", "nota": "CIE-11. Triptanos o analgésicos específicos en crisis; profilaxis con Propranolol o Topiramato."},
    {"codigo": "8A81", "descripcion": "Cefalea tensional episódica o crónica", "categoria": "Cefaleas", "nota": "CIE-11. Paracetamol, Ibuprofeno o relajante muscular; manejo del estrés."},
    {"codigo": "8B11", "descripcion": "Polineuropatía diabética periférica", "categoria": "Neuropatías", "nota": "CIE-11. Control glucémico estricto, Pregabalina o Gabapentina y ácido alfa lipoico."},
    {"codigo": "8B90", "descripcion": "Parálisis de Bell (Parálisis facial periférica idiopática)", "categoria": "Neurología", "nota": "CIE-11. Corticoides orales tempranos (Prednisona), lágrimas artificiales y fisioterapia facial."},

    # -------------------------------------------------------------------------
    # Cap. 09: Enfermedades del sistema visual (9A00-9E1Z)
    # -------------------------------------------------------------------------
    {"codigo": "9A60", "descripcion": "Conjuntivitis aguda infecciosa o alérgica", "categoria": "Oftalmología", "nota": "CIE-11. Colirio antibiótico (Tobramicina / Ciprofloxacino) o antihistamínico (Olopatadina)."},
    {"codigo": "9A01", "descripcion": "Orzuelo y chalazión palpebral", "categoria": "Oftalmología", "nota": "CIE-11. Fomentos tibios locales y pomada oftálmica antibacteriana con antiinflamatorio."},
    {"codigo": "9B10", "descripcion": "Catarata senil o no especificada", "categoria": "Oftalmología", "nota": "CIE-11. Pérdida progresiva de agudeza visual; resolución quirúrgica con lente intraocular."},
    {"codigo": "9C61", "descripcion": "Glaucoma primario de ángulo abierto", "categoria": "Oftalmología", "nota": "CIE-11. Análogos de prostaglandinas (Latanoprost) o betabloqueadores oftálmicos (Timolol)."},

    # -------------------------------------------------------------------------
    # Cap. 10: Enfermedades del oído o apófisis mastoides (AA00-AC0Z)
    # -------------------------------------------------------------------------
    {"codigo": "AA00", "descripcion": "Otitis media aguda supurativa o serosa", "categoria": "Otorrinolaringología", "nota": "CIE-11. Amoxicilina con Ácido Clavulánico por 7-10 días y analgésicos sistémicos."},
    {"codigo": "AA30", "descripcion": "Otitis externa difusa (Oído de nadador)", "categoria": "Otorrinolaringología", "nota": "CIE-11. Gotas óticas con Neomicina/Polimixina B/Fluocinolona o Ciprofloxacino."},
    {"codigo": "AB30", "descripcion": "Vértigo posicional paroxístico benigno (VPPB)", "categoria": "Otorrinolaringología", "nota": "CIE-11. Maniobras de reposición canalicular (Epley) y Dimenhidrinato en crisis aguda."},

    # -------------------------------------------------------------------------
    # Cap. 11: Enfermedades del sistema circulatorio (BA00-BE2Z)
    # -------------------------------------------------------------------------
    {"codigo": "BA00", "descripcion": "Hipertensión esencial (primaria)", "categoria": "Cardiovascular", "nota": "CIE-11. Antihipertensivos de primera línea: IECA (Enalapril), ARA-II (Losartán), Calcioantagonistas."},
    {"codigo": "BA01", "descripcion": "Crisis hipertensiva (Urgencia o emergencia hipertensiva)", "categoria": "Cardiovascular / Urgencias", "nota": "CIE-11. TA >= 180/120 mmHg. Descartar daño agudo a órgano blanco y envío a urgencias."},
    {"codigo": "BA04", "descripcion": "Hipertensión arterial secundaria", "categoria": "Cardiovascular", "nota": "CIE-11. Causa renovascular, endocrina o por fármacos requiriendo estudio etiológico."},
    {"codigo": "BA41", "descripcion": "Angina de pecho (estable o inestable)", "categoria": "Cardiopatía isquémica", "nota": "CIE-11. Nitroglicerina sublingual en crisis, antiagregación y control estricto de lípidos."},
    {"codigo": "BA42", "descripcion": "Infarto agudo de miocardio", "categoria": "Cardiopatía isquémica", "nota": "CIE-11. Urgencia médica absoluta (Código Infarto / Reperfusión coronaria)."},
    {"codigo": "BD10", "descripcion": "Insuficiencia cardíaca congestiva", "categoria": "Cardiovascular", "nota": "CIE-11. Furosemida, Espironolactona, IECA/ARA-II y betabloqueadores cardioselectivos."},
    {"codigo": "BC81", "descripcion": "Fibrilación auricular y aleteo auricular", "categoria": "Arritmias cardíacas", "nota": "CIE-11. Control de frecuencia, anticoagulación oral (DOACs) para prevención de EVC."},
    {"codigo": "BD50", "descripcion": "Insuficiencia venosa periférica crónica (Várices)", "categoria": "Enfermedades vasculares", "nota": "CIE-11. Medias de compresión elástica graduada y flebotónicos (Diosmina / Hesperidina)."},
    {"codigo": "BD70", "descripcion": "Trombosis venosa profunda", "categoria": "Enfermedades vasculares", "nota": "CIE-11. Anticoagulación terapéutica inmediata y reposo estricto."},

    # -------------------------------------------------------------------------
    # Cap. 12: Enfermedades del sistema respiratorio (CA00-CB7Z)
    # -------------------------------------------------------------------------
    {"codigo": "CA00", "descripcion": "Rinofaringitis aguda (Resfriado común)", "categoria": "Infecciones respiratorias agudas", "nota": "CIE-11. Infección viral autolimitada; hidratación, aseo nasal con solución salina y Paracetamol."},
    {"codigo": "CA02", "descripcion": "Faringitis aguda", "categoria": "Infecciones respiratorias agudas", "nota": "CIE-11. Criterios de Centor para diferenciar origen viral vs bacteriano (Penicilina/Amoxicilina)."},
    {"codigo": "CA03", "descripcion": "Amigdalitis aguda bacteriana o viral", "categoria": "Infecciones respiratorias agudas", "nota": "CIE-11. Exudado purulento en criptas amigdalinas, odinofagia y adenopatías cervicales."},
    {"codigo": "CA08", "descripcion": "Sinusitis aguda (Rinosinusitis)", "categoria": "Infecciones respiratorias", "nota": "CIE-11. Descongestionantes, lavado nasal hipertónico y antibiótico si persiste >10 días."},
    {"codigo": "CA09", "descripcion": "Laringitis aguda y traqueítis (Crup)", "categoria": "Infecciones respiratorias", "nota": "CIE-11. Disfonía, tos perruna y estridor; nebulización fría y Dexametasona si hay estridor."},
    {"codigo": "CA22", "descripcion": "Enfermedad pulmonar obstructiva crónica (EPOC)", "categoria": "Enfermedades respiratorias crónicas", "nota": "CIE-11. Broncodilatadores inhalados (LAMA/LABA), oxigenoterapia domiciliaria y cese del tabaquismo."},
    {"codigo": "CA23", "descripcion": "Asma bronquial", "categoria": "Enfermedades respiratorias crónicas", "nota": "CIE-11. Salbutamol en aerosol de rescate y corticoide inhalado (Budesonida/Fluticasona) de control."},
    {"codigo": "CA23.0", "descripcion": "Asma alérgica con rinitis asociada", "categoria": "Enfermedades respiratorias crónicas", "nota": "CIE-11. Tratamiento combinado con antihistamínico oral y esteroide inhalado."},
    {"codigo": "CA23.1", "descripcion": "Asma no alérgica (intrínseca)", "categoria": "Enfermedades respiratorias crónicas", "nota": "CIE-11. Vigilancia de función pulmonar y técnica inhalatoria correcta."},
    {"codigo": "CA40", "descripcion": "Neumonía bacteriana adquirida en la comunidad", "categoria": "Infecciones respiratorias bajas", "nota": "CIE-11. Fiebre, tos con expectoración y estertores; Amoxicilina/Clavulánico o Macrólido."},
    {"codigo": "CA42", "descripcion": "Bronquitis aguda", "categoria": "Infecciones respiratorias", "nota": "CIE-11. Mayoría viral; no indicar antibióticos de rutina. Broncodilatador si hay sibilancias."},
    {"codigo": "CA70", "descripcion": "Rinitis alérgica estacional o perenne", "categoria": "Alergias respiratorias", "nota": "CIE-11. Antihistamínicos de 2ª generación (Loratadina, Cetirizina) y spray nasal con Mometasona."},

    # -------------------------------------------------------------------------
    # Cap. 13: Enfermedades del sistema digestivo (DA00-DE2Z)
    # -------------------------------------------------------------------------
    {"codigo": "DA01", "descripcion": "Gingivitis y enfermedades periodontales", "categoria": "Salud bucal", "nota": "CIE-11. Enjuagues con Clorhexidina al 0.12% y profilaxis dental profesional."},
    {"codigo": "DA02", "descripcion": "Caries dental", "categoria": "Salud bucal", "nota": "CIE-11. Restauración odontológica y pasta fluorada."},
    {"codigo": "DA22", "descripcion": "Enfermedad por reflujo gastroesofágico (ERGE)", "categoria": "Aparato digestivo", "nota": "CIE-11. Inhibidor de bomba de protones (Omeprazol, Pantoprazol) antes del desayuno."},
    {"codigo": "DA42", "descripcion": "Gastritis y gastroduodenitis aguda o crónica", "categoria": "Aparato digestivo", "nota": "CIE-11. Medidas dietéticas (evitar irritantes, picante, alcohol) y antiácidos/IBP."},
    {"codigo": "DA60", "descripcion": "Úlcera péptica gástrica o duodenal", "categoria": "Aparato digestivo", "nota": "CIE-11. Erradicación de Helicobacter pylori con esquema cuádruple o triple guiado."},
    {"codigo": "DD91", "descripcion": "Síndrome del intestino irritable (Colitis nerviosa)", "categoria": "Aparato digestivo", "nota": "CIE-11. Antiespasmódicos (Bromuro de Pinaverio, Butilhioscina), fibra soluble y probióticos."},
    {"codigo": "DB30", "descripcion": "Apendicitis aguda", "categoria": "Urgencias quirúrgicas", "nota": "CIE-11. Dolor en fosa ilíaca derecha, náusea y rebote positivo; intervención quirúrgica urgente."},
    {"codigo": "DC11", "descripcion": "Colelitiasis (Cálculos biliares en la vesícula) y colecistitis", "categoria": "Enfermedades hepatobiliares", "nota": "CIE-11. Cólico biliar tras ingesta copiosa o grasosa; valoración para colecistectomía."},
    {"codigo": "DB90", "descripcion": "Hígado graso no alcohólico (Esteatosis hepática)", "categoria": "Enfermedades hepáticas", "nota": "CIE-11. Reducción ponderal, ejercicio aeróbico regular y control glucémico."},
    {"codigo": "DB71", "descripcion": "Hemorroides internas o externas", "categoria": "Enfermedades proctológicas", "nota": "CIE-11. Baños de asiento tibios, pomada de Lidocaína/Hidrocortisona y dieta alta en fibra."},

    # -------------------------------------------------------------------------
    # Cap. 14: Enfermedades de la piel (EA00-EM0Z)
    # -------------------------------------------------------------------------
    {"codigo": "EA80", "descripcion": "Dermatitis atópica (Eccema)", "categoria": "Dermatología", "nota": "CIE-11. Emolientes hidratantes libres de fragancia y corticoides tópicos leves en brotes."},
    {"codigo": "EA90", "descripcion": "Dermatitis por contacto alérgica o irritativa", "categoria": "Dermatología", "nota": "CIE-11. Identificar y retirar el alérgeno causante; crema de Hidrocortisona al 1%."},
    {"codigo": "EB00", "descripcion": "Urticaria aguda o crónica", "categoria": "Dermatología", "nota": "CIE-11. Antihistamínicos no sedantes (Cetirizina, Fexofenadina) a dosis terapéuticas."},
    {"codigo": "EA10", "descripcion": "Psoriasis en placas", "categoria": "Dermatología", "nota": "CIE-11. Queratolíticos, análogos de vitamina D tópicos y corticoterapia supervisada."},
    {"codigo": "ED40", "descripcion": "Acné vulgar común (Grado I a IV)", "categoria": "Dermatología", "nota": "CIE-11. Peróxido de Benzoilo, Retinoides tópicos (Adapaleno) y antibiótico oral si procede."},
    {"codigo": "EA50", "descripcion": "Alopecia areata o androgénica", "categoria": "Dermatología", "nota": "CIE-11. Minoxidil tópico al 5% o corticoides intralesionales según etiología."},
    {"codigo": "EE10", "descripcion": "Celulitis bacteriana cutánea", "categoria": "Infecciones cutáneas", "nota": "CIE-11. Eritema cutáneo difuso con calor local; antibióticos antiestafilocócicos (Dicloxacilina/Cefalexina)."},
    {"codigo": "EE12", "descripcion": "Impétigo contagioso (costras melicéricas)", "categoria": "Infecciones cutáneas", "nota": "CIE-11. Mupirocina en ungüento tópico al 2% o antibióticos orales si es extenso."},

    # -------------------------------------------------------------------------
    # Cap. 15: Enfermedades del sistema musculoesquelético (FA00-FC0Z)
    # -------------------------------------------------------------------------
    {"codigo": "FA00", "descripcion": "Osteoartritis / Artrosis de la rodilla (Gonartrosis)", "categoria": "Reumatología", "nota": "CIE-11. Paracetamol, AINEs tópicos/orales en crisis, fortalecimiento muscular y glucosamina."},
    {"codigo": "FA01", "descripcion": "Osteoartritis de la cadera (Coxartrosis)", "categoria": "Reumatología", "nota": "CIE-11. Control de peso corporal, fisioterapia analgésica y valoración ortopédica."},
    {"codigo": "FA20", "descripcion": "Artritis reumatoide", "categoria": "Reumatología", "nota": "CIE-11. Fármacos modificadores de la enfermedad (Metotrexato) bajo supervisión médica estricta."},
    {"codigo": "FB56", "descripcion": "Osteoporosis sin fractura patológica actual", "categoria": "Metabolismo óseo", "nota": "CIE-11. Calcio + Vitamina D3, Bifosfonatos (Alendronato) y prevención de caídas."},
    {"codigo": "ME84.2", "descripcion": "Lumbalgia / Dolor lumbar mecánico (Lumbago / Ciática)", "categoria": "Traumatología y ortopedia", "nota": "CIE-11. AINEs (Ketorolaco, Meloxicam), Complejo B con relajante muscular (Metocarbamol)."},
    {"codigo": "FA31", "descripcion": "Gota aguda (Artritis gotosa tofácea)", "categoria": "Reumatología", "nota": "CIE-11. Colchicina o Indometacina en crisis aguda; Alopurinol en fase intercrítica."},
    {"codigo": "FB30", "descripcion": "Tendinitis y bursitis (Manguito rotador / Epicondilitis)", "categoria": "Traumatología", "nota": "CIE-11. Reposo relativo, frío local, antiinflamatorios no esteroideos y rehabilitación."},
    {"codigo": "FB40", "descripcion": "Fibromialgia", "categoria": "Reumatología", "nota": "CIE-11. Puntos dolorosos generalizados; Pregabalina, Duloxetina y ejercicio aeróbico suave."},

    # -------------------------------------------------------------------------
    # Cap. 16: Enfermedades del sistema genitourinario (GA00-GC8Z)
    # -------------------------------------------------------------------------
    {"codigo": "GC00", "descripcion": "Cistitis aguda (Infección de vías urinarias bajas no complicada)", "categoria": "Urología", "nota": "CIE-11. Disuria, polaquiuria; Nitrofurantoína, Fosfomicina o Trimetoprima con Sulfametoxazol."},
    {"codigo": "GC08", "descripcion": "Pielonefritis aguda (Infección urinaria alta)", "categoria": "Urología", "nota": "CIE-11. Fiebre alta, dolor lumbar y Giordano positivo; antibiótico parenteral inicial."},
    {"codigo": "GA90", "descripcion": "Hiperplasia prostática benigna (Crecimiento de próstata)", "categoria": "Urología", "nota": "CIE-11. Tamsulosina 0.4mg diaria y Finasterida si el volumen prostático es grande."},
    {"codigo": "GB61", "descripcion": "Cálculos renales y ureterales (Litiasis urinaria)", "categoria": "Urología", "nota": "CIE-11. Hidratación vigorosa, analgésicos potentes y valoración urológica para litotricia."},
    {"codigo": "GB60", "descripcion": "Cólico renal / nefrítico agudo", "categoria": "Urgencias urológicas", "nota": "CIE-11. Dolor espasmódico intenso; analgesia I.V. (AINE + antiespasmódico) y ultrasonido renal."},
    {"codigo": "GA34", "descripcion": "Dismenorrea primaria (Dolor menstrual intenso)", "categoria": "Ginecología", "nota": "CIE-11. AINEs (Ácido Mefenámico, Ibuprofeno) iniciando antes del flujo menstrual."},
    {"codigo": "GA10", "descripcion": "Vaginitis y vulvovaginitis infecciosa", "categoria": "Ginecología", "nota": "CIE-11. Tratamiento etiológico específico (óvulos combinados con Metronidazol y Nistatina)."},

    # -------------------------------------------------------------------------
    # Cap. 18: Embarazo, parto o puerperio (JA00-JB6Z)
    # -------------------------------------------------------------------------
    {"codigo": "JA00", "descripcion": "Supervisión médica de embarazo normal", "categoria": "Obstetricia", "nota": "CIE-11. Control prenatal mensual, Ácido Fólico 0.4-5mg y Sulfato Ferroso profiláctico."},
    {"codigo": "JA20", "descripcion": "Hipertensión gestacional / Preeclampsia", "categoria": "Obstetricia / Urgencias", "nota": "CIE-11. Monitoreo estricto de proteinuria, reflejos osteotendinosos y bienestar fetal."},
    {"codigo": "JA65", "descripcion": "Infección de vías urinarias en el embarazo", "categoria": "Obstetricia", "nota": "CIE-11. Tratar bacteriuria asintomática con Amoxicilina, Cefalexina o Nitrofurantoína (según trimestre)."},

    # -------------------------------------------------------------------------
    # Cap. 21: Síntomas, signos o hallazgos clínicos no clasificados (MA00-MH9Z)
    # -------------------------------------------------------------------------
    {"codigo": "MG22", "descripcion": "Fiebre de origen desconocido o persistente", "categoria": "Signos y síntomas generales", "nota": "CIE-11. Medios físicos, Paracetamol y búsqueda minuciosa del foco infeccioso o inflamatorio."},
    {"codigo": "MG30", "descripcion": "Cefalea no especificada (Dolor de cabeza)", "categoria": "Signos y síntomas", "nota": "CIE-11. Analgesia simple; descartar signos de alarma neurológica (cefalea en trueno)."},
    {"codigo": "MD90", "descripcion": "Tos aguda (< 3 semanas de evolución)", "categoria": "Signos respiratorios", "nota": "CIE-11. Descartar broncoespasmo; antitusígenos o mucolíticos (Ambroxol/Dextrometorfano)."},
    {"codigo": "MD91", "descripcion": "Tos crónica persistente (> 8 semanas)", "categoria": "Signos respiratorios", "nota": "CIE-11. Descartar asma tososa, reflujo gastroesofágico, goteo posnasal o fármacos (IECA)."},
    {"codigo": "MD30", "descripcion": "Disnea / Dificultad para respirar", "categoria": "Signos respiratorios", "nota": "CIE-11. Signo de alarma; requiere oximetría de pulso y evaluación cardiopulmonar inmediata."},
    {"codigo": "MD81", "descripcion": "Epistaxis (Hemorragia nasal)", "categoria": "Signos y síntomas", "nota": "CIE-11. Compresión digital de alas nasales por 10 min inclinando la cabeza hacia adelante."},
    {"codigo": "MD50", "descripcion": "Dolor torácico no especificado", "categoria": "Urgencias / Signos", "nota": "CIE-11. Electrocardiograma obligado para descartar síndrome coronario agudo."},
    {"codigo": "ME00", "descripcion": "Dolor abdominal agudo no especificado", "categoria": "Signos digestivos", "nota": "CIE-11. Evitar analgésicos opioides previos a la valoración para no enmascarar abdomen agudo."},

    # -------------------------------------------------------------------------
    # Cap. 22: Traumatismos, envenenamientos y consecuencias externas (NA00-NF0Z)
    # -------------------------------------------------------------------------
    {"codigo": "NC32", "descripcion": "Esguince y torcedura del tobillo", "categoria": "Traumatología", "nota": "CIE-11. Reposo, hielo local, vendaje elástico compresivo y elevación de extremidad + AINE."},
    {"codigo": "NC12", "descripcion": "Esguince y torcedura cervical (Síndrome de latigazo)", "categoria": "Traumatología", "nota": "CIE-11. Collarín cervical blando por pocos días, analgésico y relajante muscular."},
    {"codigo": "NC52", "descripcion": "Fractura de la muñeca y mano (Radio distal / Colles)", "categoria": "Traumatología", "nota": "CIE-11. Inmovilización inmediata con férula y referencia a ortopedia."},
    {"codigo": "ND56", "descripcion": "Contusión y traumatismo superficial (Hematoma / Raspadura)", "categoria": "Traumatología", "nota": "CIE-11. Lavado con agua y antiséptico, frío local para reducir edema."},
    {"codigo": "ND32", "descripcion": "Quemaduras térmicas de primer y segundo grado superficial", "categoria": "Traumatología", "nota": "CIE-11. Enfriar con agua limpia a temperatura ambiente; Sulfadiazina de plata en crema."},
    {"codigo": "NE61", "descripcion": "Efecto tóxico por veneno de escorpión / alacrán", "categoria": "Toxicología", "nota": "CIE-11. Suero antialacránico (Faboterápico Alacramyn) según severidad clínica."},
    {"codigo": "NE60", "descripcion": "Efecto tóxico por veneno de serpiente (Mordedura de víbora)", "categoria": "Toxicología", "nota": "CIE-11. Antivipmyn en servicio de urgencias médicas hospitalarias de inmediato."},

    # -------------------------------------------------------------------------
    # Cap. 25: Códigos para propósitos especiales (RA00-RZ9Z)
    # -------------------------------------------------------------------------
    {"codigo": "RA01", "descripcion": "Enfermedad por coronavirus 2019 (COVID-19), virus identificado", "categoria": "Infecciones emergentes", "nota": "CIE-11. Oximetría de pulso continua, aislamiento domiciliario y vigilancia de disnea."},
    {"codigo": "RA02", "descripcion": "Afección posterior a la COVID-19 (COVID prolongado / Long COVID)", "categoria": "Secuelas postinfecciosas", "nota": "CIE-11. Fatiga crónica, niebla mental y disnea persistente tras infección aguda."},
]

# Alias para retrocompatibilidad
CIE10_DIAGNOSTICOS = CIE11_DIAGNOSTICOS


# Diccionario semántico bilingüe Español -> Inglés para consultar el motor oficial de la API ICD-11
DICCIONARIO_TERMINOS_MEDICOS = {
    "hipertension": "hypertension",
    "presion": "blood pressure",
    "presion alta": "essential hypertension",
    "diabetes": "diabetes",
    "azucar": "diabetes mellitus",
    "asma": "asthma",
    "faringitis": "pharyngitis",
    "amigdalitis": "tonsillitis",
    "dolor": "pain",
    "cabeza": "headache",
    "pecho": "chest pain",
    "estomago": "abdominal pain",
    "gastroenteritis": "gastroenteritis",
    "diarrea": "diarrhea",
    "vomito": "vomiting",
    "nausea": "nausea",
    "gripe": "influenza",
    "gripa": "common cold",
    "resfriado": "nasopharyngitis",
    "tos": "cough",
    "rinofaringitis": "nasopharyngitis",
    "sinusitis": "sinusitis",
    "neumonia": "pneumonia",
    "pulmonia": "pneumonia",
    "bronquitis": "bronchitis",
    "infeccion": "infection",
    "urinaria": "cystitis",
    "vias urinarias": "urinary tract infection",
    "rinon": "kidney",
    "vejiga": "cystitis",
    "cistitis": "cystitis",
    "artritis": "arthritis",
    "artrosis": "osteoarthritis",
    "columna": "spine",
    "espalda": "back pain",
    "lumbalgia": "low back pain",
    "cuello": "neck pain",
    "piel": "dermatitis",
    "alergia": "allergy",
    "urticaria": "urticaria",
    "herpes": "herpes",
    "varicela": "varicella",
    "embarazo": "pregnancy",
    "parto": "labor",
    "ojo": "eye",
    "conjuntivitis": "conjunctivitis",
    "oido": "ear",
    "otitis": "otitis",
    "ansiedad": "anxiety",
    "depresion": "depression",
    "insomnio": "insomnia",
    "tiroides": "thyroid",
    "hipotiroidismo": "hypothyroidism",
    "hipertiroidismo": "hyperthyroidism",
    "obesidad": "obesity",
    "colesterol": "hypercholesterolemia",
    "trigliceridos": "hypertriglyceridemia",
    "acido urico": "hyperuricemia",
    "gota": "gout",
    "esguince": "sprain",
    "fractura": "fracture",
    "quemadura": "burn",
    "covid": "covid",
    "coronavirus": "coronavirus",
    "epoc": "chronic obstructive pulmonary disease",
    "gastritis": "gastritis",
    "colitis": "irritable bowel syndrome",
    "migrana": "migraine",
    "epilepsia": "epilepsy",
    "parkinson": "parkinson",
    "alzheimer": "alzheimer",
}


def buscar_en_catalogo_cie_local(query: str, limit: int = 50) -> List[Dict[str, Any]]:
    """
    Busca diagnósticos en el catálogo CIE-11 local con un algoritmo de ponderación
    normalizado insensible a acentos, mayúsculas, y con coincidencia de múltiples términos.
    """
    q_norm = normalizar_texto(query)
    if not q_norm:
        return []

    tokens = [t for t in q_norm.split() if len(t) > 1]
    if not tokens:
        tokens = [q_norm]

    coincidencias: List[Dict[str, Any]] = []

    for diag in CIE11_DIAGNOSTICOS:
        cod_norm = normalizar_texto(diag["codigo"])
        desc_norm = normalizar_texto(diag["descripcion"])
        cat_norm = normalizar_texto(diag["categoria"])
        nota_norm = normalizar_texto(diag.get("nota", ""))

        puntaje = 0

        # Coincidencia de código exacta o por prefijo (ej: "BA00", "5A11")
        cod_sin_punto = cod_norm.replace(".", "")
        q_sin_punto = q_norm.replace(".", "")

        if cod_norm == q_norm or cod_sin_punto == q_sin_punto:
            puntaje += 150
        elif cod_norm.startswith(q_norm) or cod_sin_punto.startswith(q_sin_punto):
            puntaje += 100
        elif q_norm in cod_norm:
            puntaje += 75

        # Coincidencia de frase exacta en descripción
        if q_norm in desc_norm:
            puntaje += 60
        elif q_norm in cat_norm:
            puntaje += 40

        # Coincidencia de palabras individuales (tokens)
        coincidencias_tokens = 0
        for token in tokens:
            if token in desc_norm:
                coincidencias_tokens += 1
            elif token in cat_norm:
                coincidencias_tokens += 0.8
            elif token in nota_norm:
                coincidencias_tokens += 0.5

        if len(tokens) > 1 and coincidencias_tokens == len(tokens):
            puntaje += 50
        elif coincidencias_tokens > 0:
            puntaje += int(coincidencias_tokens * 15)

        if puntaje > 0:
            coincidencias.append({
                "diag": diag,
                "score": puntaje
            })

    # Ordenar por puntaje descendente
    coincidencias.sort(key=lambda x: x["score"], reverse=True)
    return [c["diag"] for c in coincidencias[:limit]]


def consultar_api_cie_externa(query: str, limit: int = 15) -> List[Dict[str, Any]]:
    """
    Consulta a la API pública oficial de NIH Clinical Tables Search Service para ICD-11 (CIE-11).
    Aplica traducción de conceptos clave y búsqueda por prefijos para obtener
    resultados altamente relevantes en la linearización oficial de la OMS.
    """
    termino_original = query.strip()
    if not termino_original or len(termino_original) < 2:
        return []

    q_norm = normalizar_texto(termino_original)
    terminos_a_probar = [termino_original]

    # Detectar palabras clave en el diccionario para enriquecer la consulta a la API de ICD-11
    traducciones = []
    for esp, eng in DICCIONARIO_TERMINOS_MEDICOS.items():
        if esp in q_norm:
            traducciones.append(eng)

    if traducciones:
        terminos_a_probar.append(" ".join(traducciones[:2]))

    resultados_externos: List[Dict[str, Any]] = []
    codigos_vistos = set()

    for term in terminos_a_probar:
        if len(resultados_externos) >= limit:
            break

        url = (
            f"https://clinicaltables.nlm.nih.gov/api/icd11_codes/v3/search?"
            f"terms={urllib.parse.quote(term)}&df=code,title,chapter&maxResults={limit}"
        )

        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "FarmaControl-POS-CIE11-Advanced/2.0"}
            )
            with urllib.request.urlopen(req, timeout=2.5) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode("utf-8"))
                    if len(data) >= 4 and data[3]:
                        for row in data[3]:
                            code = str(row[0]).strip().upper()
                            name = str(row[1]).strip()
                            cap_num = str(row[2]).strip() if len(row) > 2 else ""
                            cap_desc = CAPITULOS_CIE11.get(cap_num.zfill(2), f"Capítulo {cap_num} (CIE-11)")
                            if code not in codigos_vistos:
                                codigos_vistos.add(code)
                                resultados_externos.append({
                                    "codigo": code,
                                    "descripcion": name,
                                    "categoria": cap_desc,
                                    "nota": f"CIE-11 Oficial (OMS / API NIH) - Cap. {cap_num}."
                                })
        except Exception:
            pass

    return resultados_externos[:limit]
