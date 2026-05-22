import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/faro_logger.dart';
import 'local_notification_service.dart';

/// Gerencia FCM: permissão, token e subscription por região (geohash5).
///
/// Estratégia topic-based: o app calcula geohash5 baseado na localização
/// atual e assina o tópico `region_{geohash5}`. Quando ocorrência nova
/// entra em Firestore, Cloud Function onOccurrenceCreated publica nesse
/// tópico → todos inscritos recebem push.
///
/// Limitações:
/// - Granularidade ~5km (precisão geohash 5)
/// - Sem segmentação fina dentro da célula
/// - Persistência da subscription depende do FCM service do device
class MessagingService {
  static const _lastTopicKey = 'fcm_last_topic_v1';
  static const _log = FaroLogger('fcm');

  /// Pede permissão pra notificações.
  /// Retorna true se autorizado (full ou provisional).
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      
    );
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    _log.info('permission: ${settings.authorizationStatus}');
    return ok;
  }

  /// Status atual da permissão (sem prompt).
  Future<bool> isAuthorized() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Assina o tópico da região (geohash5). Se já estava em outro tópico,
  /// desassina antes pra evitar receber pushes de área antiga.
  Future<void> subscribeToRegion(String geohash5) async {
    if (geohash5.length < 5) return;
    final topic = 'region_$geohash5';

    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastTopicKey);

    if (last == topic) return; // já inscrito

    final fcm = FirebaseMessaging.instance;
    if (last != null && last.isNotEmpty) {
      try {
        await fcm.unsubscribeFromTopic(last);
      } catch (e, s) {
        _log.error('unsubscribe falhou', e, s);
      }
    }

    try {
      await fcm.subscribeToTopic(topic);
      await prefs.setString(_lastTopicKey, topic);
      _log.info('subscribed to $topic');
    } catch (e, s) {
      _log.error('subscribe falhou', e, s);
    }
  }

  /// Wrappers públicos pros outros services (ex.: ReferenceLocationService)
  /// que precisam assinar tópicos próprios sem replicar tratamento de erro.
  Future<void> subscribeToTopic(String topic) async {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }

  /// iOS precisa de APNS token resolvido antes de assinar tópicos.
  Future<bool> _hasApnsToken() async {
    if (!Platform.isIOS) return true;
    final token = await FirebaseMessaging.instance.getAPNSToken();
    return token != null;
  }

  /// Inicialização: pede permissão se ainda não tem, espera APNS no iOS,
  /// e registra handler de mensagem em foreground (FCM, por padrão, não
  /// exibe notificação quando o app está aberto — é responsabilidade do
  /// app interceptar e mostrar via notificação local).
  Future<bool> initialize() async {
    final ok = await requestPermission();
    if (!ok) return false;
    if (!await _hasApnsToken()) {
      // iOS: APNS pode demorar; tenta uma vez mais com delay curto
      await Future.delayed(const Duration(seconds: 1));
      if (!await _hasApnsToken()) return false;
    }
    _registerForegroundHandler();
    return true;
  }

  /// Variante silenciosa do `initialize`: não pede permissão se ainda
  /// não foi autorizado. Só registra o foreground handler quando já
  /// existe permissão. Usado no boot do app pra garantir que pushes
  /// chegando com o app aberto sejam materializados como notif local
  /// — sem disparar prompt de permissão no primeiro launch.
  Future<void> ensureForegroundHandlerIfAuthorized() async {
    if (!await isAuthorized()) return;
    _registerForegroundHandler();
  }

  bool _foregroundHandlerRegistered = false;

  void _registerForegroundHandler() {
    if (_foregroundHandlerRegistered) return;
    _foregroundHandlerRegistered = true;
    FirebaseMessaging.onMessage.listen((message) async {
      // App em foreground: sistema não exibe notif automaticamente. Em
      // vez disso, mostramos uma notif local com o mesmo conteúdo.
      final notif = message.notification;
      if (notif == null) return;
      try {
        final data = message.data.map(
          (k, v) => MapEntry(k, v?.toString() ?? ''),
        );
        await LocalNotificationService.instance.showFromPush(
          title: notif.title ?? 'Faro · novo relato',
          body: notif.body ?? '',
          dataPayload: data,
        );
      } catch (e) {
        _log.error('foreground notif falhou', e);
      }
    });
  }
}

/// Calcula geohash precisão 5 de uma coordenada. Implementação simples
/// (não depende de pacote externo).
String geohash5Of(double lat, double lng) {
  const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  double minLat = -90, maxLat = 90;
  double minLng = -180, maxLng = 180;
  bool even = true;
  int bit = 0;
  int ch = 0;
  final result = StringBuffer();
  while (result.length < 5) {
    if (even) {
      final mid = (minLng + maxLng) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        minLng = mid;
      } else {
        maxLng = mid;
      }
    } else {
      final mid = (minLat + maxLat) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        minLat = mid;
      } else {
        maxLat = mid;
      }
    }
    even = !even;
    if (bit < 4) {
      bit++;
    } else {
      result.write(base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return result.toString();
}
