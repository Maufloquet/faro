import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../models/historical_baseline.dart';

/// Chip discreto que comunica a tendência histórica do bairro em
/// comparação com a média semanal dele mesmo. NÃO é veredito — só
/// "este bairro nesta semana está acima/abaixo/em linha com o histórico
/// dele". Reaproveitado pela AreasScreen e pela OccurrenceDetailSheet.
///
/// Esconde quando não há baseline (null). Quando vem `insufficientData`,
/// mostra um chip neutro de "sem histórico ainda" — preferimos esse
/// estado visível ao silêncio cego (usuário não sabe se o componente
/// quebrou ou se o dado não existe).
class BaselineTrendChip extends StatelessWidget {
  final HistoricalBaseline? baseline;
  final EdgeInsetsGeometry padding;

  const BaselineTrendChip({
    super.key,
    required this.baseline,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final b = baseline;
    if (b == null) return const SizedBox.shrink();
    if (b.trend == BaselineTrend.insufficientData) {
      return Padding(
        padding: padding,
        child: Text(
          FaroStrings.baselineInsufficientData,
          style: const TextStyle(
            fontSize: 11.5,
            color: FaroColors.textHint,
          ),
        ),
      );
    }
    final trendText = _trendText(b.trend);
    final avg = b.weeklyAverage.toStringAsFixed(1);
    final color = _trendColor(b.trend);
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_trendIcon(b.trend), size: 13, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$trendText · média ~$avg/sem',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _trendText(BaselineTrend t) {
    switch (t) {
      case BaselineTrend.up:
        return FaroStrings.baselineTrendUp;
      case BaselineTrend.down:
        return FaroStrings.baselineTrendDown;
      case BaselineTrend.stable:
        return FaroStrings.baselineTrendStable;
      case BaselineTrend.insufficientData:
        return '';
    }
  }

  static IconData _trendIcon(BaselineTrend t) {
    switch (t) {
      case BaselineTrend.up:
        return Icons.trending_up;
      case BaselineTrend.down:
        return Icons.trending_down;
      case BaselineTrend.stable:
        return Icons.trending_flat;
      case BaselineTrend.insufficientData:
        return Icons.help_outline;
    }
  }

  static Color _trendColor(BaselineTrend t) {
    switch (t) {
      case BaselineTrend.up:
        return FaroColors.editorialBrown;
      case BaselineTrend.down:
        return FaroColors.textSoft;
      case BaselineTrend.stable:
        return FaroColors.textHint;
      case BaselineTrend.insufficientData:
        return FaroColors.textHint;
    }
  }
}
