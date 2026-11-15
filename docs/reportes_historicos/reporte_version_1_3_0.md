# Reporte Ejecutivo de Versión v1.3.0 - FarmaControl
**Fecha:** 28 de Octubre de 2026  
**Versión del Sistema:** `v1.3.0` (Tag Git: `v1.3.0`, Commit `e3f8610`)  
**Entorno Local:** `C:\Developer`

---

## 1. Resumen de Implementación de los 5 Sub-Agentes

| Sub-Agente | Módulo / Pantalla | Funcionalidad Implementada | Estado |
| :--- | :--- | :--- | :---: |
| **Sub-Agente 1** | Inventario & Registro de Lotes | **Dosis / Concentración + Dispositivos y Misceláneos:** Apartado dedicado en alta de lote con chips rápidos (`100mg`, `250mg`, `500mg`, `1g`, `250ml`, `500ml`, `1UI`, `100UI`, `1 kit`, `1 pza`). Registro en base de datos de **14 nuevos productos** (termómetros, oxímetros, baumanómetros, glucómetros, jeringas, gasas, vendas, Electrolit, Suerox, Ciel, Peñafiel, Coca-Cola, Sprite, Lift). | ✅ 100% |
| **Sub-Agente 2** | Asistente Clínico IA | **Alineación Terapéutica Estricta, Aviso de Compra y Deslinde:** Se eliminó cualquier sugerencia cruzada no alineada (la IA nunca sugiere paracetamol para sustituir antibióticos). Si un fármaco está agotado, notifica que puede solicitarse la compra/pedido urgente. Se añadió el deslinde obligatorio de que la respuesta es orientativa y no sustituye a un humano. | ✅ 100% |
| **Sub-Agente 3** | Punto de Venta (POS) & Cobro | **Búsqueda Telefónica y Confirmación por Fecha de Nacimiento:** Se sustituyó el dropdown estático por una barra buscadora reactiva en mostrador (búsqueda por número telefónico o nombre) y un modal con panel de confirmación de identidad por Fecha de Nacimiento (`🎂 DD/MM/AAAA`). | ✅ 100% |
| **Sub-Agente 4** | Clientes & Formulario POS | **Corrección Visual de Género ante Escalas de Fuente:** Se corrigió el desbordamiento (`RenderFlex overflowed`) al escalar la fuente al 115% o 130%. El selector de Sexo/Género ahora cuenta con `isExpanded: true`, truncamiento elíptico, fila independiente y contenedores `Wrap` en las tarjetas. | ✅ 100% |
| **Sub-Agente 5** | Clientes (Padrón y Alta POS) | **Separación en Apellido Paterno y Materno:** Desacoplamiento de apellidos con validación flexible: el primer apellido (paterno o principal) es obligatorio, mientras que el materno es opcional (para personas con un solo apellido o de origen extranjero). Sincronización automática con el apellido consolidado. | ✅ 100% |

---

## 2. Detalle de Modificaciones Técnicas

### Sub-Agente 1: Dosis / Concentración y Nuevos Catálogos
* **Frontend ([`inventario_screen.dart`](file:///C:/Developer/frontend/lib/screens/inventario_screen.dart)):**
  * Campo explícito: `Dosis / Concentración *` (`hintText: 'ej: 100mg, 250ml, 1UI, etc.'`).
  * Chips táctiles de llenado rápido: `100mg`, `250mg`, `500mg`, `1g`, `250ml`, `500ml`, `1UI`, `100UI`, `1 kit`, `1 pza`.
  * Catálogo de formas farmacéuticas ampliado con: *Dispositivo Médico*, *Material de Curación*, *Solución Rehidratante* y *Refresco / Bebida*.
* **Base de Datos ([`seed.py`](file:///C:/Developer/backend/seed.py)):**
  * 7 Dispositivos Médicos y Material de Curación sembrados:
    1. `750100000201` - Termómetro Digital Infrarrojo Clínico (Omron)
    2. `750100000202` - Oxímetro de Pulso Digital de Dedo (Contec)
    3. `750100000203` - Baumanómetro Digital de Brazo Automático (Citizen)
    4. `750100000204` - Glucómetro Accu-Chek Instant Kit (Roche)
    5. `750100000205` - Jeringas Desechables 5ml Aguja 21G (BD Plastipak)
    6. `750100000206` - Gasas Quirúrgicas Estériles 10x10cm (Le Roy)
    7. `750100000207` - Venda Elástica Quirúrgica 10cm x 5m (Protec)
  * 7 Productos Misceláneos y Bebidas sembrados:
    8. `750100000301` - Electrolit Suero Oral Rehidratante Fresa 625ml (Pisa)
    9. `750100000302` - Suerox Bebida Rehidratante Mora Azul 630ml (Genomma Lab)
    10. `750100000303` - Agua Purificada Ciel 1 Litro (Coca-Cola FEMSA)
    11. `750100000304` - Agua Mineral Peñafiel Manantial 600ml (Keurig Dr Pepper)
    12. `750100000305` - Refresco Coca-Cola Original 600ml PET
    13. `750100000306` - Refresco Sprite Lima-Limón 600ml PET
    14. `750100000307` - Refresco Manzana Lift 600ml PET

---

### Sub-Agente 2: Consulta IA con Validación Terapéutica Estricta
* **Backend ([`ia.py`](file:///C:/Developer/backend/app/routers/ia.py)):**
  * **Alineación terapéutica estricta:** Se eliminó el fallback de sugerir productos aleatorios con alto stock. La IA **únicamente** sugiere bioequivalentes directos o fármacos dentro de la **misma familia terapéutica** confirmada.
  * **Notificación de compra:** Cuando un medicamento y su familia carecen de stock físico en mostrador, responde:  
    `📦 Gestión de Abastecimiento: No contamos con existencias de este medicamento ni de sustitutos de la misma indicación terapéutica en este momento. Puede solicitarse la compra inmediata o pedido a almacén/proveedor para surtirlo.`
  * **Deslinde humano obligatorio:**  
    `⚠️ Aviso Sanitario: Esta respuesta tiene un propósito meramente orientativo basado en vademécum; no sustituye la búsqueda, evaluación clínica ni el criterio profesional de un humano calificado (médico o farmacéutico responsable).`

---

### Sub-Agente 3: Búsqueda y Confirmación de Clientes en Cobro (POS)
* **Frontend ([`pos_screen.dart`](file:///C:/Developer/frontend/lib/screens/pos_screen.dart)):**
  * En la barra lateral de cobro, se muestra una tarjeta que permite alternar con un clic entre *Público General* y un cliente registrado con descuento.
  * Botón *"Buscar (Tel)"* abre el modal `_abrirBuscadorYConfirmacionCliente()` con:
    * Campo de búsqueda con auto-focus que filtra instantáneamente por teléfono (`555-321-7890`), nombre o apellidos.
    * Panel de **Confirmación de Identidad por Fecha de Nacimiento** (`🎂 DD/MM/AAAA`) que le permite al cajero corroborar los datos del cliente antes de asignarlo, evitando confusiones con homónimos.

---

### Sub-Agente 4: Corrección Visual de Género ante Escalas de Fuente
* **Frontend ([`clientes_screen.dart`](file:///C:/Developer/frontend/lib/screens/clientes_screen.dart) / [`pos_screen.dart`](file:///C:/Developer/frontend/lib/screens/pos_screen.dart)):**
  * Se asignó `isExpanded: true` y `overflow: TextOverflow.ellipsis` en los `DropdownButtonFormField<String>` de género.
  * Se separaron el Sexo y la Fecha de Nacimiento en bloques independientes para evitar colisiones horizontales.
  * En la lista de clientes, los datos de contacto y badges se reorganizaron dentro de un `Wrap` adaptable para tolerar fuentes al 115% o 130% sin alertas de renderizado.

---

### Sub-Agente 5: Separación en Apellido Paterno y Materno
* **Base de Datos & Esquemas ([`models.py`](file:///C:/Developer/backend/app/models.py), [`schemas.py`](file:///C:/Developer/backend/app/schemas.py), [`database.py`](file:///C:/Developer/backend/app/database.py)):**
  * Nuevas columnas `apellido_paterno` y `apellido_materno` con migración no destructiva en SQLite.
  * Compatibilidad hacia atrás: el campo `apellido` se sincroniza automáticamente con `"$paterno $materno".trim()`.
* **Formularios de Captura:**
  * Dos campos independientes: `Apellido Paterno *` (obligatorio si tiene apellido) y `Apellido Materno` (opcional).
  * Soporte completo para personas con un solo apellido (extranjeros) y apellidos compuestos (ej: *del Toro*, *de la Cruz*).

---

## 3. Verificación y Pruebas Técnicas

1. **Pruebas Automatizadas de Backend (22/22 PASADAS):**
   * Ejecutadas con éxito en [`test_api.py`](file:///C:/Developer/backend/test_api.py):
     * *Test 20:* Alta de cliente con apellidos paterno y materno separados.
     * *Test 21:* Consulta IA con estricta clase terapéutica y deslinde humano.
     * *Test 22:* Verificación de grupos `DISPOSITIVO_MEDICO` y `MISCELANEO` en inventario.
2. **Análisis Estático Frontend (`flutter analyze`):**
   * **0 Errores.**
   * **0 Advertencias.**
3. **Control de Versiones:**
   * Commit: `e3f8610`
   * Tag: `v1.3.0`
   * Documentación: [`CHANGELOG.md`](file:///C:/Developer/CHANGELOG.md)
