import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/lector_codigo_barras_dialog.dart';
import '../widgets/ticket_impresion_dialog.dart';
import 'ventas/devolucion_dialog.dart';
import 'ventas/facturacion_dialog.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  List<dynamic> _ventas = [];
  bool _isLoading = true;
  String? _error;

  // Sub-Agente 1: Automatización de búsqueda por ticket para facturación
  final _ticketSearchController = TextEditingController();
  bool _buscandoTicket = false;

  // Filtros de Consulta y Búsqueda por Fecha para Historial de Ventas y Devoluciones
  final _busquedaVentasController = TextEditingController();
  DateTime? _fechaInicioVentas;
  DateTime? _fechaFinVentas;
  String _presetFechaVentas = 'TODAS';

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  @override
  void dispose() {
    _ticketSearchController.dispose();
    _busquedaVentasController.dispose();
    super.dispose();
  }

  void _aplicarPresetVentas(String preset) {
    final now = DateTime.now();
    setState(() {
      _presetFechaVentas = preset;
      if (preset == 'HOY') {
        _fechaInicioVentas = DateTime(now.year, now.month, now.day);
        _fechaFinVentas = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == '7DIAS') {
        final start = now.subtract(const Duration(days: 7));
        _fechaInicioVentas = DateTime(start.year, start.month, start.day);
        _fechaFinVentas = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == 'MES') {
        _fechaInicioVentas = DateTime(now.year, now.month, 1);
        _fechaFinVentas = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else {
        _fechaInicioVentas = null;
        _fechaFinVentas = null;
      }
    });
  }

  Future<void> _abrirSelectorRangoFechasVentas() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_fechaInicioVentas != null && _fechaFinVentas != null)
          ? DateTimeRange(start: _fechaInicioVentas!, end: _fechaFinVentas!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      helpText: 'Filtrar ventas por fecha',
      saveText: 'Aplicar Período',
    );

    if (picked != null) {
      setState(() {
        _fechaInicioVentas = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _fechaFinVentas = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _presetFechaVentas = 'PERSONALIZADO';
      });
    }
  }

  List<dynamic> get _ventasFiltradas {
    final query = _busquedaVentasController.text.trim().toLowerCase();

    return _ventas.where((v) {
      // 1. Filtro por Fecha
      if (_fechaInicioVentas != null || _fechaFinVentas != null) {
        final rawFecha = v['fecha_venta']?.toString() ?? '';
        final parsed = DateTime.tryParse(rawFecha);
        if (parsed != null) {
          if (_fechaInicioVentas != null && parsed.isBefore(_fechaInicioVentas!)) return false;
          if (_fechaFinVentas != null && parsed.isAfter(_fechaFinVentas!)) return false;
        }
      }

      // 2. Filtro por Búsqueda (Folio, Cliente, Cajero, Estado o Medicamento)
      if (query.isNotEmpty) {
        final folio = (v['folio_ticket'] ?? '').toString().toLowerCase();
        final comprador = (v['comprador_nombre'] ?? '').toString().toLowerCase();
        final cajero = (v['cajero_nombre'] ?? '').toString().toLowerCase();
        final estado = (v['estado'] ?? '').toString().toLowerCase();
        final detalles = (v['detalles'] as List<dynamic>? ?? []);
        final coincideItem = detalles.any((d) =>
            (d['producto_nombre'] ?? '').toString().toLowerCase().contains(query) ||
            (d['sustancia_activa'] ?? '').toString().toLowerCase().contains(query));

        if (!folio.contains(query) &&
            !comprador.contains(query) &&
            !cajero.contains(query) &&
            !estado.contains(query) &&
            !coincideItem) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _cargarVentas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.getVentas();
      if (mounted) {
        setState(() {
          _ventas = list;
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

  // Sub-Agente 1: Automatización de búsqueda y carga de ticket para facturar
  Future<void> _buscarTicketParaFacturar(String folioTicket) async {
    final ts = ThemeService.instance;
    final folio = folioTicket.trim();
    if (folio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese el folio de ticket o ID de compra para facturar.')),
      );
      return;
    }

    setState(() => _buscandoTicket = true);

    try {
      final venta = await ApiService.buscarVentaPorTicket(folio);
      if (mounted) {
        setState(() => _buscandoTicket = false);
        _ticketSearchController.clear();
        _abrirModalFacturacion(venta);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _buscandoTicket = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.search_off, color: ts.neonAmber, size: 40),
            title: const Text('Ticket no encontrado'),
            content: Text(
              'No se encontró ninguna venta registrada con el folio o ID "$folio". Verifique el número impreso en el ticket de compra.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar')),
            ],
          ),
        );
      }
    }
  }

  void _abrirModalFacturacion(Map<String, dynamic> venta) {
    mostrarModalFacturacion(
      context,
      venta: venta,
      setParentLoading: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
      onRefresh: _cargarVentas,
    );
  }

  void _abrirModalDevolucion(Map<String, dynamic> venta) {
    mostrarModalDevolucion(
      context,
      venta: venta,
      setParentLoading: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
      onRefresh: _cargarVentas,
    );
  }

  Color _obtenerColorEstado(String estado) {
    final ts = ThemeService.instance;
    switch (estado) {
      case 'COMPLETADA':
        return ts.neonGreen;
      case 'DEVOLUCION_PARCIAL':
        return ts.neonAmber;
      case 'DEVUELTA':
        return ts.neonRed;
      default:
        return ts.accentPrimary;
    }
  }

  Widget _buildVentasKpiCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    required ThemeService ts,
    double? width,
  }) {
    return Container(
      width: width ?? 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ts.borderColor, width: 1.2),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ts.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;

    final totalVentasCount = _ventasFiltradas.length;
    final totalIngresos = _ventasFiltradas.fold<double>(
      0.0,
      (sum, v) => sum + ((v['total'] as num?)?.toDouble() ?? 0.0),
    );
    final totalFacturadas = _ventasFiltradas.where((v) => v['facturada'] == true).length;
    final totalCompletadas = _ventasFiltradas.where((v) => (v['estado'] ?? 'COMPLETADA') == 'COMPLETADA').length;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de módulo HeroUI / Fragments UI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: ts.heroBannerGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ts.borderColor, width: 1.2),
                boxShadow: ts.cardGlowShadow,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ts.esTemaNeon
                              ? ts.accentPrimary.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ts.esTemaNeon
                                ? ts.accentPrimary.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historial de Ventas, Tickets y Facturación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ts.esTemaNeon ? ts.textPrimary : Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Emisión de CFDI 4.0, reimpresión de tickets y control de devoluciones.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ts.esTemaNeon ? ts.textSecondary : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                    ),
                    onPressed: _cargarVentas,
                    tooltip: 'Actualizar ventas',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Strip de KPIs de Ventas y Facturación
            LayoutBuilder(
              builder: (context, kConstraints) {
                final double w = kConstraints.maxWidth;
                final double cardWidth = w < 480 ? (w - 12) / 2 : (w < 820 ? (w - 24) / 3 : 210);

                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildVentasKpiCard(
                      titulo: 'Tickets en Consulta',
                      valor: '$totalVentasCount tickets',
                      icono: Icons.receipt_long,
                      color: ts.accentPrimary,
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildVentasKpiCard(
                      titulo: 'Total Vendido',
                      valor: '\$${totalIngresos.toStringAsFixed(2)} MXN',
                      icono: Icons.payments,
                      color: ts.neonGreen,
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildVentasKpiCard(
                      titulo: 'Facturas CFDI 4.0',
                      valor: '$totalFacturadas emitidas',
                      icono: Icons.verified_user,
                      color: ts.neonBlue,
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildVentasKpiCard(
                      titulo: 'Tickets Completados',
                      valor: '$totalCompletadas órdenes',
                      icono: Icons.check_circle,
                      color: ts.neonAmber,
                      ts: ts,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Sub-Agente 1: Apartado de Automatización de Facturación por Folio de Ticket
            LayoutBuilder(
              builder: (context, vConstraints) {
                final isNarrow = vConstraints.maxWidth < 750;

                final searchRow = Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ticketSearchController,
                        decoration: InputDecoration(
                          hintText: isNarrow ? 'Folio ticket (TK-...)...' : 'Folio de ticket (ej: TK-...)...',
                          prefixIcon: IconButton(
                            icon: Icon(Icons.camera_alt, color: ts.neonBlue, size: 20),
                            tooltip: 'Escanear QR o código del ticket',
                            onPressed: () async {
                              final cod = await LectorCodigoBarrasDialog.escanear(
                                context,
                                titulo: 'Escanear Ticket para Facturar',
                              );
                              if (cod != null && cod.trim().isNotEmpty) {
                                _ticketSearchController.text = cod.trim();
                                _buscarTicketParaFacturar(cod.trim());
                              }
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: ts.cardBg,
                          isDense: true,
                          suffixIcon: _buscandoTicket
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                        ),
                        onSubmitted: (val) => _buscarTicketParaFacturar(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.neonBlue,
                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                      ),
                      onPressed: _buscandoTicket ? null : () => _buscarTicketParaFacturar(_ticketSearchController.text),
                      icon: const Icon(Icons.request_quote_outlined, size: 18),
                      label: const Text('Facturar'),
                    ),
                  ],
                );

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ts.tintBg(ts.neonBlue, lightAlpha: 0.10, darkAlpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ts.borderColor, width: 1.2),
                    boxShadow: ts.cardGlowShadow,
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: ts.tintBg(ts.neonBlue),
                                  radius: 16,
                                  child: Icon(Icons.receipt_long, color: ts.neonBlue, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Facturación Electrónica (CFDI 4.0)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            searchRow,
                          ],
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: ts.tintBg(ts.neonBlue),
                              child: Icon(Icons.receipt_long, color: ts.neonBlue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Módulo de Facturación Electrónica (CFDI 4.0)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Automatización: Si el cliente solicita factura, ingrese el folio (ej: TK-...) para emitirla.',
                                    style: TextStyle(fontSize: 11, color: ts.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: 360, child: searchRow),
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Barra de Búsqueda y Filtros de Fecha para el Historial de Ventas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ts.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ts.borderColor, width: 1.2),
                boxShadow: ts.cardGlowShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      final searchField = TextField(
                        controller: _busquedaVentasController,
                        decoration: InputDecoration(
                          hintText: 'Filtrar ventas por ticket (TK-...), cliente o medicamento...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: _busquedaVentasController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _busquedaVentasController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      );

                      final String labelRangoVentas = (_fechaInicioVentas != null && _fechaFinVentas != null)
                          ? '${_fechaInicioVentas!.day.toString().padLeft(2, "0")}/${_fechaInicioVentas!.month.toString().padLeft(2, "0")}/${_fechaInicioVentas!.year} - ${_fechaFinVentas!.day.toString().padLeft(2, "0")}/${_fechaFinVentas!.month.toString().padLeft(2, "0")}/${_fechaFinVentas!.year}'
                          : 'Rango de Fechas';

                      final datePickerBtn = OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          side: BorderSide(
                            color: _presetFechaVentas == 'PERSONALIZADO' ? ts.accentPrimary : ts.borderColor,
                            width: _presetFechaVentas == 'PERSONALIZADO' ? 1.5 : 1,
                          ),
                        ),
                        icon: Icon(
                          Icons.calendar_month,
                          size: 18,
                          color: _presetFechaVentas == 'PERSONALIZADO' ? ts.accentPrimary : ts.textSecondary,
                        ),
                        label: Text(
                          labelRangoVentas,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _presetFechaVentas == 'PERSONALIZADO' ? FontWeight.bold : FontWeight.normal,
                            color: _presetFechaVentas == 'PERSONALIZADO' ? ts.accentPrimary : ts.textPrimary,
                          ),
                        ),
                        onPressed: _abrirSelectorRangoFechasVentas,
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchField,
                            const SizedBox(height: 8),
                            datePickerBtn,
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(flex: 3, child: searchField),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: datePickerBtn),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(Icons.date_range, size: 16, color: ts.textSecondary),
                        const SizedBox(width: 6),
                        Text('Período: ', style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('Todas (${_ventas.length})'),
                          selected: _presetFechaVentas == 'TODAS',
                          onSelected: (_) => _aplicarPresetVentas('TODAS'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Hoy'),
                          selected: _presetFechaVentas == 'HOY',
                          selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.25, darkAlpha: 0.3),
                          onSelected: (_) => _aplicarPresetVentas('HOY'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Últimos 7 días'),
                          selected: _presetFechaVentas == '7DIAS',
                          selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.25, darkAlpha: 0.3),
                          onSelected: (_) => _aplicarPresetVentas('7DIAS'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Este mes'),
                          selected: _presetFechaVentas == 'MES',
                          selectedColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.25, darkAlpha: 0.3),
                          onSelected: (_) => _aplicarPresetVentas('MES'),
                        ),
                        if (_fechaInicioVentas != null || _fechaFinVentas != null || _busquedaVentasController.text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: Icon(Icons.close, size: 14, color: ts.neonRed),
                            label: Text('Limpiar filtros', style: TextStyle(color: ts.neonRed, fontSize: 11)),
                            onPressed: () {
                              _busquedaVentasController.clear();
                              _aplicarPresetVentas('TODAS');
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Lista de Ventas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _ventasFiltradas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 54, color: ts.textSecondary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No se encontraron tickets en el período o búsqueda especificada',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Prueba seleccionando "Todas" para consultar el historial completo.',
                                    style: TextStyle(color: ts.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonal(
                                    onPressed: () {
                                      _busquedaVentasController.clear();
                                      _aplicarPresetVentas('TODAS');
                                    },
                                    child: const Text('Ver Todas las Ventas'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _ventasFiltradas.length,
                              itemBuilder: (context, index) {
                                final v = _ventasFiltradas[index];
                                final List<dynamic> detalles = v['detalles'] ?? [];
                                final String estado = v['estado'] ?? 'COMPLETADA';
                                final bool estaFacturada = v['facturada'] == true;

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
                                    child: ExpansionTile(
                                      shape: const Border(),
                                      collapsedShape: const Border(),
                                      leading: CircleAvatar(
                                        backgroundColor: estaFacturada ? ts.tintBg(ts.neonBlue) : ts.tintBg(ts.accentPrimary),
                                        child: Icon(
                                          estaFacturada ? Icons.verified : Icons.receipt,
                                          color: estaFacturada ? ts.neonBlue : ts.accentPrimary,
                                        ),
                                      ),
                                    title: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Folio: ${v["folio_ticket"]}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _obtenerColorEstado(estado).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: _obtenerColorEstado(estado)),
                                          ),
                                          child: Text(
                                            estado,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _obtenerColorEstado(estado),
                                            ),
                                          ),
                                        ),
                                        if (estaFacturada)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ts.tintBg(ts.neonBlue),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: ts.neonBlue.withValues(alpha: 0.5)),
                                            ),
                                            child: Text(
                                              'FACTURADA: ${v["folio_factura"] ?? "CFDI"}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: ts.neonBlue,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'Comprador: ${v["comprador_nombre"] ?? "Público General"} | Pago: ${v["metodo_pago"] ?? "EFECTIVO"}\n'
                                      'Fecha: ${v["fecha_venta"].toString().replaceFirst("T", " ").substring(0, 16)}',
                                    ),
                                    trailing: Text(
                                      '\$${v["total"]} MXN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: ts.esTemaNeon ? ts.neonGreen : ts.accentPrimary,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                  icon: const Icon(Icons.print, size: 16),
                                                  label: const Text('Ver Ticket Térmico', style: TextStyle(fontSize: 12)),
                                                  onPressed: () => TicketImpresionDialog.mostrar(context, v),
                                                ),
                                                // Sub-Agente 1: Botón Facturar o Ver Factura
                                                FilledButton.tonalIcon(
                                                  icon: Icon(estaFacturada ? Icons.description : Icons.request_quote_outlined, size: 16),
                                                  label: Text(
                                                    estaFacturada ? 'Ver Factura CFDI' : 'Facturar Ticket',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: estaFacturada ? ts.tintBg(ts.neonBlue) : null,
                                                    foregroundColor: estaFacturada ? ts.neonBlue : null,
                                                  ),
                                                  onPressed: () => _abrirModalFacturacion(v),
                                                ),
                                                if (estado != 'DEVUELTA')
                                                  FilledButton.tonalIcon(
                                                    icon: const Icon(Icons.replay, size: 16),
                                                    label: const Text('Devolución / Merma', style: TextStyle(fontSize: 12)),
                                                    onPressed: () => _abrirModalDevolucion(v),
                                                  ),
                                              ],
                                            ),
                                            const Divider(),
                                            const Text(
                                              'Detalle de artículos despachados:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 8),
                                            ...detalles.map((d) {
                                              final List<dynamic> lotesDespachados = d['despachos_lotes'] ?? [];
                                              final String nombreProd = d['producto_nombre'] ?? 'Prod ID #${d["producto_id"]}';
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: ts.surfaceBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: ts.borderColor),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '$nombreProd [ID: #${d["producto_id"]}]  •  Cantidad: ${d["cantidad"]} pzas  •  Subtotal: \$${d["subtotal"]}',
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 8,
                                                      children: lotesDespachados.map((ld) {
                                                        return Chip(
                                                          label: Text(
                                                            'Lote #${ld["lote_id"]}: ${ld["cantidad_despachada"]} pzas',
                                                            style: const TextStyle(fontSize: 11),
                                                          ),
                                                          backgroundColor: ts.tintBg(ts.accentPrimary),
                                                          side: BorderSide(color: ts.borderColor),
                                                        );
                                                      }).toList(),
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
                                ),
                              );
                            },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
