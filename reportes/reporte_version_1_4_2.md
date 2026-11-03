# Reporte de Lanzamiento - FarmaControl v1.4.2
**Fecha de Implementación:** 2 de Noviembre de 2026  
**Rama:** `main` | **Commit:** `84512a6`  
**Entorno de Producción Cloud:**
- **Frontend PWA:** [https://ybisjuxx.github.io/Developer/](https://ybisjuxx.github.io/Developer/)
- **Backend API:** [https://developer-80fs.onrender.com](https://developer-80fs.onrender.com)

---

## 1. Resumen Ejecutivo de la Versión

En la versión **v1.4.2**, FarmaControl se transforma en una aplicación **100% responsiva (Mobile-First / Adaptive)**, eliminando por completo los problemas de elementos cortados, tablas desbordadas o barras rígidas en teléfonos móviles y tablets Android con anchos de pantalla reducidos (360px a 410px), preservando a su vez el diseño espacioso de escritorio para computadoras y monitores de farmacia ($\ge 850$px).

---

## 2. Mejoras y Optimizaciones por Módulo

### 🛒 1. Punto de Venta (POS) Adaptativo (`pos_screen.dart`)
- **Problema previo:** En pantallas pequeñas, el catálogo y el ticket compartían un `Row` con un ancho fijo de `370px` para el ticket, aplastando los medicamentos y provocando desbordamiento horizontal severo.
- **Solución implementada:**
  - Detección reactiva mediante `LayoutBuilder` (`isMobile = constraints.maxWidth < 850`).
  - **En Móviles:**
    - El catálogo de medicamentos pasa a ocupar el **100% del ancho de pantalla**.
    - Rejilla fluida de fármacos con `childAspectRatio: 0.74` y tarjetas compactas para evitar truncamientos.
    - Se introduce una **Barra Inferior Flotante de Resumen (`bottomNavigationBar`)** que muestra en tiempo real: número de productos agregados, total a pagar en \$ MXN y un botón táctil destacado `[Ver Ticket / Cobrar]`.
    - Al presionar el botón, se despliega un **Modal Bottom Sheet táctil** (al 88% de la pantalla) donde el cajero puede:
      - Buscar o registrar clientes frecuentes por teléfono.
      - Seleccionar médico prescriptor para antibióticos o controlados.
      - Ajustar cantidades con botones `(+)` y `(-)`.
      - Seleccionar método de pago (Efectivo, Tarjeta, Transferencia), calcular cambio automático con botón `Exacto`.
      - Ejecutar el cobro con FEFO en un solo toque con cierre automático del modal al imprimir.
  - **En Escritorio:** Se mantiene la disposición clásica lado a lado sin alterar la experiencia de monitores grandes.

---

### 📊 2. Tablero de Mando y Gráficos (`dashboard_screen.dart`)
- **Encabezado Fluido:** Envuelto en `Wrap` para que el título y el botón `[Nueva Venta / Cobrar]` no se empalmen ni se corten en viewports estrechos.
- **Métricas KPI:** Ajuste de cuadrícula a 2 columnas con proporciones verticales optimizadas (`childAspectRatio: 1.15`), evitando que los valores o subtítulos salgan de las tarjetas.
- **Gráfico Mes a Mes y Tarjetas Anuales:**
  - Las 4 tarjetas de métricas anuales se integran dentro de un `SingleChildScrollView` horizontal, garantizando lectura limpia en cualquier celular.
  - El gráfico anual de 12 barras se envuelve en un contenedor desplazable táctil con un ancho mínimo garantizado de `540px`, permitiendo al usuario deslizar horizontalmente con el pulgar para consultar el historial de ventas mes a mes.
- **Alertas FEFO y Últimas Ventas:** En computadoras se muestran en paralelo (flex 5 y 4); en celulares se apilan automáticamente en una **columna vertical**, dando a cada sección espacio completo y legibilidad.

---

### 📦 3. Inventario, Caducidades y Kardex (`inventario_screen.dart`)
- **Pestañas Desplazables (`isScrollable: true`):** Las 3 pestañas principales de inventario ya no se comprimen ni chocan entre sí.
- **Botón Flotante (`FloatingActionButton.extended`):** En móviles, el botón "Registrar Lote" se retira de la cabecera comprimida y pasa a flotar en la esquina inferior derecha, haciéndolo 100% accesible con el pulgar.

---

### 🧾 4. Historial de Ventas y Facturación CFDI 4.0 (`ventas_screen.dart`)
- **Panel CFDI 4.0 Responsivo:** En móviles, la descripción de facturación, el campo de búsqueda de folio de ticket y el botón de timbrado se apilan verticalmente sin causar ningún desbordamiento.
- **Insignias y Folios:** El folio de venta, insignia de estado y folio fiscal se reestructuran con `Wrap` para fluir naturalmente a una segunda línea en pantallas estrechas.
- **Botones de Acción:** Los botones `Ver Ticket Térmico`, `Facturar Ticket` y `Devolución / Merma` se adaptan automáticamente a múltiples filas.

---

### 👥 5. Padrón de Clientes y Arqueo de Caja (`clientes_screen.dart`, `caja_screen.dart`)
- Encabezados adaptativos con `Wrap` que recolocan los botones de acción (`Registrar Nuevo Cliente` y `Corte Z / Arqueo`) debajo de los títulos en smartphones.

---

### 🪟 6. Diálogos y Modales Elásticos Universales
- Se sustituyeron todos los anchos fijos de `380px` a `580px` por contenedores fluidos basados en `width: MediaQuery.of(context).size.width * 0.9` acoplados a `constraints: BoxConstraints(maxWidth: ...)`.
- Optimización aplicada a:
  1. **Ticket Térmico Realista:** `ticket_impresion_dialog.dart` (se adapta perfectamente al ancho de 360-400px en celulares y cuenta con apilado vertical automático de botones `actionsOverflowButtonSpacing: 8`).
  2. Alta de Lotes y Fórmulas FEFO.
  3. Registro Exprés de Clientes y Búsqueda por Teléfono.
  4. Ajuste de Piezas y Baja por Merma.
  5. Registro de Diagnósticos CIE-10.
  6. Configuración de Usuarios y Roles.

---

### 🧭 7. Barra de Navegación Global (`home_screen.dart`)
- **AppBar Móvil Compacta:** Muestra el isotipo y nombre de la farmacia junto a la insignia de módulo actual, trasladando la Consulta IA y el selector de usuario a botones de acción rápidos en la barra superior.
- **Navegación Inferior Robusta:** Se corrigió el disparador del menú lateral Drawer (`_scaffoldKey.currentState?.openDrawer()`) para garantizar apertura fluida desde la barra inferior táctil.

---

## 3. Verificación de Despliegue Cloud

| Componente | Plataforma | URL Pública | Estado |
| :--- | :--- | :--- | :--- |
| **Frontend PWA** | GitHub Pages | `https://ybisjuxx.github.io/Developer/` | 🚀 Auto-desplegando vía GitHub Actions (`main`) |
| **Backend API** | Render Cloud | `https://developer-80fs.onrender.com` | ✅ Activo / Operativo (CORS + GZip) |
| **Código Fuente** | GitHub | `https://github.com/Ybisjuxx/Developer` | ✅ Sincronizado en rama `main` |
