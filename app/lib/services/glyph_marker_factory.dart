import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Marcadores customizados com ícone dentro de um disco arredondado, no lugar
/// das "gotas" padrão do Google (`defaultMarkerWithHue`) que pareciam
/// genéricas. Cada categoria tem cor própria e um ícone que *fala* do lugar
/// (cruz pra hospital, distintivo pra delegacia, poste aceso pra iluminação),
/// pra o mapa ter linguagem visual coesa — detalhe que separa app pro de
/// amador.
///
/// O disco tem leve gradiente vertical (topo mais claro), anel branco e sombra
/// — profundidade discreta sobre o mapa. A maioria usa glifo da fonte
/// MaterialIcons; a iluminação pública é desenhada à mão (vetor) porque o
/// Material não tem um poste de luz decente.
///
/// Build é caro (PictureRecorder + toImage); cacheado por instância.
enum GlyphMarker { busStop, police, hospital, commerce, streetLamp, report }

class GlyphMarkerFactory {
  Map<GlyphMarker, BitmapDescriptor>? _cache;

  static const _color = <GlyphMarker, Color>{
    GlyphMarker.busStop: Color(0xFF3A7BD5),
    GlyphMarker.police: Color(0xFF2A4A7A),
    GlyphMarker.hospital: Color(0xFFB23A4F),
    GlyphMarker.commerce: Color(0xFF4E8C5A),
    GlyphMarker.streetLamp: Color(0xFFC79A1E),
    GlyphMarker.report: Color(0xFF7A6FB0),
  };

  // Glifo da fonte por categoria. A iluminação pública não está aqui de
  // propósito — é desenhada por [_paintStreetLamp].
  static const _icon = <GlyphMarker, IconData>{
    GlyphMarker.busStop: Icons.directions_bus,
    GlyphMarker.police: Icons.local_police,
    GlyphMarker.hospital: Icons.local_hospital,
    GlyphMarker.commerce: Icons.storefront,
    GlyphMarker.report: Icons.campaign,
  };

  Future<Map<GlyphMarker, BitmapDescriptor>> all(
      {double devicePixelRatio = 2.5}) async {
    if (_cache != null) return _cache!;
    final result = <GlyphMarker, BitmapDescriptor>{};
    for (final kind in GlyphMarker.values) {
      result[kind] = await _build(kind, devicePixelRatio);
    }
    _cache = result;
    return result;
  }

  Future<BitmapDescriptor> _build(GlyphMarker kind, double dpr) async {
    final color = _color[kind]!;
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
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * dpr),
    );
    // Anel branco externo.
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    // Disco da categoria com gradiente vertical sutil (topo mais claro) —
    // dá um volume discreto sem cair no "glossy" datado.
    final discR = r - 3.0 * dpr;
    canvas.drawCircle(
      center,
      discR,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - discR),
          Offset(center.dx, center.dy + discR),
          [
            Color.lerp(color, Colors.white, 0.16)!,
            color,
          ],
        ),
    );

    if (kind == GlyphMarker.streetLamp) {
      _paintStreetLamp(canvas, center, discR);
    } else {
      _paintGlyph(canvas, center, r, _icon[kind]!);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List(), width: 44);
  }

  /// Glifo da fonte MaterialIcons, branco, centralizado.
  void _paintGlyph(Canvas canvas, Offset center, double r, IconData icon) {
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
  }

  /// Poste de iluminação pública (lampião sobre poste, com facho de luz),
  /// desenhado em vetor branco. `s` é o raio do disco; o glifo ocupa ~1.4×
  /// esse raio em altura. Bordas arredondadas pra não ficar duro no tamanho
  /// pequeno do marcador.
  void _paintStreetLamp(Canvas canvas, Offset c, double s) {
    final white = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;
    final g = s * 0.92; // meia-altura do glifo

    // Facho de luz: trapézio translúcido descendo do lampião, dá o "aceso".
    final beam = Path()
      ..moveTo(c.dx - g * 0.22, c.dy - g * 0.18)
      ..lineTo(c.dx + g * 0.22, c.dy - g * 0.18)
      ..lineTo(c.dx + g * 0.46, c.dy + g * 0.46)
      ..lineTo(c.dx - g * 0.46, c.dy + g * 0.46)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - g * 0.18),
          Offset(c.dx, c.dy + g * 0.46),
          [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );

    // Cúpula (telhadinho) do lampião — triângulo com topo arredondado.
    final cap = Path()
      ..moveTo(c.dx, c.dy - g * 0.92)
      ..lineTo(c.dx + g * 0.30, c.dy - g * 0.52)
      ..lineTo(c.dx - g * 0.30, c.dy - g * 0.52)
      ..close();
    canvas.drawPath(cap, white);
    // Finial (bolinha no topo).
    canvas.drawCircle(Offset(c.dx, c.dy - g * 0.96), g * 0.07, white);

    // Corpo do lampião (a luz) — trapézio que afunila pra baixo.
    final lantern = Path()
      ..moveTo(c.dx - g * 0.26, c.dy - g * 0.52)
      ..lineTo(c.dx + g * 0.26, c.dy - g * 0.52)
      ..lineTo(c.dx + g * 0.18, c.dy - g * 0.18)
      ..lineTo(c.dx - g * 0.18, c.dy - g * 0.18)
      ..close();
    canvas.drawPath(lantern, white);

    // Poste (haste vertical) + base, com cantos levemente arredondados.
    canvas.drawRRect(
      RRect.fromLTRBR(
        c.dx - g * 0.055, c.dy - g * 0.18,
        c.dx + g * 0.055, c.dy + g * 0.78,
        Radius.circular(g * 0.03),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        c.dx - g * 0.22, c.dy + g * 0.74,
        c.dx + g * 0.22, c.dy + g * 0.90,
        Radius.circular(g * 0.05),
      ),
      white,
    );
  }
}
