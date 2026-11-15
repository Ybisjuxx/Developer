import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/lector_codigo_barras_dialog.dart';

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

  // Búsqueda y Categorización por Grupo Terapéutico COFEPRIS (Catálogo de Lotes)
  final TextEditingController _busquedaLotesController = TextEditingController();
  String _filtroGrupoLotes = 'TODOS';
  bool _soloConStockLotes = false;

  // Filtros de Kardex por Fecha, Búsqueda y Tipo de Movimiento
  final TextEditingController _busquedaKardexController = TextEditingController();
  DateTime? _fechaInicioKardex;
  DateTime? _fechaFinKardex;
  String _presetFechaKardex = 'TODAS'; // 'TODAS', 'HOY', '7DIAS', 'MES', 'PERSONALIZADO'
  String _filtroTipoKardex = 'TODOS'; // 'TODOS', 'ENTRADAS', 'SALIDAS', 'AJUSTES'

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
    _busquedaLotesController.dispose();
    _busquedaKardexController.dispose();
    super.dispose();
  }

  // Escaneo óptico de medicamento para búsqueda inmediata en almacén
  Future<void> _escanearCodigoParaInventario() async {
    final cod = await LectorCodigoBarrasDialog.escanear(
      context,
      titulo: 'Escanear Medicamento para Inventario',
    );
    if (cod != null && cod.trim().isNotEmpty) {
      setState(() {
        _busquedaLotesController.text = cod.trim();
      });
    }
  }

  // Filtrado reactivo del catálogo de lotes por texto y grupo terapéutico COFEPRIS
  List<dynamic> get _productosFiltrados {
    final query = _busquedaLotesController.text.trim().toLowerCase();

    return _productos.where((p) {
      // 1. Filtro por disponibilidad de stock
      final int stock = p['stock_total'] ?? 0;
      if (_soloConStockLotes && stock <= 0) {
        return false;
      }

      // 2. Filtro por Grupo Farmacopea / Terapéutico COFEPRIS (similar al mostrador POS)
      if (_filtroGrupoLotes != 'TODOS') {
        final grupo = (p['grupo_farmacopea'] ?? 'GRUPO_VI').toString().toUpperCase();
        if (_filtroGrupoLotes == 'CONTROLADOS') {
          if (!grupo.contains('GRUPO_I') && !grupo.contains('GRUPO_II') && !grupo.contains('GRUPO_III') && !grupo.contains('CONTROLADO')) {
            return false;
          }
        } else if (_filtroGrupoLotes == 'GRUPO_IV') {
          if (!grupo.contains('GRUPO_IV') && !grupo.contains('ANTIBIOTICO')) {
            return false;
          }
        } else if (_filtroGrupoLotes == 'GRUPO_V') {
          if (!grupo.contains('GRUPO_V') && !grupo.contains('CRONICO')) {
            return false;
          }
        } else if (_filtroGrupoLotes == 'GRUPO_VI') {
          if (!grupo.contains('GRUPO_VI') && !grupo.contains('LIBRE')) {
            return false;
          }
        } else if (grupo != _filtroGrupoLotes) {
          return false;
        }
      }

      // 3. Filtro por Búsqueda (Nombre Comercial, Sustancia Activa, Presentación, Laboratorio, Código o Lote)
      if (query.isNotEmpty) {
        final nom = (p['nombre_comercial'] ?? '').toString().toLowerCase();
        final sus = (p['sustancia_activa'] ?? '').toString().toLowerCase();
        final pre = (p['presentacion'] ?? '').toString().toLowerCase();
        final lab = (p['laboratorio'] ?? '').toString().toLowerCase();
        final cod = (p['codigo_barras'] ?? '').toString().toLowerCase();

        final lotes = (p['lotes'] as List<dynamic>? ?? []);
        final coincideLote = lotes.any((l) =>
            (l['numero_lote'] ?? '').toString().toLowerCase().contains(query) ||
            (l['laboratorio_fabricante'] ?? '').toString().toLowerCase().contains(query));

        if (!nom.contains(query) &&
            !sus.contains(query) &&
            !pre.contains(query) &&
            !lab.contains(query) &&
            !cod.contains(query) &&
            !coincideLote) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Escaneo óptico de medicamento para búsqueda inmediata en Kardex
  Future<void> _escanearCodigoParaKardex() async {
    final cod = await LectorCodigoBarrasDialog.escanear(
      context,
      titulo: 'Escanear Medicamento para Kardex',
    );
    if (cod != null && cod.trim().isNotEmpty) {
      final limpio = cod.trim().toLowerCase();
      String texto = limpio;
      for (final p in _productos) {
        if ((p['codigo_barras'] ?? '').toString().toLowerCase() == limpio) {
          texto = p['nombre_comercial'] ?? limpio;
          break;
        }
      }
      setState(() {
        _busquedaKardexController.text = texto;
      });
    }
  }

  void _aplicarPresetKardex(String preset) {
    final now = DateTime.now();
    setState(() {
      _presetFechaKardex = preset;
      if (preset == 'HOY') {
        _fechaInicioKardex = DateTime(now.year, now.month, now.day);
        _fechaFinKardex = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == '7DIAS') {
        final start = now.subtract(const Duration(days: 7));
        _fechaInicioKardex = DateTime(start.year, start.month, start.day);
        _fechaFinKardex = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == 'MES') {
        _fechaInicioKardex = DateTime(now.year, now.month, 1);
        _fechaFinKardex = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else {
        _fechaInicioKardex = null;
        _fechaFinKardex = null;
      }
    });
  }

  Future<void> _abrirSelectorRangoFechasKardex() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_fechaInicioKardex != null && _fechaFinKardex != null)
          ? DateTimeRange(start: _fechaInicioKardex!, end: _fechaFinKardex!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      helpText: 'Seleccionar período para Kardex',
      saveText: 'Aplicar Período',
    );

    if (picked != null) {
      setState(() {
        _fechaInicioKardex = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _fechaFinKardex = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _presetFechaKardex = 'PERSONALIZADO';
      });
    }
  }

  // Mapa de resolución rápida de Lote ID -> Nombre de Producto y Número de Lote
  Map<int, Map<String, String>> get _loteInfoMap {
    final map = <int, Map<String, String>>{};
    for (final p in _productos) {
      final String prodNombre = p['nombre_comercial'] ?? 'Medicamento';
      final String lab = p['laboratorio'] ?? '';
      final lotes = (p['lotes'] as List<dynamic>? ?? []);
      for (final l in lotes) {
        final int? loteId = l['id'] is int ? l['id'] : int.tryParse(l['id']?.toString() ?? '');
        if (loteId != null) {
          map[loteId] = {
            'producto': prodNombre,
            'numero_lote': (l['numero_lote'] ?? '').toString(),
            'laboratorio': lab,
          };
        }
      }
    }
    return map;
  }

  // Filtrado reactivo de movimientos de Kardex por fecha, búsqueda y tipo
  List<dynamic> get _kardexFiltrado {
    final query = _busquedaKardexController.text.trim().toLowerCase();
    final infoMap = _loteInfoMap;

    return _kardex.where((k) {
      // 1. Filtro por irregularidades
      if (_soloIrregulares && (k['es_irregular'] != true)) {
        return false;
      }

      // 2. Filtro por tipo de movimiento
      if (_filtroTipoKardex != 'TODOS') {
        final int stockAnt = (k['stock_anterior'] as num?)?.toInt() ?? 0;
        final int stockPost = (k['stock_posterior'] as num?)?.toInt() ?? 0;
        final String tipo = (k['tipo_movimiento'] ?? '').toString().toUpperCase();
        final int rawCant = (k['cantidad'] as num?)?.toInt() ?? 0;
        final bool esEntrada = tipo.contains('ENTRADA') || (stockPost > stockAnt) || (rawCant > 0 && !tipo.contains('SALIDA') && !tipo.contains('BAJA'));

        if (_filtroTipoKardex == 'ENTRADAS' && !esEntrada) {
          return false;
        } else if (_filtroTipoKardex == 'SALIDAS' && (esEntrada || tipo.contains('AJUSTE'))) {
          return false;
        } else if (_filtroTipoKardex == 'AJUSTES' && !tipo.contains('AJUSTE') && !tipo.contains('BAJA')) {
          return false;
        }
      }

      // 3. Filtro por Rango de Fechas
      if (_fechaInicioKardex != null || _fechaFinKardex != null) {
        final rawFecha = k['created_at']?.toString() ?? '';
        final parsed = DateTime.tryParse(rawFecha);
        if (parsed != null) {
          if (_fechaInicioKardex != null && parsed.isBefore(_fechaInicioKardex!)) return false;
          if (_fechaFinKardex != null && parsed.isAfter(_fechaFinKardex!)) return false;
        }
      }

      // 4. Búsqueda por texto libre
      if (query.isNotEmpty) {
        final loteId = k['lote_id'];
        final int? idNum = loteId is int ? loteId : int.tryParse(loteId?.toString() ?? '');
        final loteData = idNum != null ? infoMap[idNum] : null;

        final prodNombre = (loteData?['producto'] ?? '').toLowerCase();
        final numLote = (loteData?['numero_lote'] ?? '').toLowerCase();
        final lab = (loteData?['laboratorio'] ?? '').toLowerCase();

        final tipo = (k['tipo_movimiento'] ?? '').toString().toLowerCase();
        final loteIdStr = (loteId ?? '').toString().toLowerCase();
        final refTipo = (k['referencia_tipo'] ?? '').toString().toLowerCase();
        final refId = (k['referencia_id'] ?? '').toString().toLowerCase();
        final motivo = (k['motivo'] ?? '').toString().toLowerCase();
        final obs = (k['observaciones_auditoria'] ?? '').toString().toLowerCase();
        final auditor = (k['usuario_auditor'] ?? '').toString().toLowerCase();

        if (!prodNombre.contains(query) &&
            !numLote.contains(query) &&
            !lab.contains(query) &&
            !tipo.contains(query) &&
            !loteIdStr.contains(query) &&
            !refTipo.contains(query) &&
            !refId.contains(query) &&
            !motivo.contains(query) &&
            !obs.contains(query) &&
            !auditor.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatoFechaKardex(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString();
    final dt = DateTime.tryParse(str);
    if (dt != null) {
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min';
    }
    return str.length >= 16 ? str.substring(0, 16).replaceAll('T', ' ') : str;
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
      final ts = ThemeService.instance;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.gpp_bad, color: ts.neonRed, size: 48),
          title: const Text('Acceso Restringido'),
          content: Text(
            'El usuario actual (${AuthService.currentUser.nombreCompleto}) tiene rol de CAJERO.\n\n'
            'Por políticas de seguridad y control interno, solo los roles de ADMINISTRADOR '
            'o RESPONSABLE SANITARIO están autorizados para ajustar piezas o dar de baja lotes en inventario.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
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
      final ts = ThemeService.instance;
      final stockCtrl = TextEditingController(text: (lote['stock_actual'] ?? 0).toString());
      final motivoCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_note, color: ts.accentPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Ajustar Piezas - Lote ${lote["numero_lote"]}'),
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 440),
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
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
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
                        backgroundColor: ts.neonGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
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
      final ts = ThemeService.instance;
      final motivoCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.delete_forever, color: ts.neonRed, size: 44),
          title: Text('Dar de Baja Lote ${lote["numero_lote"]}'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ts.tintBg(ts.neonRed),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ts.neonRed.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'ATENCIÓN: Esta acción dará de baja el lote completo, fijando su stock en cero y generando una salida inmutable de auditoría en el Kardex.',
                    style: TextStyle(fontSize: 12, color: ts.neonRed, fontWeight: FontWeight.bold),
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
              style: FilledButton.styleFrom(
                backgroundColor: ts.neonRed,
                foregroundColor: Colors.white,
              ),
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
                        backgroundColor: ts.neonRed,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
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
    final ts = ThemeService.instance;
    final obsCtrl = TextEditingController(text: movimiento['observaciones_auditoria'] ?? '');
    bool esIrregular = movimiento['es_irregular'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.comment_bank, color: ts.accentPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Auditoría de Movimiento #${movimiento["id"]}'),
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ts.surfaceAltBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipo: ${movimiento["tipo_movimiento"]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Lote ID: ${movimiento["lote_id"]} • Cantidad: ${movimiento["cantidad"]} pzas'),
                        Text('Saldo: ${movimiento["stock_anterior"]} -> ${movimiento["stock_posterior"]} pzas'),
                        if (movimiento['motivo'] != null)
                          Text('Motivo original: ${movimiento["motivo"]}', style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    title: Text(
                      'Marcar como irregular / fuera de lugar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.neonRed),
                    ),
                    subtitle: Text(
                      'Identifica posibles faltantes no justificados, inconsistencias o mermas dudosas.',
                      style: TextStyle(fontSize: 11, color: ts.textSecondary),
                    ),
                    value: esIrregular,
                    activeColor: ts.neonRed,
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
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
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
                      SnackBar(
                        content: const Text('Observación de auditoría registrada en el Kardex.'),
                        backgroundColor: ts.accentPrimary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
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
                    // Se eliminaron por completo los botones táctiles de concentración.
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
                      'activo': true,
                    });

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    _cargarTodo();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Lote $numLote registrado con éxito! Dosificación: $dosisVistaPrevia'),
                        backgroundColor: ts.accentPrimary,
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
    final ts = ThemeService.instance;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 800;

        return Scaffold(
          backgroundColor: ts.scaffoldBg,
          floatingActionButton: isMobile
              ? FloatingActionButton.extended(
                  onPressed: _mostrarDialogoNuevoLote,
                  backgroundColor: ts.accentPrimary,
                  foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Lote'),
                )
              : null,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              decoration: BoxDecoration(
                gradient: ts.heroBannerGradient,
                border: Border(
                  bottom: BorderSide(
                    color: ts.esTemaNeon ? ts.accentPrimary.withValues(alpha: 0.45) : ts.borderColor,
                    width: 1.2,
                  ),
                ),
                boxShadow: ts.cardGlowShadow,
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                        unselectedLabelColor: ts.esTemaNeon ? ts.textSecondary : Colors.white.withValues(alpha: 0.75),
                        indicatorColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.inventory_2),
                            text: isMobile ? 'Catálogo y Lotes' : 'Catálogo y Todos los Lotes',
                          ),
                          Tab(
                            icon: Badge(
                              isLabelVisible: _lotesCaducidades.isNotEmpty,
                              label: Text('${_lotesCaducidades.length}'),
                              backgroundColor: ts.neonRed,
                              child: const Icon(Icons.warning_amber_rounded),
                            ),
                            text: isMobile ? 'Alertas FEFO' : 'Lotes por Caducar (Alertas FEFO)',
                          ),
                          Tab(
                            icon: const Icon(Icons.history_edu),
                            text: isMobile ? 'Kardex' : 'Kardex y Auditoría de Movimientos',
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                            foregroundColor: ts.esTemaNeon ? Colors.black : ts.accentPrimary,
                          ),
                          onPressed: _mostrarDialogoNuevoLote,
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar Lote', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error', style: TextStyle(color: ts.neonRed)))
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
      },
    );
  }

  Widget _buildListaProductos() {
    final ts = ThemeService.instance;
    final productosVisibles = _productosFiltrados;

    return Column(
      children: [
        // Barra de Búsqueda y Clasificación por Grupo Terapéutico COFEPRIS HeroUI
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ts.surfaceBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ts.borderColor, width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de Búsqueda con Cámara y Botón Limpiar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _busquedaLotesController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por medicamento, sustancia, lote o escanea código...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: ts.cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ts.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ts.borderColor),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_busquedaLotesController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _busquedaLotesController.clear();
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.camera_alt, color: ts.accentPrimary),
                                tooltip: 'Escanear código de barras con la cámara',
                                onPressed: _escanearCodigoParaInventario,
                              ),
                            ],
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Chips de Clasificación Sanitaria COFEPRIS (similar al mostrador POS)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Todos (${_productos.length})'),
                        selected: _filtroGrupoLotes == 'TODOS',
                        selectedColor: ts.tintBg(ts.accentPrimary),
                        onSelected: (_) => setState(() => _filtroGrupoLotes = 'TODOS'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Venta Libre (Grupo VI)'),
                        selected: _filtroGrupoLotes == 'GRUPO_VI',
                        selectedColor: ts.tintBg(ts.accentPrimary),
                        onSelected: (_) => setState(() => _filtroGrupoLotes = 'GRUPO_VI'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Antibióticos (Grupo IV)'),
                        selected: _filtroGrupoLotes == 'GRUPO_IV',
                        selectedColor: ts.tintBg(ts.neonAmber),
                        onSelected: (_) => setState(() => _filtroGrupoLotes = 'GRUPO_IV'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Controlados (Grupo I-III)'),
                        selected: _filtroGrupoLotes == 'CONTROLADOS',
                        selectedColor: ts.tintBg(ts.neonRed),
                        onSelected: (_) => setState(() => _filtroGrupoLotes = 'CONTROLADOS'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Crónicos (Grupo V)'),
                        selected: _filtroGrupoLotes == 'GRUPO_V',
                        selectedColor: ts.tintBg(ts.neonPurple),
                        onSelected: (_) => setState(() => _filtroGrupoLotes = 'GRUPO_V'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Solo con Stock'),
                        selected: _soloConStockLotes,
                        selectedColor: ts.tintBg(ts.neonGreen),
                        onSelected: (val) => setState(() => _soloConStockLotes = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Listado de Medicamentos con sus Lotes
        Expanded(
          child: productosVisibles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 54, color: ts.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron medicamentos ni lotes para "${_busquedaLotesController.text.trim()}"',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Prueba buscando por nombre comercial, sustancia activa o número de lote.',
                        style: TextStyle(color: ts.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonal(
                        onPressed: () {
                          _busquedaLotesController.clear();
                          setState(() {
                            _filtroGrupoLotes = 'TODOS';
                            _soloConStockLotes = false;
                          });
                        },
                        child: const Text('Limpiar Filtros y Ver Todos'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productosVisibles.length,
                  itemBuilder: (context, index) {
                    final p = productosVisibles[index];
                    final int stockTotal = p['stock_total'] ?? 0;
                    final bool requiereReceta = p['requiere_receta'] ?? false;
                    final String familiaTerap = (p['familia_terapeutica'] ?? '').toString().trim();
                    final String indicacionTerap = (p['indicacion_terapeutica'] ?? '').toString().trim();
                    final List<dynamic> lotes = p['lotes'] ?? [];
                    final Color roleColor = requiereReceta ? ts.neonAmber : ts.accentPrimary;
                    final Color stockColor = stockTotal > 10 ? ts.neonGreen : ts.neonAmber;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: ts.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ts.borderColor, width: 1.2),
                        boxShadow: ts.cardGlowShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: ts.tintBg(roleColor),
                          child: Icon(
                            requiereReceta ? Icons.receipt_long : Icons.medication_liquid,
                            color: roleColor,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p['nombre_comercial'] ?? '',
                                style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary),
                              ),
                            ),
                            if (familiaTerap.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ts.tintBg(ts.neonPurple),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  familiaTerap,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: ts.neonPurple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ts.tintBg(roleColor),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p['grupo_farmacopea'] ?? 'GRUPO_VI',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p["sustancia_activa"]}  •  ${p["presentacion"]}\nPrecio: \$${p["precio_venta"]} MXN  •  ${lotes.length} ${lotes.length == 1 ? "lote registrado" : "lotes registrados"}',
                              style: TextStyle(color: ts.textSecondary),
                            ),
                            if (indicacionTerap.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'IA / Indicación: $indicacionTerap',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: ts.neonBlue, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ts.tintBg(stockColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Stock: $stockTotal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: stockColor,
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Lotes en existencia (Prioridad FEFO):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!_usuarioTienePermisoInventario)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonAmber),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ts.neonAmber.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Solo Administrador puede ajustar piezas o dar de baja',
                              style: TextStyle(fontSize: 10, color: ts.neonAmber, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (lotes.isEmpty)
                      Text('Sin lotes activos registrados.', style: TextStyle(color: ts.textSecondary))
                    else
                      ...lotes.map((lote) {
                        final bool loteActivo = lote['activo'] ?? true;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: loteActivo ? ts.surfaceBg : ts.tintBg(ts.neonRed),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: loteActivo ? ts.borderColor : ts.neonRed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, lConstraints) {
                              final bool isNarrow = lConstraints.maxWidth < 500;
                              final infoContent = Column(
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
                                            color: ts.neonRed,
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
                                    style: TextStyle(fontSize: 11, color: ts.textSecondary),
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
                                            _chipMetadatoLote(Icons.factory, lote["laboratorio_fabricante"], ts.neonBlue),
                                          if (lote["forma_farmaceutica"] != null)
                                            _chipMetadatoLote(Icons.medication, lote["forma_farmaceutica"], ts.neonPurple),
                                          if (lote["dosificacion"] != null)
                                            _chipMetadatoLote(Icons.scale, lote["dosificacion"], ts.accentPrimary),
                                          if (lote["fecha_ingreso"] != null)
                                            _chipMetadatoLote(Icons.input, 'Ingreso: ${lote["fecha_ingreso"]}', ts.neonAmber),
                                        ],
                                      ),
                                    ),
                                ],
                              );

                              final actionsContent = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${lote["stock_actual"]} pzas',
                                    style: TextStyle(
                                      color: loteActivo ? ts.neonGreen : ts.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.tune, size: 20, color: ts.accentPrimary),
                                    tooltip: 'Ajustar piezas de lote',
                                    onPressed: () => _dialogoAjustarPiezasLote(p, lote),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: ts.neonRed),
                                    tooltip: 'Dar de baja lote',
                                    onPressed: loteActivo ? () => _dialogoDarDeBajaLote(p, lote) : null,
                                  ),
                                ],
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    infoContent,
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: actionsContent,
                                    ),
                                  ],
                                );
                              } else {
                                return Row(
                                  children: [
                                    Expanded(child: infoContent),
                                    const SizedBox(width: 12),
                                    actionsContent,
                                  ],
                                );
                              }
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
  ),
),
      ],
    );
  }

  // =========================================================================
  // SUB-AGENTE 1: VISTA DE LOTES POR CADUCAR SEPARADOS EN INVENTARIO
  // =========================================================================
  Widget _buildListaLotesPorCaducar() {
    final ts = ThemeService.instance;
    if (_lotesCaducidades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, color: ts.neonGreen, size: 64),
            const SizedBox(height: 14),
            const Text(
              'No hay lotes con riesgo de caducidad en los próximos 90 días',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo el inventario activo cumple los márgenes de seguridad sanitaria de COFEPRIS.',
              style: TextStyle(color: ts.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
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

    final Color bannerColor = criticos > 0 ? ts.neonRed : ts.neonAmber;

    return Column(
      children: [
        // Banner Superior Informativo de Alertas FEFO HeroUI
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ts.tintBg(bannerColor),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bannerColor.withValues(alpha: 0.4), width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: LayoutBuilder(
              builder: (context, bConstraints) {
                final isNarrow = bConstraints.maxWidth < 650;
                final iconAndText = Row(
                  children: [
                    Icon(
                      criticos > 0 ? Icons.alarm_on : Icons.warning_amber_rounded,
                      color: bannerColor,
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
                              color: bannerColor,
                            ),
                          ),
                          Text(
                            '${_lotesCaducidades.length} lotes detectados ($piezasRiesgo piezas en anaquel). Surtir prioritariamente antes de caducar.',
                            style: TextStyle(fontSize: 12, color: ts.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final refreshBtn = FilledButton.tonalIcon(
                  onPressed: _cargarTodo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      iconAndText,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: refreshBtn),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: iconAndText),
                      const SizedBox(width: 12),
                      refreshBtn,
                    ],
                  );
                }
              },
            ),
          ),
        ),

        // Filtros y Búsqueda de Lotes por Caducar HeroUI
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ts.surfaceBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ts.borderColor, width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: LayoutBuilder(
            builder: (context, fConstraints) {
              final isNarrow = fConstraints.maxWidth < 650;
              final searchField = TextField(
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
              );

              final chips = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Todos (${_lotesCaducidades.length})'),
                      selected: _filtroCaducidad == 'TODOS',
                      selectedColor: ts.tintBg(ts.accentPrimary),
                      onSelected: (_) => setState(() => _filtroCaducidad = 'TODOS'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: Icon(Icons.alarm, color: ts.neonRed, size: 16),
                      label: Text('Críticos <= 30d ($criticos)'),
                      selected: _filtroCaducidad == 'CRITICA',
                      selectedColor: ts.tintBg(ts.neonRed),
                      onSelected: (_) => setState(() => _filtroCaducidad = 'CRITICA'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: Icon(Icons.schedule, color: ts.neonAmber, size: 16),
                      label: Text('Preventivos ($preventivos)'),
                      selected: _filtroCaducidad == 'PREVENTIVA',
                      selectedColor: ts.tintBg(ts.neonAmber),
                      onSelected: (_) => setState(() => _filtroCaducidad = 'PREVENTIVA'),
                    ),
                    if (caducados > 0) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(Icons.block, color: ts.neonPurple, size: 16),
                        label: Text('Caducados ($caducados)'),
                        selected: _filtroCaducidad == 'CADUCADO',
                        selectedColor: ts.tintBg(ts.neonPurple),
                        onSelected: (_) => setState(() => _filtroCaducidad = 'CADUCADO'),
                      ),
                    ],
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    chips,
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(flex: 4, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: chips),
                  ],
                );
              }
            },
          ),
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
    final ts = ThemeService.instance;
    final urgencia = lote['urgencia'] as String? ?? 'PREVENTIVA';
    final int dias = lote['dias_restantes'] as int? ?? 0;
    final int stock = lote['stock_actual'] as int? ?? 0;

    Color badgeBg;
    Color badgeFg;
    IconData badgeIcon;
    String badgeTexto;

    if (urgencia == 'CADUCADO' || dias < 0) {
      badgeBg = ts.tintBg(ts.neonPurple);
      badgeFg = ts.neonPurple;
      badgeIcon = Icons.block;
      badgeTexto = 'PRODUCTO CADUCADO (Hace ${dias.abs()} días)';
    } else if (urgencia == 'CRITICA' || dias <= 30) {
      badgeBg = ts.tintBg(ts.neonRed);
      badgeFg = ts.neonRed;
      badgeIcon = Icons.error_outline;
      badgeTexto = 'CRÍTICO: Vence en $dias días (Despachar Ya)';
    } else {
      badgeBg = ts.tintBg(ts.neonAmber);
      badgeFg = ts.neonAmber;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgencia == 'CRITICA' ? ts.neonRed : ts.borderColor,
          width: urgencia == 'CRITICA' ? 1.6 : 1.2,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Producto y Badge de Urgencia
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lote['nombre_comercial'] ?? 'Medicamento',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ts.surfaceAltBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ts.borderColor),
                          ),
                          child: Text(
                            '${lote["grupo_farmacopea"] ?? "GRUPO_VI"}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lote["sustancia_activa"]} • ${lote["presentacion"]}',
                      style: TextStyle(color: ts.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeFg.withValues(alpha: 0.35)),
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
                _chipMetadatoLote(Icons.qr_code, 'Lote: ${lote["numero_lote"]}', ts.accentPrimary),
                _chipMetadatoLote(Icons.event_busy, 'Caduca: ${lote["fecha_caducidad"]}', ts.neonRed),
                if (lote['laboratorio_fabricante'] != null)
                  _chipMetadatoLote(Icons.factory, 'Lab: ${lote["laboratorio_fabricante"]}', ts.neonBlue),
                if (lote['forma_farmaceutica'] != null)
                  _chipMetadatoLote(Icons.medication, 'Forma: ${lote["forma_farmaceutica"]}', ts.neonPurple),
                if (lote['dosificacion'] != null)
                  _chipMetadatoLote(Icons.scale, 'Dosis: ${lote["dosificacion"]}', ts.accentPrimary),
                if (lote['fecha_ingreso'] != null)
                  _chipMetadatoLote(Icons.input, 'Ingreso: ${lote["fecha_ingreso"]}', ts.neonAmber),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Existencias y Acciones de Control
            LayoutBuilder(
              builder: (context, cConstraints) {
                final bool isNarrow = cConstraints.maxWidth < 650;
                final infoRow = Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Existencia en anaquel:', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                        Text(
                          '$stock piezas disponibles',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: stock > 0 ? ts.neonGreen : ts.neonRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Precio al público:', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                        Text(
                          '\$${lote["precio_venta"]} MXN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                );

                final actionBtns = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Ajustar Stock', style: TextStyle(fontSize: 11)),
                      onPressed: () => _dialogoAjustarPiezasLote(productoPadre, loteAdaptado),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.tintBg(ts.neonRed),
                        foregroundColor: ts.neonRed,
                      ),
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Baja', style: TextStyle(fontSize: 11)),
                      onPressed: () => _dialogoDarDeBajaLote(productoPadre, loteAdaptado),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoRow,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actionBtns),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      infoRow,
                      const Spacer(),
                      actionBtns,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipMetadatoLote(IconData icon, String texto, Color color) {
    final ts = ThemeService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ts.tintBg(color),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBarraFiltrosKardex() {
    final ts = ThemeService.instance;
    final String labelRango = (_fechaInicioKardex != null && _fechaFinKardex != null)
        ? '${_fechaInicioKardex!.day.toString().padLeft(2, "0")}/${_fechaInicioKardex!.month.toString().padLeft(2, "0")}/${_fechaInicioKardex!.year} - ${_fechaFinKardex!.day.toString().padLeft(2, "0")}/${_fechaFinKardex!.month.toString().padLeft(2, "0")}/${_fechaFinKardex!.year}'
        : 'Seleccionar Rango de Fechas';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ts.surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ts.borderColor, width: 1.2),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila Superior: Buscador de texto + Botón de Cámara + Selector de Rango de Fechas
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final searchField = TextField(
                controller: _busquedaKardexController,
                decoration: InputDecoration(
                  hintText: 'Buscar por medicamento, lote, motivo, auditor o referencia...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: ts.accentPrimary, size: 20),
                        tooltip: 'Escanear código de barras con cámara',
                        onPressed: _escanearCodigoParaKardex,
                      ),
                      if (_busquedaKardexController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _busquedaKardexController.clear();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
                onChanged: (_) => setState(() {}),
              );

              final datePickerButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  side: BorderSide(
                    color: _presetFechaKardex == 'PERSONALIZADO' ? ts.accentPrimary : ts.borderColor,
                    width: _presetFechaKardex == 'PERSONALIZADO' ? 1.5 : 1,
                  ),
                ),
                icon: Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: _presetFechaKardex == 'PERSONALIZADO' ? ts.accentPrimary : ts.textSecondary,
                ),
                label: Text(
                  labelRango,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _presetFechaKardex == 'PERSONALIZADO' ? FontWeight.bold : FontWeight.normal,
                    color: _presetFechaKardex == 'PERSONALIZADO' ? ts.accentPrimary : ts.textPrimary,
                  ),
                ),
                onPressed: _abrirSelectorRangoFechasKardex,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    datePickerButton,
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: datePickerButton),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 8),

          // Fila Inferior: Presets Rápidos de Fecha + Filtros de Movimiento + Limpiar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 15, color: ts.textSecondary),
                const SizedBox(width: 5),
                Text('Fechas: ', style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Todo el Historial'),
                  selected: _presetFechaKardex == 'TODAS',
                  selectedColor: ts.tintBg(ts.accentPrimary),
                  onSelected: (_) => _aplicarPresetKardex('TODAS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Hoy'),
                  selected: _presetFechaKardex == 'HOY',
                  selectedColor: ts.tintBg(ts.accentPrimary),
                  onSelected: (_) => _aplicarPresetKardex('HOY'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Últimos 7 días'),
                  selected: _presetFechaKardex == '7DIAS',
                  selectedColor: ts.tintBg(ts.accentPrimary),
                  onSelected: (_) => _aplicarPresetKardex('7DIAS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Este mes'),
                  selected: _presetFechaKardex == 'MES',
                  selectedColor: ts.tintBg(ts.accentPrimary),
                  onSelected: (_) => _aplicarPresetKardex('MES'),
                ),
                const SizedBox(width: 12),
                Container(height: 20, width: 1, color: ts.borderColor),
                const SizedBox(width: 12),
                Icon(Icons.filter_list, size: 15, color: ts.textSecondary),
                const SizedBox(width: 5),
                Text('Tipo: ', style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroTipoKardex == 'TODOS',
                  selectedColor: ts.tintBg(ts.accentPrimary),
                  onSelected: (_) => setState(() => _filtroTipoKardex = 'TODOS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Entradas (+)'),
                  selected: _filtroTipoKardex == 'ENTRADAS',
                  selectedColor: ts.tintBg(ts.neonGreen),
                  onSelected: (_) => setState(() => _filtroTipoKardex = 'ENTRADAS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Salidas (-)'),
                  selected: _filtroTipoKardex == 'SALIDAS',
                  selectedColor: ts.tintBg(ts.neonBlue),
                  onSelected: (_) => setState(() => _filtroTipoKardex = 'SALIDAS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Ajustes y Bajas'),
                  selected: _filtroTipoKardex == 'AJUSTES',
                  selectedColor: ts.tintBg(ts.neonAmber),
                  onSelected: (_) => setState(() => _filtroTipoKardex = 'AJUSTES'),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('⚠️ Solo Irregulares'),
                  selected: _soloIrregulares,
                  selectedColor: ts.tintBg(ts.neonRed),
                  checkmarkColor: ts.neonRed,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _soloIrregulares ? FontWeight.bold : FontWeight.normal,
                    color: _soloIrregulares ? ts.neonRed : ts.textPrimary,
                  ),
                  onSelected: (val) {
                    setState(() => _soloIrregulares = val);
                  },
                ),
                if (_fechaInicioKardex != null ||
                    _fechaFinKardex != null ||
                    _busquedaKardexController.text.isNotEmpty ||
                    _filtroTipoKardex != 'TODOS' ||
                    _soloIrregulares) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(Icons.close, size: 14, color: ts.neonRed),
                    label: Text('Limpiar filtros', style: TextStyle(color: ts.neonRed, fontSize: 11)),
                    onPressed: () {
                      _busquedaKardexController.clear();
                      _aplicarPresetKardex('TODAS');
                      setState(() {
                        _soloIrregulares = false;
                        _filtroTipoKardex = 'TODOS';
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaKardex() {
    final ts = ThemeService.instance;
    final movimientos = _kardexFiltrado;
    final infoMap = _loteInfoMap;

    int totalEntradas = 0;
    int totalSalidas = 0;
    int totalIrregulares = 0;

    for (final k in movimientos) {
      final int stockAnt = (k['stock_anterior'] as num?)?.toInt() ?? 0;
      final int stockPost = (k['stock_posterior'] as num?)?.toInt() ?? 0;
      final String tipo = (k['tipo_movimiento'] ?? '').toString().toUpperCase();
      final int rawCant = (k['cantidad'] as num?)?.toInt() ?? 0;
      final bool esEntrada = tipo.contains('ENTRADA') || (stockPost > stockAnt) || (rawCant > 0 && !tipo.contains('SALIDA') && !tipo.contains('BAJA'));

      final int cantAbs = (stockPost - stockAnt) != 0 ? (stockPost - stockAnt).abs() : rawCant.abs();
      if (esEntrada) {
        totalEntradas += cantAbs;
      } else {
        totalSalidas += cantAbs;
      }
      if (k['es_irregular'] == true) {
        totalIrregulares++;
      }
    }

    return Column(
      children: [
        // Barra interactiva de Búsqueda y Rango de Fechas
        _buildBarraFiltrosKardex(),

        // Resumen KPI del Período Filtrado
        if (movimientos.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ts.surfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ts.borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final kpiMovs = Text(
                  '${movimientos.length} mov. filtrados (${_kardex.length} total)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.textPrimary),
                );
                final kpiBalance = Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '+$totalEntradas pzas entrantes',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonGreen),
                    ),
                    Text(
                      '-$totalSalidas pzas salientes',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonRed),
                    ),
                    if (totalIrregulares > 0)
                      Text(
                        '⚠️ $totalIrregulares irregulares',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonRed),
                      ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      kpiMovs,
                      const SizedBox(height: 4),
                      kpiBalance,
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      kpiMovs,
                      kpiBalance,
                    ],
                  );
                }
              },
            ),
          ),

        // Listado de Movimientos o Estado Vacío
        Expanded(
          child: movimientos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 54, color: ts.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          _soloIrregulares
                              ? '¡Excelente! No hay movimientos marcados como irregulares en este período.'
                              : 'No se encontraron movimientos de Kardex para la búsqueda o fecha seleccionada.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Prueba seleccionando "Todo el Historial" o limpiando el texto de búsqueda.',
                          style: TextStyle(color: ts.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonal(
                          onPressed: () {
                            _busquedaKardexController.clear();
                            _aplicarPresetKardex('TODAS');
                            setState(() {
                              _soloIrregulares = false;
                              _filtroTipoKardex = 'TODOS';
                            });
                          },
                          child: const Text('Ver Todo el Kardex'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: movimientos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final k = movimientos[index];
                    final int stockAnt = (k['stock_anterior'] as num?)?.toInt() ?? 0;
                    final int stockPost = (k['stock_posterior'] as num?)?.toInt() ?? 0;
                    final String tipo = (k['tipo_movimiento'] ?? '').toString().toUpperCase();
                    final int rawCant = (k['cantidad'] as num?)?.toInt() ?? 0;
                    final bool esEntrada = tipo.contains('ENTRADA') || (stockPost > stockAnt) || (rawCant > 0 && !tipo.contains('SALIDA') && !tipo.contains('BAJA'));
                    final bool esIrregular = k['es_irregular'] ?? false;
                    final String? obs = k['observaciones_auditoria'];
                    final String? auditor = k['usuario_auditor'];

                    final loteId = k['lote_id'];
                    final int? idNum = loteId is int ? loteId : int.tryParse(loteId?.toString() ?? '');
                    final loteData = idNum != null ? infoMap[idNum] : null;
                    final String prodNombre = loteData?['producto'] ?? 'Lote ID: $loteId';
                    final String numLote = loteData?['numero_lote'] ?? (loteId != null ? 'ID: $loteId' : '');
                    final String lab = loteData?['laboratorio'] ?? '';
                    final String fechaStr = _formatoFechaKardex(k['created_at']);

                    final int displayCant = (stockPost - stockAnt) != 0 ? (stockPost - stockAnt).abs() : rawCant.abs();

                    return Container(
                      decoration: BoxDecoration(
                        color: ts.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: esIrregular ? ts.neonRed : ts.borderColor,
                          width: esIrregular ? 1.6 : 1.2,
                        ),
                        boxShadow: ts.cardGlowShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: esIrregular
                                      ? ts.tintBg(ts.neonRed)
                                      : esEntrada
                                          ? ts.tintBg(ts.neonGreen)
                                          : tipo.contains('BAJA')
                                              ? ts.tintBg(ts.neonRed)
                                              : ts.tintBg(ts.neonBlue),
                                  radius: 20,
                                  child: Icon(
                                    esIrregular
                                        ? Icons.warning_amber_rounded
                                        : esEntrada
                                            ? Icons.arrow_downward
                                            : tipo.contains('BAJA')
                                                ? Icons.delete_outline
                                                : tipo.contains('AJUSTE')
                                                    ? Icons.sync_alt
                                                    : Icons.arrow_upward,
                                    color: esIrregular
                                        ? ts.neonRed
                                        : esEntrada
                                            ? ts.neonGreen
                                            : tipo.contains('BAJA')
                                                ? ts.neonRed
                                                : ts.neonBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Nombre del Medicamento
                                      Text(
                                        prodNombre,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ts.textPrimary),
                                      ),
                                      const SizedBox(height: 3),
                                      // Badges de Tipo y Anomalía
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: esEntrada ? ts.tintBg(ts.neonGreen) : ts.tintBg(ts.neonBlue),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: esEntrada
                                                    ? ts.neonGreen.withValues(alpha: 0.4)
                                                    : ts.neonBlue.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              tipo,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: esEntrada ? ts.neonGreen : ts.neonBlue,
                                              ),
                                            ),
                                          ),
                                          if (numLote.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.surfaceAltBg,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: ts.borderColor),
                                              ),
                                              child: Text(
                                                'Lote: $numLote',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.textSecondary),
                                              ),
                                            ),
                                          if (esIrregular)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonRed),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: ts.neonRed.withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                '⚠️ FUERA DE LUGAR',
                                                style: TextStyle(
                                                  color: ts.neonRed,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Metadatos: Fecha, Motivo y Saldo
                                      if (fechaStr.isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 12, color: ts.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              fechaStr,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts.textSecondary),
                                            ),
                                            if (lab.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text('• $lab', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        '${k["motivo"] ?? ""}\nSaldo: $stockAnt -> $stockPost pzas (Ref: ${k["referencia_tipo"]} #${k["referencia_id"]})',
                                        style: TextStyle(fontSize: 12, color: ts.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${esEntrada ? "+" : "-"}$displayCant pzas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: esEntrada ? ts.neonGreen : ts.neonRed,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    IconButton(
                                      icon: Icon(
                                        obs != null ? Icons.comment : Icons.add_comment_outlined,
                                        color: esIrregular ? ts.neonRed : ts.accentPrimary,
                                        size: 20,
                                      ),
                                      tooltip: 'Agregar o editar observación de auditoría',
                                      onPressed: () => _dialogoComentarKardex(k),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (obs != null && obs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: esIrregular ? ts.tintBg(ts.neonRed) : ts.tintBg(ts.accentPrimary),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: esIrregular
                                        ? ts.neonRed.withValues(alpha: 0.4)
                                        : ts.accentPrimary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 14,
                                      color: esIrregular ? ts.neonRed : ts.accentPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Comentario de auditoría: "$obs"${auditor != null ? " — por $auditor" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: esIrregular ? ts.neonRed : ts.accentPrimary,
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
