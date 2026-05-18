import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/design/tokens.dart';

/// Gera o BitmapDescriptor da "seta de carro" usada no modo direção.
///
/// Inspiração visual no marker do Waze/Google Maps Navigation: ícone
/// compacto, sem halos externos exagerados, com a paleta Faro
/// (não roxo). A seta sempre é desenhada apontando pra cima (norte do
/// bitmap). O Google Maps rotaciona o marker pelo `heading` do GPS via
/// `Marker.rotation`.
class DrivingArrowFactory {
  BitmapDescriptor? _cache;

  Future<BitmapDescriptor> build({double devicePixelRatio = 2.5}) async {
    if (_cache != null) return _cache!;
    // 28pt-base: chega a ~28dp na tela em DPR ~3 — footprint do ícone
    // de carro do Waze e do Google Maps em modo navegação.
    final size = 28.0 * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    const primary = FaroColors.primary;

    // Sombra suave atrás do disco (profundidade contra mapa)
    canvas.drawCircle(
      Offset(center.dx, center.dy + 1.5 * devicePixelRatio),
      size / 2.6,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * devicePixelRatio),
    );

    // Anel branco externo (contraste contra mapa em qualquer fundo)
    canvas.drawCircle(
      center,
      size / 2.4,
      Paint()..color = Colors.white,
    );

    // Disco azul Faro (cor primary)
    canvas.drawCircle(
      center,
      size / 2.75,
      Paint()..color = primary,
    );

    // Seta branca apontando pra cima
    final arrowPath = Path();
    final tipY = center.dy - size / 5;
    final baseY = center.dy + size / 8;
    final halfWidth = size / 7;
    arrowPath
      ..moveTo(center.dx, tipY)
      ..lineTo(center.dx + halfWidth, baseY)
      ..lineTo(center.dx, baseY - size / 22)
      ..lineTo(center.dx - halfWidth, baseY)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _cache = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    return _cache!;
  }
}
