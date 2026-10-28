# Resumen Ejecutivo y Técnico: Sistema de Farmacia (FarmaControl)

Documento de traspaso de contexto para inicializar la siguiente sesión de agentes.

---

## 1. Visión General del Proyecto
Sistema integral para farmacias con cumplimiento de la normativa sanitaria mexicana (**Ley General de Salud Art. 226, FEUM y COFEPRIS**), gestión estricta de inventario bajo el método **FEFO (*First Expired, First Out*)**, auditoría contable mediante **Kardex inmutable**, punto de venta (POS) y catálogo clínico **CIE-10**.

* **Backend:** Python 3.12 + FastAPI + SQLite (SQLAlchemy 2.0 + Pydantic V2).
* **Frontend:** Flutter 3.47 (Material 3) compilado para Web (Chrome), compatible con Windows, macOS, Android e iOS.
* **Ubicación en disco:**
  * Backend: `c:\Users\ybis\OneDrive\Documentos\Ingenieria en Sistemas\Developer\backend`
  * Frontend: `c:\Users\ybis\OneDrive\Documentos\Ingenieria en Sistemas\Developer\frontend`

---

## 2. Reglas de Negocio Implementadas

1. **Despacho FEFO Estricto:** Al realizar una venta, el backend descuenta inventario automáticamente de los lotes más próximos a caducar (`fecha_caducidad ASC`). Si un lote no cubre la cantidad solicitada, fragmenta el despacho entre el lote actual y el siguiente.
2. **Control Sanitario de Recetas:**
   * Medicamentos clasificados según Farmacopea: **Grupo I a IV** (Antibióticos y controlados) exigen seleccionar un médico con cédula profesional vigente.
   * Medicamentos de **Grupo V y VI** (Venta libre / OTC) permiten venta directa a "Público General".
3. **Kardex Inmutable (Append-Only):** Cada entrada por compra, salida por venta o merma genera un registro histórico inmutable con saldo anterior y posterior.
4. **Catálogo Clínico CIE-10:** Diagnósticos internacionales vinculables a recetas e historiales con notas especiales.
5. **CORS Abierto:** El backend permite peticiones desde `localhost` para conectar con Flutter en Chrome sin restricciones de origen.

---

## 3. Estado del Backend (`/backend`)

### Archivos Principales:
* `app/database.py`: Motor SQLite (`farmacia.db`), gestión de sesiones y `Base`.
* `app/models.py`: Modelos relacionales:
  * `Medico`: Nombres, cédula profesional (única), especialidad, institución, vigencia.
  * `Enfermedad`: Código CIE-10 (único), descripción, categoría, consideraciones especiales.
  * `Producto`: Código de barras, nombre comercial, sustancia, presentación, grupo farmacopea, flag `requiere_receta`, precio.
  * `Lote`: Producto ID, número de lote, fecha de caducidad (indexada), costo, stock actual.
  * `Venta`, `VentaDetalle`, `VentaDetalleLote`: Tickets con desglose exacto de los lotes despachados.
  * `KardexMovimiento`: Auditoría estricta de existencias.
* `app/schemas.py`: Validadores Pydantic V2 para request/response.
* `app/routers/`:
  * `medicos.py`: CRUD (`POST`, `GET`, `PUT`, `DELETE`).
  * `enfermedades.py`: CRUD de diagnósticos CIE-10.
  * `inventario.py`: Catálogo de productos, alta de lotes con caducidad y consulta de Kardex.
  * `ventas.py`: Registro de ventas con despacho automático FEFO y validación médica.
* `app/main.py`: Entrada de FastAPI con CORS y documentación Swagger en `/docs`.
* `seed.py`: Semilla de datos con médicos demostrativos, padecimientos CIE y medicamentos con lotes escalonados.
* `test_api.py`: Suite de pruebas automatizadas aprobadas al 100%.

---

## 4. Estado del Frontend (`/frontend`)

### Arquitectura de Pantallas (Material 3):
1. **`dashboard_screen.dart` (Tablero de Mando):**
   * Métricas KPI: Stock global, Lotes en riesgo (< 90 días), Ventas totales ($ MXN) y Médicos vigentes.
   * Tabla con semáforo de prioridad de despacho FEFO.
   * Acceso rápido a Punto de Venta.
2. **`pos_screen.dart` (Punto de Venta / Cobro):**
   * Catálogo con stock en tiempo real.
   * Carrito interactivo con cantidades y cálculo de totales.
   * Bloqueo automático de antibióticos: exige médico emisor si hay fármacos controlados.
   * Emisión de ticket con modal detallando qué lotes y cantidades se descontaron.
3. **`inventario_screen.dart` (Inventario & Kardex):**
   * Pestaña 1: Catálogo de medicamentos y desglose de lotes por caducidad.
   * Modal "+ Registrar Lote" con selector de fecha en calendario.
   * Pestaña 2: Historial del Kardex inmutable.
4. **`medicos_screen.dart` & `registrar_medico_screen.dart`:**
   * Directorio con buscador y badges de vigencia.
   * Formulario sanitario con validación de cédula ante backend.
5. **`enfermedades_screen.dart`:**
   * Catálogo de diagnósticos CIE-10 con modal de alta y notas clínicas.
6. **`ventas_screen.dart`:**
   * Historial de tickets emitidos y desglose de auditoría.
7. **`services/api_service.dart`:**
   * Cliente HTTP completo con llamadas a todos los endpoints de FastAPI.

---

## 5. Comandos de Ejecución

### Terminal 1 - Backend (FastAPI):
```powershell
cd "c:\Users\ybis\OneDrive\Documentos\Ingenieria en Sistemas\Developer\backend"
python run.py
```
* Swagger UI: http://127.0.0.1:8000/docs

### Terminal 2 - Frontend (Flutter Web en Chrome):
```powershell
cd "c:\Users\ybis\OneDrive\Documentos\Ingenieria en Sistemas\Developer\frontend"
flutter run -d chrome
```

---

## 6. Próximos Pasos Sugeridos para la Nueva Sesión
1. **Flujo de Devoluciones y Mermas:** Registro de productos devueltos (reingreso a lote si está en buen estado, o envío a merma/cuarentena si está dañado).
2. **Generación e Impresión de Tickets:** Exportación a PDF o formato de ticket térmico (58mm/80mm).
3. **Cortes de Caja:** Arqueo de turnos (monto inicial, ventas en efectivo/tarjeta y balance al cierre).
4. **Autenticación y Roles:** Login con JWT para roles de *Cajero*, *Administrador* y *Responsable Sanitario*.
