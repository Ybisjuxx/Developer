import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/premium_ui.dart';
import 'dashboard_kpi_widgets.dart';

class IndicadoresCentroSection extends StatefulWidget {
  final int anioIndicadores;
  final int mesIndicadores;
  final Map<String, dynamic>? indicadoresData;
  final bool cargandoIndicadores;
  final String? errorIndicadores;
  final bool descargandoCsv;
  final void Function(int anio, int mes) onCargarIndicadores;
  final void Function({String? areaClave, String? areaTitulo}) onDescargarCsv;

  const IndicadoresCentroSection({
    super.key,
    required this.anioIndicadores,
    required this.mesIndicadores,
    required this.indicadoresData,
    required this.cargandoIndicadores,
    required this.errorIndicadores,
    required this.descargandoCsv,
    required this.onCargarIndicadores,
    required this.onDescargarCsv,
  });

  @override
  State<IndicadoresCentroSection> createState() => _IndicadoresCentroSectionState();
}

class _IndicadoresCentroSectionState extends State<IndicadoresCentroSection> {
  int? _areaSeleccionadaIndex;
  String? _areaDescargaClave;

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
  void didUpdateWidget(covariant IndicadoresCentroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.indicadoresData != oldWidget.indicadoresData) {
      final List areas = (widget.indicadoresData?['areas'] as List? ?? []);
      if (_areaSeleccionadaIndex != null && _areaSeleccionadaIndex! >= areas.length) {
        _areaSeleccionadaIndex = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final rol = AuthService().usuarioActual.rol.toUpperCase().trim();
    final bool esAdmin = rol == 'ADMINISTRADOR' || rol.isEmpty;

    final String periodoTexto =
        '${widget.anioIndicadores}-${widget.mesIndicadores.toString().padLeft(2, '0')}';
    final List areas = (widget.indicadoresData?['areas'] as List? ?? []);
    final int totalKpis =
        widget.indicadoresData?['total_indicadores'] as int? ?? (esAdmin ? 35 : 17);
    final int totalAreas =
        widget.indicadoresData?['total_areas'] as int? ?? (esAdmin ? 6 : 3);

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
                                esAdmin
                                    ? 'RBAC: AUDITORÍA TOTAL (6 ÁREAS)'
                                    : 'RBAC: SANITARIO / CLÍNICO (3 ÁREAS)',
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
                        value: widget.mesIndicadores,
                        isDense: true,
                        items: _mesesLista.map((m) {
                          return DropdownMenuItem<int>(
                            value: m['numero'] as int,
                            child: Text(
                              m['nombre'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: ts.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevoMes) {
                          if (nuevoMes != null) {
                            widget.onCargarIndicadores(widget.anioIndicadores, nuevoMes);
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
                        value: widget.anioIndicadores,
                        isDense: true,
                        items: [2026, 2025, 2024, 2023].map((y) {
                          return DropdownMenuItem<int>(
                            value: y,
                            child: Text(
                              '$y',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: ts.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevoAnio) {
                          if (nuevoAnio != null) {
                            widget.onCargarIndicadores(nuevoAnio, widget.mesIndicadores);
                          }
                        },
                      ),
                    ),
                  ),

                  // Botón Recargar
                  IconButton(
                    tooltip: 'Actualizar indicadores del mes',
                    icon: Icon(Icons.refresh_rounded, size: 20, color: ts.textSecondary),
                    onPressed: () =>
                        widget.onCargarIndicadores(widget.anioIndicadores, widget.mesIndicadores),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: ts.textPrimary,
                                ),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: ts.textPrimary,
                                  ),
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
                    onPressed: widget.descargandoCsv
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
                            widget.onDescargarCsv(
                              areaClave: _areaDescargaClave,
                              areaTitulo: areaTit,
                            );
                          },
                    icon: widget.descargandoCsv
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
                      widget.descargandoCsv
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
          if (widget.cargandoIndicadores)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.errorIndicadores != null)
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
                        Text(
                          widget.errorIndicadores!,
                          style: TextStyle(fontSize: 12, color: ts.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        widget.onCargarIndicadores(widget.anioIndicadores, widget.mesIndicadores),
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
                    onPressed: widget.descargandoCsv
                        ? null
                        : () => widget.onDescargarCsv(
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
        // Almacén e Inventario: Naranja vivo de alto contraste
        return ts.esOscuro ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
      case 3:
        // Compras y Proveedores: Fucsia/Magenta intenso de alto contraste
        return ts.esOscuro ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
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
