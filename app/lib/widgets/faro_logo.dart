import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';

/// Glifo de marca do Faro — desenhado em CustomPainter pra escalar
/// nitidamente em qualquer tamanho sem depender de PNG.
///
/// Forma: ponto central sólido (núcleo do farol) + 3 arcos concêntricos
/// abertos com gap deliberado no canto inferior-direito. A abertura
/// quebra a leitura "círculo cheio / loading / wifi" e sugere visualmente
/// que a luz **sai** do centro (pulso, atenção, captação) sem fechar
/// certezas — alinhado ao princípio editorial "não afirmamos seguro".
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
            painter: _FaroLogoPainter(
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
        painter: _FaroLogoPainter(color: mainColor, accent: accent),
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

class _FaroLogoPainter extends CustomPainter {
  final Color color;
  final Color accent;
  /// Multiplicador do raio do anel externo (1.0 = neutro). Usado pelo
  /// modo animado pra criar pulso sutil (0.96 ↔ 1.04).
  final double outerScale;

  _FaroLogoPainter({
    required this.color,
    required this.accent,
    this.outerScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final strokeWidth = size.width * 0.07;

    // Gap no canto inferior-direito (4h–8h) pra quebrar a leitura
    // "anel fechado / wifi / loading".
    const gapStart = math.pi * 0.30;
    const gapEnd = math.pi * 0.70;
    const startAngle = gapEnd;
    const sweepAngle = 2 * math.pi - (gapEnd - gapStart);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Anel externo — translúcido (alcance). Aplica `outerScale` quando
    // animado pra dar pulso sutil; nos casos estáticos vale 1.0.
    paint.color = color.withValues(alpha: 0.32);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.78 * outerScale),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Anel médio
    paint.color = color.withValues(alpha: 0.62);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.55),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Anel interno — cor de acento (destaque editorial)
    paint.color = accent;
    paint.strokeWidth = strokeWidth * 0.9;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.32),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Núcleo — ponto sólido (a "luz" do farol)
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius * 0.10, dot);
  }

  @override
  bool shouldRepaint(_FaroLogoPainter old) =>
      old.color != color ||
      old.accent != accent ||
      old.outerScale != outerScale;
}
