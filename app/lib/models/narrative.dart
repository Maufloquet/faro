import 'package:cloud_firestore/cloud_firestore.dart';

/// Cluster semanal de relatos relacionados escrito por
/// `aggregateNarratives` (Cloud Function diária). Cada doc representa
/// um padrão editorial: "vários relatos do mesmo tipo numa região".
///
/// Tom: nunca veredito — só contexto. `headline` já vem pré-formada
/// pelo backend pra evitar duplicar a lógica editorial na UI.
class Narrative {
  final String id;
  final String? city;
  final List<String> neighborhoods;
  final int count;
  final List<NarrativeReason> topReasons;
  final List<NarrativeSample> sample;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final String headline;
  final int windowDays;

  const Narrative({
    required this.id,
    required this.city,
    required this.neighborhoods,
    required this.count,
    required this.topReasons,
    required this.sample,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.headline,
    required this.windowDays,
  });

  factory Narrative.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return Narrative(
      id: doc.id,
      city: data['city'] as String?,
      neighborhoods: (data['neighborhoods'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      count: (data['count'] as num?)?.toInt() ?? 0,
      topReasons: (data['topReasons'] as List?)
              ?.whereType<Map>()
              .map((m) => NarrativeReason.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      sample: (data['sample'] as List?)
              ?.whereType<Map>()
              .map((m) => NarrativeSample.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      firstSeenAt: _toDate(data['firstSeenAt']),
      lastSeenAt: _toDate(data['lastSeenAt']),
      headline: (data['headline'] as String?) ?? 'Esta semana — relatos relacionados.',
      windowDays: (data['windowDays'] as num?)?.toInt() ?? 7,
    );
  }
}

class NarrativeReason {
  final String reason;
  final int count;
  const NarrativeReason({required this.reason, required this.count});

  factory NarrativeReason.fromMap(Map<String, dynamic> m) => NarrativeReason(
        reason: (m['reason'] as String?) ?? 'outros',
        count: (m['count'] as num?)?.toInt() ?? 0,
      );
}

class NarrativeSample {
  final String id;
  final String? externalTitle;
  final String? neighborhood;
  final String? mainReason;

  const NarrativeSample({
    required this.id,
    required this.externalTitle,
    required this.neighborhood,
    required this.mainReason,
  });

  factory NarrativeSample.fromMap(Map<String, dynamic> m) => NarrativeSample(
        id: (m['id'] as String?) ?? '',
        externalTitle: m['externalTitle'] as String?,
        neighborhood: m['neighborhood'] as String?,
        mainReason: m['mainReason'] as String?,
      );
}

DateTime? _toDate(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
