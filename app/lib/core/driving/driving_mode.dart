library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Perfis suportados pelo "modo direção". A escolha muda zoom, tilt,
/// se o mapa rotaciona com o heading e se a seta gira.
///
/// Princípio editorial mantido: nenhum perfil ativa alerta de voz ou
/// recomendação de rota. Modo direção é só UX (visualização em
/// movimento) — Faro continua sendo contexto, não veredito.
enum DrivingMode {
  /// Desligado — vista normal do mapa, dot azul nativo.
  off,

  /// Carro/moto — zoom 17.5, perspectiva 3D (tilt 50°), o mapa
  /// rotaciona com o heading do GPS, seta gira pra apontar pra frente
  /// da tela.
  car,

  /// Bicicleta — zoom 18, sem tilt, norte sempre pra cima, seta sem
  /// rotação. Heading de bike via GPS é ruidoso em velocidades baixas;
  /// preferimos um mapa estável que o usuário lê em paradas curtas.
  bike,
}

const _prefsKey = 'faro_driving_mode_v2';

class DrivingModeNotifier extends Notifier<DrivingMode> {
  /// Lembra o último perfil ativo (carro ou bike) pro botão flutuante
  /// conseguir alternar entre "desligado" e "último modo escolhido"
  /// sem precisar passar pela tela de seleção.
  DrivingMode _lastActive = DrivingMode.car;

  @override
  DrivingMode build() => DrivingMode.off;

  DrivingMode get lastActive => _lastActive;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final mode = _decode(saved);
    state = mode;
    if (mode != DrivingMode.off) _lastActive = mode;
  }

  Future<void> set(DrivingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
    if (mode != DrivingMode.off) _lastActive = mode;
    state = mode;
  }

  /// Tap rápido do botão flutuante: alterna entre `off` e o último
  /// perfil ativo (carro por default).
  Future<void> toggleQuick() async {
    if (state == DrivingMode.off) {
      await set(_lastActive);
    } else {
      await set(DrivingMode.off);
    }
  }

  DrivingMode _decode(String? raw) {
    switch (raw) {
      case 'car':
        return DrivingMode.car;
      case 'bike':
        return DrivingMode.bike;
      default:
        return DrivingMode.off;
    }
  }
}

final drivingModeProvider =
    NotifierProvider<DrivingModeNotifier, DrivingMode>(DrivingModeNotifier.new);
