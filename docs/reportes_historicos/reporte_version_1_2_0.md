# Reporte Ejecutivo de Versión v1.2.0 - FarmaControl
**Fecha:** 28 de Octubre de 2026  
**Versión del Sistema:** `v1.2.0` (Tag Git: `v1.2.0`, Commit `e6497ba`)  
**Entorno de Producción Local:** `C:\Developer`

---

## 1. Resumen de Implementación de los 6 Sub-Agentes

| Sub-Agente | Módulo / Pantalla | Funcionalidad Implementada | Estado |
| :--- | :--- | :--- | :---: |
| **Sub-Agente 1** | Tablero de Mando & Inventario | **Conexión interactiva FEFO:** Clic en KPI de Alertas o Lotes Críticos navega directo a la nueva pestaña *"Lotes por Caducar (Alertas FEFO)"* con clasificación semafórica (≤30, 31-60, 61-90 días). | ✅ 100% |
| **Sub-Agente 2** | Registro de Lotes & Kardex | **Metadatos Sanitarios:** Se agregaron Laboratorio Fabricante, Forma Farmacéutica (dropdown con 8 opciones), Dosificación por presentación y Fecha de Ingreso en backend y frontend. | ✅ 100% |
| **Sub-Agente 3** | Padrón de Clientes & POS | **Fecha de Nacimiento y Sexo Opcionales:** Captura desglosada en Día (DD), Mes (MM) y Año (AAAA) + calendario interactivo (`showDatePicker`) y selector de Sexo en clientes y modal exprés del POS. | ✅ 100% |
| **Sub-Agente 4** | Navegación Global & Layout | **Robustez y Accesibilidad Visual:** Menú de navegación (`NavigationRail`) con scroll protegido ante escalas de fuente al 115% o 130% sin desbordamientos (`overflow`), más menú desplegable `Drawer` de respaldo. | ✅ 100% |
| **Sub-Agente 5** | Barra Superior & Chat IA | **Asistente Farmacéutico IA:** Botón `[🤖 Consulta IA]` en cabecera con router de bioequivalencia (`/api/ia/consulta-medicamento`), búsqueda de fármacos y recomendación de sustitutos terapéuticos con stock real. | ✅ 100% |
| **Sub-Agente 6** | Tablero de Mando & Ventas | **Gráfico de Ventas Mes a Mes:** Gráfico de barras interactivo de 12 meses con alturas dinámicas, destacado del mes pico (`★ PICO`), selector de año fiscal (2026/2025/2024) y métricas anuales. | ✅ 100% |

---

## 2. Detalles Técnicos por Componente

### Sub-Agente 1: Conexión de Tablero a Alertas FEFO y Pestaña de Lotes por Caducar
* **Backend:** Nuevo endpoint `GET /api/inventario/lotes/caducidades?dias=90` con clasificación automática de severidad (`CRITICA`, `EN_RIESGO`, `PREVENTIVA`).
* **Frontend:**
  * En [`dashboard_screen.dart`](file:///C:/Developer/frontend/lib/screens/dashboard_screen.dart), tanto la tarjeta de *"Alertas de Caducidad"* como la lista de *"Lotes con Prioridad de Despacho (FEFO)"* y el botón *"Ver en Inventario"* disparan `widget.onNavigate(3, subTab: 1)`.
  * En [`inventario_screen.dart`](file:///C:/Developer/frontend/lib/screens/inventario_screen.dart), se rediseñó el módulo con 3 pestañas:
    1. *Catálogo y Todos los Lotes*
    2. *Lotes por Caducar (Alertas FEFO)*: Incluye filtros reactivos (*Todos*, *Críticos ≤30d*, *En Riesgo 31-60d*, *Preventivos 61-90d*), indicadores de existencia y botones directos de *Ajustar* o *Dar de baja*.
    3. *Kardex y Trazabilidad*

### Sub-Agente 2: Datos de Fabricación y Dosificación de Lotes
* **Base de Datos:** Modelo `Lote` ampliado con:
  * `laboratorio_fabricante`: VARCHAR(150)
  * `forma_farmaceutica`: VARCHAR(80) (Tabletas, Cápsulas, Solución oral, Suspensión, Inyectable, Gel/Crema, Jarabe, Gotas oftálmicas)
  * `dosificacion`: VARCHAR(80) (ej: 500 mg, 1 g / 100 ml, 250 mg / 5 ml)
  * `fecha_ingreso`: DATE (automático o seleccionado en recepción)
* **Frontend:** Formulario en diálogo *"Registrar Nuevo Lote"* con validación y campos de captura organizados en dos columnas responsivas.

### Sub-Agente 3: Fecha de Nacimiento Desglosada y Sexo en Clientes
* **Base de Datos:** Modelo `Cliente` enriquecido con `fecha_nacimiento` (Date) y `sexo` (String).
* **Frontend:**
  * En [`clientes_screen.dart`](file:///C:/Developer/frontend/lib/screens/clientes_screen.dart) y [`pos_screen.dart`](file:///C:/Developer/frontend/lib/screens/pos_screen.dart):
    * 3 campos numéricos independientes: `Día (DD)`, `Mes (MM)` y `Año (AAAA)`.
    * Botón de calendario interactivo que sincroniza automáticamente las tres cajas al elegir una fecha.
    * Selector de Sexo (`MASCULINO`, `FEMENINO`, `OTRO`).
    * Visualización de edad calculada en años y distintivos de género en el expediente clínico del cliente.

### Sub-Agente 4: Navegación Estable ante Cambios de Fuente y Tema
* **Solución de Overflow:** Se envolvió el `NavigationRail` de 10 módulos dentro de un `SingleChildScrollView` acoplado a un `ConstrainedBox(minHeight: constraints.maxHeight)`.
* **Resultado:** Al seleccionar en Configuración una escala tipográfica del **115%** o **130%**, el menú se desplaza suavemente sin romper el layout ni arrojar alertas rojas de Flutter.
* **Drawer Alternativo:** Se integró un menú lateral deslizable (`Drawer`) disponible en todo momento.

### Sub-Agente 5: Chat IA Clínico con Sugerencia de Sustitutos en Inventario
* **Backend (`backend/app/routers/ia.py`):**
  * Base de conocimiento con 8 familias terapéuticas y mapeo marca-a-genérico (ej: Tempra/Tylenol -> Paracetamol; Flanax -> Naproxeno; Sensibit -> Loratadina; Amoxil -> Amoxicilina).
  * Inspecciona la base de datos de lotes y stock en tiempo real: si el fármaco consultado no está en existencia o tiene stock 0, localiza alternativas de la misma familia que **sí tengan piezas disponibles**.
  * Incluye advertencias regulatorias COFEPRIS automáticas (ej: *"Requiere receta médica para antibióticos Grupo IV"*).
* **Frontend:** Botón permanente `[🤖 Consulta IA]` en el `AppBar` que despliega un modal tipo mensajería con preguntas frecuentes sugeridas en chips.

### Sub-Agente 6: Gráfico Desglosado de Ventas Mes a Mes
* **Backend (`backend/app/routers/ventas.py`):**
  * Endpoint `GET /api/ventas/reporte-mensual?anio=2026` con desglose por mes de enero a diciembre, cálculo de importe total, promedio mensual y mes pico.
* **Frontend:**
  * Tarjeta ejecutiva con selector de año fiscal (2026, 2025, 2024).
  * 4 mini KPIs: Ingreso Total Anual, Promedio Mensual, Mes con Mayor Venta y Total de Tickets Emitidos.
  * Gráfico de barras de 12 meses con gradientes de color, insignia dorada `★ PICO` para el mes con mayores ingresos y desglose detallado al tocar cualquier barra.

---

## 3. Pruebas y Validación Técnica

1. **Pruebas Automatizadas de Backend (19/19 PASADAS):**
   * Todas las 19 pruebas de integración ejecutadas con éxito (`test_api.py`), validando caducidades, nuevos lotes con laboratorio/forma/dosis, clientes con fecha de nacimiento/sexo, consulta clínica IA y reporte mensual de ventas.
2. **Análisis Estático de Frontend (`flutter analyze`):**
   * **0 Errores de compilación.**
   * **0 Advertencias.**

---

## 4. Solución al Mensaje: `bash: flutter: command not found`

Si al abrir Git Bash aparece `bash: flutter: command not found`, se debe a que la sesión de Git Bash se abrió antes de que el PATH del sistema se actualizara con la ruta de Flutter (`C:\Users\ybis\flutter\bin`).

Para solucionarlo de inmediato en Git Bash, ejecuta:

```bash
export PATH="$PATH:/c/Users/ybis/flutter/bin"
```

O si prefieres que quede permanente en Git Bash:
```bash
echo 'export PATH="$PATH:/c/Users/ybis/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Comandos de Arranque (en C:\Developer):

* **Terminal 1 - Backend FastAPI:**
  ```bash
  cd /c/Developer/backend
  python run.py
  ```
  *(Documentación interactiva en http://127.0.0.1:8000/docs)*

* **Terminal 2 - Frontend Flutter:**
  ```bash
  cd /c/Developer/frontend
  flutter run -d web-server --web-port=8080
  ```
  *(Acceso en http://localhost:8080)*
