library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Logger estruturado do Faro.
///
/// Substitui `debugPrint` espalhado pelo código. Vantagens:
/// - Níveis explícitos (debug/info/warn/error)
/// - Tag de origem (`fcm`, `bg_location`, `analytics`, etc.) — fácil
///   filtrar quando o app cresce
/// - Erros graves automaticamente reportados ao Crashlytics em release
/// - Debug nunca polui console em release
///
/// Uso:
///   import 'package:projeto_seg/core/log/faro_logger.dart';
///   final log = FaroLogger('fcm');
///   log.info('subscribed to $topic');
///   log.warn('apns token ausente após retry');
///   log.error('falha enviando push', e, st);
class FaroLogger {
  /// Tag de origem. Convenção: minúsculas com underscore.
  final String tag;
  const FaroLogger(this.tag);

  /// Detalhe de execução. Só aparece em debug build — totalmente
  /// descartado em release pra não vazar info nem custar performance.
  void debug(String message) {
    if (!kDebugMode) return;
    debugPrint('[$tag] $message');
  }

  /// Evento esperado e relevante (ex.: "FCM inscrito em region_abcde").
  /// Aparece no console em debug. Em release fica silencioso a menos
  /// que você decida mandar pra um backend de logs no futuro.
  void info(String message) {
    if (kDebugMode) debugPrint('[$tag/info] $message');
  }

  /// Algo degradado mas não-crítico (ex.: "APNS demorou, retry").
  /// Em release manda como `log` no Crashlytics (não conta como erro,
  /// mas vira contexto se um erro real estourar logo depois).
  void warn(String message) {
    if (kDebugMode) {
      debugPrint('[$tag/warn] $message');
    } else {
      FirebaseCrashlytics.instance.log('[$tag/warn] $message');
    }
  }

  /// Falha real. Em debug printa stacktrace; em release reporta
  /// pro Crashlytics como erro não-fatal (não derruba o app, mas vira
  /// issue rastreável no console).
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[$tag/error] $message · $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
      return;
    }
    FirebaseCrashlytics.instance.recordError(
      error ?? message,
      stackTrace,
      reason: '[$tag] $message',
    );
  }
}
