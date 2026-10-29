# Historial de Versiones (Changelog) - FarmaControl

Todas las modificaciones notables de este proyecto están documentadas en este archivo.
El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto se adhiere a [Semantic Versioning (SemVer 2.0.0)](https://semver.org/lang/es/).

---

## [1.4.0] - 2026-10-28 (Facturación CFDI Ventas, Catálogo CIE-10 Ampliado, Gestión y Apellidos de Médicos, ID en Tickets y Dosis Separada)

### 🚀 Añadido
- **Sub-Agente 1: Facturación Electrónica CFDI 4.0 y Automatización por Búsqueda de Ticket (`ventas_screen.dart`, `ventas.py`, `schemas.py`, `models.py`, `database.py`, `api_service.dart`):**
  - Módulo y apartado dedicado de **Facturación Electrónica** en el panel de Ventas con banner interactivo de automatización para que el cliente o cajero busque la venta por Folio de Ticket (`TK-...` o ID numérico).
  - Modal integral de emisión de factura con validación de campos fiscales del SAT (RFC, Razón Social, Régimen Fiscal, Código Postal, Uso de CFDI y Correo Electrónico).
  - Emisión de CFDI 4.0 con generación de UUID Fiscal simétrico (36 caracteres), folio `FAC-YYYYMMDD-XXXXX` y almacenamiento persistente en base de datos.
  - Visor interactivo de comprobante fiscal digital con opción de visualización de datos timbrados, desglose de IVA y badges de estado `FACTURADA` en el historial de ventas.
  - Endpoints implementados: `GET /api/ventas/ticket/{folio_ticket}`, `POST /api/ventas/{venta_id}/facturar` y `GET /api/ventas/{venta_id}/factura`.
- **Sub-Agente 2: Catálogo Epidemiológico CIE-10 Enriquecido y Motor de Búsqueda Normalizado (`catalogo_cie.py`, `enfermedades.py`, `test_api.py`):**
  - Catálogo nativo ampliado con más de **200 diagnósticos clínicos y epidemiológicos** representativos del sistema de salud mexicano, cubriendo los 22 capítulos de la Clasificación Internacional de Enfermedades (CIE-10).
  - Algoritmo de búsqueda inteligente insensible a mayúsculas y acentos (`á`, `é`, `í`, `ó`, `ú`, `ñ`), con tokenización multitérmino ponderada por concordancia de código y descripción clínica.
  - Diccionario de mapeo bilingüe (Español a Inglés) para integración resiliente con la API NIH ICD-10 externa, ejecutándose con fallback inmediato sin bloqueos de red.
  - Soporte de búsqueda por términos populares y síntomas comunes (ej: "resfriado" -> `J00`, "dolor de cabeza" -> `R51`, "gripe" -> `J11`).
- **Sub-Agente 3: Desglose de Apellidos Paterno y Materno en Registro de Médicos (`medico.dart`, `registrar_medico_screen.dart`, `models.py`, `schemas.py`, `medicos.py`, `database.py`):**
  - Desacoplamiento de apellidos en `apellido_paterno` y `apellido_materno` en el formulario y entidad de Médicos.
  - Flexibilidad para médicos con un solo apellido y compatibilidad con apellidos compuestos (ej: *de la Cruz*, *del Moral*, *Montes de Oca*).
  - Propiedad de lectura calculada `nombre_completo` y sincronización bidireccional no destructiva con el campo histórico `apellidos` para preservar la compatibilidad con recetas existentes.
- **Sub-Agente 4: Módulo de Gestión Completa de Médicos: Edición y Borrado / Desactivación (`medicos_screen.dart`, `registrar_medico_screen.dart`, `medicos.py`, `api_service.dart`):**
  - Acción de **Edición de Médicos** directamente desde la tarjeta del médico en el catálogo, precargando todos sus datos en el formulario para actualización inmediata.
  - Acción de **Borrado de Médicos** con modal de confirmación inteligente: si el médico tiene recetas o ventas vinculadas, se ejecuta una baja lógica / desactivación (`vigente = False`) protegiendo la integridad referencial; si no tiene registros vinculados, permite la eliminación definitiva.
  - Endpoints actualizados: `PUT /api/medicos/{medico_id}` y `DELETE /api/medicos/{medico_id}`.
- **Sub-Agente 5: Ticket de Compra al Cliente con Nombre de Producto e ID de Inventario y Remoción de Lote Interno (`ticket_impresion_dialog.dart`, `models.py`, `schemas.py`, `ventas.py`):**
  - En el ticket de compra entregado al cliente, se despliega de forma destacada el **Nombre del Producto** y su **ID de Inventario** (ej: `[ID: #1] Paracetamol 500mg`).
  - **Eliminación del número de lote en el comprobante del cliente:** Los lotes se mantienen como información de control interno exclusiva de la farmacia para devoluciones, mermas y auditoría de Kardex, evitando confusión en el comprador final.
  - Campos calculados `@property producto_nombre` y `@property sustancia_activa` expuestos en `VentaDetalleOut`.
- **Sub-Agente 6: Dosis Separada de Dosificación, Eliminación de Botones de Concentración y Autocompletado por Código de Barras Previo (`inventario_screen.dart`, `inventario.py`, `models.py`, `schemas.py`, `api_service.dart`):**
  - **Estructuración canónica de dosis:** Separación de la forma farmacéutica y la dosis en campos independientes (`forma_farmaceutica`, `dosis_valor`, `dosis_unidad`), consolidándose bajo el formato canónico estricto: `Forma | Dosis | Unidad` (ej: `Tableta | 100 | mg`).
  - **Eliminación de botones de concentración:** Se retiraron los botones de chips predeterminados, habilitando la captura manual y precisa de la magnitud y su unidad (mg, ml, mcg, g, UI, pza).
  - **Restricción estricta de autocompletado de producto:** El nombre del medicamento o producto se ingresa manualmente por defecto; el autocompletado inteligente se activa **únicamente** si el código de barras escaneado ya se encuentra registrado previamente en la base de datos de la farmacia mediante el nuevo endpoint `GET /api/inventario/productos/buscar-codigo/{codigo_barras}`.

---

## [1.3.0] - 2026-10-28 (Dosis y Dispositivos, IA Terapéutica Estricta, Búsqueda Telefónica POS y Apellidos Paterno/Materno)

### 🚀 Añadido
- **Sub-Agente 1: Dosis y Concentración Rápida + Catálogo de Dispositivos Médicos y Misceláneos (`inventario_screen.dart`, `seed.py`, `catalogo_medicamentos.py`):**
  - Apartado destacado *"Dosis / Concentración del Lote"* en el diálogo de registro con chips de acceso rápido (`100mg`, `250mg`, `500mg`, `1g`, `250ml`, `500ml`, `1UI`, `100UI`, `1 kit`, `1 pza`).
  - Incorporación al inventario de **7 dispositivos médicos y material de curación** (Termómetro Infrarrojo, Oxímetro de Pulso, Baumanómetro Digital, Glucómetro Accu-Chek, Jeringas 5ml BD, Gasas Estériles y Vendas Elásticas).
  - Incorporación al inventario de **7 productos misceláneos y bebidas** (Electrolit Fresa, Suerox Mora Azul, Agua Purificada Ciel 1L, Agua Mineral Peñafiel, Coca-Cola 600ml, Sprite y Manzana Lift).
  - Asignación de formas farmacéuticas como *Dispositivo Médico*, *Material de Curación*, *Solución Rehidratante* y *Refresco / Bebida*.
- **Sub-Agente 2: Consulta IA con Validación Terapéutica Estricta, Aviso de Compra y Deslinde (`ia.py`, `test_api.py`):**
  - **Alineación farmacológica estricta:** Bloqueo absoluto de cruces erróneos entre familias clínicas (la IA nunca sugiere analgésicos para sustituir antibióticos ni viceversa; solo bioequivalentes directos o de la misma indicación terapéutica).
  - **Aviso de solicitud de compra:** Si un fármaco o su clase terapéutica no tiene stock físico en farmacia, notifica explícitamente al usuario que puede tramitarse una solicitud de compra o pedido urgente a proveedor/almacén.
  - **Deslinde orientativo obligatorio:** Mensaje de deslinde clínico que aclara que la respuesta es asistencial y no reemplaza la búsqueda, diagnóstico ni validación de un humano calificado (médico o farmacéutico).
- **Sub-Agente 3: Barra Buscadora de Clientes en Cobro (POS) y Confirmación de Identidad (`pos_screen.dart`):**
  - Barra de búsqueda interactiva en mostrador con filtrado instantáneo por **número telefónico**, nombre completo o apellidos.
  - Modal *"Búsqueda y Confirmación de Cliente"* con panel de verificación por **Fecha de Nacimiento** (`🎂 DD/MM/AAAA`) para corroborar la identidad del comprador y evitar seleccionar homónimos o clientes incorrectos.
  - Acciones rápidas para asignar a *Público General* o invocar el alta rápida de clientes con 1 clic.
- **Sub-Agente 4: Corrección de Visualización del Género ante Escalas de Fuente (`clientes_screen.dart`, `pos_screen.dart`):**
  - Resolución del error de renderizado y desbordamiento (`RenderFlex overflowed`) al aumentar la fuente al 115% o 130%.
  - El selector de Sexo/Género (`DropdownButtonFormField`) ahora cuenta con `isExpanded: true` y control de texto (`TextOverflow.ellipsis`).
  - Separación del género y la fecha de nacimiento en bloques independientes y reemplazo de filas rígidas por contenedores `Wrap` adaptables en las tarjetas de cliente.
- **Sub-Agente 5: Desglose Obligatorio/Opcional en Apellido Paterno y Materno (`models.py`, `database.py`, `schemas.py`, `clientes.py`, `clientes_screen.dart`, `pos_screen.dart`):**
  - Desacoplamiento de apellidos en `apellido_paterno` y `apellido_materno`.
  - Flexibilidad legal: el primer apellido (paterno o principal) es obligatorio, mientras que el materno es opcional para amparar personas con un solo apellido o de origen extranjero.
  - Sincronización transparente con el campo consolidado `apellido` para mantener compatibilidad total con ventas y tickets previos.

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
