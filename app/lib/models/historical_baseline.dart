import 'package:cloud_firestore/cloud_firestore.dart';

/// Tendência de relatos de um bairro comparada à sua própria média
/// histórica. NUNCA é veredito ("área perigosa") — só "esta semana está
/// acima/abaixo do normal *desse bairro*".
enum BaselineTrend {
  up,
  down,
  stable,
  insufficientData;

  static BaselineTrend fromString(String? s) {
    switch (s) {
      case 'up':
        return BaselineTrend.up;
      case 'down':
        return BaselineTrend.down;
      case 'stable':
        return BaselineTrend.stable;
      case 'insufficient_data':
      default:
        return BaselineTrend.insufficientData;
    }
  }
}

/// Snapshot agregado de `/historical_baseline/{regionKey}` — o backend roda
/// `aggregateHistoricalBaseline` 1x/dia. Cada doc cobre um bairro.
class HistoricalBaseline {
  final String? neighborhood;
  final String? city;
  final String? state;
  final int totalOccurrences;
  final double weeklyAverage;
  final int recentWeekCount;
  final BaselineTrend trend;
  final int windowDays;
  final int recentWindowDays;

  const HistoricalBaseline({
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.totalOccurrences,
    required this.weeklyAverage,
    required this.recentWeekCount,
    required this.trend,
    required this.windowDays,
    required this.recentWindowDays,
  });

  factory HistoricalBaseline.fromMap(Map<String, dynamic> m) =>
      HistoricalBaseline(
        neighborhood: m['neighborhood'] as String?,
        city: m['city'] as String?,
        state: m['state'] as String?,
        totalOccurrences: (m['totalOccurrences'] as num?)?.toInt() ?? 0,
        weeklyAverage: (m['weeklyAverage'] as num?)?.toDouble() ?? 0,
        recentWeekCount: (m['recentWeekCount'] as num?)?.toInt() ?? 0,
        trend: BaselineTrend.fromString(m['trend'] as String?),
        windowDays: (m['windowDays'] as num?)?.toInt() ?? 90,
        recentWindowDays: (m['recentWindowDays'] as num?)?.toInt() ?? 7,
      );

  factory HistoricalBaseline.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return const HistoricalBaseline(
        neighborhood: null,
        city: null,
        state: null,
        totalOccurrences: 0,
        weeklyAverage: 0,
        recentWeekCount: 0,
        trend: BaselineTrend.insufficientData,
        windowDays: 90,
        recentWindowDays: 7,
      );
    }
    return HistoricalBaseline.fromMap(data);
  }
}

/// Slug determinístico de bairro, em sincronia com `regionKey` do backend
/// (`functions/lib/historicalBaseline.js`). Estável: mudanças aqui exigem
/// mudança equivalente lá.
String baselineRegionKey({
  String? state,
  String? city,
  required String neighborhood,
}) {
  String slug(String? s) {
    final base = (s ?? '_').toLowerCase();
    final stripped = _stripDiacritics(base);
    final cleaned = stripped.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = cleaned.replaceAll(RegExp(r'^-|-$'), '');
    return trimmed.isEmpty ? '_' : trimmed;
  }

  return '${slug(state)}__${slug(city)}__${slug(neighborhood)}';
}

String _stripDiacritics(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString();
}
