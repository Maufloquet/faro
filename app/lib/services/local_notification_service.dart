import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificações locais (não-FCM). Disparadas pelo BackgroundLocationService
/// quando o usuário entra em região com relatos ativos recentes.
///
/// Copy editorial: nunca "perigo", "evite", "área perigosa". Sempre fatos
/// contáveis + contexto temporal. Decisão fica com o usuário.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _channelId = 'faro_proximity';
  static const String _channelName = 'Alertas de proximidade';
  static const String _channelDescription =
      'Avisa quando você se aproxima de regiões com relatos recentes.';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  /// Pede permissão de notificação no iOS (Android 13+ é tratado via
  /// POST_NOTIFICATIONS no manifest e prompt do sistema).
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Exibe notificação derivada de um push FCM recebido em foreground.
  /// O sistema operacional não exibe notif do FCM quando o app está
  /// aberto, então recriamos via canal local com o mesmo conteúdo.
  Future<void> showFromPush({
    required String title,
    required String body,
    Map<String, String>? dataPayload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Faro',
      category: AndroidNotificationCategory.status,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // ID estável por payload pra evitar duplicar quando o mesmo push
    // chega mais de uma vez (raro, mas FCM pode retry).
    final id = (dataPayload?['occurrenceId'] ?? body).hashCode & 0x7fffffff;

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: dataPayload?['occurrenceId'] ?? 'fcm_foreground',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Faro] notif foreground falhou: $e');
    }
  }

  /// Dispara notif de proximidade. [count] é número de relatos próximos
  /// nas últimas 6h. Copy é deliberadamente factual.
  Future<void> showProximityCatchUp({
    required int count,
    String? bairro,
  }) async {
    if (count <= 0) return;
    await initialize();

    final title = count == 1
        ? '1 relato próximo a você'
        : '$count relatos próximos a você';

    final scope = bairro != null && bairro.isNotEmpty ? ' em $bairro' : '';
    final body = 'Nas últimas 6h$scope. Toque para ver no mapa.';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Faro',
      category: AndroidNotificationCategory.status,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    try {
      await _plugin.show(
        // ID estável por hora — evita spam se o catch-up dispara várias
        // vezes em sequência (ex: usuário oscilando perto da borda).
        DateTime.now().hour,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: 'proximity_catchup',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Faro] local notif falhou: $e');
    }
  }
}
