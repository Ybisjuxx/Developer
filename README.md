# FarmaControl - Sistema de Gestión Farmacéutica y Dispensación Sanitaria

[![Version](https://img.shields.io/badge/version-1.4.7-teal.svg)](CHANGELOG.md)
[![Compliance](https://img.shields.io/badge/COFEPRIS-Art._226_LGS-blue.svg)](#marco-normativo-y-regulatorio)
[![Backend](https://img.shields.io/badge/FastAPI-Python_3.11+-009688.svg)](backend/)
[![Frontend](https://img.shields.io/badge/Flutter-3.x_Material_3-02569B.svg)](frontend/)

Sistema integral de gestión farmacéutica diseñado bajo estricto cumplimiento de la normativa sanitaria mexicana (**Ley General de Salud Art. 226, Farmacopea de los Estados Unidos Mexicanos [FEUM] y lineamientos de COFEPRIS**). Incorpora despacho de medicamentos por lotes con método **FEFO (*First Expired, First Out*)**, auditoría contable mediante **Kardex inmutable**, control de recetas médicas, catálogo oficial **CIE-10 / CIE-11**, seguimiento de pacientes crónicos, devoluciones/mermas sanitarias y arqueo de caja (Corte Z).

---

## 🏛️ Marco Normativo y Regulatorio

1. **Ley General de Salud (México) - Artículo 226:**
   * **Grupos I a IV (Controlados y Antibióticos):** Exigencia obligatoria de médico emisor con cédula profesional vigente para autorizar el despacho en punto de venta.
   * **Grupos V y VI (Venta Libre / OTC):** Despacho ágil a público general sin requerimiento de receta.
2. **Despacho FEFO Estricto (*First Expired, First Out*):**
   * El sistema selecciona automáticamente los lotes más próximos a caducar para garantizar la rotación sanitaria y evitar merma por vencimiento en anaquel.
3. **Kardex Inmutable (Append-Only):**
   * Cada entrada por compra, salida por venta, reingreso por devolución o baja por merma sanitaria genera una traza histórica inmutable con saldo anterior, posterior y folio de auditoría.
4. **Catálogo Internacional de Enfermedades (CIE-10 / CIE-11):**
   * Búsqueda híbrida de diagnósticos con catálogo local enriquecido y consulta en vivo a tablas clínicas de la OMS/NIH.
5. **Separación Sanitaria de Mermas:**
   * Toda devolución en estado "Dañado" es remitida a cuarentena/destrucción sin reingresar al inventario vendible.

---

## 📂 Estructura del Repositorio para Auditoría

```
FarmaControl/
├── backend/                  # Servidor de API REST (Python / FastAPI)
│   ├── app/
│   │   ├── routers/          # Endpoints modulares (auth, caja, clientes, devoluciones,
│   │   │                     # enfermedades, ia, inventario, medicos, ventas)
│   │   ├── database.py       # Conexión SQLAlchemy (SQLite predeterminado / MySQL listo)
│   │   ├── models.py         # Modelos relacionales con integridad referencial
│   │   ├── schemas.py        # Validadores estrictos Pydantic v2
│   │   ├── catalogo_cie.py   # Catálogo y conector clínico CIE-11 OMS
│   │   └── catalogo_medicamentos.py # Catálogo de fármacos y grupos FEUM
│   ├── seed.py               # Generador de datos sintéticos de prueba
│   ├── test_api.py           # Suite completa de pruebas de integración
│   ├── requirements.txt      # Dependencias oficiales de Python
│   ├── run.py                # Servidor Uvicorn para desarrollo
│   └── .env.example          # Plantilla de variables de entorno (sin credenciales)
├── frontend/                 # Aplicación multiplataforma (Flutter / Dart)
│   ├── lib/
│   │   ├── models/           # Entidades tipadas
│   │   ├── screens/          # Pantallas de POS, Inventario, Caja, Clientes, Médicos, etc.
│   │   ├── services/         # Clientes de API, sesión RBAC y temas
│   │   └── widgets/          # Componentes reutilizables (Ticket térmico, escáner)
│   └── pubspec.yaml          # Dependencias y configuración de Flutter
├── reportes/                 # Bitácoras de cambios de versión y arquitectura técnica
├── CHANGELOG.md              # Registro cronológico detallado de cambios (SemVer)
└── Iniciar_FarmaControl.bat  # Script de inicio rápido en Windows
```

---

## 🔒 Consideraciones de Seguridad y Privacidad para el Auditor

* **Cero Secretos / API Keys en Código:** El código fuente no contiene llaves privadas, tokens de producción ni secretos hardcodeados. Todas las configuraciones sensibles se manejan mediante variables de entorno documentadas en `.env.example`.
* **Protección de Datos (PII):** La base de datos de demostración incluye exclusivamente registros sintéticos generados para pruebas. No se incluye información personal identificable de pacientes ni datos clínicos reales.
* **Autenticación y Roles (RBAC):**
  * `ADMINISTRADOR`: Acceso total, arqueos, anulación y reportes.
  * `CAJERO`: Operación de punto de venta, apertura y corte personal de caja.
  * `RESPONSABLE_SANITARIO`: Validación facultativa de médicos, auditoría de recetas y mermas.
* **Contraseñas Seguras:** Hasheadas con PBKDF2-HMAC-SHA256 en almacenamiento (con migración transparente de hashes heredados).

---

## 🤖 Motor Determinista de Dispensación y Sustitución (`/api/ia`)

El módulo de consulta de medicamentos (`/api/ia/consulta-medicamento` y `/api/ia/v2/consulta-medicamento`) opera como un **motor determinista y auditable basado en reglas sanitarias** (sin LLM ni APIs externas), estructurado en **3 niveles de sustitución**:

1. **`INTERCAMBIABLE` (Nivel 1 — Verde / `OFRECER_AL_CLIENTE`):**
   * Misma sustancia activa exacta (normalizada), misma concentración, misma forma farmacéutica y misma vía de administración. Visible para el cajero.
2. **`MISMA_SUSTANCIA_OTRA_PRESENTACION` (Nivel 2 — Amarillo / `CONFIRMAR_FARMACEUTICO` o `CONSULTAR_MEDICO`):**
   * Misma sustancia activa exacta en distinta concentración, forma farmacéutica o vía de administración. Si el producto requiere receta, exige confirmación médica (`CONSULTAR_MEDICO`); de lo contrario, confirmación del farmacéutico (`CONFIRMAR_FARMACEUTICO`).
3. **`CONSULTAR_MEDICO` (Nivel 3 — Rojo / `CONSULTAR_MEDICO`):**
   * Sustancia activa diferente únicamente cuando existe un **par de sustitución validado y firmado** en la tabla `pares_sustitucion` (`validado_por` no nulo). **Oculto por defecto al rol `CAJERO`** (`visible_para_cajero = false`) y sujeto a prescripción/autorización médica. Nunca se sustituyen medicamentos controlados (`GRUPO_I`, `GRUPO_II`, `GRUPO_III`) por otra sustancia ni se generan sugerencias por coincidencia de texto en `indicacion_terapeutica`.

### Proceso de Validación de Pares por el Farmacéutico (`RESPONSABLE_SANITARIO` / `ADMINISTRADOR`)
1. Cuando se da de alta un producto con una sustancia nueva no registrada previamente en `sustancias`, el sistema la registra con `estado_clasificacion = "PENDIENTE"`, marca `requiere_revision_manual = true` y crea una tarea en `tareas_clasificacion_farmaceutica`. Mientras esté `PENDIENTE`, la IA muestra su existencia pero responde *"sin alternativas validadas"* y no la sugiere como sustituto de otro fármaco.
2. El farmacéutico consulta la bandeja de pendientes mediante `GET /api/ia/pendientes`.
3. Para habilitar una sustancia, la clasifica vía `POST /api/ia/sustancias/{id}/clasificar` (asignando `codigo_atc` y `estado_clasificacion = "CLASIFICADA"`).
4. Para autorizar equivalencias entre sustancias distintas, registra y firma explícitamente el par en `POST /api/ia/pares` (indicando `sustancia_origen`, `sustancia_alternativa`, `tipo`, `advertencias` y `validado_por` con cédula/nombre del responsable sanitario). Solo los pares firmados son considerados en el Nivel 3.

---

## 🚀 Guía de Ejecución Rápida

### Requisitos Previos:
- Python 3.10+
- Flutter 3.16+ (opcional si solo se audita el backend)

### 1. Iniciar el Backend (FastAPI):
```bash
cd backend
pip install -r requirements.txt
python run.py
```
* **Swagger UI Interactivo:** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
* **Health Check:** [http://127.0.0.1:8000/api/health](http://127.0.0.1:8000/api/health)

### 2. Ejecutar la Suite de Pruebas Automatizadas:
```bash
cd backend
python test_api.py
```

### 3. Iniciar el Frontend (Flutter Web):
```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port=8080
```
Abrir en el navegador: [http://localhost:8080](http://localhost:8080)
