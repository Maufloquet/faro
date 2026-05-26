import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';

/// Glifo de marca do Faro — desenhado em CustomPainter pra escalar
/// nitidamente em qualquer tamanho sem depender de PNG.
///
/// Forma: silhueta de uma **torre de farol** com a luz acesa no topo
/// (casa da luz em cor de acento) e um facho curto saindo pros dois lados.
/// É literal ao nome (Faro/farol) e foge da leitura de "wifi / sinal" que
/// a versão anterior (ponto + arcos concêntricos) provocava.
class FaroLogo extends StatefulWidget {
  final double size;
  final Color? color;
  final Color? accentColor;
  final bool inverted;

  /// Quando true, anima sutilmente o anel externo (escala 0.96-1.04 em
  /// loop) — usado no splash pra dar sensação de "pulso vivo". Default
  /// false pra não distrair em drawer/onboarding onde o logo é estático.
  final bool animated;

  const FaroLogo({
    super.key,
    this.size = 64,
    this.color,
    this.accentColor,
    this.inverted = false,
    this.animated = false,
  });

  @override
  State<FaroLogo> createState() => _FaroLogoState();
}

class _FaroLogoState extends State<FaroLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
      _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainColor =
        widget.inverted ? Colors.white : (widget.color ?? FaroColors.primary);
    final accent = widget.accentColor ?? FaroColors.editorialOcher;

    if (!widget.animated) {
      return _staticLogo(mainColor, accent);
    }
    return AnimatedBuilder(
      animation: _pulse!,
      builder: (_, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: FaroLogoPainter(
              color: mainColor,
              accent: accent,
              outerScale: _pulse!.value,
            ),
          ),
        );
      },
    );
  }

  Widget _staticLogo(Color mainColor, Color accent) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: FaroLogoPainter(color: mainColor, accent: accent),
      ),
    );
  }
}

/// Lockup completo: glifo + nome "Faro" em serif editorial. Usado no
/// splash e no header do drawer.
class FaroLogoLockup extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? accentColor;
  final bool inverted;

  const FaroLogoLockup({
    super.key,
    this.size = 96,
    this.color,
    this.accentColor,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        inverted ? Colors.white : (color ?? FaroColors.textPrimary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaroLogo(
          size: size,
          color: color,
          accentColor: accentColor,
          inverted: inverted,
        ),
        SizedBox(height: size * 0.18),
        Text(
          'Faro',
          style: TextStyle(
            fontFamily: FaroFonts.serifEditorial,
            fontSize: size * 0.42,
            height: 1.0,
            letterSpacing: -0.5,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// Painter exposto (não-private) pra que ferramentas externas possam
/// renderizar o glifo Faro em outras superfícies — por exemplo, o script
/// `test/tool/generate_icon_test.dart` que regenera o launcher icon
/// (assets/icon/faro_icon.png) usando este mesmo desenho.
class FaroLogoPainter extends CustomPainter {
  final Color color;
  final Color accent;
  /// Multiplicador do raio do anel externo (1.0 = neutro). Usado pelo
  /// modo animado pra criar pulso sutil (0.96 ↔ 1.04).
  final double outerScale;

  FaroLogoPainter({
    required this.color,
    required this.accent,
    this.outerScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Pulso sutil no modo animado (splash): "respira" o glifo inteiro.
    // Em estático outerScale = 1.0, então não afeta.
    if (outerScale != 1.0) {
      canvas.translate(cx, h / 2);
      canvas.scale(outerScale);
      canvas.translate(-cx, -h / 2);
    }

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Layout vertical (frações da altura) — torre esguia e elegante.
    final domeApex = h * 0.150;
    final lanternTop = h * 0.270;
    final galleryTop = h * 0.385;
    final galleryBot = h * 0.420;
    final towerBot = h * 0.800;
    final baseBot = h * 0.852;
    final footBot = h * 0.876;
    // Larguras (frações do lado).
    final halfLantern = w * 0.085;
    final halfGallery = w * 0.150;
    final halfTowerTop = w * 0.105;
    final halfTowerBase = w * 0.165;
    final halfBase = w * 0.210;
    final halfFoot = w * 0.255;

    final lamp = Offset(cx, (lanternTop + galleryTop) / 2);

    // 1) Glow da lanterna (atrás de tudo) — dá a sensação de luz acesa.
    final glowR = w * 0.32;
    canvas.drawCircle(
      lamp,
      glowR,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(lamp, glowR, [
          accent.withValues(alpha: 0.42),
          accent.withValues(alpha: 0.0),
        ]),
    );

    // 2) Base em dois níveis (rochedo largo + plataforma) — assentamento.
    fill.color = color;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - halfFoot, baseBot, cx + halfFoot, footBot,
          Radius.circular(w * 0.02)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(cx - halfBase, towerBot, cx + halfBase, baseBot,
          Radius.circular(w * 0.02)),
      fill,
    );

    // 3) Corpo da torre (trapézio afunilando).
    final tower = Path()
      ..moveTo(cx - halfTowerTop, galleryBot)
      ..lineTo(cx + halfTowerTop, galleryBot)
      ..lineTo(cx + halfTowerBase, towerBot)
      ..lineTo(cx - halfTowerBase, towerBot)
      ..close();
    canvas.drawPath(tower, fill);

    // 4) Listras douradas (clipadas na torre) — a assinatura do farol.
    canvas.save();
    canvas.clipPath(tower);
    fill.color = accent;
    for (final band in <List<double>>[
      [h * 0.490, h * 0.548],
      [h * 0.632, h * 0.690],
    ]) {
      canvas.drawRect(Rect.fromLTRB(0, band[0], w, band[1]), fill);
    }
    canvas.restore();

    // 5) Galeria (varanda) — deck que se projeta no topo da torre.
    fill.color = color;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - halfGallery, galleryTop, cx + halfGallery, galleryBot,
          Radius.circular(w * 0.012)),
      fill,
    );

    // 6) Lanterna (a luz) — em cor de acento, com um caixilho central.
    fill.color = accent;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - halfLantern, lanternTop, cx + halfLantern, galleryTop,
          Radius.circular(w * 0.012)),
      fill,
    );
    canvas.drawLine(
      Offset(cx, lanternTop + h * 0.014),
      Offset(cx, galleryTop - h * 0.014),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = w * 0.011
        ..strokeCap = StrokeCap.round,
    );

    // 7) Cúpula curva + finial (pináculo) — remate elegante no topo.
    fill.color = color;
    final domeHalf = halfLantern + w * 0.015;
    final dome = Path()
      ..moveTo(cx - domeHalf, lanternTop)
      ..arcToPoint(
        Offset(cx + domeHalf, lanternTop),
        radius: Radius.elliptical(domeHalf, lanternTop - domeApex),
      )
      ..close();
    canvas.drawPath(dome, fill);
    canvas.drawRect(
      Rect.fromLTWH(cx - w * 0.006, domeApex - h * 0.028, w * 0.012, h * 0.030),
      fill,
    );
    canvas.drawCircle(Offset(cx, domeApex - h * 0.030), w * 0.020, fill);
  }

  @override
  bool shouldRepaint(FaroLogoPainter old) =>
      old.color != color ||
      old.accent != accent ||
      old.outerScale != outerScale;
}
