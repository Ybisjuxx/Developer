# Reporte de Versión FarmaControl v1.4.4
**Fecha:** 2026-11-03  
**Módulos Clave:** Catálogo de Lotes e Inventario, Módulo de Devoluciones y Mermas, Historial de Ventas, Clasificación Regulatoria COFEPRIS  

---

## 🎯 Objetivo de la Versión
Atender los requerimientos de optimización operativa en mostrador y almacén:
1. **Catálogo de Lotes (`inventario_screen.dart`):** Incorporar una barra de búsqueda inteligente que filtre por nombre, sustancia activa, presentación, laboratorio, código de barras y número de lote específico, además de categorizar los medicamentos por **Grupo Terapéutico COFEPRIS** con chips de filtrado rápido y botón de escáner con cámara.
2. **Módulo de Devoluciones (`devoluciones_screen.dart`):** Añadir filtrado por fechas con calendario interactivo (`DateRangePicker`), atajos de tiempo predefinidos (Hoy, 7 días, Este mes, Todo) y barra de búsqueda textual por folio/motivo, facilitando la auditoría de mermas y reembolsos.
3. **Historial de Ventas (`ventas_screen.dart`):** Incorporar filtrado de tickets por rango de fechas para agilizar la búsqueda de ventas previas sujetas a devolución o refacturación.

---

## 🛠️ Modificaciones Realizadas

### 1. Barra de Búsqueda y Clasificación COFEPRIS en Lotes (`inventario_screen.dart`)
- **Buscador Multicriterio:** Coincidencias en tiempo real sobre:
  - Nombre comercial del medicamento.
  - Sustancia activa / Fórmula química.
  - Presentación y Laboratorio farmacéutico.
  - Código de barras universal (EAN/UPC).
  - **Número de lote específico (`numero_lote`):** Permite ingresar directamente un identificador como `LT-` y ubicar de inmediato el producto y su lote asociado.
- **Lector de Código de Barras con Cámara:** Botón directo (`Icons.camera_alt`) que abre el visor interactivo de cámara para escanear medicamentos físicos directamente en almacén.
- **Categorización por Grupo COFEPRIS:**
  - `TODOS`: Muestra el catálogo completo.
  - `GRUPO VI`: Venta libre / OTC.
  - `GRUPO IV`: Medicamentos que requieren receta médica para su venta (fracción IV).
  - `CONTROLADOS`: Estupefacientes y psicotrópicos sujetos a control especial (Grupos I, II y III).
  - `GRUPO V`: Medicamentos sin receta de venta exclusiva en farmacia.
  - Chip alternador `Solo con Stock`: Para visualizar únicamente medicamentos con existencia disponible.
- **Identificadores Visuales:** Cada producto en la lista incluye su badge de Grupo Terapéutico COFEPRIS con código de colores oficial y el recuento de lotes activos registrados.

### 2. Filtro de Fechas y Búsqueda en Devoluciones y Mermas (`devoluciones_screen.dart`)
- **Selector de Rango de Fechas:** Calendario interactivo modal (`showDateRangePicker`) con selección de fecha de inicio y fecha de término.
- **Atajos Predefinidos:**
  - `Todo`: Historial completo sin restricción de fecha.
  - `Hoy`: Operaciones del día actual.
  - `7 días`: Última semana móvil.
  - `Este mes`: Todo el mes en curso.
- **Buscador de Texto Libre:** Filtra en tiempo real por número de folio de venta, motivo de devolución o justificación de merma.
- **Tarjeta Resumen del Período:** Muestra el número total de devoluciones y su importe monetario consolidado, así como las mermas registradas y su costo económico.

### 3. Filtro de Fechas en Consulta de Ventas (`ventas_screen.dart`)
- Se implementó el mismo selector de rango de fechas con presets (`Hoy`, `7 días`, `Este mes`, `Todo`) en el historial de ventas.
- Permite a los cajeros y administradores localizar en segundos tickets emitidos en fechas pasadas para procesar devoluciones o timbrar facturas CFDI 4.0 sin tener que desplazarse por listas extensas.

---

## 📱 Responsividad y Compatibilidad
- **Modo Móvil Vertical (Portrait):** Los chips de COFEPRIS y de fechas cuentan con desplazamiento horizontal táctil (`SingleChildScrollView` con scroll horizontal), y los campos de búsqueda ocupan el ancho completo sin desbordamientos.
- **Modo PC / Escritorio:** Conserva la disposición amplia con paneles extendidos y vistas tabulares completas.

---

## 🚀 Despliegue y Acceso
- **Web App:** [https://ybisjuxx.github.io/Developer/](https://ybisjuxx.github.io/Developer/)
- **Backend API:** [https://developer-80fs.onrender.com](https://developer-80fs.onrender.com)

