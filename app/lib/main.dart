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
