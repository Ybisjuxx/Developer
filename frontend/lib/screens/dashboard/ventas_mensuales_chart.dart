import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../widgets/premium_ui.dart';

class VentasMensualesChart extends StatefulWidget {
  final int anioReporte;
  final Map<String, dynamic>? reporteVentasMensual;
  final bool cargandoReporteMensual;
  final ValueChanged<int> onCargarReporteMensual;

  const VentasMensualesChart({
    super.key,
    required this.anioReporte,
    required this.reporteVentasMensual,
    required this.cargandoReporteMensual,
    required this.onCargarReporteMensual,
  });

  @override
  State<VentasMensualesChart> createState() => _VentasMensualesChartState();
}

class _VentasMensualesChartState extends State<VentasMensualesChart> {
  int? _mesSeleccionadoIndex;

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final reporte = widget.reporteVentasMensual;
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
                        value: widget.anioReporte,
                        isDense: true,
                        items: [2026, 2025, 2024].map((y) {
                          return DropdownMenuItem<int>(
                            value: y,
                            child: Text('$y', style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (nuevoAnio) {
                          if (nuevoAnio != null) {
                            widget.onCargarReporteMensual(nuevoAnio);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Actualizar reporte',
                    icon: Icon(Icons.refresh, size: 20, color: ts.textSecondary),
                    onPressed: () => widget.onCargarReporteMensual(widget.anioReporte),
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
          if (widget.cargandoReporteMensual)
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
                                  message: '$nombreMes ${widget.anioReporte}\nVentas: \$${ventasMes.toStringAsFixed(2)} MXN\nTickets: $ticketsMes emitidos',
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
                                              key: ValueKey('bar_${widget.anioReporte}_${index}_$barHeight'),
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
                        if (_mesSeleccionadoIndex != null && _mesSeleccionadoIndex! < meses.length) ...[
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
                                      'Detalle de $comp ${widget.anioReporte}:',
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
}
