import 'dart:async';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/driving/driving_mode.dart';
import 'core/i18n/faro_strings.dart';
import 'core/i18n/locale_notifier.dart';
import 'core/log/faro_logger.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/analytics_service.dart';
import 'services/background_location_service.dart';
import 'services/density_service.dart';
import 'services/dev_data_source.dart';
import 'services/favorites_service.dart';
import 'services/local_notification_service.dart';
import 'services/messaging_service.dart';
import 'services/occurrences_service.dart';
import 'services/push_handlers.dart';
import 'services/reference_location_service.dart';

/// Modo dev: lê ocorrências do asset local, sem precisar de Firebase.
/// Default agora é FALSE — o app usa Firestore real. Pra rodar offline com
/// snapshot histórico (assets/dev_occurrences.json), use:
///   flutter run --dart-define=USE_DEV_DATA=true
const bool kUseDevAssetData = bool.fromEnvironment('USE_DEV_DATA');

const _log = FaroLogger('main');

Future<void> main() async {
  // runZonedGuarded captura erros async fora do framework. Crashlytics
  // só ativa em release — debug usa o console normal.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Tradução: inicializa com o locale do device antes do primeiro frame
    // pra evitar flicker. A escolha persistida (se houver) é aplicada logo
    // depois via LocaleNotifier.bootstrap (já dentro do ProviderScope).
    FaroStrings.init(
      WidgetsBinding.instance.platformDispatcher.locale,
    );

    if (!kUseDevAssetData) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Handler de push em background isolate. PRECISA ser registrado
      // antes de qualquer outro setup FCM — quando o app está killed,
      // o isolate de background usa essa referência pra invocar o
      // handler top-level em `push_handlers.dart`. Sem isso, notifs
      // de proximidade não geram analytics nem registro local.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
        Isolate.current.addErrorListener(RawReceivePort((pair) async {
          final errorAndStacktrace = pair as List<dynamic>;
          await FirebaseCrashlytics.instance.recordError(
            errorAndStacktrace.first,
            errorAndStacktrace.last is StackTrace
                ? errorAndStacktrace.last as StackTrace
                : null,
            fatal: true,
          );
        }).sendPort);
      }

      // Cache offline do Firestore: usuário sem sinal ainda vê os últimos
      // dados sincronizados. Útil em túneis, áreas com 3G fraco, ou pra
      // economizar mobile data. Persistência ilimitada — Firestore gerencia.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      // Anonymous auth: usuário sem cadastro mas com UID estável. Necessário
      // pras escritas em /contestations/ (e futuramente /reports/). UID
      // persiste entre opens — não cria sessão nova a cada cold start.
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
        } catch (e, s) {
          _log.error('anonymous sign-in falhou', e, s);
        }
      }

      // Notificações locais (canal + permissão pré-checada). O prompt de
      // permissão só é disparado no toggle do /sobre/.
      await LocalNotificationService.instance.initialize();

      // Handlers de tap em notif que abriu o app (killed → open ou
      // background → foreground). Por enquanto só loga; quando tivermos
      // deep link pra detail da ocorrência, este callback navega.
      unawaited(bindPushOpenHandlers(onOpen: (_) {}));

      // Foreground handler: quando o app está aberto e chega push, o
      // sistema não desenha a notif sozinho. Materializamos como notif
      // local com o mesmo copy. Só registra se permissão já foi dada
      // antes — não dispara prompt no boot.
      unawaited(MessagingService().ensureForegroundHandlerIfAuthorized());

      // Camada 7 — densidade populacional por bairro. Carrega asset JSON
      // pra normalizar "relatos por 10k habitantes". Falha silenciosa: se
      // o asset não carregar, populationFor retorna null e a UI esconde.
      unawaited(DensityService.instance.initialize().catchError((Object e) {
        _log.error('density init falhou', e);
      }));

      // Background location tracking: só inicia se o usuário já fez opt-in
      // numa sessão anterior. Caso contrário fica dormindo até toggle no
      // /sobre/. Roda em fire-and-forget pra não atrasar o boot.
      unawaited(_resumeBackgroundTracking());

      // Local de referência (turista/casa): re-assina o tópico FCM do
      // ponto salvo. FCM pode perder a subscription se o device ficou
      // muito tempo offline, então re-afirmamos no boot.
      unawaited(ReferenceLocationService.instance.resumeOnBoot());

      // Quando o usuário faz login com Google (não-anônimo), puxamos
      // o local de referência + favoritos salvos em outro device.
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && !user.isAnonymous) {
          unawaited(ReferenceLocationService.instance.pullFromCloud());
          unawaited(FavoritesService.instance.pullFromCloud());
        }
      });
    } else {
      _log.debug('modo dev: lendo ocorrências de assets/, sem Firebase.');
    }

    runApp(ProviderScope(
      overrides: kUseDevAssetData
          ? [recentOccurrencesProvider.overrideWith((_) => devOccurrencesStream())]
          : const [],
      child: const FaroApp(),
    ));
  }, (error, stack) {
    if (!kDebugMode && !kUseDevAssetData) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      // Em debug, deixa o erro escalar pro console.
      _log.error('unhandled zone error', error, stack);
    }
  });
}

Future<void> _resumeBackgroundTracking() async {
  try {
    if (await BackgroundLocationService.isOptedIn()) {
      await BackgroundLocationService.instance.start();
    }
  } catch (e, s) {
    _log.error('resume bg tracking falhou', e, s);
  }
}

class FaroApp extends ConsumerStatefulWidget {
  const FaroApp({super.key});

  @override
  ConsumerState<FaroApp> createState() => _FaroAppState();
}

class _FaroAppState extends ConsumerState<FaroApp> {
  @override
  void initState() {
    super.initState();
    // Bootstrap do override persistido. Fire-and-forget: o FaroStrings já
    // foi inicializado sincronamente com o locale do device em main(),
    // então a UI sobe traduzida; quando o prefs resolver, o notifier dispara
    // rebuild se o override divergir do device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(localeNotifierProvider.notifier)
          .bootstrap(WidgetsBinding.instance.platformDispatcher.locale);
      ref.read(drivingModeProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    // O watch garante rebuild quando o usuário troca de idioma — toda a
    // árvore (incluindo as telas via Navigator) recria com strings novas.
    ref.watch(localeNotifierProvider);
    return MaterialApp(
      title: 'Faro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      navigatorObservers: kUseDevAssetData ? const [] : [AnalyticsService.observer],
      home: const SplashScreen(),
    );
  }
}
