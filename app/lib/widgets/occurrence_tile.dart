import 'package:flutter/material.dart';

import '../core/text/string_format.dart';
import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import 'risk_dot.dart';

class OccurrenceTile extends StatelessWidget {
  final Occurrence occurrence;
  final VoidCallback? onTap;

  const OccurrenceTile({super.key, required this.occurrence, this.onTap});

  @override
  Widget build(BuildContext context) {
    final risk = _classifyAge(occurrence.date);
    final neighborhood = titleCasePtBr(occurrence.neighborhood);
    final city = titleCasePtBr(occurrence.city);
    final where = neighborhood.isNotEmpty
        ? neighborhood
        : (city.isNotEmpty ? city : 'Sem localização específica');
    final what = occurrence.mainReason ?? 'Relato';
    final when = _relativeTime(occurrence.date);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: RiskDot(level: risk),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    where,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 15.5,
                      height: 1.2,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$what · $when',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: Color(0xFF6A6A6A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB8B8B0)),
          ],
        ),
      ),
    );
  }

  RiskLevel _classifyAge(DateTime date) {
    final hours = DateTime.now().difference(date).inHours;
    if (hours < 2) return RiskLevel.confirmedActivity;
    if (hours < 12) return RiskLevel.lightActivity;
    return RiskLevel.noRecentReports;
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }
}
