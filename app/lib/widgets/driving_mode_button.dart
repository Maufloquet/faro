import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';

/// Botão flutuante de "Modo direção". Maior que os botões irmãos
/// (Layers/Locate) — Fitts' Law: alvo grande pra polegar de motorista,
/// e contraste forte (cor primary quando ativo) pra leitura periférica.
class DrivingModeButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const DrivingModeButton({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: FaroStrings.menuDrivingMode,
      child: Material(
        color: active ? FaroColors.primary : Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              active ? Icons.directions_car : Icons.directions_car_outlined,
              size: 26,
              color: active ? Colors.white : FaroColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
