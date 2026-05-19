library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Helpers de TextStyle Faro — usar em vez de `fontFamily: 'Fraunces'` /
/// `fontFamily: 'Inter'` hardcoded, que caem em Roboto no Android.
///
/// **Fraunces** (serif): títulos, headlines, marca. Encorpada, com leve
/// caráter geometric-display — escapa do Times/Georgia genérico.
///
/// **Inter** (sans): UI, body, labels. Padrão moderno (Linear, Vercel,
/// Notion) — substitui Helvetica/Roboto.
class FaroTextStyles {
  FaroTextStyles._();

  /// Headline editorial — usado em telas-marca (Splash, Onboarding).
  static TextStyle headlineDisplay({
    double fontSize = 38,
    Color? color,
    FontStyle? fontStyle,
    double letterSpacing = -0.5,
    double height = 1.1,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Título de tela — AppBar, headers de cartão de princípio.
  static TextStyle headlineMedium({
    double fontSize = 22,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.2,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Título de cartão / item da lista.
  static TextStyle title({
    double fontSize = 16,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.25,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Tagline / slogan — itálico de marca.
  static TextStyle tagline({
    double fontSize = 14,
    Color? color,
    double height = 1.4,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontStyle: FontStyle.italic,
        color: color,
        height: height,
      );

  /// Body / parágrafo — Inter regular.
  static TextStyle body({
    double fontSize = 14,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// Label compacto — chips, badges, captions.
  static TextStyle label({
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.2,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Seção em caixa-alta — "NAVEGAR", "POR HORA DO DIA".
  static TextStyle sectionLabel({
    double fontSize = 11,
    Color? color,
    double letterSpacing = 0.8,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: letterSpacing,
      );
}
