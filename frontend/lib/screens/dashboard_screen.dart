import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/premium_ui.dart';
import 'dashboard/descarga_reporte_dialog.dart';
import 'dashboard/indicadores_centro_section.dart';
import 'dashboard/ventas_mensuales_chart.dart';

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

  // =========================================================================
  // CENTRO DE INDICADORES MENSUALES POR ÁREA (35 KPIs • 6 ÁREAS • RBAC)
  // =========================================================================
  int _anioIndicadores = DateTime.now().year;
  int _mesIndicadores = DateTime.now().month;
  Map<String, dynamic>? _indicadoresData;
  bool _cargandoIndicadores = false;
  String? _errorIndicadores;
  bool _descargandoCsv = false;

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
    _cargarReporteMensual(_anioReporte);
    final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
    if (rol == 'ADMINISTRADOR' || rol == 'RESPONSABLE_SANITARIO' || (kDebugMode && rol.isEmpty)) {
      _cargarIndicadoresMensuales(_anioIndicadores, _mesIndicadores);
    }
  }

  Future<void> _cargarMetricas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Carga concurrente paralela para acelerar drásticamente el inicio del Tablero
      final results = await Future.wait([
        ApiService.getProductos(),
        ApiService.getVentas(),
        ApiService.getMedicos(),
      ]);

      final productos = results[0];
      final ventas = results[1];
      final medicos = results[2];

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

      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _reporteVentasMensual = data;
        _cargandoReporteMensual = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoReporteMensual = false;
      });
    }
  }

  Future<void> _cargarIndicadoresMensuales(int anio, int mes) async {
    final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
    if (rol != 'ADMINISTRADOR' && rol != 'RESPONSABLE_SANITARIO' && !(kDebugMode && rol.isEmpty)) {
      return;
    }

    setState(() {
      _anioIndicadores = anio;
      _mesIndicadores = mes;
      _cargandoIndicadores = true;
      _errorIndicadores = null;
    });

    try {
      final data = await ApiService.getIndicadoresMensuales(anio: anio, mes: mes);
      if (!mounted) return;
      setState(() {
        _indicadoresData = data;
        _cargandoIndicadores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorIndicadores = e.toString().replaceAll('Exception: ', '');
        _cargandoIndicadores = false;
      });
    }
  }

  Future<void> _descargarReporteCsv({String? areaClave, String? areaTitulo}) async {
    setState(() {
      _descargandoCsv = true;
    });

    try {
      final csvContent = await ApiService.descargarReporteMensualCsv(
        anio: _anioIndicadores,
        mes: _mesIndicadores,
        area: areaClave,
      );

      final periodo = '$_anioIndicadores-${_mesIndicadores.toString().padLeft(2, '0')}';
      final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
      final rolLabel = rol.isNotEmpty ? rol : 'ADMINISTRADOR';
      final sufijoArea = (areaClave != null && areaClave.isNotEmpty) ? '_$areaClave' : '';
      final nombreArchivo = 'FarmaControl_Indicadores_$periodo${sufijoArea}_$rolLabel.csv';

      if (!mounted) return;

      mostrarDialogoDescargaCsv(context, nombreArchivo, periodo, rolLabel, csvContent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeService.instance.neonRed,
          behavior: SnackBarBehavior.floating,
          content: Text('Error al descargar reporte CSV: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _descargandoCsv = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
    final bool tienePermisoIndicadores =
        rol == 'ADMINISTRADOR' || rol == 'RESPONSABLE_SANITARIO' || (kDebugMode && rol.isEmpty);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: ts.neonAmber),
            const SizedBox(height: 12),
            Text('Error al cargar métricas:\n$_error', textAlign: TextAlign.center, style: TextStyle(color: ts.textPrimary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _cargarMetricas, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: ts.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: () async {
          await _cargarMetricas();
          await _cargarReporteMensual(_anioReporte);
          final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
          if (rol == 'ADMINISTRADOR' || rol == 'RESPONSABLE_SANITARIO' || (kDebugMode && rol.isEmpty)) {
            await _cargarIndicadoresMensuales(_anioIndicadores, _mesIndicadores);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado HeroUI de Bienvenida y Acciones Rápidas
              PremiumModuleHeader(
                title: 'Tablero de Mando Farmacéutico',
                subtitle: 'Monitoreo en tiempo real de inventario FEFO, caducidades y cobranza.',
                icon: Icons.dashboard_customize_rounded,
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ts.esTemaNeon
                        ? ts.accentPrimary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ts.esTemaNeon
                          ? ts.accentPrimary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: ts.neonGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'EN VIVO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                      foregroundColor: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      elevation: 2,
                    ),
                    onPressed: () => widget.onNavigate(1), // Ir a Punto de Venta
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text(
                      'Nueva Venta / Cobrar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                  final isSmall = constraints.maxWidth < 450;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: isSmall ? 10 : 16,
                    mainAxisSpacing: isSmall ? 10 : 16,
                    childAspectRatio: isWide ? 1.6 : (isSmall ? 1.15 : 1.3),
                    children: [
                      _buildMetricCard(
                        title: 'Stock Total',
                        value: '$_stockGlobal pzas',
                        subtitle: '$_totalProductos medicamentos',
                        icon: Icons.inventory_2_outlined,
                        color: ts.accentPrimary,
                        onTap: () => widget.onNavigate(3, subTab: 0), // Catálogo de inventario
                      ),
                      _buildMetricCard(
                        title: 'Alertas de Caducidad',
                        value: '$_lotesEnRiesgo lotes',
                        subtitle: 'Vencen en ≤ 90 días (FEFO)',
                        icon: Icons.access_time_filled,
                        color: _lotesEnRiesgo > 0 ? ts.neonRed : ts.neonGreen,
                        badge: _lotesEnRiesgo > 0 ? '¡Ver Lotes!' : null,
                        onTap: () => widget.onNavigate(3, subTab: 1), // Sub-Agente 1: Lotes por caducar
                      ),
                      _buildMetricCard(
                        title: 'Ventas Totales',
                        value: '\$${_ventasTotales.toStringAsFixed(2)}',
                        subtitle: '$_conteoVentas tickets emitidos',
                        icon: Icons.payments_outlined,
                        color: ts.neonBlue,
                        onTap: () => widget.onNavigate(4), // Historial de Ventas
                      ),
                      _buildMetricCard(
                        title: 'Médicos Activos',
                        value: '$_medicosVigentes vigentes',
                        subtitle: 'Listos para recetas',
                        icon: Icons.medical_services_outlined,
                        color: ts.accentSecondary,
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
              VentasMensualesChart(
                anioReporte: _anioReporte,
                reporteVentasMensual: _reporteVentasMensual,
                cargandoReporteMensual: _cargandoReporteMensual,
                onCargarReporteMensual: _cargarReporteMensual,
              ),
              const SizedBox(height: 24),

              // =====================================================================
              // CENTRO DE INDICADORES MENSUALES POR ÁREA (35 KPIS • 6 ÁREAS • RBAC)
              // =====================================================================
              if (tienePermisoIndicadores) ...[
                IndicadoresCentroSection(
                  anioIndicadores: _anioIndicadores,
                  mesIndicadores: _mesIndicadores,
                  indicadoresData: _indicadoresData,
                  cargandoIndicadores: _cargandoIndicadores,
                  errorIndicadores: _errorIndicadores,
                  descargandoCsv: _descargandoCsv,
                  onCargarIndicadores: _cargarIndicadoresMensuales,
                  onDescargarCsv: _descargarReporteCsv,
                ),
                const SizedBox(height: 24),
              ],

              // Sección de Alertas FEFO y Últimas Ventas
              LayoutBuilder(
                builder: (context, secConstraints) {
                  final isDesktopSec = secConstraints.maxWidth >= 850;

                  final fefoCard = PremiumSurfaceCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: ts.neonAmber),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Lotes con Prioridad de Despacho (FEFO)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ts.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => widget.onNavigate(3, subTab: 1), // Sub-Agente 1
                                  icon: Icon(Icons.open_in_new, size: 16, color: ts.accentPrimary),
                                  label: Text('Ver en Inventario', style: TextStyle(color: ts.accentPrimary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Medicamentos más próximos a expirar que deben surtirse primero según la regulación sanitaria:',
                              style: TextStyle(fontSize: 12, color: ts.textSecondary),
                            ),
                            Divider(height: 24, color: ts.borderColor),
                            if (_alertasCaducidad.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: ts.neonGreen, size: 40),
                                      const SizedBox(height: 8),
                                      Text('No hay lotes en riesgo de caducidad inmediata.', style: TextStyle(color: ts.textPrimary)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _alertasCaducidad.length,
                                separatorBuilder: (context, index) => Divider(height: 12, color: ts.borderColor),
                                itemBuilder: (context, index) {
                                  final item = _alertasCaducidad[index];
                                  final dias = item['dias'] as int;
                                  final Color badgeColor = dias <= 30 ? ts.neonRed : ts.neonAmber;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: ts.tintBg(badgeColor, lightAlpha: 0.15, darkAlpha: 0.25),
                                      child: Icon(
                                        Icons.alarm,
                                        color: badgeColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(item['producto'], style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary)),
                                    subtitle: Text('Lote: ${item["lote"]} • Existencia: ${item["stock"]} pzas', style: TextStyle(color: ts.textSecondary)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: ts.tintBg(badgeColor, lightAlpha: 0.12, darkAlpha: 0.20),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: badgeColor.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Text(
                                        '$dias días para vencer',
                                        style: TextStyle(
                                          color: badgeColor,
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
                    );

                  // Últimas Ventas
                  final ventasCard = PremiumSurfaceCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.receipt_long, color: ts.accentPrimary),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Últimas Ventas',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ts.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => widget.onNavigate(4), // Ir a Ventas
                                  child: Text('Ver todas', style: TextStyle(color: ts.accentPrimary)),
                                ),
                              ],
                            ),
                            Divider(height: 24, color: ts.borderColor),
                            if (_ultimasVentas.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(child: Text('Sin ventas registradas aún.', style: TextStyle(color: ts.textSecondary))),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _ultimasVentas.length,
                                separatorBuilder: (context, index) => Divider(height: 12, color: ts.borderColor),
                                itemBuilder: (context, index) {
                                  final v = _ultimasVentas[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(v['folio_ticket'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ts.textPrimary)),
                                    subtitle: Text('${v["comprador_nombre"] ?? "Público General"}', style: TextStyle(color: ts.textSecondary)),
                                    trailing: Text(
                                      '\$${v["total"]} MXN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ts.neonGreen,
                                        fontSize: 15,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                    );

                  if (isDesktopSec) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: fefoCard),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: ventasCard),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        fefoCard,
                        const SizedBox(height: 16),
                        ventasCard,
                      ],
                    );
                  }
                },
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
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    final ts = ThemeService.instance;
    return Container(
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ts.borderColor, width: 1.2),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withValues(alpha: 0.05),
          splashColor: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: ts.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: ts.neonRed,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: ts.neonRed.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: ts.esTemaNeon ? Colors.black : Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ts.tintBg(color, lightAlpha: 0.12, darkAlpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: ts.esOscuro ? 0.40 : 0.25),
                              width: 1,
                            ),
                          ),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ts.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: ts.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
