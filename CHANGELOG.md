# Historial de Versiones (Changelog) - FarmaControl

Todas las modificaciones notables de este proyecto están documentadas en este archivo.
El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto se adhiere a [Semantic Versioning (SemVer 2.0.0)](https://semver.org/lang/es/).

---

## [1.0.0] - 2026-10-26 (Versión Mayor: Búsqueda POS, Catálogo Maestro 100 y API CIE-10)

### 🚀 Añadido
- **Búsqueda Reactiva en Punto de Venta (`pos_screen.dart`):**
  - Motor de búsqueda en memoria con filtrado instantáneo por nombre comercial, sustancia activa, código de barras EAN-13 y laboratorio fabricante.
  - Soporte de pistola/escáner de código de barras: auto-adición al carrito al detectar escaneo exacto o pulsar `Enter`, con vaciado automático del buffer de entrada.
  - Chips de filtrado rápido por categorías regulatorias COFEPRIS: *Todos*, *Venta Libre (Grupo VI)*, *Antibióticos (Grupo IV)*, *Controlados (Grupo I-III)*, *Crónicos (Grupo V)* y *Solo con Stock*.
  - Indicador de stock en carrito directamente en cada tarjeta de medicamento (`🛒 X en carrito`).
  - Contador dinámico de inventario mostrado en mostrador y estado vacío interactivo con botón para restablecer filtros.
- **Base de Datos Maestra de 100 Medicamentos (`catalogo_medicamentos.py` y `seed.py`):**
  - 100 medicamentos mexicanos reales estructurados rigurosamente según el Art. 226 de la Ley General de Salud:
    - 25 Antibióticos de prescripción médica (Grupo IV).
    - 15 Psicotrópicos y Estupefacientes con receta especial/retenida (Grupos I, II y III).
    - 30 Medicamentos para padecimientos crónicos y especializados (Grupo V).
    - 30 Medicamentos de venta libre / OTC (Grupo VI).
  - 103 Lotes con fechas de caducidad escalonadas bajo política FEFO (*First Expired, First Out*).
  - Generación de asientos inmutables en el Kardex (`ENTRADA_COMPRA` con referencia `SEED-100`) para auditar la recepción de cada lote.
- **Conexión de API y Catálogo de Enfermedades CIE-10 (`catalogo_cie.py`, `enfermedades.py`, `enfermedades_screen.dart`):**
  - Catálogo híbrido con más de 80 afecciones clínicas estándar en México y conexión a la API pública de terminología médica **NIH Clinical Tables (ICD-10)**.
  - Endpoint `GET /api/enfermedades/catalogo-cie/buscar`: Búsqueda asistida con indicador en vivo `ya_registrado` para cruzar diagnósticos con la base de datos de la farmacia.
  - Endpoint `POST /api/enfermedades/catalogo-cie/importar`: Importación de diagnósticos con 1 solo clic sin riesgos de duplicación.
  - Endpoint `POST /api/enfermedades/auto-registrar`: Adición dinámica sobre la marcha durante la expedición de recetas y cobro.
  - Rediseño de la interfaz de enfermedades en Flutter con navegación por pestañas: *Mis Diagnósticos en Farmacia* y *Catálogo Oficial CIE-10 (Búsqueda Global y API)*.
  - Asistente de autocompletado en el formulario de captura manual basado en códigos CIE.

### 🔧 Modificado
- `ApiService` en Flutter actualizado con métodos `buscarCatalogoCIE`, `importarDesdeCatalogoCIE` y `autoRegistrarEnfermedad`.
- Refactorización de tipos en decoraciones de interfaz para compatibilidad estricta con Flutter Web SDK.

---

## [0.3.0] - 2026-10-25 (Paso 6: Control de Caja, Tickets Térmicos y Mermas Sanitarias)

### 🚀 Añadido
- **Módulo de Devoluciones y Mermas Sanitarias:**
  - Clasificación sanitaria de producto retornado: `BUEN_ESTADO` (reingreso a stock con Kardex `ENTRADA_DEVOLUCION`) y `DANADO` (apartado a cuarentena/baja con Kardex `SALIDA_MERMA`).
  - Endpoints `/api/devoluciones/` y `/api/devoluciones/mermas` para seguimiento y auditoría sanitaria.
- **Emisión de Tickets Térmicos de 80mm:**
  - Modal visual con membrete sanitario COFEPRIS, RFC, desglose de lotes y fechas de caducidad FEFO por producto.
  - Botones de *"Imprimir Ticket"* y *"Copiar Ticket"* en formato de texto plano para impresoras térmicas ESC/POS.
- **Control de Turnos y Cortes de Caja (Corte Z):**
  - Endpoints `/api/caja/abrir`, `/api/caja/resumen`, `/api/caja/cerrar` y `/api/caja/turno-activo`.
  - Registro de fondo de apertura ($ MXN), arqueo en tiempo real de ventas en efectivo/tarjeta/transferencia y semáforo de cuadre (Exacto, Sobrante o Faltante).
  - Selector de método de pago en mostrador con botones de importe rápido ($100, $200, $500, $1000, Exacto) y cálculo automático de cambio.
- **Autenticación y Matriz de Roles:**
  - Tabla `usuarios` con hash SHA-256 de contraseña.
  - Perfiles preconfigurados: `ADMINISTRADOR` (Alejandro Mendoza), `CAJERO` (Juan Daniel Morales) y `RESPONSABLE_SANITARIO` (Dra. Carmen Sofía Morales).
  - Selector de usuario en la barra superior para alternar de perfil durante pruebas operativas.
- **Migración a Entorno Local Libre de Bloqueos:**
  - Migración del proyecto fuera de OneDrive a `C:\Developer` para evitar bloqueos de archivos en `.dart_tool/` y `build/`.

---

## [0.2.0] - 2026-10-24 (Paso 5: Trazabilidad FEFO y Candados Sanitarios)

### 🚀 Añadido
- **Motor de Despacho FEFO (*First Expired, First Out*):**
  - Algoritmo que consume automáticamente los lotes más próximos a caducar al momento de cobrar una venta.
  - Desglose por lote y cantidad despachada en la tabla `ventas_detalle_lotes`.
- **Candado Regulatorio para Antibióticos (Grupo IV):**
  - Bloqueo preventivo de venta en el POS si el carrito incluye fármacos del Grupo IV y no se ha seleccionado un médico prescriptor.
  - Validación de cédula profesional médica y vigencia antes de autorizar la transacción.
- **Kardex Inmutable:**
  - Tabla `kardex_movimientos` para registrar cada entrada (`ENTRADA_COMPRA`, `ENTRADA_DEVOLUCION`) y salida (`SALIDA_VENTA`, `SALIDA_MERMA`) con stock anterior y posterior.

---

## [0.1.0] - 2026-10-23 (Paso 1-4: Arquitectura Base y MVP)

### 🚀 Añadido
- **Base de Datos y Modelado Relacional:**
  - Configuración de SQLite con SQLAlchemy en `backend/app/models.py`.
  - Tablas fundacionales: `productos`, `lotes`, `medicos`, `enfermedades`, `ventas`, `ventas_detalle`.
- **Backend API REST (FastAPI):**
  - Endpoints CRUD para productos, lotes, médicos y ventas.
  - Documentación interactiva Swagger UI en `/docs`.
- **Frontend Base en Flutter Web:**
  - Pantallas iniciales: `dashboard_screen.dart`, `inventario_screen.dart`, `pos_screen.dart`, `ventas_screen.dart`, `medicos_screen.dart`.
  - Conexión HTTP con el backend mediante `ApiService`.
