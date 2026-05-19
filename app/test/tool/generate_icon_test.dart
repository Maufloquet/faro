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
