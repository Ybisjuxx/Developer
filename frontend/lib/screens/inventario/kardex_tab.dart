import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../widgets/lector_codigo_barras_dialog.dart';
import '../../widgets/premium_ui.dart';
import 'lote_acciones_dialogs.dart';

class KardexTab extends StatefulWidget {
  final List<dynamic> kardex;
  final List<dynamic> productos;
  final VoidCallback onReload;

  const KardexTab({
    super.key,
    required this.kardex,
    required this.productos,
    required this.onReload,
  });

  @override
  State<KardexTab> createState() => _KardexTabState();
}

class _KardexTabState extends State<KardexTab> with AutomaticKeepAliveClientMixin {
  bool _soloIrregulares = false;
  final TextEditingController _busquedaKardexController = TextEditingController();
  DateTime? _fechaInicioKardex;
  DateTime? _fechaFinKardex;
  String _presetFechaKardex = 'TODAS'; // 'TODAS', 'HOY', '7DIAS', 'MES', 'PERSONALIZADO'
  String _filtroTipoKardex = 'TODOS'; // 'TODOS', 'ENTRADAS', 'SALIDAS', 'AJUSTES'

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _busquedaKardexController.dispose();
    super.dispose();
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
      for (final p in widget.productos) {
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
    for (final p in widget.productos) {
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

    return widget.kardex.where((k) {
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

  Color _movimientoColor(ThemeService ts, String tipo, bool esEntrada) {
    if (tipo.contains('MERMA') || tipo.contains('BAJA') || tipo.contains('CADUCADO')) {
      return ts.neonRed;
    }
    if (tipo.contains('AJUSTE')) {
      return ts.neonAmber;
    }
    if (esEntrada || tipo.contains('ENTRADA')) {
      return ts.neonGreen;
    }
    return ts.neonBlue;
  }

  Widget _buildBarraFiltrosKardex() {
    final ts = ThemeService.instance;
    final String labelRango = (_fechaInicioKardex != null && _fechaFinKardex != null)
        ? '${_fechaInicioKardex!.day.toString().padLeft(2, "0")}/${_fechaInicioKardex!.month.toString().padLeft(2, "0")}/${_fechaInicioKardex!.year} - ${_fechaFinKardex!.day.toString().padLeft(2, "0")}/${_fechaFinKardex!.month.toString().padLeft(2, "0")}/${_fechaFinKardex!.year}'
        : 'Seleccionar Rango de Fechas';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumSurfaceCard(
        padding: const EdgeInsets.all(14),
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
                    filled: true,
                    fillColor: ts.surfaceBg,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevatedGlow: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final kpiMovs = Text(
                    '${movimientos.length} mov. filtrados (${widget.kardex.length} total)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.textPrimary),
                  );
                  final kpiBalance = Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ts.tintBg(ts.neonGreen),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ts.neonGreen.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '+$totalEntradas pzas entrantes',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.neonGreen),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ts.tintBg(ts.neonRed),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ts.neonRed.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '-$totalSalidas pzas salientes',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.neonRed),
                        ),
                      ),
                      if (totalIrregulares > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ts.tintBg(ts.neonRed),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ts.neonRed.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            '⚠️ $totalIrregulares irregulares',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.neonRed),
                          ),
                        ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kpiMovs,
                        const SizedBox(height: 6),
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
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: movimientos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final k = movimientos[index];
                    final int stockAnt = (k['stock_anterior'] as num?)?.toInt() ?? 0;
                    final int stockPost = (k['stock_posterior'] as num?)?.toInt() ?? 0;
                    final String tipo = (k['tipo_movimiento'] ?? '').toString().toUpperCase();
                    final int rawCant = (k['cantidad'] as num?)?.toInt() ?? 0;
                    final bool esEntrada = tipo.contains('ENTRADA') || (stockPost > stockAnt) || (rawCant > 0 && !tipo.contains('SALIDA') && !tipo.contains('BAJA') && !tipo.contains('MERMA'));
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
                    final Color tipoColor = _movimientoColor(ts, tipo, esEntrada);
                    final Color avatarColor = esIrregular ? ts.neonRed : tipoColor;

                    return AnimatedHoverScaleCard(
                      hoverScale: 1.008,
                      child: PremiumSurfaceCard(
                        padding: const EdgeInsets.all(14),
                        accentBorder: esIrregular ? ts.neonRed.withValues(alpha: 0.7) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: ts.tintBg(avatarColor),
                                  radius: 20,
                                  child: Icon(
                                    esIrregular
                                        ? Icons.warning_amber_rounded
                                        : esEntrada
                                            ? Icons.arrow_downward
                                            : (tipo.contains('BAJA') || tipo.contains('MERMA'))
                                                ? Icons.delete_outline
                                                : tipo.contains('AJUSTE')
                                                    ? Icons.sync_alt
                                                    : Icons.arrow_upward,
                                    color: avatarColor,
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
                                      const SizedBox(height: 4),
                                      // Badges de Tipo y Anomalía
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ts.tintBg(tipoColor),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: tipoColor.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              tipo,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: tipoColor,
                                              ),
                                            ),
                                          ),
                                          if (numLote.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.surfaceAltBg,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: ts.borderColor),
                                              ),
                                              child: Text(
                                                'Lote: $numLote',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.textSecondary),
                                              ),
                                            ),
                                          if (esIrregular)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonRed),
                                                borderRadius: BorderRadius.circular(20),
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
                                      const SizedBox(height: 5),
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
                                              Flexible(
                                                child: Text(
                                                  '• $lab',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 11, color: ts.textSecondary),
                                                ),
                                              ),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ts.tintBg(esEntrada ? ts.neonGreen : tipoColor),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: (esEntrada ? ts.neonGreen : tipoColor).withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        '${esEntrada ? "+" : "-"}$displayCant pzas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: esEntrada ? ts.neonGreen : tipoColor,
                                        ),
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
                                      onPressed: () => mostrarDialogoComentarKardex(
                                        context,
                                        movimiento: k,
                                        onSuccess: widget.onReload,
                                      ),
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
                                  borderRadius: BorderRadius.circular(10),
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
