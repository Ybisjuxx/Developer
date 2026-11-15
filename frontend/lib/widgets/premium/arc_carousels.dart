import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class ArcInfiniteKpiCarousel extends StatefulWidget {
  final List<Widget> items;
  final Color? accentColor;
  final double height;
  final Duration autoPlayInterval;

  const ArcInfiniteKpiCarousel({
    super.key,
    required this.items,
    this.accentColor,
    this.height = 295,
    this.autoPlayInterval = const Duration(milliseconds: 4200),
  });

  @override
  State<ArcInfiniteKpiCarousel> createState() => _ArcInfiniteKpiCarouselState();
}

class _ArcInfiniteKpiCarouselState extends State<ArcInfiniteKpiCarousel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Animation<double>? _offsetAnim;
  double _playheadOffset = 0.0;
  Timer? _autoPlayTimer;
  bool _isHovered = false;
  bool _isDragging = false;

  int get _realCount => widget.items.length;

  /// Para que el carrusel infinito luzca siempre lleno en ambos lados
  /// incluso cuando un departamento tiene pocos KPIs (ej. 4-5), usamos
  /// al menos 7 ranuras virtuales mapeadas modularmente (`slot % _realCount`).
  int get _slotCount => _realCount == 0 ? 0 : math.max(_realCount, 7);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..addListener(() {
        if (_offsetAnim != null) {
          setState(() {
            _playheadOffset = _offsetAnim!.value;
          });
        }
      });
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant ArcInfiniteKpiCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _animController.stop();
      _playheadOffset = 0.0;
      _startAutoPlay();
    }
  }

  void _animateToOffset(double target) {
    _animController.stop();
    _offsetAnim = Tween<double>(
      begin: _playheadOffset,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0.0);
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_realCount <= 1) return;
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || _isHovered || _isDragging) return;
      _animateToOffset(_playheadOffset.roundToDouble() + 1.0);
    });
  }

  void _goToRelative(int delta) {
    if (_realCount <= 1) return;
    _animateToOffset(_playheadOffset.roundToDouble() + delta);
  }

  void _goToLogicalIndex(int targetLogical) {
    if (_realCount <= 1) return;
    final int currentRounded = _playheadOffset.round();
    final int currentLogical = ((currentRounded % _realCount) + _realCount) % _realCount;
    int diff = targetLogical - currentLogical;
    if (diff > _realCount / 2) diff -= _realCount;
    if (diff < -_realCount / 2) diff += _realCount;
    _animateToOffset(currentRounded.toDouble() + diff);
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_realCount == 0) {
      return const SizedBox.shrink();
    }

    final ts = ThemeService.instance;
    final Color accent = widget.accentColor ?? ts.accentPrimary;
    final int activeLogical =
        ((_playheadOffset.round() % _realCount) + _realCount) % _realCount;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;
          final double cardWidth = w >= 1100
              ? 350.0
              : (w >= 720 ? 320.0 : (w - 48).clamp(240.0, 340.0));
          final double spreadHalfWidth = ((w - cardWidth) * 0.54).clamp(130.0, 440.0);
          final double visibleHalfSpan = w >= 1000 ? 2.4 : (w >= 650 ? 1.8 : 1.25);

          // Construir tarjetas ordenadas por distancia descendente para que la central quede al frente (zIndex máximo)
          final List<({int slot, double distance, Widget child})> entries = [];
          for (int slot = 0; slot < _slotCount; slot++) {
            double d = (slot - _playheadOffset) % _slotCount;
            if (d > _slotCount / 2.0) d -= _slotCount;
            if (d < -_slotCount / 2.0) d += _slotCount;
            if (d.abs() <= visibleHalfSpan + 0.35) {
              entries.add((
                slot: slot,
                distance: d,
                child: widget.items[slot % _realCount],
              ));
            }
          }
          entries.sort((a, b) => b.distance.abs().compareTo(a.distance.abs()));

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: ts.tintBg(accent, lightAlpha: 0.04, darkAlpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: ts.esOscuro ? 0.30 : 0.18),
                width: 1.2,
              ),
              boxShadow: ts.cardGlowShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Galería Seamless Loop con Drag proxy y zIndex dinámico
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _isDragging = true;
                    _animController.stop();
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_realCount <= 1) return;
                    setState(() {
                      _playheadOffset -= details.primaryDelta! / (cardWidth * 0.72);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    _isDragging = false;
                    final double vx = details.primaryVelocity ?? 0.0;
                    double target = _playheadOffset.roundToDouble();
                    if (vx.abs() > 350) {
                      target = vx < 0
                          ? _playheadOffset.ceilToDouble()
                          : _playheadOffset.floorToDouble();
                    }
                    _animateToOffset(target);
                  },
                  child: SizedBox(
                    height: widget.height,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (final entry in entries)
                          Builder(builder: (context) {
                            final double t = (entry.distance / visibleHalfSpan).clamp(-1.0, 1.0);
                            final double xOffset = t * spreadHalfWidth;
                            final double scale = (1.0 - t.abs() * 0.44).clamp(0.45, 1.0);
                            final double opacity =
                                (1.0 - math.pow(t.abs(), 1.35)).clamp(0.0, 1.0);

                            return Transform.translate(
                              offset: Offset(xOffset, t.abs() * 6.0),
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: IgnorePointer(
                                    ignoring: entry.distance.abs() > 0.45,
                                    child: SizedBox(
                                      width: cardWidth,
                                      height: widget.height - 16,
                                      child: entry.child,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                        // Botón Prev (izquierdo)
                        if (_realCount > 1)
                          Positioned(
                            left: 8,
                            child: _ArcCarouselNavButton(
                              icon: Icons.chevron_left_rounded,
                              accent: accent,
                              tooltip: 'Prev',
                              onTap: () => _goToRelative(-1),
                            ),
                          ),

                        // Botón Next (derecho)
                        if (_realCount > 1)
                          Positioned(
                            right: 8,
                            child: _ArcCarouselNavButton(
                              icon: Icons.chevron_right_rounded,
                              accent: accent,
                              tooltip: 'Next',
                              onTap: () => _goToRelative(1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Barra inferior Arc UI: indicadores interactivos + estado hover + contador
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // Píldoras indicadoras de posición
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_realCount, (idx) {
                        final bool isActive = idx == activeLogical;
                        return GestureDetector(
                          onTap: () => _goToLogicalIndex(idx),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 8,
                              width: isActive ? 24 : 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? accent
                                    : accent.withValues(alpha: ts.esOscuro ? 0.28 : 0.22),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.45),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    // Badge contador y estado de auto-avance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ts.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isHovered || _isDragging
                                ? Icons.pause_circle_outline_rounded
                                : Icons.all_inclusive_rounded,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'KPI ${activeLogical + 1} de $_realCount${_isHovered ? ' • Pausado' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ts.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArcCarouselNavButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String tooltip;
  final VoidCallback onTap;

  const _ArcCarouselNavButton({
    required this.icon,
    required this.accent,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ts.cardBg.withValues(alpha: 0.92),
        shape: CircleBorder(
          side: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.2),
        ),
        elevation: 4,
        shadowColor: accent.withValues(alpha: 0.30),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: accent, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Carrusel vertical estilo GSAP Pin-Section para Medidores Radiales de Cumplimiento.
/// Columna izquierda con barra de progreso vertical (`fill`, `scaleY` desde `1/N` a `1.0`)
/// y lista interactiva; panel derecho con transición `autoAlpha` entre slides.
class ArcVerticalRadialCarousel extends StatefulWidget {
  final List<String> labels;
  final List<Widget> slides;
  final Color? accentColor;
  final Duration autoPlayInterval;

  const ArcVerticalRadialCarousel({
    super.key,
    required this.labels,
    required this.slides,
    this.accentColor,
    this.autoPlayInterval = const Duration(milliseconds: 3800),
  });

  @override
  State<ArcVerticalRadialCarousel> createState() =>
      _ArcVerticalRadialCarouselState();
}

class _ArcVerticalRadialCarouselState extends State<ArcVerticalRadialCarousel> {
  int _activeIndex = 0;
  Timer? _autoPlayTimer;
  bool _isHovered = false;

  int get _count => math.min(widget.labels.length, widget.slides.length);

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant ArcVerticalRadialCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeIndex >= _count) {
      _activeIndex = 0;
    }
    if (oldWidget.slides.length != widget.slides.length) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_count <= 1) return;
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || _isHovered) return;
      setState(() {
        _activeIndex = (_activeIndex + 1) % _count;
      });
    });
  }

  void _step(int delta) {
    if (_count <= 1) return;
    setState(() {
      _activeIndex = (_activeIndex + delta + _count) % _count;
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();

    final ts = ThemeService.instance;
    final Color accent = widget.accentColor ?? ts.neonGreen;
    final double fillFraction = ((_activeIndex + 1) / _count).clamp(0.0, 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0.0;
          if (v < -180) {
            _step(1);
          } else if (v > 180) {
            _step(-1);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ts.tintBg(accent, lightAlpha: 0.04, darkAlpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: ts.esOscuro ? 0.30 : 0.18),
              width: 1.2,
            ),
            boxShadow: ts.cardGlowShadow,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 640;

              final listPanel = IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra vertical `fill` estilo GSAP (scaleY: 1/N -> 1.0 desde arriba)
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: ts.borderColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.0 / _count, end: fillFraction),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return FractionallySizedBox(
                            alignment: Alignment.topCenter,
                            heightFactor: val,
                            child: Container(
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.55),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_count, (i) {
                          final bool isActive = i == _activeIndex;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _activeIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? accent.withValues(
                                        alpha: ts.esOscuro ? 0.16 : 0.10,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isActive ? 8 : 5,
                                    height: isActive ? 8 : 5,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? accent
                                          : ts.textSecondary.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontSize: isActive ? 15 : 13.5,
                                        fontWeight: isActive
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isActive ? accent : ts.textSecondary,
                                      ),
                                      child: Text(
                                        widget.labels[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );

              final slidePanel = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (childWidget, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.94, end: 1.0)
                              .animate(animation),
                          child: childWidget,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('radial_slide_$_activeIndex'),
                      child: widget.slides[_activeIndex],
                    ),
                  ),
                  if (_count > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Medidor anterior',
                          onPressed: () => _step(-1),
                          icon: Icon(Icons.keyboard_arrow_up_rounded, color: accent),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ts.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${_activeIndex + 1} / $_count${_isHovered ? ' • Pausado' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ts.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Siguiente medidor',
                          onPressed: () => _step(1),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                        ),
                      ],
                    ),
                  ],
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    listPanel,
                    const SizedBox(height: 16),
                    Center(child: slidePanel),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: listPanel),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: Center(child: slidePanel)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fondo animado `BackgroundLines` inspirado en Aceternity UI.
/// Dibuja trayectorias Bezier radiales simétricas con pulsos de luz cromáticos
/// que recorren cada línea de forma continua y asíncrona.
