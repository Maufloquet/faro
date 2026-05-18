import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/design/tokens.dart';

/// Gera o BitmapDescriptor da "seta de carro" usada no modo direção.
///
/// Inspiração visual no marker do Waze (círculo com seta), mas com a
/// paleta Faro (não roxo). A seta sempre é desenhada apontando pra cima
/// (norte do bitmap). O Google Maps rotaciona o marker pelo `heading`
/// do GPS via `Marker.rotation`.
class DrivingArrowFactory {
  BitmapDescriptor? _cache;

  Future<BitmapDescriptor> build({double devicePixelRatio = 2.5}) async {
    if (_cache != null) return _cache!;
    final size = 96.0 * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    const primary = FaroColors.primary;

    // Halo externo translúcido — comunica "minha posição" sem ficar
    // pesado contra o satélite.
    canvas.drawCircle(
      center,
      size / 2.3,
      Paint()..color = primary.withValues(alpha: 0.18),
    );

    // Sombra do disco — profundidade contra tile de mapa.
    canvas.drawCircle(
      Offset(center.dx, center.dy + 2.5 * devicePixelRatio),
      size / 3.2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * devicePixelRatio),
    );

    // Anel branco externo
    canvas.drawCircle(
      center,
      size / 3.1,
      Paint()..color = Colors.white,
    );

    // Disco azul/marrom Faro (cor primary)
    canvas.drawCircle(
      center,
      size / 3.4,
      Paint()..color = primary,
    );

    // Seta branca apontando pra cima
    final arrowPath = Path();
    final tipY = center.dy - size / 6.5;
    final baseY = center.dy + size / 9;
    final halfWidth = size / 9;
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
