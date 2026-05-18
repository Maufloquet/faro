import 'package:flutter/material.dart';

import '../core/stats/temporal_activity.dart';

import '../core/design/tokens.dart';

/// Mini gráfico horizontal — barras proporcionais por hora/dia.
/// Sem libs externas pra manter o bundle leve. Cor neutra (tom Faro)
/// pra não disparar leitura emocional ("vermelho = perigo").
class TemporalChart extends StatelessWidget {
  final String label;
  final List<({String tag, int count})> entries;
  final Color barColor;

  const TemporalChart({
    super.key,
    required this.label,
    required this.entries,
    this.barColor = FaroColors.editorialOcher,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = entries.fold<int>(0, (a, e) => e.count > a ? e.count : a);
    if (maxCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: FaroColors.textSoft,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map((e) => _Row(
              tag: e.tag,
              count: e.count,
              max: maxCount,
              barColor: barColor,
            )),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String tag;
  final int count;
  final int max;
  final Color barColor;

  const _Row({
    required this.tag,
    required this.count,
    required this.max,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : count / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 11.5,
                color: FaroColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth * ratio).clamp(0.0, constraints.maxWidth);
                return Container(
                  height: 10,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: width,
                    height: 10,
                    decoration: BoxDecoration(
                      color: count == 0 ? Colors.transparent : barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: Text(
              count == 0 ? '–' : '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                color: FaroColors.textSoft,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helpers pra montar TemporalChart a partir dos buckets brutos.
extension TemporalEntries on Object {
  static List<({String tag, int count})> fromHours(List<HourBucket> buckets) {
    // Agrupa em janelas de 3h pra reduzir ruído visual (8 linhas em vez de 24).
    final windows = <int, int>{};
    for (final b in buckets) {
      final w = (b.hour ~/ 3) * 3;
      windows[w] = (windows[w] ?? 0) + b.count;
    }
    return [
      for (var h = 0; h < 24; h += 3)
        (
          tag: '${h.toString().padLeft(2, '0')}–${(h + 2).toString().padLeft(2, '0')}h',
          count: windows[h] ?? 0,
        ),
    ];
  }

  static List<({String tag, int count})> fromWeekdays(List<WeekdayBucket> buckets) {
    return [
      for (final b in buckets) (tag: labelForWeekday(b.weekday), count: b.count),
    ];
  }
}
