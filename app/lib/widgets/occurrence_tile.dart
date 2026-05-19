import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
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
    final where = _composeLocation(neighborhood, city);
    final what = occurrence.mainReason == null
        ? FaroStrings.occReportFallback
        : FaroStrings.reasonLabel(occurrence.mainReason!);
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 15.5,
                      height: 1.2,
                      color: FaroColors.textPrimary,
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
                  if (_sourceBadge(occurrence) != null) ...[
                    const SizedBox(height: 4),
                    _sourceBadge(occurrence)!,
                  ],
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

  /// Formata a localização do tile. Quando temos bairro + cidade, mostra
  /// "Bairro · Cidade" (separador editorial Faro) pra que o usuário saiba
  /// de onde é o relato — especialmente útil em modo RMS (Lauro, Camaçari,
  /// Simões Filho) onde o nome do bairro pode coincidir entre municípios.
  String _composeLocation(String neighborhood, String city) {
    if (neighborhood.isNotEmpty && city.isNotEmpty) {
      return '$neighborhood · $city';
    }
    if (neighborhood.isNotEmpty) return neighborhood;
    if (city.isNotEmpty) return city;
    return FaroStrings.occNoLocation;
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return FaroStrings.occRelMinutes(diff.inMinutes);
    if (diff.inHours < 24) return FaroStrings.occRelHours(diff.inHours);
    return FaroStrings.occRelDays(diff.inDays);
  }

  Widget? _sourceBadge(Occurrence o) {
    final children = <Widget>[];
    if (o.source == OccurrenceSource.media) {
      children.add(_pill(
        icon: Icons.newspaper_outlined,
        label: o.sourceName ?? FaroStrings.occMediaFallback,
        color: FaroColors.editorialBrown,
      ));
    } else if (o.source == OccurrenceSource.fogoCruzado) {
      children.add(_pill(
        icon: Icons.gpp_maybe_outlined,
        label: FaroStrings.occFogoCruzadoLabel,
        color: FaroColors.destructive,
      ));
    }
    if (o.isCityCentroid) {
      children.add(const SizedBox(width: 6));
      children.add(_pill(
        icon: Icons.adjust,
        label: FaroStrings.occApproxLocation,
        color: FaroColors.editorialOcher,
      ));
    }
    if (children.isEmpty) return null;
    return Wrap(children: children);
  }

  Widget _pill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
