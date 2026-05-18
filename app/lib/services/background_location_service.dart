import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/faro_logger.dart';
import '../models/crossing_event.dart';
import '../models/occurrence.dart';
import 'crossing_history_service.dart';
import 'local_notification_service.dart';
import 'messaging_service.dart';

/// Tracking de localização em background pra alertas estilo Waze.
///
/// Estratégia:
/// - Stream com filtro de distância 500m (config decidida com o usuário).
/// - A cada update, calcula geohash5; se mudou, reasssina o tópico FCM
///   da nova célula e dispara catch-up.
/// - Catch-up consulta Firestore por relatos < 6h na nova célula. Se
///   houver, mostra notificação local.
///
/// Lifecycle:
/// - Só inicia se o usuário tiver opt-in explícito (kBackgroundEnabledKey).
/// - Resiliente a falhas: erros no stream não derrubam o app, apenas
///   pausam o tracking até próximo resume.
class BackgroundLocationService {
  BackgroundLocationService._({
    MessagingService? messaging,
    LocalNotificationService? notifier,
    CrossingHistoryService? history,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? MessagingService(),
        _notifier = notifier ?? LocalNotificationService.instance,
        _history = history ?? CrossingHistoryService.instance,
        _firestoreOverride = firestore;

  static final BackgroundLocationService instance = BackgroundLocationService._();
  static const _log = FaroLogger('bg_location');

  /// SharedPreferences key — usuário escolheu opt-in no fluxo de permissão.
  static const String kBackgroundEnabledKey = 'bg_location_enabled_v1';
  static const String _lastGeohashKey = 'bg_last_geohash5_v1';

  static const double _distanceFilterMeters = 500;
  /// Janela ampliada pra 24h porque o catch-up agora popula o histórico
  /// pós-fato — usuário vê o que **aconteceu** durante o dia mesmo se a
  /// matéria saiu de manhã sobre um evento de madrugada.
  static const Duration _catchUpWindow = Duration(hours: 24);
  static const int _catchUpMinCount = 1;

  final MessagingService _messaging;
  final LocalNotificationService _notifier;
  final CrossingHistoryService _history;
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionSub;
  String? _lastGeohash5;
  bool _running = false;

  bool get isRunning => _running;

  /// Marca opt-in do usuário. Não inicia tracking sozinho — chamador
  /// chama [start] em seguida (ou no próximo resume).
  static Future<void> setOptIn(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBackgroundEnabledKey, enabled);
  }

  static Future<bool> isOptedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBackgroundEnabledKey) ?? false;
  }

  /// Inicia o stream. Idempotente — chamadas repetidas são no-op se já
  /// está rodando. Verifica opt-in e permissões antes de subscrever.
  Future<bool> start() async {
    if (_running) return true;
    if (!await isOptedIn()) return false;

    final perm = await Geolocator.checkPermission();
    final hasBackground = perm == LocationPermission.always;
    if (!hasBackground) {
      _log.warn('sem permissão Always, abortando');
      return false;
    }

    // Recupera último geohash conhecido pra dedupe entre cold starts.
    final prefs = await SharedPreferences.getInstance();
    _lastGeohash5 = prefs.getString(_lastGeohashKey);

    final settings = _buildLocationSettings();

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object e, StackTrace s) {
        _log.error('stream erro', e, s);
      },
      cancelOnError: false,
    );

    _running = true;
    _log.info('iniciado');
    return true;
  }

  /// Pausa o stream. Não limpa o opt-in nem o último geohash.
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _running = false;
    _log.info('parado');
  }

  Future<void> _onPosition(Position pos) async {
    final gh5 = geohash5Of(pos.latitude, pos.longitude);
    if (gh5 == _lastGeohash5) return; // mesma célula, nada a fazer

    _log.debug('geohash mudou: $_lastGeohash5 → $gh5');

    final previousGh = _lastGeohash5;
    _lastGeohash5 = gh5;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGeohashKey, gh5);

    // Reassina tópico FCM da nova célula.
    try {
      await _messaging.subscribeToRegion(gh5);
    } catch (e, s) {
      _log.error('resubscribe falhou', e, s);
    }

    // Catch-up: consulta Firestore por relatos recentes na nova célula.
    // Pula no primeiro update (sem geohash anterior) pra evitar notif
    // ruidosa no cold start — usuário já tem o banner no app quando abrir.
    if (previousGh == null) return;
    await _catchUp(gh5);
  }

  /// Sentinel do Firestore pra range query "começa com prefixo".
  ///  é o último ponto Unicode da Private Use Area — qualquer
  /// geohash8 cujo prefixo bate vai estar na faixa [gh5, gh5+sentinel).
  /// NÃO trocar por '~' ou 'z' (ambos colidem com chars válidos do
  /// alfabeto base32 do geohash). Ver:
  /// https://firebase.google.com/docs/firestore/query-data/queries#range_and_inequality_filters
  static const String _firestorePrefixSentinel = '';

  Future<void> _catchUp(String geohash5) async {
    final cutoff = DateTime.now().subtract(_catchUpWindow);
    try {
      // Range query por prefixo de geohash. Os docs gravam geohash precisão 8;
      // qualquer doc cuja precisão-5 == nossa cai no range [gh5, gh5+''].
      final snap = await _firestore
          .collection('occurrences')
          .where('geohash', isGreaterThanOrEqualTo: geohash5)
          .where('geohash', isLessThan: '$geohash5$_firestorePrefixSentinel')
          .limit(50)
          .get();

      final recent = snap.docs
          .map(Occurrence.fromFirestore)
          .where((o) => o.date.isAfter(cutoff))
          .toList();

      if (recent.length < _catchUpMinCount) return;

      // Bairro mais frequente nos relatos (pra contextualizar a notif).
      final bairro = _mostCommonBairro(recent);
      final cidade = _mostCommonCity(recent);
      final topReasons = _topReasons(recent);

      final event = CrossingEvent(
        id: DateTime.now().millisecondsSinceEpoch,
        at: DateTime.now(),
        neighborhood: bairro,
        city: cidade,
        reportCount: recent.length,
        topReasons: topReasons,
        occurrenceIds: recent.map((o) => o.id).take(20).toList(),
      );

      // tryRecord aplica dedupe (mesmo bairro/dia) e limite diário (5).
      // Se retornar false, NÃO disparamos notif — usuário já viu/teve
      // ruído suficiente desse bairro hoje.
      final recorded = await _history.tryRecord(event);
      if (!recorded) return;

      await _notifier.showProximityCatchUp(
        count: recent.length,
        bairro: bairro,
      );
    } catch (e, s) {
      _log.error('catch-up falhou', e, s);
    }
  }

  String? _mostCommonCity(List<Occurrence> list) {
    final counts = <String, int>{};
    for (final o in list) {
      final c = o.city;
      if (c == null || c.isEmpty) continue;
      counts[c] = (counts[c] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  List<String> _topReasons(List<Occurrence> list) {
    final counts = <String, int>{};
    for (final o in list) {
      final r = o.mainReason;
      if (r == null || r.isEmpty) continue;
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  String? _mostCommonBairro(List<Occurrence> list) {
    final counts = <String, int>{};
    for (final o in list) {
      final b = o.neighborhood;
      if (b == null || b.isEmpty) continue;
      counts[b] = (counts[b] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  LocationSettings _buildLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _distanceFilterMeters.toInt(),
        intervalDuration: const Duration(minutes: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Faro está atento à sua região',
          notificationText:
              'Avisa se aparecerem relatos próximos. Toque para abrir.',
          enableWakeLock: true,
          notificationChannelName: 'Faro background',
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _distanceFilterMeters.toInt(),
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: _distanceFilterMeters.toInt(),
    );
  }
}
