import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class RibbonNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const RibbonNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Menú lateral estilo Ribbon Nav Rail interactivo para escritorio.
class RibbonNavRail extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<RibbonNavItem> destinations;
  final Widget? leading;
  final Widget? trailing;

  const RibbonNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.leading,
    this.trailing,
  });

  @override
  State<RibbonNavRail> createState() => _RibbonNavRailState();
}

class _RibbonNavRailState extends State<RibbonNavRail> {
  double? _pointerY;
  int? _hoveredIndex;

  // Parámetros del algoritmo macOS Dock de Blake Bowen (osublake)
  static const double _minStep = 64.0;
  static const double _maxScale = 2.0; // El doble del tamaño base
  static const double _bound = _minStep * math.pi;

  ({double scale, double dy}) _dockTransformFor(int index, bool isSelected) {
    if (_pointerY == null) {
      return (scale: isSelected ? 1.08 : 1.0, dy: 0.0);
    }
    final double leadingOffset = widget.leading != null ? 44.0 : 0.0;
    final double iconCenterY = leadingOffset + (index * _minStep) + (_minStep / 2.0);
    final double distance = iconCenterY - _pointerY!;

    if (-_bound < distance && distance < _bound) {
      final double rad = (distance / _minStep) * 0.5;
      final double scale = 1.0 + (_maxScale - 1.0) * math.cos(rad);
      final double dy = 14.0 * math.sin(rad);
      return (scale: scale, dy: dy);
    } else {
      final double dy = (-_bound < distance ? 1.0 : -1.0) * 14.0;
      return (scale: isSelected ? 1.04 : 1.0, dy: dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        setState(() {
          _pointerY = event.localPosition.dy;
          final double leadingOffset = widget.leading != null ? 44.0 : 0.0;
          final int approx = ((_pointerY! - leadingOffset) / _minStep).floor();
          if (approx >= 0 && approx < widget.destinations.length) {
            _hoveredIndex = approx;
          } else {
            _hoveredIndex = null;
          }
        });
      },
      onExit: (_) {
        if (_pointerY != null || _hoveredIndex != null) {
          setState(() {
            _pointerY = null;
            _hoveredIndex = null;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(height: 8),
          ],
          for (int i = 0; i < widget.destinations.length; i++)
            Builder(builder: (context) {
              final dock = _dockTransformFor(i, widget.selectedIndex == i);
              return _RibbonNavDestination(
                key: ValueKey('ribbon_nav_$i'),
                item: widget.destinations[i],
                isSelected: widget.selectedIndex == i,
                isHovered: _hoveredIndex == i,
                dockScale: dock.scale,
                dockOffsetY: dock.dy,
                hoverDistance: _hoveredIndex == null ? null : (i - _hoveredIndex!).abs(),
                onHoverChanged: (hovering) {
                  setState(() {
                    if (hovering) {
                      _hoveredIndex = i;
                    } else if (_hoveredIndex == i) {
                      _hoveredIndex = null;
                    }
                  });
                },
                onTap: () => widget.onDestinationSelected(i),
              );
            }),
          if (widget.trailing != null) ...[
            const SizedBox(height: 12),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}

class _RibbonNavDestination extends StatelessWidget {
  final RibbonNavItem item;
  final bool isSelected;
  final bool isHovered;
  final double dockScale;
  final double dockOffsetY;
  final int? hoverDistance;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  const _RibbonNavDestination({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isHovered,
    required this.dockScale,
    required this.dockOffsetY,
    required this.hoverDistance,
    required this.onHoverChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final Color activeColor = ts.accentPrimary;
    final Color inactiveColor = ts.textSecondary;

    final double verticalMargin = hoverDistance == 0
        ? 10.0
        : (hoverDistance == 1 ? 6.0 : 3.0);
    final double iconLabelGap = dockScale > 1.55
        ? 14.0
        : (dockScale > 1.2 ? 8.0 : 4.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: dockOffsetY),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          builder: (context, animatedDy, childWidget) {
            return Transform.translate(
              offset: Offset(0, animatedDy),
              child: childWidget,
            );
          },
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: verticalMargin),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isHovered ? 10 : 6,
                vertical: isHovered ? 10 : 7,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: ts.esOscuro ? 0.22 : 0.16)
                    : (isHovered
                        ? activeColor.withValues(alpha: ts.esOscuro ? 0.14 : 0.09)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? activeColor.withValues(alpha: ts.esTemaNeon ? 0.85 : 0.45)
                      : (isHovered
                          ? activeColor.withValues(alpha: ts.esTemaNeon ? 0.55 : 0.32)
                          : Colors.transparent),
                  width: 1.2,
                ),
                boxShadow: (isSelected || isHovered) ? ts.cardGlowShadow : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: dockScale,
                    alignment: Alignment.center,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 24,
                      color: isSelected
                          ? activeColor
                          : (isHovered ? activeColor : inactiveColor),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: iconLabelGap,
                  ),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: (isSelected || isHovered) ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? activeColor
                          : (isHovered ? ts.textPrimary : inactiveColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con microanimación de escala sutil en hover (1.0 -> 1.02).
