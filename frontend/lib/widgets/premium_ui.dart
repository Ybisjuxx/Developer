import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Cabecera de módulo estilo HeroUI / Fragments UI con gradiente reactivo y borde luminoso.

export 'premium/ribbon_nav_rail.dart';
export 'premium/arc_carousels.dart';
export 'premium/background_lines.dart';
export 'premium/flippable_arc_card.dart';

class PremiumModuleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;
  final Widget? badge;

  const PremiumModuleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final bool darkHeaderText = !ts.esTemaNeon;
    final Color fg = darkHeaderText ? Colors.white : ts.textPrimary;
    final Color subFg = darkHeaderText ? Colors.white.withValues(alpha: 0.85) : ts.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: ts.heroBannerGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ts.esTemaNeon ? ts.accentPrimary.withValues(alpha: 0.45) : ts.borderColor,
          width: 1.2,
        ),
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
                  icon,
                  color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: fg,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
  }
}

/// Contenedor Bento / HeroUI con borde 1.2px, radio 16px y sombra cromática sutil.
class PremiumSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentBorder;
  final bool elevatedGlow;

  const PremiumSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentBorder,
    this.elevatedGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentBorder ?? ts.borderColor,
          width: 1.2,
        ),
        boxShadow: elevatedGlow ? ts.cardGlowShadow : null,
      ),
      child: child,
    );
  }
}
/// Ítem de destino para la barra vertical estilo Ribbon Nav.
class AnimatedHoverScaleCard extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  const AnimatedHoverScaleCard({
    super.key,
    required this.child,
    this.hoverScale = 1.02,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<AnimatedHoverScaleCard> createState() => _AnimatedHoverScaleCardState();
}

class _AnimatedHoverScaleCardState extends State<AnimatedHoverScaleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget card = MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.hoverScale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );

    if (widget.onTap != null) {
      card = GestureDetector(
        onTap: widget.onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Anillo medidor de porcentaje con gradiente sweep y animación reactiva Tween.
class AnimatedProgressRing extends StatelessWidget {
  final double value; // 0.0 a 1.0
  final double size;
  final double strokeWidth;
  final List<Color>? gradientColors;
  final Color? backgroundColor;
  final Widget? center;
  final Duration duration;
  final Curve curve;

  const AnimatedProgressRing({
    super.key,
    required this.value,
    this.size = 54.0,
    this.strokeWidth = 6.0,
    this.gradientColors,
    this.backgroundColor,
    this.center,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final Color defaultBg = ts.esOscuro
        ? ts.tintBg(ts.accentPrimary, darkAlpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final List<Color> colors = (gradientColors != null && gradientColors!.length >= 2)
        ? gradientColors!
        : [
            gradientColors?.firstOrNull ?? ts.accentPrimary,
            ts.neonGreen,
          ];

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, childWidget) {
        return CustomPaint(
          size: Size(size, size),
          painter: _SweepProgressRingPainter(
            progress: animatedValue,
            strokeWidth: strokeWidth,
            backgroundColor: backgroundColor ?? defaultBg,
            gradientColors: colors,
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: center),
          ),
        );
      },
    );
  }
}

class _SweepProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final List<Color> gradientColors;

  const _SweepProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Fondo del anillo
    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Arco de progreso con SweepGradient
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: gradientColors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    final double sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SweepProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Barra de progreso horizontal estilo Bullet KPI con animación Tween y marcador opcional.
class AnimatedBulletBar extends StatelessWidget {
  final double value; // 0.0 a 1.0
  final double? targetValue;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Duration duration;
  final Curve curve;

  const AnimatedBulletBar({
    super.key,
    required this.value,
    this.targetValue,
    this.height = 8.0,
    this.color,
    this.backgroundColor,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final Color barColor = color ?? ts.accentPrimary;
    final Color bg = backgroundColor ?? (ts.esOscuro ? ts.surfaceAltBg : Colors.black.withValues(alpha: 0.08));
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: value.clamp(0.0, 1.0)),
                duration: duration,
                curve: curve,
                builder: (context, val, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: val,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            barColor.withValues(alpha: 0.8),
                            barColor,
                          ],
                        ),
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (targetValue != null)
                Positioned(
                  left: (totalWidth * targetValue!.clamp(0.0, 1.0)) - 1.5,
                  top: -2,
                  bottom: -2,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: ts.textPrimary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Animación de entrada suave con desvanecimiento y desplazamiento vertical.
class AnimatedFadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Offset offset;

  const AnimatedFadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutQuad,
    this.offset = const Offset(0, 12),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              offset.dx * (1.0 - value),
              offset.dy * (1.0 - value),
            ),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

/// Carrusel Infinito estilo Arc UI / Seamless Loop (inspirado en GSAP Gallery).
/// Apila las tarjetas con orden Z dinámico (la central al frente), escala yoyo
/// (`scale: 0.45 -> 1.0 -> 0.45`), arrastre horizontal (`Drag`) con ajuste
/// automático al más cercano, botones `Prev`/`Next` y auto-avance pausable en hover.
