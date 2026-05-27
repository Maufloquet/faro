import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Marcadores customizados com ícone dentro de um círculo, no lugar das
/// "gotas" padrão do Google (`defaultMarkerWithHue`) que pareciam genéricas.
/// Mesmo estilo do dot de ocorrência (anel branco + sombra), pra o mapa ter
/// uma linguagem visual coesa — detalhe que separa app pro de amador.
///
/// Build é caro (PictureRecorder + toImage); cacheado por chave/dpr.
enum GlyphMarker { busStop, police, hospital, commerce, streetLamp, report }

class GlyphMarkerFactory {
  Map<GlyphMarker, BitmapDescriptor>? _cache;

  static const _spec = <GlyphMarker, ({IconData icon, Color color})>{
    GlyphMarker.busStop: (icon: Icons.directions_bus, color: Color(0xFF3A7BD5)),
    GlyphMarker.police: (icon: Icons.local_police, color: Color(0xFF2A4A7A)),
    GlyphMarker.hospital: (icon: Icons.local_hospital, color: Color(0xFFC2557A)),
    GlyphMarker.commerce: (icon: Icons.storefront, color: Color(0xFF4E8C5A)),
    GlyphMarker.streetLamp: (icon: Icons.lightbulb, color: Color(0xFFC9A227)),
    GlyphMarker.report: (icon: Icons.campaign, color: Color(0xFF7A6FB0)),
  };

  Future<Map<GlyphMarker, BitmapDescriptor>> all(
      {double devicePixelRatio = 2.5}) async {
    if (_cache != null) return _cache!;
    final result = <GlyphMarker, BitmapDescriptor>{};
    for (final entry in _spec.entries) {
      result[entry.key] =
          await _build(entry.value.icon, entry.value.color, devicePixelRatio);
    }
    _cache = result;
    return result;
  }

  Future<BitmapDescriptor> _build(
      IconData icon, Color color, double dpr) async {
    final size = 88.0 * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final r = size / 2.6;

    // Sombra suave (profundidade sobre o mapa).
    canvas.drawCircle(
      Offset(center.dx, center.dy + 2.5 * dpr),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * dpr),
    );
    // Anel branco externo.
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    // Disco colorido da categoria.
    canvas.drawCircle(center, r - 3.0 * dpr, Paint()..color = color);

    // Ícone (glifo da fonte MaterialIcons) centralizado, branco.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: r * 1.05,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List(), width: 44);
  }
}
