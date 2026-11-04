# Reporte de Versión FarmaControl v1.4.6
**Fecha:** 2026-11-03  
**Módulos Clave:** Catálogo de Diagnósticos y Enfermedades, Conexión Oficial CIE-11 (OMS), Búsqueda Bilingüe NIH ICD-11  

---

## 🎯 Objetivo de la Versión
Migrar y conectar formalmente el catálogo de diagnósticos del sistema a la **Clasificación Internacional de Enfermedades 11.ª Revisión (CIE-11 / ICD-11)** de la Organización Mundial de la Salud (OMS), reemplazando por completo la versión desactualizada CIE-10.

---

## 🛠️ Modificaciones Realizadas

### 1. Conexión con la API Oficial ICD-11 (NIH / OMS) (`catalogo_cie.py`)
- Se sustituyó la consulta externa a ICD-10-CM por el servicio de búsqueda oficial en tiempo real de **ICD-11** provisto por NIH Clinical Table Search Service (`https://clinicaltables.nlm.nih.gov/api/icd11_codes/v3/search`).
- Devuelve códigos alfanuméricos oficiales de la linearización MMS de CIE-11 (ej. `5A11`, `BA00`, `CA23`, `CA00`, `1A40`) junto con el título y el capítulo temático.
- Motor de traducción y expansión semántica bilingüe (Español $\rightarrow$ Inglés) para que cualquier síntoma o patología buscada en español localice los códigos globales exactos de la OMS.

### 2. Catálogo Oficial CIE-11 Enriquecido en Español para México
- Se rediseñó el catálogo local con más de 100 patologías frecuentes bajo la taxonomía oficial de CIE-11:
  - **Infecciosas:** `1A00` (Cólera), `1A07` (Fiebre tifoidea), `1A40` (Gastroenteritis aguda), `1B10` (Tuberculosis), `1D20` (Dengue), `1E50` (Varicela), `1E91` (Herpes zóster).
  - **Endocrinas y Metabólicas:** `5A10` (Diabetes tipo 1), `5A11` (Diabetes tipo 2), `5A11.1` (Pie diabético), `5A00` (Hipotiroidismo), `5B81` (Obesidad), `5C80` (Dislipidemia).
  - **Cardiovasculares:** `BA00` (Hipertensión esencial), `BA01` (Crisis hipertensiva), `BA41` (Angina de pecho), `BA42` (Infarto de miocardio), `BD10` (Insuficiencia cardíaca).
  - **Respiratorias:** `CA00` (Rinofaringitis aguda / Resfriado común), `CA02` (Faringitis), `CA03` (Amigdalitis), `CA22` (EPOC), `CA23` (Asma bronquial), `CA40` (Neumonía).
  - **Digestivas:** `DA22` (ERGE), `DA42` (Gastritis), `DD91` (Síndrome de intestino irritable), `DC11` (Colelitiasis), `DB71` (Hemorroides).
  - **Musculoesqueléticas:** `FA00` (Osteoartritis de rodilla), `FA20` (Artritis reumatoide), `FB56` (Osteoporosis), `ME84.2` (Lumbalgia).
  - **Genitourinarias:** `GC00` (Cistitis aguda), `GA90` (Hiperplasia benigna prostática), `GB61` (Litiasis renal).
  - **Especiales:** `RA01` (COVID-19), `RA02` (Long COVID).

### 3. Actualización de Interfaz y Navegación (`enfermedades_screen.dart`, `home_screen.dart`, `clientes_screen.dart`)
- **Pantalla de Diagnósticos:** Título, pestañas, modales de alta, campos de código y banners informativos actualizados a **CIE-11**.
- **Menú y Navegación:** Opciones de menú actualizadas a *'Catálogo de Diagnósticos CIE-11'* y *'Padrón de Clientes CIE-11'*.
- **Padrón de Clientes:** Vinculación de historial clínico de pacientes crónicos adaptado a la nomenclatura CIE-11.

### 4. Pruebas y Validación Automatizada (`test_api.py`)
- Se actualizaron las pruebas unitarias e integrales del backend, verificando con 100% de éxito la búsqueda, normalización y registro con códigos CIE-11 oficiales.

---

## 🚀 Despliegue y Acceso
- **Web App:** [https://ybisjuxx.github.io/Developer/](https://ybisjuxx.github.io/Developer/)
- **Backend API:** [https://developer-80fs.onrender.com](https://developer-80fs.onrender.com)

