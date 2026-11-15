import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class BackgroundLines extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const BackgroundLines({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 9),
  });

  @override
  State<BackgroundLines> createState() => _BackgroundLinesState();
}

class _BackgroundLinesState extends State<BackgroundLines>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
    final ts = ThemeService.instance;
    final List<Color> palette = [
      ts.accentPrimary,
      ts.neonBlue,
      ts.neonPurple,
      ts.neonGreen,
      ts.accentSecondary,
      ts.neonAmber,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BackgroundLinesPainter(
                    progress: _controller.value,
                    isDark: ts.esOscuro,
                    baseLineColor: ts.esOscuro
                        ? Colors.white.withValues(alpha: 0.06)
                        : ts.accentPrimary.withValues(alpha: 0.10),
                    pulseColors: palette,
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackgroundLinesPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color baseLineColor;
  final List<Color> pulseColors;

  _BackgroundLinesPainter({
    required this.progress,
    required this.isDark,
    required this.baseLineColor,
    required this.pulseColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final Paint basePaint = Paint()
      ..color = baseLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    const int lineCount = 20;
    for (int i = 0; i < lineCount; i++) {
      final double angle = (i / lineCount) * 2 * math.pi;
      final double outerR = math.max(size.width, size.height) * 0.82;
      final double innerR = math.min(size.width, size.height) * 0.10;

      final Offset start = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      final Offset end = Offset(
        center.dx + innerR * math.cos(angle + 0.35),
        center.dy + innerR * math.sin(angle + 0.35),
      );

      final double waveSign = i.isEven ? 1.0 : -1.0;
      final double curveSpread = outerR * 0.30 * waveSign;
      final Offset ctrl1 = Offset(
        center.dx + (outerR * 0.55) * math.cos(angle + 0.25 * waveSign) - curveSpread * 0.15,
        center.dy + (outerR * 0.55) * math.sin(angle + 0.25 * waveSign) + curveSpread * 0.15,
      );
      final Offset ctrl2 = Offset(
        center.dx + (outerR * 0.25) * math.cos(angle - 0.30 * waveSign),
        center.dy + (outerR * 0.25) * math.sin(angle - 0.30 * waveSign),
      );

      final Path path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, end.dx, end.dy);

      canvas.drawPath(path, basePaint);

      // Pulso luminoso animado viajando por el trazo
      final Color pulseColor = pulseColors[i % pulseColors.length];
      final double phase = (progress + (i * 0.137)) % 1.0;
      for (final metric in path.computeMetrics()) {
        final double totalLen = metric.length;
        if (totalLen <= 0) continue;
        final double segLen = totalLen * 0.18;
        final double head = phase * (totalLen + segLen);
        final double segStart = (head - segLen).clamp(0.0, totalLen);
        final double segEnd = head.clamp(0.0, totalLen);
        if (segEnd > segStart) {
          final Path subPath = metric.extractPath(segStart, segEnd);
          final Paint glowPaint = Paint()
            ..color = pulseColor.withValues(alpha: isDark ? 0.78 : 0.62)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawPath(subPath, glowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundLinesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.baseLineColor != baseLineColor;
  }
}

/// Tarjeta con giro 3D interactivo (frente / reverso) para mostrar el cálculo de KPIs.
/// Solo responde a `onTap`, por lo que convive sin conflicto dentro de carruseles
/// con arrastre horizontal o vertical.
