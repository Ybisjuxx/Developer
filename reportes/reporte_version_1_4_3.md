# Reporte de Versión FarmaControl v1.4.3
**Fecha:** 2026-11-02  
**Módulos Clave:** Punto de Venta, Inventario, Arqueo de Caja, Ventas CFDI, Escáner de Código de Barras Móvil con Cámara  

---

## 🎯 Objetivo de la Versión
Atender la retroalimentación de uso en smartphones Android en **orientación vertical (Modo Portrait)**:
1. Incorporar la funcionalidad nativa de **escaneo de código de barras mediante la cámara del celular**.
2. Adaptar contenedores, diálogos con teclado en pantalla y botones de acción que quedaban ocultos o desbordados en pantallas estrechas ($360\text{px} - 420\text{px}$).
3. Garantizar que la experiencia en PC/Escritorio permanezca **100% inalterada** mediante diseño responsivo estricto.

---

## 🛠️ Modificaciones Realizadas

### 1. Escáner de Código de Barras con Cámara (`mobile_scanner: ^7.5.0`)
- Se implementó el componente reutilizable `LectorCodigoBarrasDialog` (`frontend/lib/widgets/lector_codigo_barras_dialog.dart`).
- **Punto de Venta (`pos_screen.dart`):** En la barra de búsqueda de medicamentos ahora se muestra un botón táctil con ícono de cámara (`Icons.camera_alt`). Al pulsarlo se abre la cámara en vivo con retícula de enfoque, linterna (flash), alternancia de cámara frontal/trasera y opción de teclado manual.
- Al enfocar cualquier código de barras, se captura automáticamente, se valida contra el catálogo y el producto se añade de inmediato al carrito.
- **Historial de Ventas / Facturación (`ventas_screen.dart`):** Botón de escaneo rápido de tickets para timbrado fiscal CFDI 4.0 sin tener que escribir el folio manualmente.

### 2. Adaptación a Modo Vertical (Portrait / Pantalla Móvil Estrecha)
- **Inventario (`inventario_screen.dart`):**
  - La fila de lotes dentro del producto ahora utiliza un diseño responsivo en pantallas $< 500\text{px}$, colocando el número de lote y stock en la parte superior y los botones de **Ajustar Stock** y **Dar de Baja** visibles y accesibles abajo, erradicando desbordamientos horizontales.
  - El listado de caducidades FEFO adapta su cabecera y el bloque de existencia/precio para que los botones de acción nunca se corten.
  - La barra de búsqueda y filtros de caducidad se dividen en dos niveles con desplazamiento horizontal fluido.
- **Punto de Venta Mostrador (`pos_screen.dart`):**
  - El catálogo de medicamentos en modo vertical utiliza proporciones `childAspectRatio: 0.67` en pantallas $< 420\text{px}$ y `MainAxisAlignment.spaceBetween`, eliminando `Spacer()` rígidos.
  - El diálogo de confirmación de clientes ahora utiliza una altura elástica del 70% del viewport en lugar de un `height: 500` fijo, adaptándose suavemente cuando se abre el teclado.
  - El Bottom Sheet del Ticket incluye `viewInsets.bottom` para elevarse dinámicamente sobre el teclado numérico de cobro.
- **Arqueo de Caja (`caja_screen.dart`):**
  - Las 6 tarjetas KPI del turno activo calculan dinámicamente su anchura `(ancho - 12) / 2` en celulares, formando una cuadrícula perfecta de 2 columnas que ocupa el 100% del ancho sin dejar huecos.
- **Asistente IA y Navegación (`home_screen.dart`):**
  - El modal de conversación con la IA farmacéutica pasó de una altura fija de 520px a una altura adaptativa del 65% de la pantalla.

### 3. Impacto en Visualización en PC / Computadora
- **¿Afecta a la PC?:** **NO.**
- FarmaControl utiliza reglas condicionales de ancho (`LayoutBuilder` y `constraints.maxWidth >= 850px`).
- En monitores y computadoras:
  - El mostrador conserva su vista dual simultánea de Catálogo a la izquierda y Ticket a la derecha (370px).
  - El tablero de mando conserva sus 4 columnas de KPIs y visualización lado a lado de alertas y ventas.
  - Las tablas y listados conservan su disposición horizontal extendida.

---

## 🚀 Despliegue
- **Web App (GitHub Pages):** `https://ybisjuxx.github.io/Developer/`
- **Backend API (Render Cloud):** `https://developer-80fs.onrender.com`
