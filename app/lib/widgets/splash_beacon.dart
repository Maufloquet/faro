import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import 'faro_logo.dart';

/// Farol animado do splash: o glifo do farol dentro de um disco azul (a
/// "noite"), com o facho de luz varrendo de um lado a outro e o lampião
/// pulsando quando a luz aponta pra cima. Reusa o `FaroLogoPainter` pro
/// desenho estático da torre — aqui só acrescentamos a luz que se move.
class SplashBeacon extends StatefulWidget {
  final double size;
  const SplashBeacon({super.key, this.size = 132});

  @override
  State<SplashBeacon> createState() => _SplashBeaconState();
}

class _SplashBeaconState extends State<SplashBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) =>
            CustomPaint(painter: SplashBeaconPainter(progress: _c.value)),
      ),
    );
  }
}

/// Pinta o disco + facho varrendo + glifo do farol. `progress` em [0,1)
/// avança o tempo da animação (loop).
class SplashBeaconPainter extends CustomPainter {
  final double progress;
  SplashBeaconPainter({required this.progress});

  /// Abertura máxima da varredura, em radianos (~68° pra cada lado do topo).
  static const _maxAngle = 1.20;
  static const _warm = Color(0xFFFFE6A6); // luz quente

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.47;

    // Disco azul — a "noite" onde a luz se destaca.
    canvas.drawCircle(
        c, r, Paint()..color = FaroColors.primary..isAntiAlias = true);

    // Caixa do glifo, lampião alinhado ao centro do disco.
    final g = r * 2 * 0.62;
    final boxLeft = c.dx - g / 2;
    final boxTop = c.dy - 0.36 * g;
    final lamp = Offset(c.dx, boxTop + 0.36 * g);

    // Ângulo do facho: varre ida-e-volta com seno (suave nas pontas).
    final a = _maxAngle * math.sin(2 * math.pi * progress);
    // Brilho: máximo quando aponta pra cima (a≈0), mínimo nas pontas —
    // como o facho de um farol girando que "acende" ao passar pela frente.
    final bright = 0.45 + 0.55 * (1 - a.abs() / _maxAngle);

    // Luz fica dentro do disco (vinheta noturna).
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    Offset dirAt(double ang) => Offset(math.sin(ang), -math.cos(ang));
    const half = 0.19; // meia-abertura do cone (~11°)
    final beamLen = r * 1.15;
    final tip = lamp + dirAt(a) * beamLen;
    final e1 = lamp + dirAt(a - half) * beamLen;
    final e2 = lamp + dirAt(a + half) * beamLen;
    final beamPath = Path()
      ..moveTo(lamp.dx, lamp.dy)
      ..lineTo(e1.dx, e1.dy)
      ..lineTo(e2.dx, e2.dy)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(lamp, tip, [
          _warm.withValues(alpha: 0.85 * bright),
          _warm.withValues(alpha: 0.0),
        ]),
    );

    // Glow no lampião, pulsando junto com o brilho.
    final glowR = r * 0.24;
    canvas.drawCircle(
      lamp,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(lamp, glowR, [
          _warm.withValues(alpha: 0.95 * bright),
          _warm.withValues(alpha: 0.0),
        ]),
    );

    canvas.restore();

    // Farol branco por cima (torre estática reusando o painter da marca).
    canvas.save();
    canvas.translate(boxLeft, boxTop);
    FaroLogoPainter(color: Colors.white, accent: FaroColors.editorialOcher)
        .paint(canvas, Size(g, g));
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashBeaconPainter old) => old.progress != progress;
}
