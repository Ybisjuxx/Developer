"""
Catálogo Oficial CIE-10 (Clasificación Internacional de Enfermedades - OMS/OPS)
Catálogo ampliado con más de 200 patologías frecuentes en medicina general, especialidades,
urgencias, pediatría y farmacia comunitaria en México.
Soporta búsqueda inteligente normalizada (sin acentos, tokens múltiples, códigos con o sin punto)
e integración bilingüe con la API de terminología médica de NIH (ICD-10-CM).
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


# Catálogo exhaustivo y enriquecido de diagnósticos frecuentes CIE-10 en México
CIE10_DIAGNOSTICOS: List[Dict[str, str]] = [
    # -------------------------------------------------------------------------
    # Cap. I: Ciertas enfermedades infecciosas y parasitarias (A00-B99)
    # -------------------------------------------------------------------------
    {"codigo": "A00", "descripcion": "Cólera", "categoria": "Infecciones gastrointestinales", "nota": "Notificación epidemiológica inmediata obligatoria ante Jurisdicción Sanitaria."},
    {"codigo": "A01", "descripcion": "Fiebres tifoidea y paratifoidea (Salmonella typhi)", "categoria": "Infecciones gastrointestinales", "nota": "Ceftriaxona, Azitromicina o Ciprofloxacino. Evitar automedicación."},
    {"codigo": "A02", "descripcion": "Otras infecciones por Salmonella (Salmonelosis / enteritis)", "categoria": "Infecciones gastrointestinales", "nota": "Rehidratación oral intensiva; antibióticos en casos graves o ancianos."},
    {"codigo": "A03", "descripcion": "Shigelosis (Disentería bacilar)", "categoria": "Infecciones gastrointestinales", "nota": "Heces con moco y sangre. Hidratación y fluoroquinolonas si procede."},
    {"codigo": "A04", "descripcion": "Otras infecciones intestinales bacterianas (E. coli, Campylobacter)", "categoria": "Infecciones gastrointestinales", "nota": "Manejo hidroelectrolítico y cultivo de heces."},
    {"codigo": "A06", "descripcion": "Amebiasis intestinal (Entamoeba histolytica)", "categoria": "Infecciones parasitarias", "nota": "Metronidazol oral por 7 a 10 días o Nitazoxanida."},
    {"codigo": "A07.1", "descripcion": "Giardiasis (infección por Giardia lamblia)", "categoria": "Infecciones parasitarias", "nota": "Tinidazol dosis única o Metronidazol por 5 días."},
    {"codigo": "A08", "descripcion": "Infecciones intestinales víricas (Rotavirus / Norovirus)", "categoria": "Infecciones gastrointestinales", "nota": "Autolimitada; no dar antibióticos ni antidiarreicos fuertes a niños."},
    {"codigo": "A09", "descripcion": "Gastroenteritis y colitis de origen infeccioso no especificada", "categoria": "Infecciones gastrointestinales", "nota": "Priorizar suero oral (Electrolit/Vida Suero Oral) y probióticos."},
    {"codigo": "A15", "descripcion": "Tuberculosis respiratoria confirmada bacteriológicamente", "categoria": "Infecciones respiratorias crónicas", "nota": "Tratamiento TAES normado obligatorio por Secretaría de Salud."},
    {"codigo": "A38", "descripcion": "Escarlatina (Streptococcus pyogenes)", "categoria": "Infecciones bacterianas", "nota": "Fiebre con exantema en papel de lija; Penicilina o Amoxicilina."},
    {"codigo": "A46", "descripcion": "Erisipela", "categoria": "Infecciones de la piel", "nota": "Placa eritematosa bien delimitada; antibiótico sistémico antiesptreptocócico."},
    {"codigo": "A49", "descripcion": "Infección bacteriana de sitio no especificado", "categoria": "Infecciones bacterianas", "nota": "Valoración médica clínica para antibioticoterapia guiada."},
    {"codigo": "A53", "descripcion": "Sífilis no especificada", "categoria": "Infecciones de transmisión sexual", "nota": "Penicilina G benzatínica según estadio clínico."},
    {"codigo": "A54", "descripcion": "Infección gonocócica (Gonorrea)", "categoria": "Infecciones de transmisión sexual", "nota": "Ceftriaxona intramuscular + Azitromicina oral (manejo de pareja)."},
    {"codigo": "A60", "descripcion": "Infección anogenital por virus del herpes simple", "categoria": "Infecciones de transmisión sexual", "nota": "Aciclovir o Valaciclovir temprano y analgesia."},
    {"codigo": "B00", "descripcion": "Infecciones por el virus del herpes simple (Herpes labial / facial)", "categoria": "Infecciones virales", "nota": "Aciclovir tópico u oral en fase de pródromos o vesículas."},
    {"codigo": "B01", "descripcion": "Varicela sin complicaciones", "categoria": "Infecciones virales", "nota": "Aislamiento y sintomáticos; evitar Aspirina por riesgo de Sd. de Reye."},
    {"codigo": "B02", "descripcion": "Herpes zóster (Fuego de San Antonio)", "categoria": "Infecciones virales", "nota": "Valaciclovir / Aciclovir antes de 72h y neuromoduladores (Pregabalina)."},
    {"codigo": "B05", "descripcion": "Sarampión", "categoria": "Infecciones virales", "nota": "Enfermedad prevenible por vacunación; notificación obligatoria."},
    {"codigo": "B06", "descripcion": "Rubeola", "categoria": "Infecciones virales", "nota": "Riesgo teratogénico severo en embarazadas."},
    {"codigo": "B15", "descripcion": "Hepatitis aguda tipo A", "categoria": "Infecciones virales hepáticas", "nota": "Transmisión fecal-oral; reposo, dieta hipercalórica y control de enzimas."},
    {"codigo": "B16", "descripcion": "Hepatitis aguda tipo B", "categoria": "Infecciones virales hepáticas", "nota": "Transmisión parenteral y sexual; seguimiento especializado."},
    {"codigo": "B18.2", "descripcion": "Hepatitis viral tipo C crónica", "categoria": "Infecciones virales hepáticas", "nota": "Antivirales de acción directa (AAD) con tasa de cura >95%."},
    {"codigo": "B20", "descripcion": "Enfermedad por virus de la inmunodeficiencia humana (VIH)", "categoria": "Enfermedades por retrovirus", "nota": "Tratamiento antirretroviral triterapia en CAPASITS / centros de salud."},
    {"codigo": "B26", "descripcion": "Parotiditis infecciosa (Paperas)", "categoria": "Infecciones virales", "nota": "Afectación de glándulas salivales; reposo y antiinflamatorios."},
    {"codigo": "B27", "descripcion": "Mononucleosis infecciosa (Virus de Epstein-Barr)", "categoria": "Infecciones virales", "nota": "Fiebre, odinofagia, adenomegalias; no dar ampicilina por exantema reactivo."},
    {"codigo": "B34.9", "descripcion": "Infección viral no especificada (Síndrome viral)", "categoria": "Infecciones virales", "nota": "Manejo sintomático con analgésicos, hidratación oral y reposo."},
    {"codigo": "B35", "descripcion": "Dermatofitosis (Tiña pedis / Pie de atleta / Tiña corporis)", "categoria": "Micosis superficiales", "nota": "Antimicótico tópico (Clotrimazol, Miconazol, Terbinafina) por 2-4 semanas."},
    {"codigo": "B35.1", "descripcion": "Tiña de las uñas (Onicomicosis)", "categoria": "Micosis superficiales", "nota": "Itraconazol o Terbinafina oral por periodos prolongados."},
    {"codigo": "B37", "descripcion": "Candidiasis (oral / mucocutánea / intertrigo)", "categoria": "Micosis", "nota": "Tratamiento con Nistatina o Fluconazol oral."},
    {"codigo": "B37.3", "descripcion": "Candidiasis de la vulva y de la vagina (Candidiasis vaginal)", "categoria": "Micosis ginecológicas", "nota": "Óvulos de Clotrimazol / Miconazol o Fluconazol 150mg dosis única."},
    {"codigo": "B82", "descripcion": "Parasitosis intestinal sin otra especificación", "categoria": "Parasitosis", "nota": "Desparasitación familiar recomendada (Albendazol 400mg o Mebendazol)."},
    {"codigo": "B86", "descripcion": "Escabiosis (Sarna humana)", "categoria": "Parasitosis cutáneas", "nota": "Permetrina crema al 5% o Ivermectina oral; tratar a todos los contactos."},
    {"codigo": "B85", "descripcion": "Pediculosis (Piojos de la cabeza)", "categoria": "Parasitosis cutáneas", "nota": "Permetrina tópica al 1% o Dimeticona y remoción mecánica de liendres."},

    # -------------------------------------------------------------------------
    # Cap. II: Neoplasias (C00-D48)
    # -------------------------------------------------------------------------
    {"codigo": "C50", "descripcion": "Tumor maligno de la mama (Cáncer de mama)", "categoria": "Neoplasias malignas", "nota": "Detección temprana con mastografía anual en mujeres >40 años."},
    {"codigo": "C53", "descripcion": "Tumor maligno del cuello del útero (Cáncer cervicouterino)", "categoria": "Neoplasias malignas", "nota": "Tamizaje periódico mediante Papanicolaou y prueba de VPH."},
    {"codigo": "C61", "descripcion": "Tumor maligno de la próstata (Cáncer de próstata)", "categoria": "Neoplasias malignas", "nota": "Vigilancia de antígeno prostático específico (APE) en varones >45 años."},
    {"codigo": "C34", "descripcion": "Tumor maligno de los bronquios y del pulmón", "categoria": "Neoplasias malignas", "nota": "Fuerte correlación con tabaquismo activo o pasivo."},
    {"codigo": "C18", "descripcion": "Tumor maligno del colon", "categoria": "Neoplasias malignas", "nota": "Manejo quirúrgico y oncológico."},
    {"codigo": "D12", "descripcion": "Tumor benigno del colon, del recto y del ano", "categoria": "Neoplasias benignas", "nota": "Pólipos adenomatosos resecables por colonoscopia."},
    {"codigo": "D25", "descripcion": "Leiomioma del útero (Miomatosis uterina)", "categoria": "Neoplasias benignas", "nota": "Causa común de hemorragia uterina anormal y dolor pélvico."},

    # -------------------------------------------------------------------------
    # Cap. III: Enfermedades de la sangre y de los órganos hematopoyéticos (D50-D89)
    # -------------------------------------------------------------------------
    {"codigo": "D50", "descripcion": "Anemia por deficiencia de hierro (ferropénica)", "categoria": "Enfermedades de la sangre", "nota": "Suplementación con Sulfato Ferroso y Vitamina C con estómago vacío."},
    {"codigo": "D51", "descripcion": "Anemia por deficiencia de vitamina B12 (megaloblástica)", "categoria": "Enfermedades de la sangre", "nota": "Cianocobalamina intramuscular o sublingual."},
    {"codigo": "D53", "descripcion": "Otras anemias nutricionales (déficit de ácido fólico)", "categoria": "Enfermedades de la sangre", "nota": "Ácido Fólico 5mg diario en pacientes con desnutrición o gestación."},
    {"codigo": "D69.6", "descripcion": "Trombocitopenia no especificada", "categoria": "Enfermedades hematológicas", "nota": "Requiere investigación etiológica y biometría hemática completa."},

    # -------------------------------------------------------------------------
    # Cap. IV: Enfermedades endocrinas, nutricionales y metabólicas (E00-E90)
    # -------------------------------------------------------------------------
    {"codigo": "E03.9", "descripcion": "Hipotiroidismo no especificado", "categoria": "Endocrino y metabólico", "nota": "Levotiroxina en ayunas 30-60 min antes de alimentos; control con TSH."},
    {"codigo": "E05", "descripcion": "Tirotoxicosis (Hipertiroidismo)", "categoria": "Endocrino y metabólico", "nota": "Antitiroideos (Tiamazol) y Propranolol para control adrenérgico."},
    {"codigo": "E06", "descripcion": "Tiroiditis (Tiroiditis subaguda / crónica de Hashimoto)", "categoria": "Endocrino", "nota": "Control con perfil tiroideo y antiinflamatorios."},
    {"codigo": "E10", "descripcion": "Diabetes mellitus tipo 1 (insulinodependiente)", "categoria": "Endocrino y metabólico", "nota": "Insulinoterapia intensiva obligatoria y conteo de carbohidratos."},
    {"codigo": "E11", "descripcion": "Diabetes mellitus tipo 2 (no insulinodependiente)", "categoria": "Endocrino y metabólico", "nota": "Metformina, inhibidores SGLT2/GLP-1, cambios nutricionales y HbA1c <7%."},
    {"codigo": "E11.5", "descripcion": "Diabetes mellitus tipo 2 con complicaciones circulatorias periféricas (Pie diabético)", "categoria": "Endocrino y metabólico", "nota": "Cuidado podológico riguroso, desbridamiento y calzado especial."},
    {"codigo": "E16.2", "descripcion": "Hipoglucemia no especificada", "categoria": "Endocrino y emergencias", "nota": "Administración inmediata de glucosa oral o glucosado I.V."},
    {"codigo": "E66", "descripcion": "Obesidad debida a exceso de calorías (IMC > 30)", "categoria": "Endocrino y metabólico", "nota": "Terapia nutricional integral, actividad física y valoración médica."},
    {"codigo": "E78.0", "descripcion": "Hipercolesterolemia pura (Colesterol elevado)", "categoria": "Trastornos lipídicos", "nota": "Estatinas (Atorvastatina 20-40mg o Rosuvastatina) y dieta cardioprotectora."},
    {"codigo": "E78.1", "descripcion": "Hipertrigliceridemia pura (Triglicéridos elevados)", "categoria": "Trastornos lipídicos", "nota": "Fibratos (Bezafibrato 200mg / Fenofibrato) y reducción de azúcares simples."},
    {"codigo": "E78.2", "descripcion": "Hiperlipidemia mixta (Dislipidemia combinada)", "categoria": "Trastornos lipídicos", "nota": "Manejo combinado del riesgo cardiovascular aterogénico."},
    {"codigo": "E79.0", "descripcion": "Hiperuricemia sin signos de artritis ni tofos", "categoria": "Metabolismo de purinas", "nota": "Alopurinol e hidratación abundante; restringir carnes rojas y alcohol."},
    {"codigo": "E86", "descripcion": "Depleción del volumen (Deshidratación moderada a severa)", "categoria": "Trastornos hidroelectrolíticos", "nota": "Reposición con solución oral de baja osmolaridad o soluciones I.V."},

    # -------------------------------------------------------------------------
    # Cap. V: Trastornos mentales y del comportamiento (F00-F99)
    # -------------------------------------------------------------------------
    {"codigo": "F32", "descripcion": "Episodio depresivo moderado a severo (Depresión clínica)", "categoria": "Salud mental", "nota": "Antidepresivos ISRS (Sertralina, Escitalopram) y psicoterapia."},
    {"codigo": "F33", "descripcion": "Trastorno depresivo recurrente", "categoria": "Salud mental", "nota": "Tratamiento de mantenimiento y prevención de recaídas."},
    {"codigo": "F41.0", "descripcion": "Trastorno de pánico (Crisis de angustia / Ataques de pánico)", "categoria": "Salud mental", "nota": "Manejo agudo con benzodiacepinas de rescate e ISRS a largo plazo."},
    {"codigo": "F41.1", "descripcion": "Trastorno de ansiedad generalizada (TAG)", "categoria": "Salud mental", "nota": "Terapia cognitivo-conductual e inhibidores de recaptura de serotonina."},
    {"codigo": "F41.2", "descripcion": "Trastorno mixto de ansiedad y depresión", "categoria": "Salud mental", "nota": "Patología muy prevalente en primer nivel de atención médica."},
    {"codigo": "F43.0", "descripcion": "Reacción al estrés agudo", "categoria": "Salud mental", "nota": "Apoyo emocional, contención e higiene del sueño."},
    {"codigo": "F43.2", "descripcion": "Trastornos de adaptación", "categoria": "Salud mental", "nota": "Acompañamiento psicoterapéutico ante duelos o cambios vitales."},
    {"codigo": "F51.0", "descripcion": "Insomnio no orgánico (Trastorno del sueño)", "categoria": "Trastornos del sueño", "nota": "Higiene del sueño; inductores hipnóticos controlados bajo estricta receta."},
    {"codigo": "F90", "descripcion": "Trastorno por déficit de atención e hiperactividad (TDAH)", "categoria": "Salud mental", "nota": "Psicoestimulantes (Metilfenidato) requieren receta médica retenida."},

    # -------------------------------------------------------------------------
    # Cap. VI: Enfermedades del sistema nervioso (G00-G99)
    # -------------------------------------------------------------------------
    {"codigo": "G20", "descripcion": "Enfermedad de Parkinson", "categoria": "Enfermedades neurodegenerativas", "nota": "Levodopa / Carbidopa con horarios estrictos."},
    {"codigo": "G30", "descripcion": "Enfermedad de Alzheimer", "categoria": "Enfermedades neurodegenerativas", "nota": "Donepezilo, Memantina y soporte al cuidador primario."},
    {"codigo": "G40", "descripcion": "Epilepsia y síndromes epilépticos", "categoria": "Sistema nervioso", "nota": "Anticonvulsivantes continuos; no suspender abruptamente."},
    {"codigo": "G43", "descripcion": "Migraña (con o sin aura)", "categoria": "Cefaleas", "nota": "Triptanes o AINEs en fase precoz; profilaxis si >3 crisis/mes."},
    {"codigo": "G44.2", "descripcion": "Cefalea tensional (Dolor de cabeza por tensión)", "categoria": "Cefaleas", "nota": "Paracetamol, AINEs, relajación muscular y manejo del estrés."},
    {"codigo": "G47", "descripcion": "Trastornos del inicio y del mantenimiento del sueño", "categoria": "Sistema nervioso", "nota": "Descartar apnea del sueño, reflujo nocturno o cafeína."},
    {"codigo": "G50.0", "descripcion": "Neuralgia del trigémino", "categoria": "Neurología", "nota": "Carbamazepina como fármaco de primera elección."},
    {"codigo": "G51.0", "descripcion": "Parálisis de Bell (Parálisis facial periférica)", "categoria": "Neurología", "nota": "Corticoides orales tempranos (Prednisona) y protección ocular nocturna."},
    {"codigo": "G56.0", "descripcion": "Síndrome del túnel carpiano", "categoria": "Neurología periférica", "nota": "Férula nocturna de muñeca, complejo B, AINEs o cirugía descompresiva."},

    # -------------------------------------------------------------------------
    # Cap. VII: Enfermedades del ojo y sus anexos (H00-H59)
    # -------------------------------------------------------------------------
    {"codigo": "H00", "descripcion": "Orzuelo y calacio (Perilla / Chalazión)", "categoria": "Oftalmología", "nota": "Compresas tibias húmedas y pomada oftálmica con antibiótico."},
    {"codigo": "H01.0", "descripcion": "Blefaritis", "categoria": "Oftalmología", "nota": "Aseo de párpados con champú neutro y lágrimas artificiales."},
    {"codigo": "H10", "descripcion": "Conjuntivitis aguda (bacteriana / viral / alérgica)", "categoria": "Oftalmología", "nota": "Colirios específicos según etiología y lavado frecuente de manos."},
    {"codigo": "H10.1", "descripcion": "Conjuntivitis alérgica aguda", "categoria": "Oftalmología", "nota": "Antihistamínico ocular (Olopatadina) y compresas frías."},
    {"codigo": "H16", "descripcion": "Queratitis corneal", "categoria": "Oftalmología", "nota": "Urgencia oftalmológica; evitar corticoides tópicos sin microscopía."},
    {"codigo": "H25", "descripcion": "Catarata senil", "categoria": "Oftalmología", "nota": "Tratamiento quirúrgico con implante de lente intraocular."},
    {"codigo": "H40", "descripcion": "Glaucoma de ángulo abierto", "categoria": "Oftalmología", "nota": "Gotas hipotensoras oculares de uso diario continuo para evitar ceguera."},
    {"codigo": "H04.1", "descripcion": "Síndrome de ojo seco", "categoria": "Oftalmología", "nota": "Gotas lubricantes oculares (hipromelosa, carmelosa) a libre demanda."},

    # -------------------------------------------------------------------------
    # Cap. VIII: Enfermedades del oído y de la apófisis mastoides (H60-H95)
    # -------------------------------------------------------------------------
    {"codigo": "H60", "descripcion": "Otitis externa (Oído de nadador)", "categoria": "Otorrinolaringología", "nota": "Gotas óticas con Neomicina/Polimixina/Dexametasona; no mojar el oído."},
    {"codigo": "H65", "descripcion": "Otitis media no supurativa (serosa)", "categoria": "Otorrinolaringología", "nota": "Frecuente en niños tras cuadros catarrales; descongestionantes."},
    {"codigo": "H66", "descripcion": "Otitis media supurativa aguda", "categoria": "Otorrinolaringología", "nota": "Amoxicilina a dosis plenas por 7-10 días y analgesia oral."},
    {"codigo": "H81.1", "descripcion": "Vértigo posicional paroxístico benigno (VPPB)", "categoria": "Otorrinolaringología", "nota": "Maniobras de reposicionamiento de Epley y Dimenhidrinato."},
    {"codigo": "H91.9", "descripcion": "Pérdida de la audición no especificada (Hipoacusia)", "categoria": "Otorrinolaringología", "nota": "Descartar tapón de cerumen antes de audiometría."},
    {"codigo": "H93.1", "descripcion": "Tinnitus (Acúfenos / Zumbido de oídos)", "categoria": "Otorrinolaringología", "nota": "Evaluar presión arterial y trauma acústico."},

    # -------------------------------------------------------------------------
    # Cap. IX: Enfermedades del sistema circulatorio (I00-I99)
    # -------------------------------------------------------------------------
    {"codigo": "I10", "descripcion": "Hipertensión esencial (primaria / arterial)", "categoria": "Cardiovascular", "nota": "Losartán, Telmisartán, Enalapril o Amlodipino; meta tensional <130/80."},
    {"codigo": "I11", "descripcion": "Enfermedad cardíaca hipertensiva", "categoria": "Cardiovascular", "nota": "Complicación crónica de hipertensión no controlada."},
    {"codigo": "I15", "descripcion": "Hipertensión secundaria", "categoria": "Cardiovascular", "nota": "Descartar causa renal, renovascular o endocrina."},
    {"codigo": "I20", "descripcion": "Angina de pecho (estable / inestable)", "categoria": "Cardiovascular", "nota": "Nitroglicerina sublingual de rescate y valoración cardiológica inmediata."},
    {"codigo": "I21", "descripcion": "Infarto agudo de miocardio (Ataque al corazón)", "categoria": "Urgencias cardiovasculares", "nota": "CÓDIGO INFARTO: Traslado inmediato a sala de hemodinamia."},
    {"codigo": "I25", "descripcion": "Cardiopatía isquémica crónica", "categoria": "Cardiovascular", "nota": "Antiagregantes plaquetarios (Aspirina Protect) y estatinas."},
    {"codigo": "I48", "descripcion": "Fibrilación y aleteo auricular", "categoria": "Arritmias cardíacas", "nota": "Control de frecuencia cardíaca y anticoagulación oral según CHA2DS2-VASc."},
    {"codigo": "I50", "descripcion": "Insuficiencia cardíaca congestiva", "categoria": "Cardiovascular", "nota": "Diuréticos (Furosemida), Espironolactona, IECA/ARA-II y betabloqueador."},
    {"codigo": "I83", "descripcion": "Venas varicosas de los miembros inferiores (Várices)", "categoria": "Vascular periférico", "nota": "Flebotónicos (Diosmina/Hesperidina) y medias elásticas de compresión gradual."},
    {"codigo": "I84", "descripcion": "Hemorroides (internas / externas)", "categoria": "Enfermedades vasculares", "nota": "Baños de asiento tibios, pomada con lidocaína/hidrocortisona y fibra."},
    {"codigo": "I80", "descripcion": "Flebitis y tromboflebitis", "categoria": "Vascular periférico", "nota": "Calor local, anticoagulación o AINEs según si es superficial o profunda."},

    # -------------------------------------------------------------------------
    # Cap. X: Enfermedades del sistema respiratorio (J00-J99)
    # -------------------------------------------------------------------------
    {"codigo": "J00", "descripcion": "Rinofaringitis aguda (Resfriado común / Gripa)", "categoria": "Infecciones respiratorias altas", "nota": "Tratamiento sintomático: hidratación, Paracetamol y descongestionante nasal."},
    {"codigo": "J01", "descripcion": "Sinusitis aguda bacteriana", "categoria": "Infecciones respiratorias altas", "nota": "Lavados nasales abundantes con solución salina y Amoxicilina con Clavulánico."},
    {"codigo": "J02", "descripcion": "Faringitis aguda estreptocócica", "categoria": "Infecciones respiratorias altas", "nota": "Penicilina G benzatínica o Amoxicilina oral por 10 días para evitar fiebre reumática."},
    {"codigo": "J03", "descripcion": "Amigdalitis aguda purulenta", "categoria": "Infecciones respiratorias altas", "nota": "Placas exudativas amigdalinas; analgesia y antibiótico según criterios Centor."},
    {"codigo": "J04", "descripcion": "Laringitis y traqueítis agudas", "categoria": "Infecciones respiratorias altas", "nota": "Disfonía/afonía; reposo de la voz, vaporizaciones y corticoide oral si hay estridor."},
    {"codigo": "J06", "descripcion": "Infecciones agudas de las vías respiratorias superiores múltiples", "categoria": "Infecciones respiratorias altas", "nota": "Cuadro catarral mixto viral de manejo conservador."},
    {"codigo": "J10", "descripcion": "Influenza debida a virus de la influenza identificado (H1N1/H3N2)", "categoria": "Infecciones virales respiratorias", "nota": "Oseltamivir 75mg cada 12h dentro de las primeras 48h de inicio de síntomas."},
    {"codigo": "J11", "descripcion": "Influenza debida a virus no identificado", "categoria": "Infecciones virales respiratorias", "nota": "Fiebre alta repentina, mialgias intensas; hidratación y antipiréticos."},
    {"codigo": "J18", "descripcion": "Neumonía, organismo no especificado", "categoria": "Infecciones respiratorias bajas", "nota": "Manejo antibiótico temprano; vigilar saturación de oxígeno (>92%)."},
    {"codigo": "J20", "descripcion": "Bronquitis aguda", "categoria": "Infecciones respiratorias bajas", "nota": "Etiología viral en >90%; broncodilatador si hay sibilancias al examen."},
    {"codigo": "J21", "descripcion": "Bronquiolitis aguda", "categoria": "Infecciones pediátricas", "nota": "Lactantes con dificultad respiratoria; oxigenoterapia y lavados nasales."},
    {"codigo": "J30", "descripcion": "Rinitis alérgica y vasomotora", "categoria": "Alergias respiratorias", "nota": "Antihistamínicos (Loratadina, Cetirizina) y spray nasal de Mometasona o Fluticasona."},
    {"codigo": "J44", "descripcion": "Enfermedad pulmonar obstructiva crónica (EPOC)", "categoria": "Enfermedades respiratorias crónicas", "nota": "Broncodilatadores inhalados (LAMA/LABA), oxigenoterapia y cese de tabaquismo."},
    {"codigo": "J45", "descripcion": "Asma bronquial (alérgica / no alérgica)", "categoria": "Enfermedades respiratorias crónicas", "nota": "Salbutamol en spray de rescate y corticoides inhalados (Budesonida) de control."},
    {"codigo": "J45.9", "descripcion": "Asma no especificada", "categoria": "Enfermedades respiratorias crónicas", "nota": "Vigilancia de técnica de inhalación y uso de espaciador."},

    # -------------------------------------------------------------------------
    # Cap. XI: Enfermedades del sistema digestivo (K00-K93)
    # -------------------------------------------------------------------------
    {"codigo": "K02", "descripcion": "Caries dental", "categoria": "Salud bucal", "nota": "Valoración odontológica, flúor y técnica de cepillado."},
    {"codigo": "K05", "descripcion": "Gingivitis y enfermedades periodontales", "categoria": "Salud bucal", "nota": "Enjuagues bucales con Clorhexidina al 0.12% y limpieza dental."},
    {"codigo": "K12.0", "descripcion": "Aftas bucales recurrentes (Estomatitis aftosa)", "categoria": "Salud bucal", "nota": "Anestésicos tópicos orales (Benzocaína gel) y antisépticos."},
    {"codigo": "K21", "descripcion": "Enfermedad por reflujo gastroesofágico (ERGE)", "categoria": "Aparato digestivo", "nota": "Inhibidor de bomba de protones (Omeprazol, Pantoprazol) antes del desayuno."},
    {"codigo": "K25", "descripcion": "Úlcera gástrica", "categoria": "Aparato digestivo", "nota": "Erradicación de Helicobacter pylori y supresión de AINEs/aspirina."},
    {"codigo": "K26", "descripcion": "Úlcera duodenal", "categoria": "Aparato digestivo", "nota": "Dolor epigástrico que calma con alimentos; tratamiento con IBP."},
    {"codigo": "K29", "descripcion": "Gastritis y duodenitis", "categoria": "Aparato digestivo", "nota": "Antiácidos (Magaldrato/Dimeticona) e inhibidores de acidez gástrica."},
    {"codigo": "K29.7", "descripcion": "Gastritis no especificada (Gastritis erosiva / aguda)", "categoria": "Aparato digestivo", "nota": "Dieta no irritante, evitar café, alcohol y grasas saturadas."},
    {"codigo": "K30", "descripcion": "Dispepsia funcional (Indigestión / Pesadez estomacal)", "categoria": "Aparato digestivo", "nota": "Procinéticos (Metoclopramida, Cinitaprida) y digestivos enzimáticos."},
    {"codigo": "K35", "descripcion": "Apendicitis aguda", "categoria": "Urgencias quirúrgicas", "nota": "URGENCIA QUIRÚRGICA: Dolor en fosa ilíaca derecha; no dar laxantes."},
    {"codigo": "K40", "descripcion": "Hernia inguinal", "categoria": "Aparato digestivo", "nota": "Reparación quirúrgica electiva (hernioplastia con malla)."},
    {"codigo": "K58", "descripcion": "Síndrome del intestino irritable (Colon irritable)", "categoria": "Aparato digestivo", "nota": "Antiespasmódicos (Butilhioscina, Bromuro de Pinaverio) y fibra soluble."},
    {"codigo": "K59.0", "descripcion": "Constipación / Estreñimiento funcional", "categoria": "Aparato digestivo", "nota": "Agua abundante, Plantago psyllium y laxantes osmóticos (Polietilenglicol)."},
    {"codigo": "K76.0", "descripcion": "Hígado graso no alcohólico (Esteatosis hepática)", "categoria": "Enfermedades hepáticas", "nota": "Bajar de peso, dieta mediterránea y control glucémico."},
    {"codigo": "K80", "descripcion": "Colelitiasis (Cálculos biliares / Piedras en la vesícula)", "categoria": "Aparato digestivo", "nota": "Dieta sin colecistoquinéticos (grasas); valoración para colecistectomía."},
    {"codigo": "K81", "descripcion": "Colecistitis aguda", "categoria": "Urgencias digestivas", "nota": "Signo de Murphy positivo; dolor en hipocondrio derecho posprandial."},
    {"codigo": "K85", "descripcion": "Pancreatitis aguda", "categoria": "Urgencias digestivas", "nota": "Hospitalización, ayuno estricto e hidratación intravenosa vigorosa."},

    # -------------------------------------------------------------------------
    # Cap. XII: Enfermedades de la piel y el tejido subcutáneo (L00-L99)
    # -------------------------------------------------------------------------
    {"codigo": "L01", "descripcion": "Impétigo contagioso (Staphylococcus / Streptococcus)", "categoria": "Dermatología infecciosa", "nota": "Costras melicéricas; Mupirocina tópica al 2% o Cefalexina oral."},
    {"codigo": "L02", "descripcion": "Absceso cutáneo, forúnculo y ántrax", "categoria": "Dermatología infecciosa", "nota": "Calor húmedo, incisión y drenaje quirúrgico con antibiótico."},
    {"codigo": "L03", "descripcion": "Celulitis bacteriana de tejidos blandos", "categoria": "Dermatología infecciosa", "nota": "Dicloxacilina o Cefalexina oral; marcar bordes de eritema para vigilar."},
    {"codigo": "L20", "descripcion": "Dermatitis atópica (Eccema infantil / adulto)", "categoria": "Dermatología", "nota": "Emolientes diarios sin perfume y corticoides tópicos leves en brotes."},
    {"codigo": "L21", "descripcion": "Dermatitis seborreica (Caspa / costra láctea)", "categoria": "Dermatología", "nota": "Champús con Ketoconazol o Piritionato de Zinc y corticoides suaves."},
    {"codigo": "L23", "descripcion": "Dermatitis alérgica de contacto", "categoria": "Alergias cutáneas", "nota": "Retirar el alérgeno (metales, cosméticos) y aplicar Hidrocortisona tópica."},
    {"codigo": "L40", "descripcion": "Psoriasis vulgar (Psoriasis en placas)", "categoria": "Dermatología crónica", "nota": "Corticoides tópicos potentes, derivados de vitamina D y fototerapia."},
    {"codigo": "L50", "descripcion": "Urticaria aguda", "categoria": "Alergias cutáneas", "nota": "Habones pruriginosos evanescentes; antihistamínicos (Cetirizina, Bilastina)."},
    {"codigo": "L50.8", "descripcion": "Otras urticarias (Urticaria física / colinérgica)", "categoria": "Alergias cutáneas", "nota": "Evitar desencadenantes físicos (frío, calor, presión)."},
    {"codigo": "L70", "descripcion": "Acné vulgar", "categoria": "Dermatología", "nota": "Peróxido de Benzoilo, Retinoides tópicos (Adapaleno) o Doxiciclina."},
    {"codigo": "L71", "descripcion": "Rosácea", "categoria": "Dermatología", "nota": "Metronidazol tópico al 0.75%, Ivermectina crema y fotoprotección solar."},
    {"codigo": "L63", "descripcion": "Alopecia areata (Caída de cabello en parches)", "categoria": "Dermatología", "nota": "Corticoides intralesionales o tópicos y valoración dermatológica."},

    # -------------------------------------------------------------------------
    # Cap. XIII: Enfermedades del sistema osteomuscular y tejido conjuntivo (M00-M99)
    # -------------------------------------------------------------------------
    {"codigo": "M05", "descripcion": "Artritis reumatoide seropositiva", "categoria": "Reumatología", "nota": "Fármacos modificadores de la enfermedad (Metotrexato) bajo reumatología."},
    {"codigo": "M06", "descripcion": "Otras artritis reumatoides", "categoria": "Reumatología", "nota": "Rigidez matutina prolongada y dolor articular bilateral."},
    {"codigo": "M10", "descripcion": "Gota articular aguda (Artritis gotosa)", "categoria": "Reumatología", "nota": "Colquicina, AINEs en fase aguda; Alopurinol como prevención posterior."},
    {"codigo": "M15", "descripcion": "Poliartrosis / Osteoartritis generalizada", "categoria": "Reumatología degenerativa", "nota": "Paracetamol, ejercicio aeróbico sin impacto y pérdida de peso."},
    {"codigo": "M17", "descripcion": "Gonartrosis (Artrosis de la rodilla)", "categoria": "Reumatología degenerativa", "nota": "Fortalecimiento de cuádriceps, analgesia y visco-suplementación."},
    {"codigo": "M16", "descripcion": "Coxartrosis (Artrosis de la cadera)", "categoria": "Reumatología degenerativa", "nota": "Dolor inguinal mecánico que empeora al caminar."},
    {"codigo": "M54.2", "descripcion": "Cervicalgia (Dolor de cuello / contractura cervical)", "categoria": "Trastornos de la columna", "nota": "Calor local, analgésicos, relajante muscular (Metocarbamol) y ergonomía."},
    {"codigo": "M54.4", "descripcion": "Lumbago con ciática (Lumbociática)", "categoria": "Trastornos de la columna", "nota": "Dolor lumbar irradiado a miembro inferior; descartar hernia de disco."},
    {"codigo": "M54.5", "descripcion": "Lumbago no especificado (Lumbalgia mecánica aguda)", "categoria": "Trastornos de la columna", "nota": "Reposo relativo activo, AINEs y calor local; evitar reposo en cama prolongado."},
    {"codigo": "M75.1", "descripcion": "Síndrome del manguito rotador (Tendinitis de hombro)", "categoria": "Osteomuscular", "nota": "Infiltración subacromial, fisioterapia y ejercicios de péndulo."},
    {"codigo": "M77.1", "descripcion": "Epicondilitis lateral (Codo de tenista)", "categoria": "Osteomuscular", "nota": "Banda de contratensión, estiramientos de extensores de muñeca y AINEs."},
    {"codigo": "M72.2", "descripcion": "Fascitis plantar", "categoria": "Osteomuscular", "nota": "Dolor en el talón al dar los primeros pasos por la mañana; taloneras de gel."},
    {"codigo": "M79.1", "descripcion": "Mialgia (Dolor muscular / contracturas)", "categoria": "Osteomuscular", "nota": "Analgésicos de venta libre y estiramientos suaves."},
    {"codigo": "M79.7", "descripcion": "Fibromialgia", "categoria": "Reumatología", "nota": "Puntos dolorosos sensibles; Pregabalina, Duloxetina y ejercicio aeróbico."},
    {"codigo": "M81", "descripcion": "Osteoporosis sin fractura patológica", "categoria": "Metabolismo óseo", "nota": "Calcio + Vitamina D3, Bifosfonatos (Alendronato) y densitometría ósea."},

    # -------------------------------------------------------------------------
    # Cap. XIV: Enfermedades del sistema genitourinario (N00-N99)
    # -------------------------------------------------------------------------
    {"codigo": "N18", "descripcion": "Enfermedad renal crónica (ERC estadios 1 a 5)", "categoria": "Nefrología", "nota": "Control de presión arterial, glucemia y restricción proteica moderada."},
    {"codigo": "N20", "descripcion": "Cálculo del riñón y del uréter (Litiasis renal / Cólico nefrítico)", "categoria": "Urología", "nota": "Ketorolaco con Butilhioscina I.V. y tomografía simple de abdomen."},
    {"codigo": "N30", "descripcion": "Cistitis aguda bacteriana", "categoria": "Urología e infecciones", "nota": "Disuria, polaquiuria; Nitrofurantoína 100mg cada 12h o Fosfomicina 3g."},
    {"codigo": "N39.0", "descripcion": "Infección de vías urinarias, sitio no especificado (IVU)", "categoria": "Urología e infecciones", "nota": "Urocultivo con antibiograma; hidratación oral abundante."},
    {"codigo": "N40", "descripcion": "Hiperplasia benigna de la próstata (HBP)", "categoria": "Urología", "nota": "Tamsulosina 0.4mg diaria e inhibidores de 5-alfa reductasa (Finasterida)."},
    {"codigo": "N41", "descripcion": "Enfermedades inflamatorias de la próstata (Prostatitis)", "categoria": "Urología", "nota": "Fluoroquinolonas orales por 4 semanas y antiinflamatorios."},
    {"codigo": "N76", "descripcion": "Vaginitis y vulvitis agudas (Vaginosis bacteriana)", "categoria": "Ginecología", "nota": "Metronidazol oral u óvulos vaginales combinados."},
    {"codigo": "N94.6", "descripcion": "Dismenorrea no especificada (Cólicos menstruales)", "categoria": "Ginecología", "nota": "AINEs iniciados 24-48h antes del sangrado (Ibuprofeno, Naproxeno)."},
    {"codigo": "N95.1", "descripcion": "Estados climatéricos y menopáusicos", "categoria": "Ginecología", "nota": "Bochornos y labilidad emocional; terapia hormonal o fitoestrógenos."},

    # -------------------------------------------------------------------------
    # Cap. XV: Embarazo, parto y puerperio (O00-O99)
    # -------------------------------------------------------------------------
    {"codigo": "O14", "descripcion": "Preeclampsia (Hipertensión gestacional con proteinuria)", "categoria": "Obstetricia", "nota": "Vigilancia estrecha; Alfametildopa o Labetalol; traslado obstétrico."},
    {"codigo": "O20.0", "descripcion": "Amenaza de aborto", "categoria": "Obstetricia", "nota": "Reposo absoluto, ultrasonido transvaginal y progesterona si indicada."},
    {"codigo": "O21.0", "descripcion": "Hiperémesis gravídica leve a severa", "categoria": "Obstetricia", "nota": "Náuseas incoercibles; Doxilamina con Piridoxina y reposición salina."},
    {"codigo": "O23", "descripcion": "Infección de las vías genitourinarias en el embarazo", "categoria": "Obstetricia", "nota": "Tratar bacteriuria asintomática para evitar parto pretérmino."},

    # -------------------------------------------------------------------------
    # Cap. XVIII: Síntomas, signos y hallazgos anormales (R00-R99)
    # -------------------------------------------------------------------------
    {"codigo": "R00.0", "descripcion": "Taquicardia, no especificada (Palpitaciones)", "categoria": "Síntomas cardiovasculares", "nota": "Realizar electrocardiograma para descartar taquiarritmias."},
    {"codigo": "R05", "descripcion": "Tos (Tos seca o tos con expectoración)", "categoria": "Síntomas respiratorios", "nota": "Antitusivos para tos no productiva; hidratación y mucolíticos para tos con flemas."},
    {"codigo": "R06.0", "descripcion": "Disnea (Falta de aire / Dificultad respiratoria)", "categoria": "Síntomas respiratorios", "nota": "Evaluar saturación de oxígeno, auscultación pulmonar y radiografía."},
    {"codigo": "R07.4", "descripcion": "Dolor en el pecho, no especificado (Dolor torácico)", "categoria": "Síntomas cardiorrespiratorios", "nota": "Descartar causa coronaria isquémica con electrocardiograma urgente."},
    {"codigo": "R10", "descripcion": "Dolor abdominal y pélvico (Dolor de estómago)", "categoria": "Síntomas digestivos", "nota": "Descartar signos de peritonitis o abdomen agudo antes de analgesia fuerte."},
    {"codigo": "R10.1", "descripcion": "Dolor localizado en abdomen superior (Epigastralgia)", "categoria": "Síntomas digestivos", "nota": "Relacionado a gastritis, ERGE o enfermedad péptica."},
    {"codigo": "R11", "descripcion": "Náusea y vómito", "categoria": "Síntomas digestivos", "nota": "Metoclopramida u Ondansetrón e hidratación con sales de rehidratación."},
    {"codigo": "R14", "descripcion": "Flatulencia y afecciones afines (Gases / Meteorismo)", "categoria": "Síntomas digestivos", "nota": "Dimeticona, carbón activado y dieta baja en carbohidratos fermentables."},
    {"codigo": "R30.0", "descripcion": "Disuria (Ardor o dolor al orinar)", "categoria": "Síntomas urinarios", "nota": "Fenazopiridina como analgésico urinario por máximo 48h con antibiótico."},
    {"codigo": "R42", "descripcion": "Mareo y desvanecimiento (Inestabilidad / Aturdimiento)", "categoria": "Síntomas generales", "nota": "Checar presión arterial en bipedestación (descartar ortostatismo)."},
    {"codigo": "R50", "descripcion": "Fiebre de origen desconocido o no especificada", "categoria": "Síntomas generales", "nota": "Medios físicos con agua tibia y Paracetamol cada 6 u 8 horas."},
    {"codigo": "R51", "descripcion": "Cefalea (Dolor de cabeza no especificado)", "categoria": "Síntomas generales", "nota": "Descartar fiebre, signos meníngeos o déficit motor focal."},
    {"codigo": "R52", "descripcion": "Dolor no especificado (Dolor agudo / crónico)", "categoria": "Síntomas generales", "nota": "Escalera analgésica de la OMS: Paracetamol -> AINEs -> Opioides débiles."},
    {"codigo": "R53", "descripcion": "Malestar general y fatiga / Astenia y adinamia", "categoria": "Síntomas generales", "nota": "Descartar anemia, disfunción tiroidea o cuadro viral en curso."},
    {"codigo": "R60.0", "descripcion": "Edema localizado (Hinchazón de pies y tobillos)", "categoria": "Síntomas circulatorios", "nota": "Común en insuficiencia venosa o efecto secundario de Amlodipino."},

    # -------------------------------------------------------------------------
    # Cap. XIX: Traumatismos, envenenamientos y ciertas consecuencias externas (S00-T98)
    # -------------------------------------------------------------------------
    {"codigo": "S93.4", "descripcion": "Esguince y torcedura del tobillo (Grado I a III)", "categoria": "Traumatología", "nota": "Protocolo RICE: Reposo, Hielo local, Compresión y Elevación + AINE."},
    {"codigo": "S13.4", "descripcion": "Esguince y torcedura de la columna cervical (Latigazo cervical)", "categoria": "Traumatología", "nota": "Collarín blando temporal y analgésicos con relajante muscular."},
    {"codigo": "S62", "descripcion": "Fractura a nivel de la muñeca y de la mano", "categoria": "Traumatología", "nota": "Inmovilización con férula y envío urgente a ortopedia."},
    {"codigo": "T14.0", "descripcion": "Traumatismo superficial (Golpes / Hematomas / Raspaduras)", "categoria": "Traumatología", "nota": "Lavado con agua y jabón antiséptico y hielo local."},
    {"codigo": "T30", "descripcion": "Quemadura de región del cuerpo no especificada (Grado 1 y 2)", "categoria": "Traumatología", "nota": "Enfriar con agua corriente (no hielo); Sulfadiazina de plata en crema."},
    {"codigo": "T63.2", "descripcion": "Veneno de escorpión / alacrán (Picadura de alacrán)", "categoria": "Toxicología", "nota": "Suero antialacránico (Faboterápico Alacramyn) en casos de envenenamiento moderado a severo."},
    {"codigo": "T63.0", "descripcion": "Veneno de serpiente (Mordedura de víbora de cascabel / nauyaca)", "categoria": "Toxicología", "nota": "Antivipmyn de urgencia médica absoluta hospitalaria."},

    # -------------------------------------------------------------------------
    # Cap. XXII: Códigos para situaciones especiales
    # -------------------------------------------------------------------------
    {"codigo": "U07.1", "descripcion": "COVID-19, virus identificado mediante prueba PCR o antígeno", "categoria": "Infecciones respiratorias emergentes", "nota": "Oximetría continua, aislamiento domiciliario por 5 días y sintomáticos."},
    {"codigo": "U07.2", "descripcion": "COVID-19, virus no identificado (Sospecha clínica epidemiológica)", "categoria": "Infecciones respiratorias emergentes", "nota": "Vigilancia de signos de alarma: disnea, cianosis, fiebre persistente."},
]

# Mapa de traducción y expansión semántica Español -> Inglés para consultar la API de NIH (ICD10CM)
DICCIONARIO_TERMINOS_MEDICOS = {
    "hipertension": "hypertension",
    "presion": "blood pressure",
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
    "gripa": "cold",
    "resfriado": "nasopharyngitis",
    "tos": "cough",
    "rinofaringitis": "nasopharyngitis",
    "sinusitis": "sinusitis",
    "neumonia": "pneumonia",
    "pulmonia": "pneumonia",
    "infeccion": "infection",
    "urinaria": "urinary tract infection",
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
    "obesidad": "obesity",
    "colesterol": "hypercholesterolemia",
    "trigliceridos": "hypertriglyceridemia",
    "acido urico": "hyperuricemia",
    "gota": "gout",
    "esguince": "sprain",
    "fractura": "fracture",
    "quemadura": "burn",
}


def buscar_en_catalogo_cie_local(query: str, limit: int = 50) -> List[Dict[str, Any]]:
    """
    Busca diagnósticos en el catálogo local con un algoritmo de ponderación
    normalizado insensible a acentos, mayúsculas, y con coincidencia de múltiples términos.
    """
    q_norm = normalizar_texto(query)
    if not q_norm:
        return []

    tokens = [t for t in q_norm.split() if len(t) > 1]
    if not tokens:
        tokens = [q_norm]

    coincidencias: List[Dict[str, Any]] = []

    for diag in CIE10_DIAGNOSTICOS:
        cod_norm = normalizar_texto(diag["codigo"])
        desc_norm = normalizar_texto(diag["descripcion"])
        cat_norm = normalizar_texto(diag["categoria"])
        nota_norm = normalizar_texto(diag.get("nota", ""))

        puntaje = 0

        # Coincidencia de código exacta o por prefijo (ej: "I10" o "I10.1")
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
    Consulta a la API pública oficial de NIH Clinical Tables Search Service para ICD-10.
    Aplica traducción de conceptos clave y búsqueda por prefijos para obtener
    resultados altamente relevantes incluso cuando la consulta se realiza en español.
    """
    termino_original = query.strip()
    if not termino_original or len(termino_original) < 2:
        return []

    q_norm = normalizar_texto(termino_original)
    terminos_a_probar = [termino_original]

    # Detectar palabras clave en el diccionario para enriquecer la consulta a NIH
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
            f"https://clinicaltables.nlm.nih.gov/api/icd10cm/v3/search?"
            f"terms={urllib.parse.quote(term)}&sf=code,name&maxList={limit}"
        )

        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "FarmaControl-POS-CIE-Advanced/2.0"}
            )
            with urllib.request.urlopen(req, timeout=2.0) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode("utf-8"))
                    if len(data) >= 4 and data[3]:
                        for row in data[3]:
                            code = str(row[0]).strip().upper()
                            name = str(row[1]).strip()
                            if code not in codigos_vistos:
                                codigos_vistos.add(code)
                                resultados_externos.append({
                                    "codigo": code,
                                    "descripcion": name,
                                    "categoria": "Catálogo Internacional ICD-10 (NIH)",
                                    "nota": f"Resultado obtenido desde servicio NIH Clinical Tables (Término: '{term}')."
                                })
        except Exception:
            pass

    return resultados_externos[:limit]
