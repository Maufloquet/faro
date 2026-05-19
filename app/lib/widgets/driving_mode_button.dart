import 'package:flutter/material.dart';

import '../core/driving/driving_mode.dart';
import '../core/i18n/faro_strings.dart';
import 'map_floating_button.dart';

/// Botão flutuante de "Modo direção". Maior que os botões irmãos
/// (Layers/Locate) — Fitts' Law: alvo grande pra polegar de motorista,
/// e contraste forte (cor primary quando ativo) pra leitura periférica.
/// O ícone muda conforme o perfil ativo (carro/bike) — quando off,
/// mostra carro outline como default.
class DrivingModeButton extends StatelessWidget {
  final DrivingMode mode;
  final VoidCallback onTap;
  const DrivingModeButton({super.key, required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = mode != DrivingMode.off;
    final iconData = switch (mode) {
      DrivingMode.car => Icons.directions_car,
      DrivingMode.bike => Icons.directions_bike,
      DrivingMode.off => Icons.directions_car_outlined,
    };
    final tooltip = switch (mode) {
      DrivingMode.car => FaroStrings.drivingCar,
      DrivingMode.bike => FaroStrings.drivingBike,
      DrivingMode.off => FaroStrings.menuDrivingMode,
    };
    return MapFloatingButton(
      icon: iconData,
      active: active,
      onTap: onTap,
      tooltip: tooltip,
      size: 56,
      iconSize: 26,
    );
  }
}
