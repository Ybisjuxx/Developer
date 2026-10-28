import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int index, {int subTab}) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;

  int _totalProductos = 0;
  int _stockGlobal = 0;
  int _lotesEnRiesgo = 0;
  double _ventasTotales = 0.0;
  int _conteoVentas = 0;
  int _medicosVigentes = 0;

  List<dynamic> _alertasCaducidad = [];
  List<dynamic> _ultimasVentas = [];

  // =========================================================================
  // SUB-AGENTE 6: Estado de reporte mensual de ventas
  // =========================================================================
  int _anioReporte = DateTime.now().year;
  Map<String, dynamic>? _reporteVentasMensual;
  bool _cargandoReporteMensual = false;
  int? _mesSeleccionadoIndex;

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
    _cargarReporteMensual(_anioReporte);
  }

  Future<void> _cargarMetricas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final productos = await ApiService.getProductos();
      final ventas = await ApiService.getVentas();
      final medicos = await ApiService.getMedicos();

      int stockAcumulado = 0;
      final hoy = DateTime.now();
      final List<dynamic> lotesProximos = [];

      for (var p in productos) {
        stockAcumulado += (p['stock_total'] as int? ?? 0);
        final List<dynamic> lotes = p['lotes'] ?? [];
        for (var lote in lotes) {
          final caducidadStr = lote['fecha_caducidad'] as String?;
          if (caducidadStr != null) {
            final fechaCad = DateTime.tryParse(caducidadStr);
            if (fechaCad != null) {
              final diasRestantes = fechaCad.difference(hoy).inDays;
              if (diasRestantes <= 90 && (lote['stock_actual'] ?? 0) > 0) {
                lotesProximos.add({
                  'producto': p['nombre_comercial'],
                  'sustancia': p['sustancia_activa'] ?? '',
                  'lote': lote['numero_lote'],
                  'caducidad': caducidadStr,
                  'dias': diasRestantes,
                  'stock': lote['stock_actual'],
                });
              }
            }
          }
        }
      }

      // Ordenar lotes por urgencia FEFO (menor cantidad de días primero)
      lotesProximos.sort((a, b) => (a['dias'] as int).compareTo(b['dias'] as int));

      double totalDinero = 0.0;
      for (var v in ventas) {
        totalDinero += (v['total'] as num? ?? 0.0).toDouble();
      }

      setState(() {
        _totalProductos = productos.length;
        _stockGlobal = stockAcumulado;
        _lotesEnRiesgo = lotesProximos.length;
        _alertasCaducidad = lotesProximos;
        _ventasTotales = totalDinero;
        _conteoVentas = ventas.length;
        _ultimasVentas = ventas.take(5).toList();
        _medicosVigentes = medicos.where((m) => m.vigente == true).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarReporteMensual(int anio) async {
    setState(() {
      _anioReporte = anio;
      _cargandoReporteMensual = true;
    });

    try {
      final data = await ApiService.getReporteVentasMensual(anio: anio);
      setState(() {
        _reporteVentasMensual = data;
        _cargandoReporteMensual = false;
      });
    } catch (_) {
      setState(() {
        _cargandoReporteMensual = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text('Error al cargar métricas:\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _cargarMetricas, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _cargarMetricas();
          await _cargarReporteMensual(_anioReporte);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado de Bienvenida y Acciones Rápidas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tablero de Mando Farmacéutico',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitoreo en tiempo real de inventario FEFO, caducidades y cobranza.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    onPressed: () => widget.onNavigate(1), // Ir a Punto de Venta
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Nueva Venta / Cobrar'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // =====================================================================
              // SUB-AGENTE 1: Tarjetas de Métricas KPI con Conexión a Inventario/Alertas
              // =====================================================================
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isWide ? 1.6 : 1.3,
                    children: [
                      _buildMetricCard(
                        title: 'Stock Total',
                        value: '$_stockGlobal pzas',
                        subtitle: '$_totalProductos medicamentos',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.teal,
                        onTap: () => widget.onNavigate(3, subTab: 0), // Catálogo de inventario
                      ),
                      _buildMetricCard(
                        title: 'Alertas de Caducidad',
                        value: '$_lotesEnRiesgo lotes',
                        subtitle: 'Vencen en ≤ 90 días (FEFO)',
                        icon: Icons.access_time_filled,
                        color: _lotesEnRiesgo > 0 ? Colors.red.shade700 : Colors.green,
                        badge: _lotesEnRiesgo > 0 ? '¡Ver Lotes!' : null,
                        onTap: () => widget.onNavigate(3, subTab: 1), // Sub-Agente 1: Lotes por caducar
                      ),
                      _buildMetricCard(
                        title: 'Ventas Totales',
                        value: '\$${_ventasTotales.toStringAsFixed(2)}',
                        subtitle: '$_conteoVentas tickets emitidos',
                        icon: Icons.payments_outlined,
                        color: Colors.indigo,
                        onTap: () => widget.onNavigate(4), // Historial de Ventas
                      ),
                      _buildMetricCard(
                        title: 'Médicos Activos',
                        value: '$_medicosVigentes vigentes',
                        subtitle: 'Listos para recetas',
                        icon: Icons.medical_services_outlined,
                        color: Colors.teal.shade800,
                        onTap: () => widget.onNavigate(7), // Directorio de Médicos
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // =====================================================================
              // SUB-AGENTE 6: GRÁFICO DESGLOSADO DE VENTAS MES A MES
              // =====================================================================
              _buildSeccionGraficoVentasMensuales(context),
              const SizedBox(height: 24),

              // Sección de Alertas FEFO y Últimas Ventas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lotes Próximos a Vencer (Prioridad FEFO) - SUB-AGENTE 1
                  Expanded(
                    flex: 5,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Lotes con Prioridad de Despacho (FEFO)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => widget.onNavigate(3, subTab: 1), // Sub-Agente 1
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Ver en Inventario'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Medicamentos más próximos a expirar que deben surtirse primero según la regulación sanitaria:',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const Divider(height: 24),
                            if (_alertasCaducidad.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 40),
                                      const SizedBox(height: 8),
                                      const Text('No hay lotes en riesgo de caducidad inmediata.'),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _alertasCaducidad.length,
                                separatorBuilder: (context, index) => const Divider(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _alertasCaducidad[index];
                                  final dias = item['dias'] as int;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: dias <= 30 ? Colors.red.shade100 : Colors.amber.shade100,
                                      child: Icon(
                                        Icons.alarm,
                                        color: dias <= 30 ? Colors.red.shade900 : Colors.amber.shade900,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(item['producto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Lote: ${item["lote"]} • Existencia: ${item["stock"]} pzas'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: dias <= 30 ? Colors.red.shade50 : Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: dias <= 30 ? Colors.red.shade300 : Colors.amber.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        '$dias días para vencer',
                                        style: TextStyle(
                                          color: dias <= 30 ? Colors.red.shade900 : Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    onTap: () => widget.onNavigate(3, subTab: 1), // Navega a la pestaña de Lotes por Caducar
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Últimas Ventas
                  Expanded(
                    flex: 4,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.receipt_long, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Últimas Ventas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => widget.onNavigate(4), // Ir a Ventas
                                  child: const Text('Ver todas'),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            if (_ultimasVentas.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(child: Text('Sin ventas registradas aún.')),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _ultimasVentas.length,
                                separatorBuilder: (context, index) => const Divider(height: 12),
                                itemBuilder: (context, index) {
                                  final v = _ultimasVentas[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(v['folio_ticket'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('${v["comprador_nombre"] ?? "Público General"}'),
                                    trailing: Text(
                                      '\$${v["total"]} MXN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SUB-AGENTE 6: WIDGET DE GRÁFICO MES A MES
  // =========================================================================
  Widget _buildSeccionGraficoVentasMensuales(BuildContext context) {
    final reporte = _reporteVentasMensual;
    final List<dynamic> meses = reporte?['meses'] ?? [];
    final double totalAnual = (reporte?['total_anual'] as num? ?? 0.0).toDouble();
    final double promedioMensual = (reporte?['promedio_mensual'] as num? ?? 0.0).toDouble();
    final String mesMayor = reporte?['mes_mayor_venta'] ?? 'N/D';
    final int ticketsAnuales = reporte?['total_tickets'] as int? ?? 0;

    // Encontrar la venta máxima para calcular las alturas proporcionales de las barras
    double maxVenta = 0.0;
    for (var m in meses) {
      final v = (m['total_ventas'] as num? ?? 0.0).toDouble();
      if (v > maxVenta) maxVenta = v;
    }
    if (maxVenta <= 0) maxVenta = 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con selector de año
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bar_chart_rounded, color: Colors.indigo.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Evolución de Ventas Mes a Mes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Desglose anual comparativo de ingresos y volumen de tickets',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                // Selector de Año
                Row(
                  children: [
                    const Text('Año: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _anioReporte,
                          isDense: true,
                          items: [2026, 2025, 2024].map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y', style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (nuevoAnio) {
                            if (nuevoAnio != null) {
                              _cargarReporteMensual(nuevoAnio);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Actualizar reporte',
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => _cargarReporteMensual(_anioReporte),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mini Tarjetas de Métricas del Año
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Row(
                  children: [
                    _buildKpiResumen(
                      'Ingreso Total Anual',
                      '\$${totalAnual.toStringAsFixed(2)} MXN',
                      Icons.account_balance_wallet_outlined,
                      Colors.teal,
                    ),
                    const SizedBox(width: 12),
                    _buildKpiResumen(
                      'Promedio Mensual',
                      '\$${promedioMensual.toStringAsFixed(2)} MXN',
                      Icons.trending_up,
                      Colors.indigo,
                    ),
                    const SizedBox(width: 12),
                    _buildKpiResumen(
                      'Mes con Mayor Venta',
                      mesMayor,
                      Icons.emoji_events_outlined,
                      Colors.amber.shade800,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 12),
                      _buildKpiResumen(
                        'Tickets Emitidos',
                        '$ticketsAnuales tickets',
                        Icons.receipt,
                        Colors.purple,
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Gráfico de Barras Mes a Mes
            if (_cargandoReporteMensual)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (meses.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(child: Text('No hay datos disponibles para este año.')),
              )
            else
              Container(
                padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Área de barras (12 columnas)
                    SizedBox(
                      height: 190,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(meses.length, (index) {
                          final m = meses[index];
                          final double ventasMes = (m['total_ventas'] as num? ?? 0.0).toDouble();
                          final int ticketsMes = m['cantidad_tickets'] as int? ?? 0;
                          final String nombreMes = m['mes_nombre'] ?? '';
                          final bool esPico = (ventasMes == maxVenta && maxVenta > 0);
                          final bool seleccionado = (_mesSeleccionadoIndex == index);

                          // Proporción de altura (mínimo 6 px si es > 0, máximo 130 px)
                          final double factor = ventasMes / maxVenta;
                          final double barHeight = ventasMes > 0 ? (factor * 110.0).clamp(10.0, 110.0) : 4.0;

                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _mesSeleccionadoIndex = (_mesSeleccionadoIndex == index) ? null : index;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: seleccionado
                                    ? BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.teal.shade400),
                                      )
                                    : null,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Etiqueta del valor arriba de la barra
                                    if (esPico)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        margin: const EdgeInsets.only(bottom: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade700,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '★ PICO',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    else if (ventasMes > 0)
                                      Text(
                                        '\$${(ventasMes / 1000).toStringAsFixed(1)}k',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 12),
                                    const SizedBox(height: 4),

                                    // La Barra
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeOut,
                                      height: barHeight,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: esPico
                                              ? [Colors.amber.shade600, Colors.amber.shade800]
                                              : seleccionado
                                                  ? [Colors.teal.shade400, Colors.teal.shade800]
                                                  : ventasMes > 0
                                                      ? [Colors.indigo.shade400, Colors.indigo.shade700]
                                                      : [Colors.grey.shade300, Colors.grey.shade400],
                                        ),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        boxShadow: esPico || seleccionado
                                            ? [
                                                BoxShadow(
                                                  color: (esPico ? Colors.amber : Colors.teal).withValues(alpha: 0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Nombre del Mes
                                    Text(
                                      nombreMes,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: (esPico || seleccionado) ? FontWeight.bold : FontWeight.w500,
                                        color: seleccionado ? Colors.teal.shade900 : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),

                                    // Conteo de tickets
                                    Text(
                                      '$ticketsMes tck',
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Detalle del mes seleccionado
                    if (_mesSeleccionadoIndex != null) ...[
                      const Divider(height: 16),
                      Builder(builder: (context) {
                        final m = meses[_mesSeleccionadoIndex!];
                        final double v = (m['total_ventas'] as num? ?? 0.0).toDouble();
                        final int t = m['cantidad_tickets'] as int? ?? 0;
                        final String comp = m['mes_nombre_completo'] ?? '';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                                const SizedBox(width: 6),
                                Text(
                                  'Detalle de $comp $_anioReporte:',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: \$${v.toStringAsFixed(2)} MXN  •  $t tickets emitidos',
                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _mesSeleccionadoIndex = null;
                                });
                              },
                              child: const Text('Ocultar detalle'),
                            ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiResumen(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 16,
              child: Icon(icono, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        radius: 18,
                        child: Icon(icon, color: color, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
