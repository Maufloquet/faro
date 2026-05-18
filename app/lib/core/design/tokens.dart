library;

import 'package:flutter/material.dart';

/// Tokens de design — fonte única da verdade pra cores, espaçamentos, raios
/// e tipografia editorial. **Sempre** referenciar daqui, nunca hardcodar
/// `Color(0xFF...)` ou números mágicos em widgets.
///
/// Mudou a paleta? Mudou aqui, app inteiro segue. Esse é o ponto.
class FaroColors {
  FaroColors._();

  // ─── Primárias editoriais ──────────────────────────────────────────────
  /// Azul institucional Faro — botões primários, CTA, headers, ícones de
  /// destaque. Foi a cor que mais aparecia hardcoded antes desses tokens.
  static const Color primary = Color(0xFF2A4A7A);

  /// Variante mais escura pra estados pressionados / fundo de overlays.
  static const Color primaryDeep = Color(0xFF1F3A60);

  // ─── Acentos editoriais ────────────────────────────────────────────────
  /// Bege institucional — fundo de telas, cartões neutros.
  static const Color sand = Color(0xFFF7F3EC);

  /// Variante de seção informativa (containers de explicação).
  static const Color sandSoft = Color(0xFFFBF6EC);

  /// Borda de cartões em fundo claro.
  static const Color sandBorder = Color(0xFFE3DFD3);

  /// Chip / pill no estado não-selecionado.
  static const Color sandChip = Color(0xFFF4F1E8);

  /// Borda de cartão neutro de listagem (mais quente que sandBorder).
  static const Color cardBorder = Color(0xFFE6E6DC);

  // ─── Textos ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF3A3A3A);
  static const Color textMuted = Color(0xFF555555);
  static const Color textSoft = Color(0xFF7A7A7A);
  static const Color textHint = Color(0xFF8A8A8A);

  // ─── Estados editoriais (alinha com docs/principios_editoriais.md) ─────
  /// Marrom institucional — usado em disclaimers, hints, "atenção sem alarme".
  static const Color editorialBrown = Color(0xFF7A5C2C);
  /// Tom complementar do marrom — bullets, marcadores de rank.
  static const Color editorialOcher = Color(0xFF8A6A3A);

  /// Toggle ativo / botão de aviso editorial (laranja institucional Faro,
  /// usado no banner de proximidade — informativo, não alarmista).
  static const Color alertAccent = Color(0xFFC46A2C);

  /// Vermelho institucional Faro — usado quando preciso indicar "contestar"
  /// ou destacar ação destrutiva editorial (não pra "perigo!").
  static const Color destructive = Color(0xFF8A3F3F);

  // ─── Risco temporal (escala de "frescor" de relato) ────────────────────
  // Mantida no `RiskPalette` original — mas espelhada aqui pra deixar claro
  // que faz parte dos tokens. Nunca usar `Color(0xFF...)` direto.
  static const Color riskNoData = Color(0xFFA8A8A0);
  static const Color riskNoRecent = Color(0xFF7E8C9A);
  static const Color riskLight = Color(0xFFC9A65A);
  static const Color riskConfirmed = Color(0xFFC46A2C);
  static const Color riskHigh = Color(0xFF9A3C2C);
}

/// Espaçamentos consistentes — múltiplos de 4. Evita números soltos
/// (12, 14, 22) espalhados pelo código.
class FaroSpacing {
  FaroSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 32;
}

/// Raios de borda usados em cartões, pílulas e botões.
class FaroRadii {
  FaroRadii._();

  /// Pílula / chip
  static const double pill = 18;
  /// Botão / cartão padrão
  static const double card = 12;
  /// Bottom sheet — só borda superior
  static const double sheet = 20;
  /// Botão arredondado pequeno (pill chip dentro de área de filtro)
  static const double chip = 16;
}

/// Fontes editoriais. `serifEditorial` pra título institucional /
/// headlines de tom autoral. `sansBody` é o padrão de UI.
class FaroFonts {
  FaroFonts._();

  static const String serifEditorial = 'Georgia';
  static const String sansBody = 'Helvetica';
}
