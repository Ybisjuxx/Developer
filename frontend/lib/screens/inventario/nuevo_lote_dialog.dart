import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';

void mostrarDialogoNuevoLote(
  BuildContext context, {
  required List<dynamic> productos,
  required VoidCallback onSuccess,
}) {
  // Controladores de producto
  final codigoBarrasController = TextEditingController();
  final nombreComercialController = TextEditingController();
  final sustanciaActivaController = TextEditingController();
  final laboratorioController = TextEditingController();
  final precioVentaController = TextEditingController(text: '100.0');
  String grupoFarmacopea = 'GRUPO_VI';
  bool requiereReceta = false;

  // Estado de autocompletado por código de barras
  int? productoIdSeleccionado;
  bool codigoVerificado = false;
  bool codigoPreviamenteRegistrado = false;
  bool verificandoCodigo = false;

  // Controladores de Lote y Dosis separada
  final loteController = TextEditingController();
  final fechaCaducidadController = TextEditingController();
  final costoController = TextEditingController(text: '0.0');
  final proveedorController = TextEditingController(text: 'Distribuidor General');
  final piezasSolicitadasController = TextEditingController();
  final horasEntregaController = TextEditingController(text: '24');
  final stockController = TextEditingController(text: '10');

  // Sub-Agente 6: Dosis separada de la dosificación (Forma | Cantidad | Unidad)
  String formaFarmaceutica = 'Tableta';
  final dosisValorController = TextEditingController(text: '100');
  final dosisUnidadController = TextEditingController(text: 'mg');

  // Campos de descripción clínica para recomendación IA al cajero
  String familiaTerapeutica = 'OTRO';
  final indicacionController = TextEditingController();

  final hoy = DateTime.now();
  final fechaIngresoController = TextEditingController(
    text: "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}",
  );

  final List<String> opcionesForma = [
    'Tableta',
    'Cápsula',
    'Jarabe',
    'Suspensión Oral',
    'Solución Inyectable',
    'Gotas Oftálmicas',
    'Crema / Pomada',
    'Ungüento',
    'Gel',
    'Aerosol / Inhalador',
    'Parches Transdérmicos',
    'Polvo para Solución',
    'Dispositivo Médico',
    'Material de Curación',
    'Solución Rehidratante',
    'Refresco / Bebida',
  ];

  final List<String> unidadesComunes = ['mg', 'ml', 'g', 'mcg', 'UI', 'kit', 'pza', '%'];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) {
        // Función para consultar código de barras
        Future<void> verificarCodigoBarras(String codigo) async {
          final codLimpio = codigo.trim();
          if (codLimpio.isEmpty) return;

          setDialogState(() {
            verificandoCodigo = true;
          });

          try {
            // 1. Buscar en lista local de productos
            final matchLocal = productos.firstWhere(
              (p) => (p['codigo_barras'] ?? '').toString().trim() == codLimpio,
              orElse: () => null,
            );

            if (matchLocal != null) {
              setDialogState(() {
                productoIdSeleccionado = matchLocal['id'];
                nombreComercialController.text = matchLocal['nombre_comercial'] ?? '';
                sustanciaActivaController.text = matchLocal['sustancia_activa'] ?? '';
                laboratorioController.text = matchLocal['laboratorio'] ?? '';
                precioVentaController.text = (matchLocal['precio_venta'] ?? 0.0).toString();
                grupoFarmacopea = matchLocal['grupo_farmacopea'] ?? 'GRUPO_VI';
                requiereReceta = matchLocal['requiere_receta'] ?? false;
                familiaTerapeutica = matchLocal['familia_terapeutica'] ?? 'OTRO';
                indicacionController.text = matchLocal['indicacion_terapeutica'] ?? '';
                codigoPreviamenteRegistrado = true;
                codigoVerificado = true;
                verificandoCodigo = false;
              });
            } else {
              // 2. Consultar al backend
              final prodApi = await ApiService.buscarProductoPorCodigo(codLimpio);
              setDialogState(() {
                if (prodApi != null) {
                  productoIdSeleccionado = prodApi['id'];
                  nombreComercialController.text = prodApi['nombre_comercial'] ?? '';
                  sustanciaActivaController.text = prodApi['sustancia_activa'] ?? '';
                  laboratorioController.text = prodApi['laboratorio'] ?? '';
                  precioVentaController.text = (prodApi['precio_venta'] ?? 0.0).toString();
                  grupoFarmacopea = prodApi['grupo_farmacopea'] ?? 'GRUPO_VI';
                  requiereReceta = prodApi['requiere_receta'] ?? false;
                  familiaTerapeutica = prodApi['familia_terapeutica'] ?? 'OTRO';
                  indicacionController.text = prodApi['indicacion_terapeutica'] ?? '';
                  codigoPreviamenteRegistrado = true;
                } else {
                  productoIdSeleccionado = null;
                  codigoPreviamenteRegistrado = false;
                }
                codigoVerificado = true;
                verificandoCodigo = false;
              });
            }
          } catch (e) {
            setDialogState(() {
              productoIdSeleccionado = null;
              codigoPreviamenteRegistrado = false;
              codigoVerificado = true;
              verificandoCodigo = false;
            });
          }
        }

        final ts = ThemeService.instance;
        final String dosisVistaPrevia =
            '$formaFarmaceutica | ${dosisValorController.text.trim().isEmpty ? "100" : dosisValorController.text.trim()} | ${dosisUnidadController.text.trim().isEmpty ? "mg" : dosisUnidadController.text.trim()}';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.inventory, color: ts.accentPrimary),
              const SizedBox(width: 8),
              const Text('Alta de Producto y Lote FEFO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sub-Agente 6: Verificación de Código de Barras previo para Autocompletado
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ts.tintBg(ts.accentPrimary),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Identificación por Código de Barras:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: codigoBarrasController,
                                decoration: InputDecoration(
                                  labelText: 'Código de Barras *',
                                  hintText: 'Escanee o ingrese código (ej: 750100000001)',
                                  prefixIcon: const Icon(Icons.qr_code_scanner),
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: ts.surfaceBg,
                                  isDense: true,
                                  suffixIcon: verificandoCodigo
                                      ? const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                        )
                                      : null,
                                ),
                                onSubmitted: (val) => verificarCodigoBarras(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: verificandoCodigo
                                  ? null
                                  : () => verificarCodigoBarras(codigoBarrasController.text),
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('Verificar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (codigoVerificado && codigoPreviamenteRegistrado)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonGreen),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ts.neonGreen.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: ts.neonGreen, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '✓ Código previamente registrado. Datos autocompletados desde catálogo.',
                                    style: TextStyle(color: ts.neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (codigoVerificado && !codigoPreviamenteRegistrado)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonAmber),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ts.neonAmber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: ts.neonAmber, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'ℹ Código nuevo no registrado. Capture el nombre y datos del fármaco manualmente.',
                                    style: TextStyle(color: ts.neonAmber, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Datos del Medicamento / Producto (Captura Manual o Autocompletada)
                  const Text(
                    '2. Datos del Medicamento / Fármaco:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nombreComercialController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Medicamento / Fármaco / Producto *',
                      hintText: 'ej: Paracetamol 500mg, Amoxicilina, Electrolit Fresa',
                      prefixIcon: const Icon(Icons.medication_liquid),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: codigoPreviamenteRegistrado
                          ? 'Autocompletado con base en el código de barras registrado'
                          : 'Capture manualmente el nombre del producto',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sustanciaActivaController,
                          decoration: const InputDecoration(
                            labelText: 'Sustancia Activa / Fórmula *',
                            hintText: 'ej: Paracetamol, Amoxicilina',
                            prefixIcon: Icon(Icons.science),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: laboratorioController,
                          decoration: const InputDecoration(
                            labelText: 'Laboratorio Fabricante *',
                            hintText: 'ej: Liomont, Pisa, Bayer',
                            prefixIcon: Icon(Icons.factory),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: precioVentaController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Precio de Venta (MXN) *',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: grupoFarmacopea,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Grupo Farmacopea',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'GRUPO_IV', child: Text('Grupo IV (Antibióticos)')),
                            DropdownMenuItem(value: 'GRUPO_II', child: Text('Grupo II (Controlados)')),
                            DropdownMenuItem(value: 'GRUPO_III', child: Text('Grupo III (Psicotrópicos)')),
                            DropdownMenuItem(value: 'GRUPO_V', child: Text('Grupo V (Receta Médica)')),
                            DropdownMenuItem(value: 'GRUPO_VI', child: Text('Grupo VI (Venta Libre / OTC)')),
                            DropdownMenuItem(value: 'DISPOSITIVO_MEDICO', child: Text('Dispositivo Médico')),
                            DropdownMenuItem(value: 'MATERIAL_CURACION', child: Text('Material Curación')),
                            DropdownMenuItem(value: 'MISCELANEO', child: Text('Misceláneo / Bebida')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                grupoFarmacopea = val;
                                requiereReceta = (val == 'GRUPO_IV' || val == 'GRUPO_II' || val == 'GRUPO_III' || val == 'GRUPO_V');
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Campos para motor IA y guía al cajero en mostrador
                  DropdownButtonFormField<String>(
                    initialValue: familiaTerapeutica,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Familia Terapéutica (Clasificación IA)',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ANALGESICO_AINE', child: Text('Analgésicos y Antiinflamatorios (AINEs)')),
                      DropdownMenuItem(value: 'ANTIBIOTICO', child: Text('Antibióticos y Antimicrobianos')),
                      DropdownMenuItem(value: 'ANTIHISTAMINICO', child: Text('Antihistamínicos y Antialérgicos')),
                      DropdownMenuItem(value: 'ANTIACIDO_GASTRO', child: Text('Gastroprotectores y Antiácidos')),
                      DropdownMenuItem(value: 'ANTIHIPERTENSIVO', child: Text('Antihipertensivos y Cardiovasculares')),
                      DropdownMenuItem(value: 'HIPOGLUCEMIANTE', child: Text('Hipoglucemiantes (Antidiabéticos)')),
                      DropdownMenuItem(value: 'RESPIRATORIO', child: Text('Broncodilatadores y Antitusivos')),
                      DropdownMenuItem(value: 'ANTIESPASMODICO', child: Text('Antiespasmódicos y Digestivos')),
                      DropdownMenuItem(value: 'DERMATOLOGICO', child: Text('Dermatológicos y Antimicóticos')),
                      DropdownMenuItem(value: 'NEUROLOGICO', child: Text('Neurológicos y Dolor Neuropático')),
                      DropdownMenuItem(value: 'SUPLEMENTO', child: Text('Vitaminas y Suplementos')),
                      DropdownMenuItem(value: 'OFTALMICO', child: Text('Oftálmicos y Óticos')),
                      DropdownMenuItem(value: 'OTRO', child: Text('Otra Especialidad / Misceláneo')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => familiaTerapeutica = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: indicacionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Indicación Terapéutica / Descripción para IA y Cajero',
                      hintText: 'Ej: Alivia dolor neuropático, náuseas o infección en piel. La IA usará esto para recomendarlo.',
                      prefixIcon: Icon(Icons.smart_toy_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sub-Agente 6: DOSIS SEPARADA DE LA DOSIFICACIÓN (Forma | 100 | mg)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ts.tintBg(ts.accentSecondary),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '3. Dosificación y Concentración Separadas:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ts.accentPrimary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                dosisVistaPrevia,
                                style: TextStyle(
                                  color: ts.esTemaNeon ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Forma Farmacéutica
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: opcionesForma.contains(formaFarmaceutica) ? formaFarmaceutica : opcionesForma[0],
                                decoration: InputDecoration(
                                  labelText: 'Forma Farmacéutica *',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: ts.surfaceBg,
                                  isDense: true,
                                ),
                                items: opcionesForma
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => formaFarmaceutica = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dosis / Valor Numérico Manual
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: dosisValorController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: 'Dosis (Valor) *',
                                  hintText: 'ej: 100, 250, 500',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: ts.surfaceBg,
                                  isDense: true,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Unidad de Medida Manual
                            Expanded(
                              flex: 2,
                              child: Autocomplete<String>(
                                initialValue: TextEditingValue(text: dosisUnidadController.text),
                                optionsBuilder: (textVal) {
                                  if (textVal.text.isEmpty) return unidadesComunes;
                                  return unidadesComunes.where((u) => u.toLowerCase().contains(textVal.text.toLowerCase()));
                                },
                                onSelected: (val) {
                                  setDialogState(() => dosisUnidadController.text = val);
                                },
                                fieldViewBuilder: (ctx, textEditingCtrl, focusNode, onFieldSubmitted) {
                                  textEditingCtrl.addListener(() {
                                    dosisUnidadController.text = textEditingCtrl.text;
                                    setDialogState(() {});
                                  });
                                  return TextField(
                                    controller: textEditingCtrl,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Unidad *',
                                      hintText: 'ej: mg, ml, UI',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: ts.surfaceBg,
                                      isDense: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Captura manual requerida: Forma farmacéutica, cantidad y unidad se integran como "Forma | Dosis | Unidad".',
                          style: TextStyle(fontSize: 10, color: ts.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Metadatos de Lote y Trazabilidad FEFO
                  const Text(
                    '4. Datos del Lote de Inventario (FEFO):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: loteController,
                          decoration: const InputDecoration(
                            labelText: 'Número de Lote *',
                            hintText: 'ej: LOT-2026-X',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock Inicial (Pzas) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.format_list_numbered),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fechaIngresoController,
                          decoration: InputDecoration(
                            labelText: 'Fecha de Ingreso *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.input),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 18),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                );
                                if (date != null) {
                                  fechaIngresoController.text =
                                      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: fechaCaducidadController,
                          decoration: InputDecoration(
                            labelText: 'Fecha Caducidad *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.event_busy),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 18),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 180)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                );
                                if (date != null) {
                                  fechaCaducidadController.text =
                                      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: costoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo Unitario de Adquisición (MXN)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: proveedorController,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor / Distribuidor (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: piezasSolicitadasController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Piezas Solicitadas',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: horasEntregaController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Lead Time (hrs)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
              onPressed: () async {
                final cod = codigoBarrasController.text.trim();
                final nombre = nombreComercialController.text.trim();
                final numLote = loteController.text.trim();
                final fCad = fechaCaducidadController.text.trim();

                if (cod.isEmpty || nombre.isEmpty || numLote.isEmpty || fCad.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código de barras, nombre del producto, lote y caducidad son obligatorios')),
                  );
                  return;
                }

                try {
                  int prodId = productoIdSeleccionado ?? 0;

                  // Si el producto no estaba registrado previamente, lo damos de alta primero
                  if (!codigoPreviamenteRegistrado || prodId == 0) {
                    final nuevoProd = await ApiService.createProducto({
                      'codigo_barras': cod,
                      'nombre_comercial': nombre,
                      'sustancia_activa': sustanciaActivaController.text.trim().isEmpty
                          ? nombre
                          : sustanciaActivaController.text.trim(),
                      'presentacion': dosisVistaPrevia,
                      'laboratorio': laboratorioController.text.trim().isEmpty
                          ? 'Genérico'
                          : laboratorioController.text.trim(),
                      'grupo_farmacopea': grupoFarmacopea,
                      'requiere_receta': requiereReceta,
                      'precio_venta': double.tryParse(precioVentaController.text.trim()) ?? 100.0,
                      'familia_terapeutica': familiaTerapeutica,
                      'indicacion_terapeutica': indicacionController.text.trim().isEmpty
                          ? null
                          : indicacionController.text.trim(),
                      'activo': true,
                    });
                    prodId = nuevoProd['id'];
                  }

                  // Registrar el lote con dosis separada
                  await ApiService.createLote({
                    'producto_id': prodId,
                    'numero_lote': numLote,
                    'fecha_caducidad': fCad,
                    'stock_actual': int.tryParse(stockController.text.trim()) ?? 0,
                    'costo_unitario': double.tryParse(costoController.text.trim()) ?? 0.0,
                    'laboratorio_fabricante': laboratorioController.text.trim(),
                    'forma_farmaceutica': formaFarmaceutica,
                    'dosis_valor': dosisValorController.text.trim(),
                    'dosis_unidad': dosisUnidadController.text.trim(),
                    'dosificacion': dosisVistaPrevia,
                    'fecha_ingreso': fechaIngresoController.text.trim(),
                    'proveedor_nombre': proveedorController.text.trim().isEmpty
                        ? 'Distribuidor General'
                        : proveedorController.text.trim(),
                    if (int.tryParse(piezasSolicitadasController.text.trim()) != null)
                      'piezas_solicitadas': int.parse(piezasSolicitadasController.text.trim()),
                    'horas_entrega_lead_time': double.tryParse(horasEntregaController.text.trim()) ?? 24.0,
                    'activo': true,
                  });

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  onSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡Lote $numLote registrado con éxito! Dosificación: $dosisVistaPrevia'),
                      backgroundColor: ts.accentPrimary,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              label: const Text('Guardar Registro'),
            ),
          ],
        );
      },
    ),
  );
}
