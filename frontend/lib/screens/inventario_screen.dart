import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class InventarioScreen extends StatefulWidget {
  final int tabInicial;

  const InventarioScreen({super.key, this.tabInicial = 0});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _productos = [];
  List<dynamic> _kardex = [];
  List<dynamic> _lotesCaducidades = [];
  bool _isLoading = true;
  String? _error;
  bool _soloIrregulares = false;
  String _filtroCaducidad = 'TODOS';
  String _busquedaCaducidad = '';

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.tabInicial >= 0 && widget.tabInicial <= 2) ? widget.tabInicial : 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        ApiService.getProductos(),
        ApiService.getKardex(),
        ApiService.getLotesCaducidades(dias: 90),
      ]);
      if (mounted) {
        setState(() {
          _productos = futures[0];
          _kardex = futures[1];
          _lotesCaducidades = futures[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  bool get _usuarioTienePermisoInventario {
    final rol = AuthService.currentUser.rol.toUpperCase().trim();
    return rol == 'ADMINISTRADOR' || rol == 'RESPONSABLE_SANITARIO';
  }

  void _verificarPermisoOAlertar(VoidCallback accionPermitida) {
    if (_usuarioTienePermisoInventario) {
      accionPermitida();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.gpp_bad, color: Colors.red, size: 48),
          title: const Text('Acceso Restringido'),
          content: Text(
            'El usuario actual (${AuthService.currentUser.nombreCompleto}) tiene rol de CAJERO.\n\n'
            'Por políticas de seguridad y control interno, solo los roles de ADMINISTRADOR '
            'o RESPONSABLE SANITARIO están autorizados para ajustar piezas o dar de baja lotes en inventario.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Comprendido'),
            ),
          ],
        ),
      );
    }
  }

  void _dialogoAjustarPiezasLote(dynamic producto, dynamic lote) {
    _verificarPermisoOAlertar(() {
      final stockCtrl = TextEditingController(text: (lote['stock_actual'] ?? 0).toString());
      final motivoCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Ajustar Piezas - Lote ${lote["numero_lote"]}'),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Producto: ${producto["nombre_comercial"]} (${producto["sustancia_activa"]})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Caducidad: ${lote["fecha_caducidad"]} • Stock Actual: ${lote["stock_actual"]} pzas'),
                const SizedBox(height: 14),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo Stock Físico (Piezas) *',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del Ajuste de Inventario *',
                    hintText: 'Ej. Conteo físico, rotura accidental, aclaración...',
                    prefixIcon: Icon(Icons.comment),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
              onPressed: () async {
                final nuevoStock = int.tryParse(stockCtrl.text.trim());
                final motivo = motivoCtrl.text.trim();
                if (nuevoStock == null || nuevoStock < 0 || motivo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingrese un stock válido y el motivo del ajuste.')),
                  );
                  return;
                }

                try {
                  await ApiService.ajustarStockLote(
                    lote['id'],
                    nuevoStock: nuevoStock,
                    motivo: motivo,
                    usuario: AuthService.currentUser.nombreCompleto,
                    rolUsuario: AuthService.currentUser.rol,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _cargarTodo();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock del Lote ${lote["numero_lote"]} ajustado a $nuevoStock pzas.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Aplicar Ajuste'),
            ),
          ],
        ),
      );
    });
  }

  void _dialogoDarDeBajaLote(dynamic producto, dynamic lote) {
    _verificarPermisoOAlertar(() {
      final motivoCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.delete_forever, color: Colors.red, size: 44),
          title: Text('Dar de Baja Lote ${lote["numero_lote"]}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'ATENCIÓN: Esta acción dará de baja el lote completo, fijando su stock en cero y generando una salida inmutable de auditoría en el Kardex.',
                    style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Producto: ${producto["nombre_comercial"]}'),
                Text('Stock a liquidar: ${lote["stock_actual"]} piezas'),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Justificación / Motivo Sanitario de la Baja *',
                    hintText: 'Ej. Deterioro físico, sospecha de contaminación, caducado...',
                    prefixIcon: Icon(Icons.report_problem),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
              onPressed: () async {
                final motivo = motivoCtrl.text.trim();
                if (motivo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debe especificar el motivo de la baja.')),
                  );
                  return;
                }

                try {
                  await ApiService.darDeBajaLote(
                    lote['id'],
                    motivo: motivo,
                    usuario: AuthService.currentUser.nombreCompleto,
                    rolUsuario: AuthService.currentUser.rol,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _cargarTodo();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lote ${lote["numero_lote"]} dado de baja con éxito.'),
                        backgroundColor: Colors.red.shade800,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Confirmar Baja Definitiva'),
            ),
          ],
        ),
      );
    });
  }

  void _dialogoComentarKardex(dynamic movimiento) {
    final obsCtrl = TextEditingController(text: movimiento['observaciones_auditoria'] ?? '');
    bool esIrregular = movimiento['es_irregular'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.comment_bank, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Auditoría de Movimiento #${movimiento["id"]}'),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipo: ${movimiento["tipo_movimiento"]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Lote ID: ${movimiento["lote_id"]} • Cantidad: ${movimiento["cantidad"]} pzas'),
                        Text('Saldo: ${movimiento["stock_anterior"]} -> ${movimiento["stock_posterior"]} pzas'),
                        if (movimiento['motivo'] != null)
                          Text('Motivo original: ${movimiento["motivo"]}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    title: const Text(
                      'Marcar como irregular / fuera de lugar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Identifica posibles faltantes no justificados, inconsistencias o mermas dudosas.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: esIrregular,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setDialogState(() => esIrregular = val ?? false);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: obsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentarios / Observaciones de Auditoría *',
                      hintText: 'Describe qué anomalía se detectó en este movimiento...',
                      prefixIcon: Icon(Icons.rate_review),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar Auditoría'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
              onPressed: () async {
                final obs = obsCtrl.text.trim();
                if (obs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingrese una observación o justificación.')),
                  );
                  return;
                }

                try {
                  await ApiService.agregarObservacionKardex(
                    movimiento['id'],
                    observaciones: obs,
                    esIrregular: esIrregular,
                    usuarioAuditor: AuthService.currentUser.nombreCompleto,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _cargarTodo();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Observación de auditoría registrada en el Kardex.'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoNuevoLote() {
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
    final stockController = TextEditingController(text: '10');

    // Sub-Agente 6: Dosis separada de la dosificación (Forma | Cantidad | Unidad)
    String formaFarmaceutica = 'Tableta';
    final dosisValorController = TextEditingController(text: '100');
    final dosisUnidadController = TextEditingController(text: 'mg');

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
        builder: (context, setDialogState) {
          // Función para consultar código de barras
          Future<void> verificarCodigoBarras(String codigo) async {
            final codLimpio = codigo.trim();
            if (codLimpio.isEmpty) return;

            setDialogState(() {
              verificandoCodigo = true;
            });

            try {
              // 1. Buscar en lista local de productos
              final matchLocal = _productos.firstWhere(
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

          final String dosisVistaPrevia =
              '$formaFarmaceutica | ${dosisValorController.text.trim().isEmpty ? "100" : dosisValorController.text.trim()} | ${dosisUnidadController.text.trim().isEmpty ? "mg" : dosisUnidadController.text.trim()}';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.inventory, color: Colors.teal.shade800),
                const SizedBox(width: 8),
                const Text('Alta de Producto y Lote FEFO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sub-Agente 6: Verificación de Código de Barras previo para Autocompletado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. Identificación por Código de Barras:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
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
                                    fillColor: Colors.white,
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
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade400),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade800, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '✓ Código previamente registrado. Datos autocompletados desde catálogo.',
                                      style: TextStyle(color: Colors.green.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (codigoVerificado && !codigoPreviamenteRegistrado)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'ℹ Código nuevo no registrado. Capture el nombre y datos del fármaco manualmente.',
                                      style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
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
                            value: grupoFarmacopea,
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
                    const SizedBox(height: 14),

                    // Sub-Agente 6: DOSIS SEPARADA DE LA DOSIFICACIÓN (Forma | 100 | mg)
                    // Se eliminaron por completo los botones táctiles de concentración.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '3. Dosificación y Concentración Separadas:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade800,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dosisVistaPrevia,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                                  value: opcionesForma.contains(formaFarmaceutica) ? formaFarmaceutica : opcionesForma[0],
                                  decoration: const InputDecoration(
                                    labelText: 'Forma Farmacéutica *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
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
                                  decoration: const InputDecoration(
                                    labelText: 'Dosis (Valor) *',
                                    hintText: 'ej: 100, 250, 500',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
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
                                      decoration: const InputDecoration(
                                        labelText: 'Unidad *',
                                        hintText: 'ej: mg, ml, UI',
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                        isDense: true,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Captura manual requerida: Forma farmacéutica, cantidad y unidad se integran como "Forma | Dosis | Unidad".',
                            style: TextStyle(fontSize: 10, color: Colors.black54, fontStyle: FontStyle.italic),
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
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
                      'activo': true,
                    });

                    if (!mounted) return;
                    Navigator.of(ctx).pop();
                    _cargarTodo();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Lote $numLote registrado con éxito! Dosificación: $dosisVistaPrevia'),
                        backgroundColor: Colors.teal.shade800,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: Colors.teal.shade50,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.teal.shade900,
                  indicatorColor: Colors.teal.shade800,
                  indicatorWeight: 3,
                  tabs: [
                    const Tab(icon: Icon(Icons.inventory_2), text: 'Catálogo y Todos los Lotes'),
                    Tab(
                      icon: Badge(
                        isLabelVisible: _lotesCaducidades.isNotEmpty,
                        label: Text('${_lotesCaducidades.length}'),
                        backgroundColor: Colors.red.shade700,
                        child: const Icon(Icons.warning_amber_rounded),
                      ),
                      text: 'Lotes por Caducar (Alertas FEFO)',
                    ),
                    const Tab(icon: Icon(Icons.history_edu), text: 'Kardex y Auditoría de Movimientos'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
                  onPressed: _mostrarDialogoNuevoLote,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Lote'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaña 1: Catálogo y Lotes
                    _buildListaProductos(),
                    // Pestaña 2: Sub-Agente 1 - Lotes Próximos a Caducar Separados
                    _buildListaLotesPorCaducar(),
                    // Pestaña 3: Kardex Inmutable con Comentarios
                    _buildListaKardex(),
                  ],
                ),
    );
  }

  Widget _buildListaProductos() {
    if (_productos.isEmpty) {
      return const Center(child: Text('No hay productos en inventario'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productos.length,
      itemBuilder: (context, index) {
        final p = _productos[index];
        final int stockTotal = p['stock_total'] ?? 0;
        final bool requiereReceta = p['requiere_receta'] ?? false;
        final List<dynamic> lotes = p['lotes'] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: requiereReceta ? Colors.amber.shade100 : Colors.teal.shade100,
              child: Icon(
                requiereReceta ? Icons.receipt_long : Icons.medication_liquid,
                color: requiereReceta ? Colors.amber.shade900 : Colors.teal.shade900,
              ),
            ),
            title: Text(p['nombre_comercial'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${p["sustancia_activa"]}  •  ${p["presentacion"]}\nPrecio: \$${p["precio_venta"]} MXN'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stockTotal > 10 ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Stock: $stockTotal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: stockTotal > 10 ? Colors.green.shade900 : Colors.orange.shade900,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lotes en existencia (ordenados por fecha de caducidad para FEFO):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!_usuarioTienePermisoInventario)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: const Text(
                              'Solo Administrador puede ajustar piezas o dar de baja',
                              style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (lotes.isEmpty)
                      const Text('Sin lotes activos registrados.')
                    else
                      ...lotes.map((lote) {
                        final bool loteActivo = lote['activo'] ?? true;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: loteActivo ? Colors.grey.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: loteActivo ? Colors.grey.shade200 : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Lote: ${lote["numero_lote"]}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (!loteActivo)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'DADO DE BAJA',
                                            style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Caducidad: ${lote["fecha_caducidad"]} • Costo: \$${lote["costo_unitario"]}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                  ),
                                  if (lote["laboratorio_fabricante"] != null ||
                                      lote["forma_farmaceutica"] != null ||
                                      lote["dosificacion"] != null ||
                                      lote["fecha_ingreso"] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (lote["laboratorio_fabricante"] != null)
                                            _chipMetadatoLote(Icons.factory, lote["laboratorio_fabricante"], Colors.blueGrey),
                                          if (lote["forma_farmaceutica"] != null)
                                            _chipMetadatoLote(Icons.medication, lote["forma_farmaceutica"], Colors.indigo),
                                          if (lote["dosificacion"] != null)
                                            _chipMetadatoLote(Icons.scale, lote["dosificacion"], Colors.teal),
                                          if (lote["fecha_ingreso"] != null)
                                            _chipMetadatoLote(Icons.input, 'Ingreso: ${lote["fecha_ingreso"]}', Colors.brown),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '${lote["stock_actual"]} pzas',
                                style: TextStyle(
                                  color: loteActivo ? Colors.teal.shade800 : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Botones de acción administrativa (Sub-Agente 3)
                              IconButton(
                                icon: const Icon(Icons.tune, size: 20, color: Colors.teal),
                                tooltip: 'Ajustar piezas de lote',
                                onPressed: () => _dialogoAjustarPiezasLote(p, lote),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Dar de baja lote',
                                onPressed: loteActivo ? () => _dialogoDarDeBajaLote(p, lote) : null,
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // SUB-AGENTE 1: VISTA DE LOTES POR CADUCAR SEPARADOS EN INVENTARIO
  // =========================================================================
  Widget _buildListaLotesPorCaducar() {
    if (_lotesCaducidades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, color: Colors.green.shade600, size: 64),
            const SizedBox(height: 14),
            const Text(
              'No hay lotes con riesgo de caducidad en los próximos 90 días',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo el inventario activo cumple los márgenes de seguridad sanitaria de COFEPRIS.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
              onPressed: _cargarTodo,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar Análisis'),
            ),
          ],
        ),
      );
    }

    final lotesFiltrados = _lotesCaducidades.where((l) {
      if (_filtroCaducidad != 'TODOS') {
        if (l['urgencia'] != _filtroCaducidad) return false;
      }
      if (_busquedaCaducidad.isNotEmpty) {
        final q = _busquedaCaducidad.toLowerCase();
        final nom = (l['nombre_comercial'] ?? '').toString().toLowerCase();
        final sust = (l['sustancia_activa'] ?? '').toString().toLowerCase();
        final numL = (l['numero_lote'] ?? '').toString().toLowerCase();
        final lab = (l['laboratorio_fabricante'] ?? l['laboratorio_producto'] ?? '').toString().toLowerCase();
        if (!nom.contains(q) && !sust.contains(q) && !numL.contains(q) && !lab.contains(q)) return false;
      }
      return true;
    }).toList();

    final int criticos = _lotesCaducidades.where((l) => l['urgencia'] == 'CRITICA').length;
    final int preventivos = _lotesCaducidades.where((l) => l['urgencia'] == 'PREVENTIVA').length;
    final int caducados = _lotesCaducidades.where((l) => l['urgencia'] == 'CADUCADO').length;
    final int piezasRiesgo = _lotesCaducidades.fold<int>(0, (sum, l) => sum + (l['stock_actual'] as int? ?? 0));

    return Column(
      children: [
        // Banner Superior Informativo de Alertas FEFO
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: criticos > 0 ? Colors.red.shade50 : Colors.amber.shade50,
            border: Border(
              bottom: BorderSide(color: criticos > 0 ? Colors.red.shade200 : Colors.amber.shade200),
            ),
          ),
          child: Row(
            children: [
              Icon(
                criticos > 0 ? Icons.alarm_on : Icons.warning_amber_rounded,
                color: criticos > 0 ? Colors.red.shade900 : Colors.orange.shade900,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitoreo Sanitario de Caducidades (Prioridad FEFO)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: criticos > 0 ? Colors.red.shade900 : Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      '${_lotesCaducidades.length} lotes detectados ($piezasRiesgo piezas en anaquel). Surtir prioritariamente antes de caducar.',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _cargarTodo,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
            ],
          ),
        ),

        // Filtros y Búsqueda de Lotes por Caducar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Filtrar por medicamento, sustancia o lote...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _busquedaCaducidad.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _busquedaCaducidad = ''),
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _busquedaCaducidad = val.trim()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Todos (${_lotesCaducidades.length})'),
                      selected: _filtroCaducidad == 'TODOS',
                      onSelected: (_) => setState(() => _filtroCaducidad = 'TODOS'),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.alarm, color: Colors.red, size: 16),
                      label: Text('Críticos <= 30d ($criticos)'),
                      selected: _filtroCaducidad == 'CRITICA',
                      selectedColor: Colors.red.shade100,
                      onSelected: (_) => setState(() => _filtroCaducidad = 'CRITICA'),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.schedule, color: Colors.amber, size: 16),
                      label: Text('Preventivos ($preventivos)'),
                      selected: _filtroCaducidad == 'PREVENTIVA',
                      selectedColor: Colors.amber.shade100,
                      onSelected: (_) => setState(() => _filtroCaducidad = 'PREVENTIVA'),
                    ),
                    if (caducados > 0)
                      ChoiceChip(
                        avatar: const Icon(Icons.block, color: Colors.purple, size: 16),
                        label: Text('Caducados ($caducados)'),
                        selected: _filtroCaducidad == 'CADUCADO',
                        selectedColor: Colors.purple.shade100,
                        onSelected: (_) => setState(() => _filtroCaducidad = 'CADUCADO'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Listado de Tarjetas de Lotes Próximos a Vencer
        Expanded(
          child: lotesFiltrados.isEmpty
              ? const Center(child: Text('No hay lotes que coincidan con los filtros seleccionados.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lotesFiltrados.length,
                  itemBuilder: (context, index) {
                    final lote = lotesFiltrados[index];
                    return _buildTarjetaLoteCaducidad(lote);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTarjetaLoteCaducidad(dynamic lote) {
    final urgencia = lote['urgencia'] as String? ?? 'PREVENTIVA';
    final int dias = lote['dias_restantes'] as int? ?? 0;
    final int stock = lote['stock_actual'] as int? ?? 0;

    Color badgeBg;
    Color badgeFg;
    IconData badgeIcon;
    String badgeTexto;

    if (urgencia == 'CADUCADO' || dias < 0) {
      badgeBg = Colors.purple.shade50;
      badgeFg = Colors.purple.shade900;
      badgeIcon = Icons.block;
      badgeTexto = 'PRODUCTO CADUCADO (Hace ${dias.abs()} días)';
    } else if (urgencia == 'CRITICA' || dias <= 30) {
      badgeBg = Colors.red.shade50;
      badgeFg = Colors.red.shade900;
      badgeIcon = Icons.error_outline;
      badgeTexto = 'CRÍTICO: Vence en $dias días (Despachar Ya)';
    } else {
      badgeBg = Colors.amber.shade50;
      badgeFg = Colors.amber.shade900;
      badgeIcon = Icons.access_time;
      badgeTexto = 'PREVENTIVO: Vence en $dias días';
    }

    // Buscar el producto padre completo si está cargado
    final prodId = lote['producto_id'] as int?;
    final productoPadre = _productos.firstWhere(
      (p) => p['id'] == prodId,
      orElse: () => {
        'id': prodId,
        'nombre_comercial': lote['nombre_comercial'],
        'sustancia_activa': lote['sustancia_activa'],
        'presentacion': lote['presentacion'],
        'laboratorio': lote['laboratorio_producto'],
      },
    );

    final Map<String, dynamic> loteAdaptado = {
      'id': lote['lote_id'],
      'numero_lote': lote['numero_lote'],
      'fecha_caducidad': lote['fecha_caducidad'],
      'stock_actual': lote['stock_actual'],
      'costo_unitario': lote['costo_unitario'],
      'activo': true,
    };

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: urgencia == 'CRITICA' ? Colors.red.shade300 : Colors.grey.shade300,
          width: urgencia == 'CRITICA' ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Producto y Badge de Urgencia
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            lote['nombre_comercial'] ?? 'Medicamento',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${lote["grupo_farmacopea"] ?? "GRUPO_VI"}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lote["sustancia_activa"]} • ${lote["presentacion"]}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeFg.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeFg, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        badgeTexto,
                        style: TextStyle(color: badgeFg, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadatos del Lote (Sub-Agente 2)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chipMetadatoLote(Icons.qr_code, 'Lote: ${lote["numero_lote"]}', Colors.teal),
                _chipMetadatoLote(Icons.event_busy, 'Caduca: ${lote["fecha_caducidad"]}', Colors.red),
                if (lote['laboratorio_fabricante'] != null)
                  _chipMetadatoLote(Icons.factory, 'Lab: ${lote["laboratorio_fabricante"]}', Colors.blueGrey),
                if (lote['forma_farmaceutica'] != null)
                  _chipMetadatoLote(Icons.medication, 'Forma: ${lote["forma_farmaceutica"]}', Colors.indigo),
                if (lote['dosificacion'] != null)
                  _chipMetadatoLote(Icons.scale, 'Dosis: ${lote["dosificacion"]}', Colors.teal),
                if (lote['fecha_ingreso'] != null)
                  _chipMetadatoLote(Icons.input, 'Ingreso: ${lote["fecha_ingreso"]}', Colors.brown),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Existencias y Acciones de Control
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Existencia en anaquel:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      '$stock piezas disponibles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: stock > 0 ? Colors.teal.shade900 : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Precio al público:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      '\$${lote["precio_venta"]} MXN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Spacer(),

                // Botones de acción rápida autorizada
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Ajustar Stock'),
                  onPressed: () => _dialogoAjustarPiezasLote(productoPadre, loteAdaptado),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade800,
                  ),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Baja / Cuarentena'),
                  onPressed: () => _dialogoDarDeBajaLote(productoPadre, loteAdaptado),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipMetadatoLote(IconData icon, String texto, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.shade800),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 11, color: color.shade900, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildListaKardex() {
    final movimientos = _soloIrregulares
        ? _kardex.where((k) => k['es_irregular'] == true).toList()
        : _kardex;

    return Column(
      children: [
        // Barra de filtro para auditoría (Sub-Agente 5)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                'Total movimientos: ${_kardex.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('⚠️ Solo movimientos irregulares / fuera de lugar'),
                selected: _soloIrregulares,
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red.shade900,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _soloIrregulares ? FontWeight.bold : FontWeight.normal,
                  color: _soloIrregulares ? Colors.red.shade900 : Colors.black87,
                ),
                onSelected: (val) {
                  setState(() => _soloIrregulares = val);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: movimientos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
                      const SizedBox(height: 10),
                      Text(
                        _soloIrregulares
                            ? '¡Excelente! No hay movimientos marcados como irregulares.'
                            : 'No hay movimientos en el Kardex.',
                        style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: movimientos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final k = movimientos[index];
                    final bool esEntrada = (k['cantidad'] as int) > 0;
                    final bool esIrregular = k['es_irregular'] ?? false;
                    final String? obs = k['observaciones_auditoria'];
                    final String? auditor = k['usuario_auditor'];

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: esIrregular ? Colors.red.shade400 : Colors.transparent,
                          width: esIrregular ? 1.5 : 0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: esEntrada ? Colors.green.shade100 : Colors.blue.shade100,
                                  radius: 18,
                                  child: Icon(
                                    esEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: esEntrada ? Colors.green.shade900 : Colors.blue.shade900,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${k["tipo_movimiento"]} (Lote ID: ${k["lote_id"]})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (esIrregular) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                '⚠️ FUERA DE LUGAR',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${k["motivo"] ?? ""}\nSaldo: ${k["stock_anterior"]} -> ${k["stock_posterior"]} pzas',
                                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${esEntrada ? "+" : ""}${k["cantidad"]} pzas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: esEntrada ? Colors.green.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    obs != null ? Icons.comment : Icons.add_comment_outlined,
                                    color: esIrregular ? Colors.red : Colors.teal,
                                  ),
                                  tooltip: 'Agregar o editar observación de auditoría',
                                  onPressed: () => _dialogoComentarKardex(k),
                                ),
                              ],
                            ),
                            if (obs != null && obs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: esIrregular ? Colors.red.shade50 : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: esIrregular ? Colors.red.shade200 : Colors.teal.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 14,
                                      color: esIrregular ? Colors.red.shade900 : Colors.teal.shade900,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Comentario de auditoría: "$obs"${auditor != null ? " — por $auditor" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: esIrregular ? Colors.red.shade900 : Colors.teal.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
