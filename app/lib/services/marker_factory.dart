import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_theme.dart';

/// Gera BitmapDescriptors customizados para cada [RiskLevel].
///
/// Os ícones default do Google Maps (gota vermelha/laranja/azul) não combinam
/// com a paleta editorial. Aqui desenhamos um dot com halo glow e anel branco,
/// fiel ao estilo do RiskDot usado na lista.
///
/// O build é caro (PictureRecorder + toImage). Resultado é cacheado por
/// instância — uma chamada por sessão.
class MarkerFactory {
  Map<RiskLevel, BitmapDescriptor>? _cache;

  Future<Map<RiskLevel, BitmapDescriptor>> all({double devicePixelRatio = 2.5}) async {
    if (_cache != null) return _cache!;
    final result = <RiskLevel, BitmapDescriptor>{};
    for (final level in RiskLevel.values) {
      result[level] = await _build(level, devicePixelRatio);
    }
    _cache = result;
    return result;
  }

  Future<BitmapDescriptor> _build(RiskLevel level, double dpr) async {
    final size = 80.0 * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final color = level.color;

    // Halo glow externo
    canvas.drawCircle(
      center,
      size / 2.4,
      Paint()..color = color.withValues(alpha: 0.18),
    );

    // Halo médio
    canvas.drawCircle(
      center,
      size / 3,
      Paint()..color = color.withValues(alpha: 0.32),
    );

    // Sombra suave atrás do dot
    canvas.drawCircle(
      Offset(center.dx, center.dy + 2 * dpr),
      size / 4.6,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * dpr),
    );

    // Dot principal
    canvas.drawCircle(
      center,
      size / 4.6,
      Paint()..color = color,
    );

    // Anel branco
    canvas.drawCircle(
      center,
      size / 4.6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * dpr,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes, width: 40);
  }
}

/// Helper que classifica idade da ocorrência em [RiskLevel].
///
/// Reutilizado pelo mapa, tile da lista e detail sheet — garante coerência
/// visual entre as três superfícies.
RiskLevel classifyAge(DateTime date) {
  final hours = DateTime.now().difference(date).inHours;
  if (hours < 2) return RiskLevel.confirmedActivity;
  if (hours < 12) return RiskLevel.lightActivity;
  return RiskLevel.noRecentReports;
}
