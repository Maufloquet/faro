@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/design/tokens.dart';
import 'package:projeto_seg/widgets/faro_logo.dart';

/// Não é um teste de comportamento — é uma **ferramenta** que reusa o
/// runner do Flutter pra renderizar o `FaroLogoPainter` e gravar PNGs
/// pro launcher icon. Rodar com:
///
///   flutter test test/tool/generate_icon_test.dart
///
/// Saídas:
///   assets/icon/faro_icon.png    1024×1024 · fundo azul + glifo branco
///   assets/icon/faro_icon_fg.png 1024×1024 · só glifo, com padding
///                                (foreground do adaptive icon Android)
///
/// Depois roda `flutter pub run flutter_launcher_icons` pra recortar
/// nos múltiplos tamanhos (mipmap-mdpi até xxxhdpi).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera launcher icon principal (1024×1024, fundo azul)', () async {
    final image = await _renderIcon(
      canvasSize: 1024,
      backgroundColor: FaroColors.primary,
      logoColor: Colors.white,
      logoAccent: FaroColors.editorialOcher,
      logoSizeRatio: 0.62,
    );
    await _save(image, 'assets/icon/faro_icon.png');
  });

  test('gera adaptive icon foreground (1024×1024, transparente, padding)',
      () async {
    // Adaptive icon Android pode recortar até 30% nas bordas — usamos
    // ratio menor pra garantir safe area com folga.
    final image = await _renderIcon(
      canvasSize: 1024,
      backgroundColor: null,
      logoColor: Colors.white,
      logoAccent: FaroColors.editorialOcher,
      logoSizeRatio: 0.42,
    );
    await _save(image, 'assets/icon/faro_icon_fg.png');
  });

  test('gera splash (selo azul + farol branco, fundo transparente)', () async {
    // flutter_native_splash centraliza este PNG sobre o fundo creme
    // (#F7F3EC). Desenhamos um selo azul arredondado com o farol branco
    // dentro — mesmo visual do ícone da tela inicial.
    final image = await _renderSplash(canvasSize: 768);
    await _save(image, 'assets/icon/faro_splash.png');
  });
}

Future<ui.Image> _renderSplash({required int canvasSize}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = canvasSize.toDouble();

  // Selo azul arredondado, centralizado (~62% do canvas).
  final badge = s * 0.62;
  final badgeOff = (s - badge) / 2;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeOff, badgeOff, badge, badge),
      Radius.circular(badge * 0.22),
    ),
    Paint()
      ..color = FaroColors.primary
      ..isAntiAlias = true,
  );

  // Farol branco dentro do selo (~62% do selo).
  final glyph = badge * 0.62;
  final glyphOff = (s - glyph) / 2;
  canvas.save();
  canvas.translate(glyphOff, glyphOff);
  FaroLogoPainter(color: Colors.white, accent: FaroColors.editorialOcher)
      .paint(canvas, Size(glyph, glyph));
  canvas.restore();

  final picture = recorder.endRecording();
  return picture.toImage(canvasSize, canvasSize);
}

Future<ui.Image> _renderIcon({
  required int canvasSize,
  required Color? backgroundColor,
  required Color logoColor,
  required Color logoAccent,
  required double logoSizeRatio,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final sizeD = canvasSize.toDouble();

  if (backgroundColor != null) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sizeD, sizeD),
      Paint()..color = backgroundColor,
    );
  }

  final logoSize = sizeD * logoSizeRatio;
  final offset = (sizeD - logoSize) / 2;
  canvas.save();
  canvas.translate(offset, offset);
  final painter = FaroLogoPainter(color: logoColor, accent: logoAccent);
  painter.paint(canvas, Size(logoSize, logoSize));
  canvas.restore();

  final picture = recorder.endRecording();
  return picture.toImage(canvasSize, canvasSize);
}

Future<void> _save(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    fail('toByteData retornou null pra $path');
  }
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes.buffer.asUint8List());
  // ignore: avoid_print
  print('✓ ${file.path} (${bytes.lengthInBytes} bytes)');
}
