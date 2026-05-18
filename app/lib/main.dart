import 'dart:async';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/analytics_service.dart';
import 'services/background_location_service.dart';
import 'services/density_service.dart';
import 'services/dev_data_source.dart';
import 'services/local_notification_service.dart';
import 'services/occurrences_service.dart';

/// Modo dev: lê ocorrências do asset local, sem precisar de Firebase.
/// Default agora é FALSE — o app usa Firestore real. Pra rodar offline com
/// snapshot histórico (assets/dev_occurrences.json), use:
///   flutter run --dart-define=USE_DEV_DATA=true
const bool kUseDevAssetData = bool.fromEnvironment('USE_DEV_DATA', defaultValue: false);

Future<void> main() async {
  // runZonedGuarded captura erros async fora do framework. Crashlytics
  // só ativa em release — debug usa o console normal.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kUseDevAssetData) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

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
        } catch (e) {
          if (kDebugMode) debugPrint('[Faro] anonymous sign-in falhou: $e');
        }
      }

      // Notificações locais (canal + permissão pré-checada). O prompt de
      // permissão só é disparado no toggle do /sobre/.
      await LocalNotificationService.instance.initialize();

      // Camada 7 — densidade populacional por bairro. Carrega asset JSON
      // pra normalizar "relatos por 10k habitantes". Falha silenciosa: se
      // o asset não carregar, populationFor retorna null e a UI esconde.
      unawaited(DensityService.instance.initialize().catchError((Object e) {
        if (kDebugMode) debugPrint('[Faro] density init falhou: $e');
      }));

      // Background location tracking: só inicia se o usuário já fez opt-in
      // numa sessão anterior. Caso contrário fica dormindo até toggle no
      // /sobre/. Roda em fire-and-forget pra não atrasar o boot.
      unawaited(_resumeBackgroundTracking());
    } else if (kDebugMode) {
      debugPrint('[Faro] modo dev: lendo ocorrências de assets/, sem Firebase.');
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
      debugPrint('[Faro] unhandled zone error: $error\n$stack');
    }
  });
}

Future<void> _resumeBackgroundTracking() async {
  try {
    if (await BackgroundLocationService.isOptedIn()) {
      await BackgroundLocationService.instance.start();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Faro] resume bg tracking falhou: $e');
  }
}

class FaroApp extends StatelessWidget {
  const FaroApp({super.key});

  @override
  Widget build(BuildContext context) {
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
