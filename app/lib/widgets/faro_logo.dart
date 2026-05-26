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

    // Proporções do farol (relativas ao lado do canvas).
    final baseY = h * 0.82; // base da torre
    final galleryY = h * 0.44; // deck/galeria no topo da torre
    final galleryTopY = galleryY - h * 0.03;
    final lanternTopY = h * 0.31; // topo da casa da luz
    final roofApexY = h * 0.20; // ponta do telhado
    final halfBase = w * 0.185;
    final halfTop = w * 0.115;
    final halfLantern = w * 0.10;

    // Plataforma/base (footing) larga embaixo.
    fill.color = color;
    final baseW = w * 0.52;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - baseW / 2, baseY, cx + baseW / 2, h * 0.87,
          Radius.circular(w * 0.03)),
      fill,
    );

    // Corpo da torre — trapézio afunilando pra cima.
    final tower = Path()
      ..moveTo(cx - halfTop, galleryY)
      ..lineTo(cx + halfTop, galleryY)
      ..lineTo(cx + halfBase, baseY)
      ..lineTo(cx - halfBase, baseY)
      ..close();
    canvas.drawPath(tower, fill);

    // Galeria (varanda) — barra fina projetada no topo da torre.
    final galleryHalf = halfTop + w * 0.05;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - galleryHalf, galleryTopY, cx + galleryHalf, galleryY,
          Radius.circular(w * 0.012)),
      fill,
    );

    // Casa da luz (lanterna) — preenchida com o acento: a luz acesa.
    fill.color = accent;
    canvas.drawRRect(
      RRect.fromLTRBR(cx - halfLantern, lanternTopY, cx + halfLantern,
          galleryTopY, Radius.circular(w * 0.02)),
      fill,
    );

    // Telhado — triângulo sobre a lanterna, na cor principal, com finial.
    fill.color = color;
    final roof = Path()
      ..moveTo(cx - halfLantern - w * 0.02, lanternTopY)
      ..lineTo(cx + halfLantern + w * 0.02, lanternTopY)
      ..lineTo(cx, roofApexY)
      ..close();
    canvas.drawPath(roof, fill);
    canvas.drawCircle(Offset(cx, roofApexY - w * 0.005), w * 0.022, fill);
  }

  @override
  bool shouldRepaint(FaroLogoPainter old) =>
      old.color != color ||
      old.accent != accent ||
      old.outerScale != outerScale;
}
