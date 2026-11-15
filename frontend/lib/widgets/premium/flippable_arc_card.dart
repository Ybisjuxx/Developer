import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlippableArcCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;

  const FlippableArcCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 440),
  });

  @override
  State<FlippableArcCard> createState() => _FlippableArcCardState();
}

class _FlippableArcCardState extends State<FlippableArcCard> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _showBack = !_showBack),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: _showBack ? 1.0 : 0.0),
          duration: widget.duration,
          curve: Curves.easeInOutCubic,
          builder: (context, value, _) {
            final double angle = value * math.pi;
            final bool isFront = angle <= (math.pi / 2.0);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: isFront
                  ? widget.front
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: widget.back,
                    ),
            );
          },
        ),
      ),
    );
  }
}
