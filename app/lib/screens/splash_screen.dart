import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import 'map_screen.dart';
import 'onboarding_screen.dart';

/// Splash de marca antes do mapa carregar.
///
/// Não substitui o splash nativo (LaunchScreen.storyboard no iOS,
/// launch_background.xml no Android) — fica entre o nativo e a primeira
/// tela útil, dando uma pausa propositada de marca.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    Timer(const Duration(milliseconds: 1400), _goNext);
  }

  Future<void> _goNext() async {
    if (!mounted) return;
    final needsOnboarding = await OnboardingScreen.shouldShow();
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => needsOnboarding ? const OnboardingScreen() : const MapScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FaroColors.sand,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: FaroColors.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4)),
                  ],
                ),
                child: const Icon(
                  Icons.travel_explore,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Faro',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 38,
                  height: 1.1,
                  color: FaroColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                FaroStrings.splashTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF6A6A6A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
