import 'package:flutter/material.dart';

import '../core/design/tokens.dart';

/// Botão flutuante circular usado na coluna direita do mapa
/// (Camadas, Localizar, Modo direção). Centraliza o tratamento de
/// sombra editorial, borda interna sutil e estados ativo/inativo
/// pra todos os botões manterem a mesma linguagem visual.
///
/// Diferenças vs FAB padrão do Material:
/// - Sombra colorida (azul Faro semi-transparente) em vez de preta —
///   mais editorial, menos "Google Maps copy-paste"
/// - Borda interna fina pra dar peso e contraste contra qualquer fundo
///   de satélite/rua
/// - Ripple respeita a paleta (FaroColors.primary)
class MapFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;

  /// Tamanho geral do botão (diâmetro). Default 44dp; pode subir pra
  /// 56 quando for um botão prioritário (modo direção).
  final double size;

  /// Tamanho do ícone dentro.
  final double iconSize;

  const MapFloatingButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? FaroColors.primary : Colors.white;
    final fg = active ? Colors.white : FaroColors.primary;

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          // Sombra editorial: tom da primary, não preto puro.
          BoxShadow(
            color: FaroColors.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        // Borda interna fina — dá peso visual e separa do fundo de mapa.
        border: Border.all(
          color: active
              ? FaroColors.primary.withValues(alpha: 0.0)
              : FaroColors.sandBorder.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          splashColor: fg.withValues(alpha: 0.10),
          highlightColor: fg.withValues(alpha: 0.05),
          child: Center(
            child: Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
