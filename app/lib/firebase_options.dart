// File generated automatically by FlutterFire CLI.
// PLACEHOLDER — substituir rodando `flutterfire configure` após criar o
// projeto Firebase no Console (https://console.firebase.google.com).
//
// Steps:
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure --project=<seu-project-id>
//
// O comando vai sobrescrever este arquivo com IDs reais.

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _placeholder('android');
      case TargetPlatform.iOS:
        return _placeholder('ios');
      default:
        throw UnsupportedError(
          'Plataforma não suportada. Rode `flutterfire configure` para gerar este arquivo.',
        );
    }
  }

  static FirebaseOptions _placeholder(String platform) => FirebaseOptions(
        apiKey: 'PLACEHOLDER_API_KEY',
        appId: 'PLACEHOLDER_APP_ID_$platform',
        messagingSenderId: '000000000000',
        projectId: 'projeto-seg-placeholder',
        storageBucket: 'projeto-seg-placeholder.appspot.com',
      );
}
