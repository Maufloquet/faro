library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado do "modo direção": preferência persistida do usuário pra
/// quando estiver dirigindo / em movimento. Não força nada — só sinaliza
/// pra UI ajustar zoom, seguir o GPS e simplificar a tela.
///
/// Princípio editorial: NÃO transformamos isso em alerta antecipado de
/// voz ou recomendação de rota. Faro continua sendo contexto, não
/// veredito — modo direção é UX, não nova classe de mensagem.
const _prefsKey = 'faro_driving_mode_v1';

class DrivingModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    state = value;
  }

  Future<void> toggle() => set(!state);
}

final drivingModeProvider =
    NotifierProvider<DrivingModeNotifier, bool>(DrivingModeNotifier.new);
