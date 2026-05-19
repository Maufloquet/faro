import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/i18n/faro_strings.dart';
import '../widgets/faro_logo.dart';
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
              const FaroLogo(size: 96, animated: true),
              const SizedBox(height: 22),
              Text(
                'Faro',
                style: FaroTextStyles.headlineDisplay(
                  color: FaroColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                FaroStrings.slogan,
                textAlign: TextAlign.center,
                style: FaroTextStyles.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: FaroColors.editorialBrown,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                FaroStrings.splashTagline,
                textAlign: TextAlign.center,
                style: FaroTextStyles.tagline(
                  fontSize: 13,
                  color: const Color(0xFF8A8A82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
