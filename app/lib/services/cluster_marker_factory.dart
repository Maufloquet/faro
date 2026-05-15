import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_theme.dart';

/// Renderiza badges de cluster pro mapa.
///
/// Princípio editorial: o badge não dá veredito — só conta. Cor do anel
/// reflete o relato mais recente do grupo (mesma escala RiskLevel dos
/// markers individuais). Texto fica em preto sobre branco pra legibilidade
/// sobre satélite ou ruas.
///
/// Counts são bucketizados (2–9 exatos, '9+' pra ≥10) pra limitar o espaço
/// de ícones — 9 strings × 5 risks = 45 ícones pré-bakeados em startup.
class ClusterMarkerFactory {
  Map<String, BitmapDescriptor>? _cache;

  /// String mostrada no badge pra um count cru.
  static String displayCount(int n) {
    if (n < 10) return '$n';
    return '9+';
  }

  /// Chave de lookup no cache.
  static String keyFor(int count, RiskLevel risk) =>
      '${risk.name}:${displayCount(count)}';

  /// Pré-baqueia todos os ícones de cluster. Chamar uma vez no startup.
  Future<Map<String, BitmapDescriptor>> all({double devicePixelRatio = 2.5}) async {
    if (_cache != null) return _cache!;
    final out = <String, BitmapDescriptor>{};
    final displays = ['2', '3', '4', '5', '6', '7', '8', '9', '9+'];
    for (final risk in RiskLevel.values) {
      for (final display in displays) {
        out['${risk.name}:$display'] = await _build(display, risk, devicePixelRatio);
      }
    }
    _cache = out;
    return out;
  }

  Future<BitmapDescriptor> _build(String display, RiskLevel risk, double dpr) async {
    // Tamanho do canvas escala com o número de dígitos — badges de 99+
    // precisam de mais largura.
    final logicalSize = display.length <= 1 ? 36.0 : (display.length == 2 ? 42.0 : 50.0);
    final size = logicalSize * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final ringColor = risk.color;

    // Sombra suave atrás do badge (profundidade sobre satélite)
    canvas.drawCircle(
      Offset(center.dx, center.dy + 2.5 * dpr),
      size / 2.4,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * dpr),
    );

    // Halo externo (mesma estética dos markers individuais)
    canvas.drawCircle(
      center,
      size / 2.0,
      Paint()..color = ringColor.withValues(alpha: 0.20),
    );

    // Disco branco principal
    canvas.drawCircle(
      center,
      size / 2.4,
      Paint()..color = Colors.white,
    );

    // Anel da cor do risco
    canvas.drawCircle(
      center,
      size / 2.4,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * dpr,
    );

    // Texto do count
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontFamily: 'Georgia',
      fontSize: (logicalSize * 0.46) * dpr,
      fontWeight: FontWeight.w600,
    );
    final textStyle = ui.TextStyle(
      color: const Color(0xFF1A1A1A),
      fontFamily: 'Georgia',
      fontSize: (logicalSize * 0.46) * dpr,
      fontWeight: FontWeight.w600,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(display);
    final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(
      paragraph,
      Offset(0, (size - paragraph.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes, width: logicalSize);
  }
}
