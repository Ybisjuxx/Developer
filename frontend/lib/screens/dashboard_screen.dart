import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/file_download_helper.dart';
import '../widgets/premium_ui.dart';
import 'dashboard/dashboard_kpi_widgets.dart';

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

  // =========================================================================
  // CENTRO DE INDICADORES MENSUALES POR ÁREA (35 KPIs • 6 ÁREAS • RBAC)
  // =========================================================================
  int _anioIndicadores = DateTime.now().year;
  int _mesIndicadores = DateTime.now().month;
  Map<String, dynamic>? _indicadoresData;
  bool _cargandoIndicadores = false;
  String? _errorIndicadores;
  int? _areaSeleccionadaIndex;
  String? _areaDescargaClave;
  bool _descargandoCsv = false;

  static const List<Map<String, dynamic>> _mesesLista = [
    {'numero': 1, 'nombre': 'Enero'},
    {'numero': 2, 'nombre': 'Febrero'},
    {'numero': 3, 'nombre': 'Marzo'},
    {'numero': 4, 'nombre': 'Abril'},
    {'numero': 5, 'nombre': 'Mayo'},
    {'numero': 6, 'nombre': 'Junio'},
    {'numero': 7, 'nombre': 'Julio'},
    {'numero': 8, 'nombre': 'Agosto'},
    {'numero': 9, 'nombre': 'Septiembre'},
    {'numero': 10, 'nombre': 'Octubre'},
    {'numero': 11, 'nombre': 'Noviembre'},
    {'numero': 12, 'nombre': 'Diciembre'},
  ];

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
      setState(() {
        _indicadoresData = data;
        _cargandoIndicadores = false;
        final List areas = (data['areas'] as List? ?? []);
        if (_areaSeleccionadaIndex != null && _areaSeleccionadaIndex! >= areas.length) {
          _areaSeleccionadaIndex = null;
        }
      });
    } catch (e) {
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

      _mostrarDialogoDescargaCsv(context, nombreArchivo, periodo, rolLabel, csvContent);
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

  void _mostrarDialogoDescargaCsv(
    BuildContext context,
    String nombreArchivo,
    String periodo,
    String rol,
    String csvContent,
  ) {
    final ts = ThemeService.instance;
    final int lineas = '\n'.allMatches(csvContent).length + 1;
    final int bytes = utf8.encode(csvContent).length;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: ts.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: ts.accentPrimary.withValues(alpha: 0.35), width: 1.2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 580),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ts.tintBg(ts.neonGreen, lightAlpha: 0.15, darkAlpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.file_download_done_rounded, color: ts.neonGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reporte Mensual CSV Generado',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ts.textPrimary,
                                ),
                              ),
                              Text(
                                'Periodo: $periodo  •  Rol: $rol',
                                style: TextStyle(fontSize: 12, color: ts.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: ts.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ts.surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreArchivo,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ts.accentPrimary,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ruta servidor: reportes_mensuales/$periodo/  •  $lineas filas  •  ${(bytes / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(color: ts.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ts.neonGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ts.neonGreen.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 14, color: ts.neonGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Copiado',
                                style: TextStyle(
                                  color: ts.neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Previsualización de datos (formato tabular CSV):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ts.esOscuro ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ts.borderColor),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SelectableText(
                            csvContent,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: ts.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ts.accentPrimary,
                          side: BorderSide(color: ts.accentPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: csvContent));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                backgroundColor: ts.neonGreen,
                                content: const Text(
                                  '¡CSV copiado nuevamente al portapapeles!',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copiar Todo el CSV'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ts.neonGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final ruta = await descargarArchivoTexto(
                            nombreArchivo,
                            csvContent,
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                backgroundColor: ts.neonGreen,
                                content: Text(
                                  ruta != null
                                      ? 'Archivo descargado: $ruta'
                                      : 'Descarga no soportada en esta plataforma.',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Descargar .CSV'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ts.accentPrimary,
                          foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Entendido / Cerrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
              _buildSeccionGraficoVentasMensuales(context),
              const SizedBox(height: 24),

              // =====================================================================
              // CENTRO DE INDICADORES MENSUALES POR ÁREA (35 KPIS • 6 ÁREAS • RBAC)
              // =====================================================================
              if (tienePermisoIndicadores) ...[
                _buildSeccionCentroIndicadores(context),
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
  Widget _buildSeccionGraficoVentasMensuales(BuildContext context) {
    final ts = ThemeService.instance;
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

    return PremiumSurfaceCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con selector de año
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ts.tintBg(ts.neonBlue, lightAlpha: 0.12, darkAlpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bar_chart_rounded, color: ts.neonBlue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evolución de Ventas Mes a Mes',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: ts.textPrimary),
                          ),
                          Text(
                            'Desglose anual comparativo de ingresos y volumen de tickets',
                            style: TextStyle(fontSize: 12, color: ts.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Selector de Año
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Año: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: ts.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ts.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          dropdownColor: ts.cardBg,
                          value: _anioReporte,
                          isDense: true,
                          items: [2026, 2025, 2024].map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y', style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary)),
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
                      icon: Icon(Icons.refresh, size: 20, color: ts.textSecondary),
                      onPressed: () => _cargarReporteMensual(_anioReporte),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mini Tarjetas de Métricas del Año
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildKpiResumen(
                    'Ingreso Total Anual',
                    '\$${totalAnual.toStringAsFixed(2)} MXN',
                    Icons.account_balance_wallet_outlined,
                    ts.accentPrimary,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiResumen(
                    'Promedio Mensual',
                    '\$${promedioMensual.toStringAsFixed(2)} MXN',
                    Icons.trending_up,
                    ts.neonBlue,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiResumen(
                    'Mes con Mayor Venta',
                    mesMayor,
                    Icons.emoji_events_outlined,
                    ts.neonAmber,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiResumen(
                    'Tickets Emitidos',
                    '$ticketsAnuales tickets',
                    Icons.receipt,
                    ts.neonPurple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Gráfico de Barras Mes a Mes
            if (_cargandoReporteMensual)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (meses.isEmpty)
              SizedBox(
                height: 220,
                child: Center(child: Text('No hay datos disponibles para este año.', style: TextStyle(color: ts.textSecondary))),
              )
            else
              LayoutBuilder(
                builder: (context, chartConstraints) {
                  final double innerW = chartConstraints.maxWidth - 18;
                  final double targetW = innerW < 440 ? 440 : innerW;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 8),
                    decoration: BoxDecoration(
                      color: ts.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: [
                          // Área de barras (12 columnas)
                          SizedBox(
                            height: 190,
                            width: targetW,
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
                          final double factor = maxVenta > 0 ? (ventasMes / maxVenta) : 0.0;
                          final double barHeight = ventasMes > 0 ? (factor * 110.0).clamp(10.0, 110.0) : 4.0;

                          return Expanded(
                            child: Tooltip(
                              message: '$nombreMes $_anioReporte\nVentas: \$${ventasMes.toStringAsFixed(2)} MXN\nTickets: $ticketsMes emitidos',
                              waitDuration: const Duration(milliseconds: 150),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
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
                                            color: ts.tintBg(ts.accentPrimary, lightAlpha: 0.15, darkAlpha: 0.25),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: ts.accentPrimary),
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
                                              color: ts.neonAmber,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '★ PICO',
                                              style: TextStyle(
                                                color: ts.esTemaNeon ? Colors.black : Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        else if (ventasMes > 0)
                                          Text(
                                            '\$${(ventasMes / 1000).toStringAsFixed(1)}k',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: ts.textSecondary,
                                            ),
                                          )
                                        else
                                          const SizedBox(height: 12),
                                        const SizedBox(height: 4),

                                        // La Barra con crecimiento animado fluido (700ms, easeOutCubic)
                                        TweenAnimationBuilder<double>(
                                          key: ValueKey('bar_${_anioReporte}_${index}_$barHeight'),
                                          tween: Tween<double>(begin: 0.0, end: barHeight),
                                          duration: const Duration(milliseconds: 700),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, animatedH, _) {
                                            return Container(
                                              height: animatedH,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: esPico
                                                      ? [ts.neonAmber, ts.neonAmber.withValues(alpha: 0.75)]
                                                      : seleccionado
                                                          ? [ts.accentPrimary, ts.accentSecondary]
                                                          : ventasMes > 0
                                                              ? [ts.neonBlue, ts.neonBlue.withValues(alpha: 0.70)]
                                                              : [ts.borderColor, ts.borderColor.withValues(alpha: 0.5)],
                                                ),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                boxShadow: esPico || seleccionado
                                                    ? [
                                                        BoxShadow(
                                                          color: (esPico ? ts.neonAmber : ts.accentPrimary).withValues(alpha: 0.35),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 6),

                                        // Nombre del Mes
                                        Text(
                                          nombreMes,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: (esPico || seleccionado) ? FontWeight.bold : FontWeight.w500,
                                            color: seleccionado ? ts.accentPrimary : ts.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),

                                        // Conteo de tickets
                                        Text(
                                          '$ticketsMes tck',
                                          style: TextStyle(fontSize: 9, color: ts.textSecondary.withValues(alpha: 0.7)),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    ),
                                  ),
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
                      Divider(height: 16, color: ts.borderColor),
                      Builder(builder: (context) {
                        final m = meses[_mesSeleccionadoIndex!];
                        final double v = (m['total_ventas'] as num? ?? 0.0).toDouble();
                        final int t = m['cantidad_tickets'] as int? ?? 0;
                        final String comp = m['mes_nombre_completo'] ?? '';
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: ts.accentPrimary),
                                Text(
                                  'Detalle de $comp $_anioReporte:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                                ),
                                Text(
                                  'Total: \$${v.toStringAsFixed(2)} MXN • $t tickets',
                                  style: TextStyle(color: ts.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _mesSeleccionadoIndex = null;
                                });
                              },
                              child: Text('Ocultar detalle', style: TextStyle(color: ts.accentPrimary)),
                            ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
                  );
                },
              ),
          ],
        ),
    );
  }

  Widget _buildKpiResumen(String titulo, String valor, IconData icono, Color color) {
    final ts = ThemeService.instance;
    return Container(
      constraints: const BoxConstraints(minWidth: 165),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ts.tintBg(color, lightAlpha: 0.08, darkAlpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: ts.esOscuro ? 0.35 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: ts.tintBg(color, lightAlpha: 0.15, darkAlpha: 0.25),
            radius: 16,
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: TextStyle(fontSize: 10, color: ts.textSecondary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ts.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
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

  // =========================================================================
  // SECCIÓN: CENTRO DE INDICADORES MENSUALES POR ÁREA
  // =========================================================================
  Widget _buildSeccionCentroIndicadores(BuildContext context) {
    final ts = ThemeService.instance;
    final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
    final bool esAdmin = rol == 'ADMINISTRADOR' || rol.isEmpty;

    final String periodoTexto = '$_anioIndicadores-${_mesIndicadores.toString().padLeft(2, '0')}';
    final List areas = (_indicadoresData?['areas'] as List? ?? []);
    final int totalKpis = _indicadoresData?['total_indicadores'] as int? ?? (esAdmin ? 35 : 17);
    final int totalAreas = _indicadoresData?['total_areas'] as int? ?? (esAdmin ? 6 : 3);

    return PremiumSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Barra superior: Título, Badge RBAC, selectores y botón Descargar CSV
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ts.accentPrimary, ts.neonPurple],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: ts.accentPrimary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Centro de Indicadores Mensuales por Área',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ts.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: esAdmin
                                    ? ts.neonPurple.withValues(alpha: 0.18)
                                    : ts.neonGreen.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: esAdmin ? ts.neonPurple : ts.neonGreen,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                esAdmin ? 'RBAC: AUDITORÍA TOTAL (6 ÁREAS)' : 'RBAC: SANITARIO / CLÍNICO (3 ÁREAS)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: esAdmin ? ts.neonPurple : ts.neonGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monitor integral mensual: $totalAreas áreas operativas • $totalKpis indicadores estratégicos (Periodo $periodoTexto)',
                          style: TextStyle(fontSize: 12, color: ts.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Controles: Selector Mes, Selector Año, Refresh, Botón Descargar CSV
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Selector Mes
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: ts.surfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        dropdownColor: ts.cardBg,
                        value: _mesIndicadores,
                        isDense: true,
                        items: _mesesLista.map((m) {
                          return DropdownMenuItem<int>(
                            value: m['numero'] as int,
                            child: Text(
                              m['nombre'] as String,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevoMes) {
                          if (nuevoMes != null) {
                            _cargarIndicadoresMensuales(_anioIndicadores, nuevoMes);
                          }
                        },
                      ),
                    ),
                  ),

                  // Selector Año
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: ts.surfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        dropdownColor: ts.cardBg,
                        value: _anioIndicadores,
                        isDense: true,
                        items: [2026, 2025, 2024, 2023].map((y) {
                          return DropdownMenuItem<int>(
                            value: y,
                            child: Text(
                              '$y',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevoAnio) {
                          if (nuevoAnio != null) {
                            _cargarIndicadoresMensuales(nuevoAnio, _mesIndicadores);
                          }
                        },
                      ),
                    ),
                  ),

                  // Botón Recargar
                  IconButton(
                    tooltip: 'Actualizar indicadores del mes',
                    icon: Icon(Icons.refresh_rounded, size: 20, color: ts.textSecondary),
                    onPressed: () => _cargarIndicadoresMensuales(_anioIndicadores, _mesIndicadores),
                  ),

                  // Selector de Área para Descarga (General o Por Área)
                  if (areas.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: ts.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _areaDescargaClave != null ? ts.accentPrimary : ts.borderColor,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          dropdownColor: ts.cardBg,
                          value: areas.any((a) => (a as Map)['clave'] == _areaDescargaClave)
                              ? _areaDescargaClave
                              : null,
                          isDense: true,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'Todas las áreas (General)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                              ),
                            ),
                            ...areas.map((a) {
                              final areaMap = a as Map<String, dynamic>;
                              final String clave = (areaMap['clave'] ?? '').toString();
                              final int numA = areaMap['numero'] as int? ?? 0;
                              final String tit = (areaMap['titulo'] ?? clave).toString();
                              return DropdownMenuItem<String?>(
                                value: clave,
                                child: Text(
                                  'Área ${numA.toString().padLeft(2, '0')}: $tit',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ts.textPrimary),
                                ),
                              );
                            }),
                          ],
                          onChanged: (nuevaClave) {
                            setState(() {
                              _areaDescargaClave = nuevaClave;
                            });
                          },
                        ),
                      ),
                    ),

                  // Botón Descargar Reporte CSV
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ts.esTemaNeon ? ts.accentPrimary : ts.colorActual.accentColor,
                      foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      elevation: 2,
                    ),
                    onPressed: _descargandoCsv
                        ? null
                        : () {
                            String? areaTit;
                            if (_areaDescargaClave != null) {
                              final match = areas.cast<Map<String, dynamic>>().where(
                                    (a) => a['clave'] == _areaDescargaClave,
                                  );
                              if (match.isNotEmpty) {
                                areaTit = match.first['titulo']?.toString();
                              }
                            }
                            _descargarReporteCsv(
                              areaClave: _areaDescargaClave,
                              areaTitulo: areaTit,
                            );
                          },
                    icon: _descargandoCsv
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ts.esTemaNeon ? Colors.black : Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _descargandoCsv
                          ? 'Generando...'
                          : (_areaDescargaClave != null
                              ? 'Descargar CSV (Por Área)'
                              : 'Descargar CSV (General)'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Interactive Área Ribbon Selector + Detalle del Área Seleccionada
          if (_cargandoIndicadores)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorIndicadores != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ts.tintBg(ts.neonRed, lightAlpha: 0.1, darkAlpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ts.neonRed),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: ts.neonRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No fue posible calcular los indicadores del periodo',
                          style: TextStyle(fontWeight: FontWeight.bold, color: ts.neonRed),
                        ),
                        Text(_errorIndicadores!, style: TextStyle(fontSize: 12, color: ts.textPrimary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _cargarIndicadoresMensuales(_anioIndicadores, _mesIndicadores),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (areas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay áreas ni indicadores configurados para el periodo seleccionado.',
                  style: TextStyle(color: ts.textSecondary),
                ),
              ),
            )
          else ...[
            // Ribbon interactivo de selección de Área
            _buildRibbonSelector(areas),
            const SizedBox(height: 16),

            // Despliegue bajo demanda con animación fluida (colapsado por defecto)
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: (_areaSeleccionadaIndex != null &&
                        _areaSeleccionadaIndex! < areas.length)
                    ? KeyedSubtree(
                        key: ValueKey('area_detalle_${_areaSeleccionadaIndex!}'),
                        child: _buildDetalleAreaSeleccionada(
                          areas[_areaSeleccionadaIndex!],
                        ),
                      )
                    : Container(
                        key: const ValueKey('area_colapsada_prompt'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: ts.tintBg(ts.accentPrimary, lightAlpha: 0.05, darkAlpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: ts.accentPrimary.withValues(alpha: ts.esOscuro ? 0.30 : 0.18),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ts.accentPrimary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.touch_app_rounded,
                                color: ts.accentPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Selecciona un departamento del submenú para desplegar su carrusel infinito de indicadores.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ts.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRibbonSelector(List areas) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 12;
        final double maxW = constraints.maxWidth;
        final int cols = maxW >= 900 ? 3 : (maxW >= 540 ? 2 : 1);
        final double itemWidth = (maxW - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(areas.length, (index) {
            final area = areas[index] as Map<String, dynamic>;
            final bool isSelected = _areaSeleccionadaIndex == index;
            final int numArea = area['numero'] as int? ?? (index + 1);
            final String titulo = area['titulo'] as String? ?? 'Área $numArea';
            final List indicadores = area['indicadores'] as List? ?? [];
            final Color colorArea = _getColorForArea(numArea);
            final IconData iconArea = _getIconForArea(numArea);

            return _AreaRibbonItem(
              width: itemWidth,
              areaNumero: numArea,
              titulo: titulo,
              subtitulo: area['subtitulo'] as String? ?? '',
              totalKpis: indicadores.length,
              color: colorArea,
              icon: iconArea,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _areaSeleccionadaIndex = isSelected ? null : index;
                });
              },
            );
          }),
        );
      },
    );
  }

  Widget _buildDetalleAreaSeleccionada(Map<String, dynamic> area) {
    final ts = ThemeService.instance;
    final int numArea = area['numero'] as int? ?? ((_areaSeleccionadaIndex ?? 0) + 1);
    final String titulo = area['titulo'] as String? ?? '';
    final String subtitulo = area['subtitulo'] as String? ?? '';
    final String resumen = area['resumen'] as String? ?? '';
    final List indicadores = area['indicadores'] as List? ?? [];
    final Color colorArea = _getColorForArea(numArea);
    final IconData iconArea = _getIconForArea(numArea);

    int optimos = 0;
    int preventivos = 0;
    int criticos = 0;
    for (var ind in indicadores) {
      final estado = (ind['estado'] ?? '').toString().toUpperCase().trim();
      if (estado == 'OPTIMO') {
        optimos++;
      } else if (estado == 'CRITICO') {
        criticos++;
      } else {
        preventivos++;
      }
    }

    final kpisCumplimiento = indicadores.where((ind) {
      final String u = (ind['unidad'] ?? '').toString().trim();
      final num? pct = ind['porcentaje_meta'] as num?;
      return u == '%' || (pct != null && pct > 0);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner cabecera del Área
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ts.tintBg(colorArea, lightAlpha: 0.08, darkAlpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorArea.withValues(alpha: 0.35), width: 1.2),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorArea.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconArea, color: colorArea, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Área $numArea: $titulo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ts.textPrimary,
                          ),
                        ),
                        if (subtitulo.isNotEmpty)
                          Text(
                            subtitulo,
                            style: TextStyle(fontSize: 12, color: ts.textSecondary),
                          ),
                        if (resumen.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorArea.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              resumen,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colorArea,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Chips resumen de estado semántico + botón colapsar
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  buildMiniBadgeEstado(
                    label: '$optimos ÓPTIMOS',
                    icon: Icons.check_circle_outline_rounded,
                    color: ts.neonGreen,
                  ),
                  if (preventivos > 0)
                    buildMiniBadgeEstado(
                      label: '$preventivos PREVENTIVOS',
                      icon: Icons.warning_amber_rounded,
                      color: ts.neonAmber,
                    ),
                  if (criticos > 0)
                    buildMiniBadgeEstado(
                      label: '$criticos CRÍTICOS',
                      icon: Icons.error_outline_rounded,
                      color: ts.neonRed,
                    ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorArea.withValues(alpha: ts.esOscuro ? 0.22 : 0.14),
                      foregroundColor: colorArea,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _descargandoCsv
                        ? null
                        : () => _descargarReporteCsv(
                              areaClave: area['clave'] as String?,
                              areaTitulo: titulo,
                            ),
                    icon: const Icon(Icons.download_rounded, size: 15),
                    label: const Text(
                      'Descargar CSV de esta área',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ts.textSecondary,
                      side: BorderSide(color: ts.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      setState(() {
                        _areaSeleccionadaIndex = null;
                      });
                    },
                    icon: const Icon(Icons.unfold_less_rounded, size: 16),
                    label: const Text(
                      'Ocultar departamento',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Fila de Animated Radial Gauges para KPIs de porcentaje/cumplimiento
        if (kpisCumplimiento.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.donut_large_rounded, size: 18, color: colorArea),
              const SizedBox(width: 8),
              Text(
                'Medidores Radiales de Cumplimiento (% de Meta)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: ts.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${kpisCumplimiento.length} métricas clave)',
                style: TextStyle(fontSize: 12, color: ts.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ArcVerticalRadialCarousel(
            key: ValueKey('radial_carousel_area_$numArea'),
            accentColor: ts.neonGreen,
            labels: kpisCumplimiento
                .map((ind) => ((ind as Map<String, dynamic>)['nombre'] ?? 'KPI').toString())
                .toList(),
            slides: kpisCumplimiento
                .map(
                  (ind) => AnimatedRadialGaugeCard(
                    kpi: ind as Map<String, dynamic>,
                    areaColor: colorArea,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Carrusel Infinito Arc UI de todos los KPIs del departamento
        Row(
          children: [
            Icon(Icons.view_carousel_rounded, size: 18, color: colorArea),
            const SizedBox(width: 8),
            Text(
              'Carrusel Infinito de Indicadores (${indicadores.length})',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: ts.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ArcInfiniteKpiCarousel(
          key: ValueKey('carousel_area_$numArea'),
          accentColor: colorArea,
          height: 295,
          items: indicadores.map((ind) {
            final kpi = ind as Map<String, dynamic>;
            return BentoKpiCard(kpi: kpi, areaColor: colorArea);
          }).toList(),
        ),
      ],
    );
  }

  Color _getColorForArea(int numArea) {
    final ts = ThemeService.instance;
    switch (numArea) {
      case 1:
        return ts.neonBlue;
      case 2:
        return ts.accentPrimary;
      case 3:
        return ts.accentSecondary;
      case 4:
        return ts.neonPurple;
      case 5:
        return ts.neonGreen;
      case 6:
        return ts.neonAmber;
      default:
        return ts.accentPrimary;
    }
  }

  IconData _getIconForArea(int numArea) {
    switch (numArea) {
      case 1:
        return Icons.point_of_sale_rounded;
      case 2:
        return Icons.inventory_2_rounded;
      case 3:
        return Icons.local_shipping_rounded;
      case 4:
        return Icons.account_balance_wallet_rounded;
      case 5:
        return Icons.health_and_safety_rounded;
      case 6:
        return Icons.gavel_rounded;
      default:
        return Icons.assessment_rounded;
    }
  }
}

// =========================================================================
// WIDGETS AUXILIARES: RIBBON SELECTOR, RADIAL GAUGES Y BENTO CARDS
// =========================================================================

class _AreaRibbonItem extends StatefulWidget {
  final double? width;
  final int areaNumero;
  final String titulo;
  final String subtitulo;
  final int totalKpis;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AreaRibbonItem({
    this.width,
    required this.areaNumero,
    required this.titulo,
    required this.subtitulo,
    required this.totalKpis,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AreaRibbonItem> createState() => _AreaRibbonItemState();
}

class _AreaRibbonItemState extends State<_AreaRibbonItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: widget.width,
            constraints: widget.width == null
                ? const BoxConstraints(minWidth: 200, maxWidth: 240)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? ts.tintBg(widget.color, lightAlpha: 0.14, darkAlpha: 0.28)
                  : (_isHovered
                      ? ts.tintBg(widget.color, lightAlpha: 0.06, darkAlpha: 0.12)
                      : ts.surfaceBg),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? widget.color
                    : (_isHovered
                        ? widget.color.withValues(alpha: 0.5)
                        : ts.borderColor),
                width: widget.isSelected ? 2.0 : 1.0,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : (_isHovered
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Área ${widget.areaNumero.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: widget.color,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? widget.color
                            : ts.borderColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.totalKpis} KPIs',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.isSelected
                              ? (ts.esTemaNeon ? Colors.black : Colors.white)
                              : ts.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AnimatedScale(
                      scale: _isHovered ? 2.0 : (widget.isSelected ? 1.15 : 1.0),
                      alignment: Alignment.center,
                      duration: const Duration(milliseconds: 190),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: (widget.isSelected || _isHovered) ? widget.color : ts.textSecondary,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 190),
                      width: _isHovered ? 16 : 8,
                    ),
                    Expanded(
                      child: Text(
                        widget.titulo,
                        style: TextStyle(
                          fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                          color: widget.isSelected ? ts.textPrimary : ts.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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

