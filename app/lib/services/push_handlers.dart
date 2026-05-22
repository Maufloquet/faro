import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/log/faro_logger.dart';
import '../firebase_options.dart';

/// Handlers de notificação fora do foreground. Centralizamos pra
/// main.dart ficar legível e pro top-level handler ter um lugar
/// óbvio onde morar (precisa ser top-level pra rodar em isolate
/// separado quando o app está killed).
///
/// Pipeline:
///   1. Background (app killed/suspended): `onBackgroundMessage`
///      dispara o `_backgroundHandler` em isolate isolado. O SO já
///      mostra a notif visual; aqui só processamos data payload
///      (analytics, dedupe, dados pra deep link no próximo open).
///   2. Tap quando killed: `getInitialMessage` (chamado depois do
///      Firebase.initializeApp em main).
///   3. Tap quando background → foreground: `onMessageOpenedApp`.
///   4. Foreground: `MessagingService._registerForegroundHandler`.

const _log = FaroLogger('push');

/// Top-level handler — Flutter exige top-level (não pode ser método
/// de classe nem closure) pra background isolate. NÃO chame UI daqui;
/// o isolate não tem `BuildContext` nem providers.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // O isolate de background é cold start — precisamos inicializar
  // Firebase do zero se quisermos ler/escrever Firestore daqui.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // initializeApp pode lançar "duplicate-app" se outra rota já fez.
    // Não impede o resto do handler de rodar.
    if (kDebugMode) _log.debug('background firebase init: $e');
  }
  final notif = message.notification;
  _log.info(
    'background push '
    'msgId=${message.messageId} '
    'topic=${message.from} '
    'hasNotif=${notif != null} '
    'data=${message.data}',
  );
  // Sistema já desenha a notif (vem com `notification` payload do
  // server). Mantemos handler vazio do ponto de vista de UI — função
  // existente apenas pra garantir que data payload não é descartado.
}

/// Registrado depois do Firebase.initializeApp em main(). Cobre os 2
/// cenários de "usuário tocou na notif e abriu o app":
///   - `getInitialMessage`: app estava killed; mensagem que abriu fica
///     pendurada e pega aqui.
///   - `onMessageOpenedApp`: app estava em background e veio pro front
///     via tap na notif.
///
/// O callback recebe `data` payload (ex: occurrenceId, geohash5) pra
/// um futuro deep link abrir o detail do relato. Por enquanto só loga
/// — fluxo de navegação fica pra UX de deep link em sessão própria.
Future<void> bindPushOpenHandlers({
  required void Function(RemoteMessage) onOpen,
}) async {
  try {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _log.info('app aberto por push · ${initial.messageId}');
      onOpen(initial);
    }
  } catch (e, s) {
    _log.error('getInitialMessage falhou', e, s);
  }

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _log.info('push tap em background · ${message.messageId}');
    onOpen(message);
  });
}
