import 'package:cloud_firestore/cloud_firestore.dart';

/// Snapshot operacional escrito pela Cloud Function `aggregateAdminMetrics`
/// a cada 30 minutos em `/admin_metrics/current`. A leitura é gateada por
/// custom claim `admin: true` nas Firestore rules.
class AdminMetrics {
  final DateTime? sampledAt;
  final UserMetrics users;
  final OccurrenceMetrics occurrences;
  final ContestationMetrics contestations;
  final SafeArrivalMetrics safeArrivals;

  const AdminMetrics({
    required this.sampledAt,
    required this.users,
    required this.occurrences,
    required this.contestations,
    required this.safeArrivals,
  });

  factory AdminMetrics.fromMap(Map<String, dynamic> m) => AdminMetrics(
        sampledAt: _toDate(m['sampledAt']),
        users: UserMetrics.fromMap(_asMap(m['users'])),
        occurrences: OccurrenceMetrics.fromMap(_asMap(m['occurrences'])),
        contestations:
            ContestationMetrics.fromMap(_asMap(m['contestations'])),
        safeArrivals: SafeArrivalMetrics.fromMap(_asMap(m['safeArrivals'])),
      );

  factory AdminMetrics.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return AdminMetrics.fromMap(data ?? const {});
  }
}

class UserMetrics {
  final int total;
  final int anonymous;
  final int google;
  final int createdLast24h;
  final int createdLast7d;
  final int activeLast24h;
  final int activeLast7d;

  const UserMetrics({
    required this.total,
    required this.anonymous,
    required this.google,
    required this.createdLast24h,
    required this.createdLast7d,
    required this.activeLast24h,
    required this.activeLast7d,
  });

  factory UserMetrics.fromMap(Map<String, dynamic> m) => UserMetrics(
        total: _asInt(m['total']),
        anonymous: _asInt(m['anonymous']),
        google: _asInt(m['google']),
        createdLast24h: _asInt(m['createdLast24h']),
        createdLast7d: _asInt(m['createdLast7d']),
        activeLast24h: _asInt(m['activeLast24h']),
        activeLast7d: _asInt(m['activeLast7d']),
      );
}

class OccurrenceMetrics {
  final int total;
  final int last24h;
  final int last7d;
  final int contested;
  final Map<String, int> bySource;
  final Map<String, int> byState;
  final Map<String, int> byCity;
  final List<ReasonCount> topReasons;

  const OccurrenceMetrics({
    required this.total,
    required this.last24h,
    required this.last7d,
    required this.contested,
    required this.bySource,
    required this.byState,
    required this.byCity,
    required this.topReasons,
  });

  factory OccurrenceMetrics.fromMap(Map<String, dynamic> m) =>
      OccurrenceMetrics(
        total: _asInt(m['total']),
        last24h: _asInt(m['last24h']),
        last7d: _asInt(m['last7d']),
        contested: _asInt(m['contested']),
        bySource: _asIntMap(m['bySource']),
        byState: _asIntMap(m['byState']),
        byCity: _asIntMap(m['byCity']),
        topReasons: (m['topReasons'] is List)
            ? (m['topReasons'] as List)
                .whereType<Map>()
                .map((e) => ReasonCount.fromMap(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
}

class ReasonCount {
  final String reason;
  final int count;
  const ReasonCount({required this.reason, required this.count});

  factory ReasonCount.fromMap(Map<String, dynamic> m) => ReasonCount(
        reason: (m['reason'] as String?) ?? 'outros',
        count: _asInt(m['count']),
      );
}

class ContestationMetrics {
  final int total;
  final int occurrencesContested;

  const ContestationMetrics({
    required this.total,
    required this.occurrencesContested,
  });

  factory ContestationMetrics.fromMap(Map<String, dynamic> m) =>
      ContestationMetrics(
        total: _asInt(m['total']),
        occurrencesContested: _asInt(m['occurrencesContested']),
      );
}

class SafeArrivalMetrics {
  final int last24h;
  final int last7d;

  const SafeArrivalMetrics({required this.last24h, required this.last7d});

  factory SafeArrivalMetrics.fromMap(Map<String, dynamic> m) =>
      SafeArrivalMetrics(
        last24h: _asInt(m['last24h']),
        last7d: _asInt(m['last7d']),
      );
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

Map<String, dynamic> _asMap(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return const {};
}

Map<String, int> _asIntMap(Object? v) {
  if (v is! Map) return const {};
  final out = <String, int>{};
  v.forEach((k, value) {
    out[k.toString()] = _asInt(value);
  });
  return out;
}

DateTime? _toDate(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
