import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  List<dynamic> _devoluciones = [];
  List<dynamic> _mermas = [];

  // Filtros de Consulta por Fecha y Texto
  final TextEditingController _busquedaController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String _presetFecha = 'TODAS'; // 'TODAS', 'HOY', '7DIAS', 'MES', 'PERSONALIZADO'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devs = await ApiService.getDevoluciones();
      final mermas = await ApiService.getMermas();

      if (mounted) {
        setState(() {
          _devoluciones = devs;
          _mermas = mermas;
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

  void _aplicarPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _presetFecha = preset;
      if (preset == 'HOY') {
        _fechaInicio = DateTime(now.year, now.month, now.day);
        _fechaFin = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == '7DIAS') {
        final start = now.subtract(const Duration(days: 7));
        _fechaInicio = DateTime(start.year, start.month, start.day);
        _fechaFin = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == 'MES') {
        _fechaInicio = DateTime(now.year, now.month, 1);
        _fechaFin = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else {
        _fechaInicio = null;
        _fechaFin = null;
      }
    });
  }

  Future<void> _abrirSelectorRangoFechas() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_fechaInicio != null && _fechaFin != null)
          ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      helpText: 'Seleccionar período de consulta',
      saveText: 'Aplicar Período',
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _fechaFin = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _presetFecha = 'PERSONALIZADO';
      });
    }
  }

  // Filtrado de devoluciones por rango de fechas y texto
  List<dynamic> get _devolucionesFiltradas {
    final query = _busquedaController.text.trim().toLowerCase();

    return _devoluciones.where((d) {
      // 1. Filtro por Fecha
      if (_fechaInicio != null || _fechaFin != null) {
        final rawFecha = d['fecha_devolucion']?.toString() ?? '';
        final parsed = DateTime.tryParse(rawFecha);
        if (parsed != null) {
          if (_fechaInicio != null && parsed.isBefore(_fechaInicio!)) return false;
          if (_fechaFin != null && parsed.isAfter(_fechaFin!)) return false;
        }
      }

      // 2. Filtro por Búsqueda (Folio, Venta ID, Motivo, Producto o Lote)
      if (query.isNotEmpty) {
        final folio = (d['folio_devolucion'] ?? '').toString().toLowerCase();
        final ventaId = (d['venta_id'] ?? '').toString().toLowerCase();
        final motivo = (d['motivo'] ?? '').toString().toLowerCase();
        final detalles = (d['detalles'] as List<dynamic>? ?? []);
        final coincideDetalle = detalles.any((det) =>
            (det['producto_id'] ?? '').toString().toLowerCase().contains(query) ||
            (det['lote_id'] ?? '').toString().toLowerCase().contains(query) ||
            (det['estado_producto'] ?? '').toString().toLowerCase().contains(query));

        if (!folio.contains(query) &&
            !ventaId.contains(query) &&
            !motivo.contains(query) &&
            !coincideDetalle) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Filtrado de mermas por fecha y texto
  List<dynamic> get _mermasFiltradas {
    final query = _busquedaController.text.trim().toLowerCase();

    return _mermas.where((m) {
      // 1. Filtro por Fecha
      if (_fechaInicio != null || _fechaFin != null) {
        final rawFecha = m['fecha']?.toString() ?? '';
        final parsed = DateTime.tryParse(rawFecha);
        if (parsed != null) {
          if (_fechaInicio != null && parsed.isBefore(_fechaInicio!)) return false;
          if (_fechaFin != null && parsed.isAfter(_fechaFin!)) return false;
        }
      }

      // 2. Filtro por Búsqueda
      if (query.isNotEmpty) {
        final prod = (m['producto_nombre'] ?? '').toString().toLowerCase();
        final lote = (m['numero_lote'] ?? '').toString().toLowerCase();
        final motivo = (m['motivo'] ?? '').toString().toLowerCase();

        if (!prod.contains(query) && !lote.contains(query) && !motivo.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildBarraFiltrosFechas() {
    final ts = ThemeService.instance;
    final String labelRango = (_fechaInicio != null && _fechaFin != null)
        ? '${_fechaInicio!.day.toString().padLeft(2, "0")}/${_fechaInicio!.month.toString().padLeft(2, "0")}/${_fechaInicio!.year} - ${_fechaFin!.day.toString().padLeft(2, "0")}/${_fechaFin!.month.toString().padLeft(2, "0")}/${_fechaFin!.year}'
        : 'Seleccionar Rango de Fechas';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ts.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ts.esOscuro ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila Superior: Buscador de texto + Botón de Calendario
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final searchField = TextField(
                controller: _busquedaController,
                style: TextStyle(color: ts.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar por folio (DEV-...), venta #, motivo o lote...',
                  prefixIcon: Icon(Icons.search, size: 20, color: ts.textSecondary),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ts.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ts.borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ts.accentPrimary, width: 2)),
                  suffixIcon: _busquedaController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: ts.textSecondary),
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              );

              final datePickerButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  side: BorderSide(
                    color: _presetFecha == 'PERSONALIZADO' ? ts.accentPrimary : ts.borderColor,
                    width: _presetFecha == 'PERSONALIZADO' ? 1.5 : 1,
                  ),
                ),
                icon: Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: _presetFecha == 'PERSONALIZADO' ? ts.accentPrimary : ts.textSecondary,
                ),
                label: Text(
                  labelRango,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _presetFecha == 'PERSONALIZADO' ? FontWeight.bold : FontWeight.normal,
                    color: _presetFecha == 'PERSONALIZADO' ? ts.accentPrimary : ts.textPrimary,
                  ),
                ),
                onPressed: _abrirSelectorRangoFechas,
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

          // Fila Inferior: Presets Rápidos de Fecha (Todas, Hoy, 7 días, Este mes) + Limpiar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 16, color: ts.textSecondary),
                const SizedBox(width: 6),
                Text('Filtro por fechas: ', style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Todo el Historial'),
                  selected: _presetFecha == 'TODAS',
                  selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.20, darkAlpha: 0.30),
                  onSelected: (_) => _aplicarPreset('TODAS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Hoy'),
                  selected: _presetFecha == 'HOY',
                  selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.20, darkAlpha: 0.30),
                  onSelected: (_) => _aplicarPreset('HOY'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Últimos 7 días'),
                  selected: _presetFecha == '7DIAS',
                  selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.20, darkAlpha: 0.30),
                  onSelected: (_) => _aplicarPreset('7DIAS'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Este mes'),
                  selected: _presetFecha == 'MES',
                  selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.20, darkAlpha: 0.30),
                  onSelected: (_) => _aplicarPreset('MES'),
                ),
                if (_fechaInicio != null || _fechaFin != null || _busquedaController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(Icons.close, size: 14, color: ts.neonRed),
                    label: Text('Limpiar filtros', style: TextStyle(color: ts.neonRed, fontSize: 11)),
                    onPressed: () {
                      _busquedaController.clear();
                      _aplicarPreset('TODAS');
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

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con pestañas y botón de recarga
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: ts.accentPrimary,
                    unselectedLabelColor: ts.textSecondary,
                    indicatorColor: ts.accentPrimary,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.assignment_return_outlined),
                        text: 'Devoluciones y Reembolsos (${_devoluciones.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        text: 'Mermas Sanitarias (${_mermas.length})',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: ts.textSecondary),
                  onPressed: _cargarDatos,
                  tooltip: 'Actualizar registros',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra Interactiva de Búsqueda y Rango de Fechas
            _buildBarraFiltrosFechas(),
            const SizedBox(height: 12),

            // Contenedor de Vistas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error', style: TextStyle(color: ts.neonRed)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPestanaDevoluciones(),
                            _buildPestanaMermas(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPestanaDevoluciones() {
    final ts = ThemeService.instance;
    final lista = _devolucionesFiltradas;
    final double totalReembolsado = lista.fold<double>(
      0.0,
      (sum, d) => sum + ((d['total_reembolsado'] as num?)?.toDouble() ?? 0.0),
    );

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 54, color: ts.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No se encontraron devoluciones en el período o búsqueda especificada',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ts.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba ampliando el rango de fechas a "Todo el Historial".',
              style: TextStyle(color: ts.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                _busquedaController.clear();
                _aplicarPreset('TODAS');
              },
              child: const Text('Ver Todo el Historial'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen del período
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ts.tintBg(ts.accentPrimary, lightAlpha: 0.10, darkAlpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ts.accentPrimary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${lista.length} ${lista.length == 1 ? "devolución encontrada" : "devoluciones encontradas"}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.accentPrimary),
              ),
              Text(
                'Total Reembolsado: \$${totalReembolsado.toStringAsFixed(2)} MXN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonRed),
              ),
            ],
          ),
        ),

        // Listado de Devoluciones
        Expanded(
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final d = lista[index];
              final List<dynamic> detalles = d['detalles'] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: ts.esTemaNeon ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
                ),
                color: ts.cardBg,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: ts.tintBg(ts.neonAmber, lightAlpha: 0.15, darkAlpha: 0.25),
                    child: Icon(Icons.replay, color: ts.neonAmber),
                  ),
                  title: Text(
                    'Folio: ${d["folio_devolucion"]}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary),
                  ),
                  subtitle: Text(
                    'Venta ID: #${d["venta_id"]} | Motivo: ${d["motivo"]}\n'
                    'Fecha: ${d["fecha_devolucion"].toString().replaceFirst("T", " ").substring(0, 16)}',
                    style: TextStyle(color: ts.textSecondary),
                  ),
                  trailing: Text(
                    'Reembolso:\n\$${d["total_reembolsado"]} MXN',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ts.neonRed,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Artículos Devueltos:', style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary)),
                          const SizedBox(height: 8),
                          ...detalles.map((det) {
                            final bool buenEstado = det['estado_producto'] == 'BUEN_ESTADO';
                            final Color itemColor = buenEstado ? ts.neonGreen : ts.neonRed;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ts.tintBg(itemColor, lightAlpha: 0.10, darkAlpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: itemColor.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '• ${det["cantidad"]} pzas (Prod #${det["producto_id"]}, Lote #${det["lote_id"]})',
                                    style: TextStyle(fontWeight: FontWeight.w500, color: ts.textPrimary),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ts.tintBg(itemColor, lightAlpha: 0.20, darkAlpha: 0.30),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      buenEstado ? 'Reingresó a Stock' : 'MERMA (Dañado)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: itemColor,
                                      ),
                                    ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildPestanaMermas() {
    final ts = ThemeService.instance;
    final listaMermas = _mermasFiltradas;
    final double costoTotal = listaMermas.fold<double>(
      0.0,
      (sum, m) => sum + ((m['costo_total'] as num?)?.toDouble() ?? 0.0),
    );

    if (listaMermas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 54, color: ts.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No hay registros de merma sanitaria en el período o búsqueda especificada',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ts.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo el inventario de mermas se mantiene registrado.',
              style: TextStyle(color: ts.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                _busquedaController.clear();
                _aplicarPreset('TODAS');
              },
              child: const Text('Ver Todo el Historial'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen del período
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ts.tintBg(ts.neonRed, lightAlpha: 0.10, darkAlpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ts.neonRed.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${listaMermas.length} ${listaMermas.length == 1 ? "baja registrada" : "bajas registradas"}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonRed),
              ),
              Text(
                'Costo Total de Bajas: \$${costoTotal.toStringAsFixed(2)} MXN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ts.neonRed),
              ),
            ],
          ),
        ),

        // Listado de Mermas
        Expanded(
          child: ListView.builder(
            itemCount: listaMermas.length,
            itemBuilder: (context, index) {
              final m = listaMermas[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: ts.esTemaNeon ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
                ),
                color: ts.cardBg,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ts.tintBg(ts.neonRed, lightAlpha: 0.15, darkAlpha: 0.25),
                    child: Icon(Icons.delete_forever, color: ts.neonRed),
                  ),
                  title: Text(
                    '${m["producto_nombre"]} (Lote: ${m["numero_lote"]})',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary),
                  ),
                  subtitle: Text(
                    'Cantidad Merma: ${m["cantidad"]} piezas | Motivo: ${m["motivo"]}\n'
                    'Fecha de baja: ${m["fecha"].toString().replaceFirst("T", " ").substring(0, 16)}',
                    style: TextStyle(color: ts.textSecondary),
                  ),
                  trailing: Text(
                    'Costo Baja:\n\$${m["costo_total"]} MXN',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: ts.neonRed,
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
}
