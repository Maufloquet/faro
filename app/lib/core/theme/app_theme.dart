import 'package:flutter/material.dart';

/// Paleta editorial do produto.
///
/// Princípio: o app NUNCA afirma segurança. A escala vai de neutro a
/// alto risco — sem verde puro, sem palavras absolutas.
///
/// Definições alinhadas com `design/linguagem_visual.md`.
class RiskPalette {
  static const Color noData = Color(0xFFA8A8A0);
  static const Color noRecentReports = Color(0xFF7E8C9A);
  static const Color lightActivity = Color(0xFFC9A65A);
  static const Color confirmedActivity = Color(0xFFC46A2C);
  static const Color highCorroborated = Color(0xFF9A3C2C);
}

enum RiskLevel { noData, noRecentReports, lightActivity, confirmedActivity, highCorroborated }

extension RiskLevelExt on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.noData:
        return RiskPalette.noData;
      case RiskLevel.noRecentReports:
        return RiskPalette.noRecentReports;
      case RiskLevel.lightActivity:
        return RiskPalette.lightActivity;
      case RiskLevel.confirmedActivity:
        return RiskPalette.confirmedActivity;
      case RiskLevel.highCorroborated:
        return RiskPalette.highCorroborated;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.noData:
        return 'Sem dados suficientes nesta região';
      case RiskLevel.noRecentReports:
        return 'Sem relatos nas últimas 24h';
      case RiskLevel.lightActivity:
        return 'Relatos esparsos. Atenção.';
      case RiskLevel.confirmedActivity:
        return 'Relatos confirmados. Avaliar rota alternativa.';
      case RiskLevel.highCorroborated:
        return 'Múltiplos relatos. Evitar se possível.';
    }
  }
}

class AppTheme {
  static ThemeData light() {
    const seed = Color(0xFF2A4A7A);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      fontFamily: 'Helvetica',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Georgia', fontSize: 32, height: 1.2),
        displayMedium: TextStyle(fontFamily: 'Georgia', fontSize: 24, height: 1.2),
        headlineSmall: TextStyle(fontFamily: 'Georgia', fontSize: 18, height: 1.3),
      ),
    );
  }

  static ThemeData dark() {
    const seed = Color(0xFF2A4A7A);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      fontFamily: 'Helvetica',
    );
  }
}
