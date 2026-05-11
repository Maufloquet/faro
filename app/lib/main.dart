import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/dev_data_source.dart';
import 'services/occurrences_service.dart';

/// Modo dev: lê ocorrências do asset local, sem precisar de Firebase.
/// Default agora é FALSE — o app usa Firestore real. Pra rodar offline com
/// snapshot histórico (assets/dev_occurrences.json), use:
///   flutter run --dart-define=USE_DEV_DATA=true
const bool kUseDevAssetData = bool.fromEnvironment('USE_DEV_DATA', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kUseDevAssetData) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
  } else if (kDebugMode) {
    debugPrint('[Faro] modo dev: lendo ocorrências de assets/, sem Firebase.');
  }

  runApp(ProviderScope(
    overrides: kUseDevAssetData
        ? [recentOccurrencesProvider.overrideWith((_) => devOccurrencesStream())]
        : const [],
    child: const FaroApp(),
  ));
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
      home: const SplashScreen(),
    );
  }
}
