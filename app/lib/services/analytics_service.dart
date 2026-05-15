import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../models/occurrence.dart';

enum OccurrenceOpenEntry {
  marker,
  list,
  proximityBanner;

  String get tag {
    switch (this) {
      case OccurrenceOpenEntry.marker:
        return 'marker';
      case OccurrenceOpenEntry.list:
        return 'list';
      case OccurrenceOpenEntry.proximityBanner:
        return 'proximity_banner';
    }
  }
}

/// Wrapper editorial pro Firebase Analytics.
///
/// Princípio: **nada de PII** vai pra Analytics. Sem coordenadas, sem endereços,
/// sem IDs de relato. Só métricas de uso agregadas:
/// - retenção D1/D7/D30 (auto via session_start do Firebase)
/// - screen_view (manual via logScreen)
/// - occurrence_open: fonte + bucket de recência + entry (sem id, sem geo)
/// - filter_applied: tipo de filtro (sem valores sensíveis)
/// - max_zoom: arredondado, sem coordenadas
///
/// Em debug não envia — evita poluir métricas com sessões de dev.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  FirebaseAnalytics get raw => _analytics;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  bool get _enabled => !kDebugMode;

  Future<void> logScreen(String name) async {
    if (!_enabled) return;
    await _analytics.logScreenView(screenName: name);
  }

  Future<void> occurrenceOpen({
    required OccurrenceOpenEntry entry,
    required OccurrenceSource source,
    required Duration age,
  }) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'occurrence_open',
      parameters: {
        'entry': entry.tag,
        'source': source.name,
        'age_bucket': _ageBucket(age),
      },
    );
  }

  Future<void> filterApplied({required String kind, String? value}) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'filter_applied',
      parameters: {
        'kind': kind,
        // ignore: use_null_aware_elements — parameters require non-null values
        if (value != null) 'value': value,
      },
    );
  }

  Future<void> maxZoomReached(double zoom) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'max_zoom',
      parameters: {'zoom': zoom.round()},
    );
  }

  Future<void> proximityAlertShown(int count) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'proximity_alert_shown',
      parameters: {'count': count.clamp(1, 50)},
    );
  }

  Future<void> proximityAlertTapped() async {
    if (!_enabled) return;
    await _analytics.logEvent(name: 'proximity_alert_tapped');
  }

  String _ageBucket(Duration age) {
    if (age.inHours < 6) return '0-6h';
    if (age.inHours < 24) return '6-24h';
    if (age.inDays < 7) return '1-7d';
    if (age.inDays < 30) return '7-30d';
    return '30d+';
  }
}
