import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../widgets/premium_ui.dart';
import 'kpi_formula_specs.dart';

export 'kpi_formula_specs.dart';

class RadialProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  RadialProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circular de fondo
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Arco de progreso con puntas redondeadas
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class FormulaMatematicaBox extends StatelessWidget {
  final KpiFormulaSpec spec;
  final Color areaColor;

  const FormulaMatematicaBox({
    super.key,
    required this.spec,
    required this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final Color boxBg = ts.esOscuro ? ts.surfaceAltBg : ts.surfaceBg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: areaColor.withValues(alpha: 0.45)),
          ),
          child: (spec.numerador != null && spec.denominador != null)
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (spec.simboloResultado != null) ...[
                      Text(
                        spec.simboloResultado!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: areaColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            spec.numerador!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ts.textPrimary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            height: 1.8,
                            color: areaColor,
                          ),
                          Text(
                            spec.denominador!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ts.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (spec.sufijo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        spec.sufijo!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: areaColor,
                        ),
                      ),
                    ],
                  ],
                )
              : Center(
                  child: Text(
                    spec.expresion ?? spec.ecuacion,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ts.textPrimary,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dónde:',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: areaColor,
          ),
        ),
        const SizedBox(height: 3),
        ...spec.componentes.map(
          (comp) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: areaColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    comp,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: ts.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedRadialGaugeCard extends StatelessWidget {
  final Map<String, dynamic> kpi;
  final Color areaColor;

  const AnimatedRadialGaugeCard({super.key, 
    required this.kpi,
    required this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final String codigo = kpi['codigo'] as String? ?? '';
    final String nombre = kpi['nombre'] as String? ?? '';
    final String meta = kpi['meta'] as String? ?? '';
    final String estado = (kpi['estado'] as String? ?? 'OPTIMO').toUpperCase().trim();
    final double pctMeta = ((kpi['porcentaje_meta'] as num?) ?? 0.0).toDouble().clamp(0.0, 100.0);
    final double valorNum = ((kpi['valor'] as num?) ?? pctMeta).toDouble();
    final String unidad = kpi['unidad'] as String? ?? '%';
    final String descripcion = kpi['descripcion'] as String? ?? '';
    final formulaSpec = obtenerFormulaKpi(codigo, descripcion);

    Color statusColor;
    if (estado == 'OPTIMO') {
      statusColor = ts.neonGreen;
    } else if (estado == 'CRITICO') {
      statusColor = ts.neonRed;
    } else {
      statusColor = ts.neonAmber;
    }

    final frontCard = Container(
      width: 215,
      height: 235,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ts.borderColor),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: areaColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  codigo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: areaColor,
                  ),
                ),
              ),
              _buildSemanticStatusBadge(estado),
            ],
          ),
          SizedBox(
            width: 92,
            height: 92,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('radial_${codigo}_$pctMeta'),
              tween: Tween<double>(begin: 0.0, end: pctMeta / 100.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                return CustomPaint(
                  painter: RadialProgressPainter(
                    progress: progress,
                    trackColor: ts.borderColor.withValues(alpha: 0.5),
                    progressColor: statusColor,
                    strokeWidth: 8.0,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          unidad == '%' ? '${(progress * 100).toStringAsFixed(1)}%' : valorNum.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ts.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% meta',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: ts.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Column(
            children: [
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ts.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Meta: $meta',
                      style: TextStyle(
                        fontSize: 10,
                        color: ts.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.flip_rounded, size: 12, color: areaColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final backCard = Container(
      width: 230,
      height: 245,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: areaColor, width: 1.5),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$codigo • Fórmula',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: areaColor,
                ),
              ),
              Icon(Icons.flip_to_front_rounded, size: 14, color: areaColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ts.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(height: 12, color: areaColor.withValues(alpha: 0.25)),
          Expanded(
            child: SingleChildScrollView(
              child: FormulaMatematicaBox(
                spec: formulaSpec,
                areaColor: areaColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca para volver',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: areaColor,
            ),
          ),
        ],
      ),
    );

    return FlippableArcCard(front: frontCard, back: backCard);
  }
}

class BentoKpiCard extends StatelessWidget {
  final Map<String, dynamic> kpi;
  final Color areaColor;

  const BentoKpiCard({super.key, 
    required this.kpi,
    required this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final String codigo = kpi['codigo'] as String? ?? '';
    final String nombre = kpi['nombre'] as String? ?? '';
    final dynamic valor = kpi['valor'];
    final String unidad = kpi['unidad'] as String? ?? '';
    final String meta = kpi['meta'] as String? ?? '';
    final String estado = (kpi['estado'] as String? ?? 'OPTIMO').toUpperCase().trim();
    final double pctMeta = ((kpi['porcentaje_meta'] as num?) ?? 0.0).toDouble().clamp(0.0, 100.0);
    final String descripcion = kpi['descripcion'] as String? ?? '';

    Color statusColor;
    if (estado == 'OPTIMO') {
      statusColor = ts.neonGreen;
    } else if (estado == 'CRITICO') {
      statusColor = ts.neonRed;
    } else {
      statusColor = ts.neonAmber;
    }

    String valorFormateado = '$valor';
    if (valor is num) {
      if (unidad == 'MXN' || unidad.contains('MXN')) {
        valorFormateado = '\$${valor.toStringAsFixed(2)}';
      } else if (valor is double) {
        valorFormateado = valor.toStringAsFixed(1);
      }
    }

    final formulaSpec = obtenerFormulaKpi(codigo, descripcion);

    final frontCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ts.borderColor,
          width: 1.2,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Fila superior: Código, Badge semántico e ícono de giro
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: areaColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: areaColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  codigo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: areaColor,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSemanticStatusBadge(estado),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Ver cómo se calcula',
                    child: Icon(Icons.flip_rounded, size: 15, color: areaColor),
                  ),
                ],
              ),
            ],
          ),

          // Título y Valor numérico
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ts.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    valorFormateado,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ts.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (unidad.isNotEmpty && !valorFormateado.contains(unidad)) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        unidad,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ts.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Meta y barra de progreso animada
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Meta: $meta',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ts.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${pctMeta.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: ts.borderColor.withValues(alpha: 0.5),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('bar_${codigo}_$pctMeta'),
                    tween: Tween<double>(begin: 0.0, end: pctMeta / 100.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, factor, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: factor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Descripción explicativa
          Text(
            descripcion,
            style: TextStyle(
              fontSize: 10,
              color: ts.textSecondary.withValues(alpha: 0.85),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final backCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: areaColor,
          width: 1.5,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_rounded, size: 16, color: areaColor),
                  const SizedBox(width: 6),
                  Text(
                    '$codigo • ¿Cómo se calcula?',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: areaColor,
                    ),
                  ),
                ],
              ),
              Icon(Icons.flip_to_front_rounded, size: 15, color: areaColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ts.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(height: 14, color: areaColor.withValues(alpha: 0.28)),
          Expanded(
            child: SingleChildScrollView(
              child: FormulaMatematicaBox(
                spec: formulaSpec,
                areaColor: areaColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Actual: $valorFormateado • Meta: $meta',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Toca para volver',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: areaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return FlippableArcCard(front: frontCard, back: backCard);
  }
}

Widget _buildSemanticStatusBadge(String estadoRaw) {
  final ts = ThemeService.instance;
  final estado = estadoRaw.toUpperCase().trim();

  Color color;
  IconData icon;
  String label;

  switch (estado) {
    case 'OPTIMO':
      color = ts.neonGreen;
      icon = Icons.check_circle_outline_rounded;
      label = 'ÓPTIMO';
      break;
    case 'PREVENTIVO':
      color = ts.neonAmber;
      icon = Icons.warning_amber_rounded;
      label = 'PREVENTIVO';
      break;
    case 'CRITICO':
      color = ts.neonRed;
      icon = Icons.error_outline_rounded;
      label = 'CRÍTICO';
      break;
    default:
      color = ts.neonBlue;
      icon = Icons.info_outline_rounded;
      label = estado;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

Widget buildMiniBadgeEstado({
  required String label,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}
