# Reporte de Versión FarmaControl v1.4.5
**Fecha:** 2026-11-03  
**Módulos Clave:** Kardex Inmutable y Auditoría, Inventario y Lotes, Filtro por Rango de Fechas, Escáner con Cámara  

---

## 🎯 Objetivo de la Versión
Homologar la experiencia de auditoría y consulta del **Kardex Inmutable** con el módulo de Devoluciones y Ventas:
1. Incorporar un **filtro por rango de fechas interactivo** con selector de calendario y preajustes rápidos (`Hoy`, `Últimos 7 días`, `Este mes`, `Todo el Historial`).
2. Añadir un **buscador multicriterio** y **lector de código de barras con cámara** para localizar cualquier medicamento o lote físico al instante.
3. Categorizar por **tipo de movimiento** (`Entradas`, `Salidas`, `Ajustes/Bajas`, `⚠️ Solo Irregulares`).
4. Enriquecer las tarjetas del Kardex con el **nombre comercial del medicamento**, **número de lote**, **fecha/hora exacta** y **resumen KPI del período**.

---

## 🛠️ Modificaciones Realizadas

### 1. Filtro Avanzado de Fechas en Kardex (`inventario_screen.dart`)
- **Selector de Rango de Fechas:** Botón con icono de calendario que abre `showDateRangePicker` para definir fechas precisas de auditoría fiscal y sanitaria.
- **Atajos Predefinidos:**
  - `Todo el Historial`: Visualización global de movimientos.
  - `Hoy`: Movimientos del día en curso.
  - `Últimos 7 días`: Semana móvil de operación.
  - `Este mes`: Todo el mes natural activo.
- **Botón Dinámico 'Limpiar filtros':** Restablece los filtros con un toque.

### 2. Buscador Multicriterio y Escáner con Cámara
- **Buscador de Texto Libre:** Filtra en tiempo real por:
  - Nombre comercial del medicamento.
  - Número de lote (`numero_lote`) o ID interno.
  - Tipo de movimiento (`ENTRADA_COMPRA`, `SALIDA_VENTA`, `ENTRADA_DEVOLUCION`, `SALIDA_MERMA`, `SALIDA_AJUSTE`, `BAJA_LOTE`).
  - Motivo de movimiento y justificación.
  - Folio de referencia (`TICKET_VENTA`, `DEVOLUCION_PACIENTE`, etc.).
  - Observaciones y nombre del auditor.
- **Lector de Código de Barras Móvil con Cámara:** Botón directo (`Icons.camera_alt`) en el buscador que permite enfocar con la cámara del celular el empaque de cualquier fármaco para filtrar de inmediato su historial en el Kardex.

### 3. Filtros por Naturaleza de Movimiento
- Chips conmutadores rápidos:
  - `Todos`: Todos los movimientos del período.
  - `Entradas (+)`: Entradas por compra, devolución de clientes o ajustes positivos.
  - `Salidas (-)`: Despachos por venta en mostrador o mermas sanitarias.
  - `Ajustes y Bajas`: Ajustes manuales autorizados y bajas definitivas de lotes.
  - `⚠️ Solo Irregulares`: Auditoría de anomalías y movimientos sospechosos.

### 4. Tarjetas Informativas Enriquecidas y KPIs del Período
- **Resolución Automática Lote -> Medicamento:** El Kardex ahora muestra el nombre real del fármaco (ej. *Paracetamol 500mg*) y su número de lote oficial (ej. *LT-8832*), en lugar de identificadores numéricos abstractos.
- **Fecha y Hora Estructurada:** Indicador visible `📅 dd/mm/aaaa hh:mm` en cada movimiento.
- **Tarjeta Resumen KPI:** Informa en el encabezado el total de movimientos del período, suma de piezas ingresadas (`+N pzas`), piezas egresadas (`-N pzas`) y recuento de irregularidades.

### 5. Capacidad de Consulta Histórica (`api_service.dart`)
- Se configuró el cliente para solicitar hasta 300 movimientos por defecto (`limit=300`) facilitando auditorías mensuales completas.

---

## 📱 Responsividad y Compatibilidad
- **Modo Móvil Vertical (Portrait):** La barra de filtros distribuye el campo de búsqueda y el botón de fechas verticalmente en pantallas $< 650\text{px}$, permitiendo una interacción táctil fluida con desplazamiento horizontal para chips de fechas.
- **Modo PC / Escritorio:** Disposición en fila de dos columnas, conservando la visualización panorámica completa.

---

## 🚀 Despliegue y Acceso
- **Web App:** [https://ybisjuxx.github.io/Developer/](https://ybisjuxx.github.io/Developer/)
- **Backend API:** [https://developer-80fs.onrender.com](https://developer-80fs.onrender.com)
