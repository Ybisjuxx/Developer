# Historial de Versiones (Changelog) - FarmaControl

Todas las modificaciones notables de este proyecto están documentadas en este archivo.
El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto se adhiere a [Semantic Versioning (SemVer 2.0.0)](https://semver.org/lang/es/).

---

## [1.2.0] - 2026-10-28 (Inteligencia Clínica, Alertas FEFO, Gráficos Anuales y Robustez de UI)

### 🚀 Añadido
- **Sub-Agente 1: Conexión de Tablero a Alertas de Caducidad y Pestaña de Lotes por Caducar (`dashboard_screen.dart`, `inventario_screen.dart`, `inventario.py`):**
  - Conexión interactiva directa: Las tarjetas de *Alertas de Caducidad* y el listado de *Lotes con Prioridad de Despacho (FEFO)* en el Tablero de Mando ahora navegan con 1 clic al submódulo de caducidades en el Inventario.
  - Pestaña dedicada *"Lotes por Caducar (Alertas FEFO)"* en el Inventario para separar y priorizar lotes próximos a vencer.
  - Filtros rápidos por horizonte de vencimiento: *Todos*, *Críticos (≤ 30 días)*, *En Riesgo (31-60 días)* y *Preventivos (61-90 días)*.
  - Badges de urgencia por color, días restantes, cálculo en vivo de existencias y botones directos de acción (Ajustar / Dar de baja).
- **Sub-Agente 2: Datos de Fabricación, Forma y Dosificación en Lotes (`models.py`, `schemas.py`, `inventario_screen.dart`, `inventario.py`):**
  - Nuevos campos en el modelo `Lote`: `laboratorio_fabricante`, `forma_farmaceutica`, `dosificacion` y `fecha_ingreso` con migración no destructiva en SQLite.
  - Formulario de alta de lotes enriquecido con selector de formas farmacéuticas (Tabletas, Cápsulas, Solución, Suspensión, Inyectable, etc.), campo de dosificación por presentación y selector de fecha de recepción.
  - Visualización integral de laboratorio fabricante y presentación en las tarjetas de lotes de inventario.
- **Sub-Agente 3: Captura Opcional de Fecha de Nacimiento Desglosada y Sexo en Clientes (`models.py`, `schemas.py`, `clientes_screen.dart`, `pos_screen.dart`):**
  - Campos `fecha_nacimiento` y `sexo` (`MASCULINO`, `FEMENINO`, `OTRO`) en `Cliente`.
  - Captura estructurada con campos independientes para Día (DD), Mes (MM) y Año (AAAA), complementado con botón selector de calendario interactivo (`showDatePicker`).
  - Integración en el catálogo maestro de Clientes y en el modal de *Registro Exprés* del Punto de Venta.
  - Badges visuales con fecha de nacimiento, edad calculada y sexo en el expediente clínico del cliente.
- **Sub-Agente 4: Menú y Navegación Responsiva sin Desbordamiento (`home_screen.dart`):**
  - Envoltura del `NavigationRail` de 10 módulos en un contenedor con desplazamiento vertical (`SingleChildScrollView` + `ConstrainedBox`), garantizando que la navegación nunca se corte ni genere excepciones `RenderFlex overflowed` al incrementar la fuente al 115% o 130%.
  - Integración de menú lateral desplegable (`Drawer`) completo para dispositivos móviles o monitores de baja resolución con accesos directos a todos los módulos.
- **Sub-Agente 5: Chat Asistente IA para Búsqueda y Sustitutos Terapéuticos en Stock (`ia.py`, `home_screen.dart`, `api_service.dart`):**
  - Botón de acceso rápido `[🤖 Consulta IA]` en la barra superior de FarmaControl.
  - Endpoint de inteligencia clínica `POST /api/ia/consulta-medicamento` con resolución de marcas comerciales a genéricos bioequivalentes y mapeo de 8 familias terapéuticas.
  - Cruce en tiempo real con el inventario de la farmacia para recomendar alternativas disponibles en stock cuando el fármaco solicitado no está disponible.
  - Alertas regulatorias automáticas para antibióticos (Grupo IV) y fármacos controlados (Grupos I-III).
  - Sugerencias rápidas de consulta en forma de chips y chat interactivo con respuestas contextuales.
- **Sub-Agente 6: Gráfico Desglosado de Ventas Mes a Mes (`dashboard_screen.dart`, `ventas.py`, `schemas.py`, `seed.py`):**
  - Endpoint `GET /api/ventas/reporte-mensual?anio=2026` con desglose mensual de ventas e importes acumulados.
  - Gráfico de barras interactivo de 12 meses integrado en el Tablero de Mando, con alturas proporcionales y destacado visual del mes con mayor facturación (`★ PICO`).
  - Selector dinámico de año fiscal (2026, 2025, 2024).
  - Tarjetas de resumen ejecutivo: Total Anual Facturado, Promedio Mensual, Mes Pico y Total de Tickets Emitidos.
  - Detalle interactivo por mes al hacer clic sobre cualquier columna del gráfico.

---

## [1.1.0] - 2026-10-27 (Expansión Multisistema: Clientes CIE-10, Permisos de Lotes, Ajustes Visuales y Auditoría Kardex)

### 🚀 Añadido
- **Sub-Agente 1: Padrón de Clientes e Historial Clínico CIE-10 (`clientes_screen.dart`, `models.py`, `routers/clientes.py`):**
  - Modelo relacional `Cliente` y tabla asociativa `cliente_enfermedades` para vincular clientes frecuentes con sus diagnósticos del CIE-10.
  - Campos obligatorios: `nombre`, `apellido`. Campos opcionales: `correo_electronico`, `telefono`, `direccion`, `notas_clinicas` y `descuento_porcentaje` (lealtad).
  - Pantalla dedicada con búsqueda reactiva, visualización de expediente clínico, edición y alta de clientes.
- **Sub-Agente 2: Integración de Clientes en Punto de Venta y Descuentos (`pos_screen.dart`, `ventas.py`):**
  - Selector en barra lateral de cobro: alternancia fluida entre *Público General* y clientes registrados.
  - Botón de *Registro Exprés* directo desde el mostrador para dar de alta clientes al instante sin perder la venta.
  - Cálculo automático y transparente del porcentaje de descuento de fidelidad sobre el subtotal.
  - Visualización de credenciales y padecimientos CIE-10 del cliente en mostrador para alertar al farmacéutico.
  - Desglose del descuento en el ticket térmico de 80mm y almacenamiento en la base de datos fiscal.
- **Sub-Agente 3: Ajustes de Piezas y Baja de Lotes con Restricción de Roles (`inventario_screen.dart`, `routers/inventario.py`):**
  - Endpoints seguros `POST /api/inventario/lotes/{id}/ajuste` y `POST /api/inventario/lotes/{id}/baja` protegidos por rol.
  - Restricción estricta: Acceso concedido solo a `ADMINISTRADOR` y `RESPONSABLE_SANITARIO`; usuarios con rol `CAJERO` reciben bloqueo preventivo y error HTTP `403 Forbidden`.
  - Trazabilidad total en Kardex mediante asientos inmutables `ENTRADA_AJUSTE`, `SALIDA_AJUSTE` o `BAJA_LOTE` con registro de usuario y motivo.
- **Sub-Agente 4: Panel de Configuración, Administración de Usuarios y Temas (`configuracion_screen.dart`, `theme_service.dart`, `routers/auth.py`):**
  - Módulo completo de administración de usuarios: alta, edición de nombres, asignación de roles y actualización de contraseñas.
  - Selector dinámico de paleta de colores institucional: *Teal Farmacéutico*, *Azul Clínico*, *Verde Médico*, *Índigo Quirúrgico* y *Cian Sanitario*.
  - Escala de tipografía global en tiempo real: 4 niveles de ajuste (*Compacta 88%*, *Estándar 100%*, *Grande 115%*, *Alta Legibilidad 130%*) para accesibilidad en pantallas táctiles.
- **Sub-Agente 5: Auditoría de Kardex y Detección de Irregularidades (`inventario_screen.dart`, `models.py`):**
  - Campos de auditoría `observaciones_auditoria`, `es_irregular` y `usuario_auditor` en la bitácora del Kardex.
  - Modal interactivo para que supervisores y usuarios añadan notas explicativas y marquen movimientos sospechosos o "fuera de lugar".
  - Filtro dinámico en vista de Kardex: chip para aislar instantáneamente movimientos marcados como irregulares.

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
