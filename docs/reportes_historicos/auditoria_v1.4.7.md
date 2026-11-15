# Auditoría técnica — FarmaControl v1.4.7

**Fecha:** 13/11/2026 · **Alcance:** backend FastAPI, frontend Flutter, CI, documentación
**Método:** revisión del código completo, ejecución de las pruebas existentes y pruebas de explotación contra una copia de `farmacia.db`.

> Todos los hallazgos marcados como **[Verificado]** se reprodujeron ejecutando la API. Los marcados como **[Corregido]** incluyen una prueba de regresión en `backend/tests/test_auditoria.py`.

---

## 1. Resumen ejecutivo

El dominio está bien modelado (FEFO, Kardex, lotes, cortes Z, CIE-10) y la suite de integración original pasa (28/28). Pero **la seguridad declarada en el README no existe en el código**: no hay autenticación real, el control de roles se decide con un campo que envía el propio cliente y hay defectos de lógica que permiten **vender medicamento caducado**, **otorgar descuentos ilimitados** y **reembolsar varias veces la misma venta**.

| Severidad | Hallazgos | Corregidos en esta auditoría |
|---|---|---|
| Crítica | 6 | 6 |
| Alta | 7 | 1 |
| Media | 10 | 2 |

---

## 2. Hallazgos críticos (corregidos)

| # | Hallazgo | Evidencia | Corrección |
|---|---|---|---|
| C1 | **El token de sesión nunca se valida.** `login` devuelve un `tk_<uuid>` aleatorio que ninguna ruta revisa; cualquiera puede crear un ADMINISTRADOR con `POST /api/auth/usuarios` sin credenciales. | [Verificado] 201 al crear `intruso` con rol ADMINISTRADOR sin cabecera. | `app/security.py`: tokens HMAC-SHA256 firmados con caducidad, `auth_guard` global y `require_roles(...)`. Gestión de usuarios restringida a ADMINISTRADOR. |
| C2 | **Login con el hash como contraseña.** Se aceptaba `password_hash == password`, así que quien vea la BD entra con el hash sin conocer la clave. | [Verificado] login 200 enviando el SHA-256 de `admin`. | Se elimina la comparación en texto plano; `verify_password` usa `hmac.compare_digest`. |
| C3 | **Contraseñas con SHA-256 sin sal.** Se rompen por diccionario en segundos (`admin123`, `caja123`, `resp123`). | `seed.py`, `auth.py`. | PBKDF2-SHA256 con sal y 310 000 iteraciones (biblioteca estándar). Los hashes heredados **se migran solos** en el primer login. Columna ampliada a `String(255)`. |
| C4 | **RBAC decidido por el cliente.** Para ajustar o dar de baja un lote basta con enviar `"rol_usuario": "ADMINISTRADOR"` en el cuerpo. | [Verificado] ajuste 200 sin sesión. | Con sesión válida, el rol y el nombre salen del token e ignoran el cuerpo. Las observaciones del Kardex quedan restringidas a ADMIN/RESPONSABLE_SANITARIO. |
| C5 | **FEFO despacha lotes caducados** (incumple FEUM y COFEPRIS). La consulta FEFO no filtraba `fecha_caducidad`. | [Verificado] venta 201 de un lote caducado en 2020. | Filtro `fecha_caducidad >= hoy`, desempate determinista y `with_for_update()` (bloqueo de fila en MySQL). |
| C6 | **Devoluciones repetibles sin límite.** Solo se comparaba contra lo despachado, no contra lo ya devuelto. Además se reembolsaba al **precio actual**, no al cobrado, y se ignoraba el descuento. | [Verificado] venta de $20 → $60 reembolsados en 3 devoluciones. | Límite acumulado por lote, reembolso = precio del ticket × factor neto del descuento, bloqueo de ventas `DEVUELTA` y validación de `estado_producto`. |

### Defectos de cobro (Alta, corregidos)

| # | Hallazgo | Corrección |
|---|---|---|
| A1 | El descuento lo enviaba el cliente sin tope (`descuento: 9999` → total $0). El efectivo con `monto_recibido = 0` se aceptaba. | El servidor calcula el descuento a partir del % de fidelización del cliente y rechaza montos mayores. Si el pago es en EFECTIVO, el monto recibido debe cubrir el total. Ambos cambios son compatibles con lo que ya envía `pos_screen.dart`. |

### Otros cambios

* **CORS:** se reemplaza `"*"` con credenciales por una lista configurable (`CORS_ORIGINS`) más `localhost` en cualquier puerto.
* **`test_api.py`** ya no escribe sobre `backend/farmacia.db`: usa una copia temporal. La BD versionada mostraba el efecto: `"Lic. Alejandro Mendoza (Actualizado) (Actualizado)…"`.
* **Versión** unificada en `APP_VERSION` (la API decía 1.4.0 en un sitio y 1.1.0 en otro).
* `.env.example` documenta `FARMACONTROL_SECRET_KEY`, `AUTH_REQUIRED`, `TOKEN_TTL_SECONDS` y `CORS_ORIGINS`.

### ⚠️ Plan de activación de la autenticación

El frontend actual **no envía el token**. Por eso el backend arranca con `AUTH_REQUIRED=0` (modo compatibilidad): si llega un token se valida y manda sobre el cuerpo, y si no llega la API responde como antes. **Mientras siga así, C1 y C4 solo están mitigados, no cerrados.** Para cerrarlos:

1. Frontend: pantalla de login real y cabecera `Authorization` en `ApiService` (ver §4.1).
2. Producción (Render): `FARMACONTROL_SECRET_KEY=<aleatoria>` y `AUTH_REQUIRED=1`.

Se verificó el modo estricto: `/api/health` responde 200, `/api/ventas/` sin token responde 401 y con token 200.

---

## 3. Pendientes de backend — arquitectura

| Sev. | Hallazgo | Recomendación |
|---|---|---|
| Alta | **CFDI simulado presentado como timbrado.** Sello, UUID y `NoCertificado` son aleatorios o fijos, y el RFC emisor está escrito en el código. Entregarlo a un cliente como factura es un riesgo legal. | Integrar un PAC autorizado (Facturama, SW Sapien, Finkok) o marcar el XML y el PDF como *"SIMULACIÓN — SIN VALIDEZ FISCAL"*. |
| Alta | **IVA mal calculado en el XML.** El traslado global usa `Base=subtotal` con `TasaOCuota=0.16` aunque las partidas sean de tasa 0 %, y el descuento no se prorratea por concepto. | Agrupar los traslados por tasa y prorratear el descuento por partida. |
| Alta | **Sustitución "IA" por familia terapéutica.** Sugiere en mostrador, por ejemplo, enalapril en lugar de losartán. En México solo es intercambiable la misma sustancia, concentración y forma (genérico intercambiable). | Limitar las sugerencias automáticas a `BIOEQUIVALENTE_DIRECTO` con la misma dosis y forma. Mostrar la "misma familia" solo como información para el responsable sanitario. Renombrarlo: es un motor de reglas, no IA. |
| Alta | **Corte Z incompleto.** Hay un único turno abierto global para todos los cajeros, los reembolsos en efectivo no se restan del efectivo esperado y se permiten ventas sin turno abierto. | Turno por usuario/caja, `turno_id` en `Devolucion`, efectivo esperado = fondo + ventas − reembolsos, y exigir turno abierto para vender. |
| Alta | **Dinero en `Float`.** Acumula errores de redondeo en cortes y reportes. | `Numeric(12,2)` en el modelo y `Decimal` en Pydantic. |
| Alta | **Kardex "inmutable" que se puede modificar** y con signos inconsistentes: `SALIDA_VENTA` es negativo, `SALIDA_AJUSTE` y `BAJA_LOTE` positivos, y la merma por devolución registra −N sin mover el stock. | Convención única (cantidad con signo = posterior − anterior). Observaciones en una tabla aparte `kardex_observaciones`. Existencias de cuarentena separadas del stock vendible. |
| Media | Migraciones a mano en `ensure_sqlite_schema` (se ejecuta dos veces y solo funciona en SQLite). | Alembic. La primera migración amplía `usuarios.password_hash` a 255 (**obligatorio antes de usar MySQL**). |
| Media | Lógica de negocio dentro de los routers (`ventas.py` tiene 485 líneas). | Capa `services/` (VentaService, InventarioService) con los routers solo como adaptadores HTTP. Permite probar FEFO sin HTTP. |
| Media | Consultas N+1: `listar_productos` carga los lotes de cada producto y `listar_mermas` consulta un lote por movimiento. | `selectinload`, o un `SUM` agregado en SQL. |
| Media | `datetime.utcnow()` (obsoleto) mezclado con `date.today()` local: la caducidad y el folio pueden variar según la zona horaria del servidor. | `datetime.now(ZoneInfo("America/Mexico_City"))` centralizado. |
| Media | `farmacia.db` versionada con datos. El README dice "cero secretos", pero las credenciales por defecto están en el seed y en las pruebas. | Quitar la BD del repositorio (ya añadida a `.gitignore`) y forzar el cambio de contraseña en el primer login. |
| Media | Los reportes incluyen rutas locales `file:///c:/Users/…/OneDrive/…`. | Usar enlaces relativos. |

---

## 4. Frontend — arquitectura, interfaz y diseño

*No se pudo compilar Flutter en el entorno de auditoría: este apartado sale de la revisión estática y no hay cambios de Dart aplicados.*

### 4.1 Arquitectura

| Sev. | Hallazgo | Recomendación |
|---|---|---|
| Crítica | **No hay inicio de sesión.** La app arranca como administrador y el diálogo *Cambiar Usuario / Rol* cambia de perfil **sin contraseña**. El RBAC de la interfaz es decorativo. | `LoginScreen` → `AuthService.login()` guarda el token (`flutter_secure_storage`), `HomeScreen` solo con sesión y cierre automático ante un 401. El selector de demostración solo en `kDebugMode`. |
| Alta | `ApiService`: 743 líneas de métodos estáticos con `http.get/post` sueltos, sin cabecera de autenticación y con el manejo de errores repetido en cada llamada. | Un `ApiClient` único con `_send()` que añade `Authorization`, timeout, decodificación UTF-8 y una `ApiException` tipada. `baseUrl` vía `--dart-define=API_URL=…`, no por host. |
| Alta | Pantallas monolíticas: `inventario_screen.dart` (2801 líneas), `pos_screen.dart` (1947) y `clientes_screen.dart` (1790), cada una con un solo `State` (31 `setState` en inventario). | Separar por funcionalidad: `features/pos/{data,state,widgets}`. Un controlador por pantalla (`ChangeNotifier`/Riverpod) y widgets de 150 a 300 líneas. |
| Alta | Datos como `Map<String, dynamic>` en todas partes: solo `Medico` tiene modelo. Un error tipográfico en una clave falla en tiempo de ejecución. | Modelos tipados (`Producto`, `Lote`, `Venta`, `Cliente`, `Turno`) con `fromJson`, o `freezed` + `json_serializable`. |
| Media | `test/widget_test.dart` es la plantilla del contador y fallaría. El CI no ejecuta pruebas. | Pruebas de widget de POS y login. CI: `pytest` + `flutter analyze` + `flutter test` antes de desplegar. |

### 4.2 Interfaz y diseño

| Sev. | Hallazgo | Recomendación |
|---|---|---|
| Alta | **~870 colores fijos** (`Colors.white`, `Colors.grey.shade50`, `Colors.teal`…). El modo oscuro y los 5 temas configurables quedan rotos en la mayoría de tarjetas y diálogos: por ejemplo, el texto `Colors.black87` del selector de usuario se pierde sobre fondo oscuro. | Usar `Theme.of(context).colorScheme` (`surface`, `surfaceContainerHigh`, `onSurfaceVariant`, `primaryContainer`…) y un `ThemeExtension` para los semáforos (caducado/crítico/preventivo, vencido/próximo/al día). |
| Alta | **Tipografía demasiado pequeña** para mostrador: 88 usos de `fontSize: 11` y 28 de 10. En el POS hay 13 textos de 8 a 10 px. No existe escala tipográfica. | Usar solo `textTheme` (`bodyMedium` ≥ 14, `labelSmall` ≥ 12). Total y cambio del POS en `displaySmall`. Cumplir WCAG AA (contraste ≥ 4.5:1). |
| Media | Emojis en datos y mensajes de negocio (`🔔`, `🚨`, `🤖` en las respuestas del backend). Se ven distinto en cada plataforma y ensucian los tickets y exportaciones. | El backend devuelve códigos (`nivel: VENCIDO`) y el frontend los pinta con `Icon` y color del tema. |
| Media | Las preferencias de tema y escala de fuente no se guardan: se pierden al recargar. | `shared_preferences`. |
| Media | POS: el flujo de cobro depende de diálogos y hojas modales. No hay atajos de teclado para el lector de códigos (escanear → Enter → agregar), ni F2 para cobrar ni Esc para cancelar. | Disposición fija en dos paneles en escritorio (catálogo \| carrito + cobro siempre visible), `Shortcuts`/`Actions` y foco permanente en la búsqueda. |
| Media | La navegación mezcla `Drawer` y `NavigationRail` con un punto de corte fijo de 700 px y muestra opciones que el rol no puede usar. | `NavigationBar` en móvil, `NavigationRail` en tablet y escritorio, y destinos filtrados por rol (no solo deshabilitados). |
| Baja | `pubspec.yaml`: `name: frontend`, `description: "A new Flutter project."`, `version: 1.0.0+1`. | Nombre, descripción y versión 1.4.7+N. |

---

## 5. Hoja de ruta sugerida

1. **Sprint 1 (seguridad):** login en Flutter + token en `ApiClient` → `AUTH_REQUIRED=1` en Render. Rotar las contraseñas por defecto. Retirar `farmacia.db` del repositorio.
2. **Sprint 2 (integridad):** Alembic, dinero en `Numeric`, Kardex con convención única, Corte Z con reembolsos y turno por usuario.
3. **Sprint 3 (diseño):** tokens de color y tipografía (`ColorScheme` + `ThemeExtension`), eliminar colores fijos, rediseño del POS en dos paneles con atajos de teclado.
4. **Sprint 4 (mantenibilidad):** dividir pantallas por funcionalidad, modelos tipados, pruebas de widget y CI con pruebas antes del despliegue.
5. **Legal:** decidir entre PAC real y etiqueta de simulación para el CFDI, y restringir las sustituciones a la misma sustancia y dosis.

---

## 6. Verificación

```
pytest backend/tests                → 13 passed  (nuevas pruebas de regresión)
python backend/test_api.py          → 28/28 pruebas superadas (sin modificar farmacia.db)
AUTH_REQUIRED=1 → /api/health 200 · /api/ventas sin token 401 · con token 200
```

Archivos modificados: `app/security.py` (nuevo), `app/main.py`, `app/models.py`, `app/routers/{auth,ventas,devoluciones,inventario}.py`, `seed.py`, `test_api.py`, `tests/` (nuevo), `.env.example`, `.gitignore`.
