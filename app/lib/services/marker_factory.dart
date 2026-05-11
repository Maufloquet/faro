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
    // Canvas em alta resolução pra evitar borrar quando o Maps escala.
    final size = 96.0 * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final color = level.color;

    // Halo externo (sutil — só pra sugerir "aura")
    canvas.drawCircle(
      center,
      size / 2.4,
      Paint()..color = color.withValues(alpha: 0.20),
    );

    // Halo médio (mais opaco)
    canvas.drawCircle(
      center,
      size / 3,
      Paint()..color = color.withValues(alpha: 0.42),
    );

    // Sombra suave atrás do dot (cria profundidade sobre satélite)
    canvas.drawCircle(
      Offset(center.dx, center.dy + 2.5 * dpr),
      size / 4.0,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * dpr),
    );

    // Anel branco externo (background ring — destaca do mapa)
    canvas.drawCircle(
      center,
      size / 4.0,
      Paint()..color = Colors.white,
    );

    // Dot principal — proporcionalmente maior pra ficar visível
    canvas.drawCircle(
      center,
      size / 4.6,
      Paint()..color = color,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    // 56 pontos lógicos: 40% maior que antes (40 → 56), fica visível mesmo
    // em zoom de cidade sem dominar a tela em zoom de rua.
    return BitmapDescriptor.bytes(bytes, width: 56);
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
