import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class ChipMetadatoLote extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;

  const ChipMetadatoLote({
    super.key,
    required this.icon,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ts.tintBg(color),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
