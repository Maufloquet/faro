library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faro_strings.dart';

const _prefsKey = 'faro_locale_override_v1';

/// Estado do idioma do app — `null` significa automático (segue o
/// `platformDispatcher.locale`); valores possíveis: 'pt' | 'en' | 'es'.
class LocaleState {
  final String? override;
  const LocaleState({this.override});

  LocaleState copyWith({String? Function()? override}) =>
      LocaleState(override: override == null ? this.override : override());
}

class LocaleNotifier extends Notifier<LocaleState> {
  @override
  LocaleState build() {
    // Aplica o estado inicial sincronamente (lido no boot via [bootstrap]),
    // mas o build do Notifier não tem await — então mantemos um valor
    // padrão e o main.dart chama [bootstrap] antes de runApp.
    return const LocaleState();
  }

  /// Lê a escolha persistida e aplica em [FaroStrings]. Chamar uma vez
  /// no boot, antes do primeiro frame.
  Future<void> bootstrap(Locale deviceLocale) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = LocaleState(override: saved);
    FaroStrings.init(deviceLocale, override: saved);
  }

  /// Troca o idioma. [code] = null restaura o automático.
  Future<void> set(String? code, Locale deviceLocale) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, code);
    }
    state = LocaleState(override: code);
    FaroStrings.init(deviceLocale, override: code);
  }
}

final localeNotifierProvider =
    NotifierProvider<LocaleNotifier, LocaleState>(LocaleNotifier.new);
