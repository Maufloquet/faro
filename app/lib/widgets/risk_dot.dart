import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class RiskDot extends StatelessWidget {
  final RiskLevel level;
  final double size;
  const RiskDot({super.key, required this.level, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: level.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: level.color.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
    );
  }
}
