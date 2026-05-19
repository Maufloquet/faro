import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../services/analytics_service.dart';
import '../widgets/faro_logo.dart';
import 'map_screen.dart';

/// Onboarding de UMA tela, bloqueante na primeira abertura.
///
/// Princípio do relatório §7.2: onboarding de múltiplas telas tem
/// abandono alto. Uma única tela com aceite explícito é o suficiente —
/// resto fica na tela /sobre/ e /ajuda/ acessível pelo header.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _prefsKey = 'onboarding_completed_v1';

  /// Roda no app start. Se já viu, vai direto pro mapa.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefsKey) ?? false);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('onboarding');
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen._prefsKey, true);
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MapScreen()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FaroColors.sand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _Header(),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Principle(
                      icon: Icons.warning_amber_rounded,
                      title: FaroStrings.principleNeverSafeTitle,
                      body: FaroStrings.principleNeverSafeBody,
                    ),
                    _Principle(
                      icon: Icons.layers_outlined,
                      title: FaroStrings.principleContextTitle,
                      body: FaroStrings.principleContextBody,
                    ),
                    _Principle(
                      icon: Icons.lock_outline,
                      title: FaroStrings.principleLocationTitle,
                      body: FaroStrings.principleLocationBody,
                    ),
                    _Principle(
                      icon: Icons.person_off_outlined,
                      title: FaroStrings.principleNoSignupTitle,
                      body: FaroStrings.principleNoSignupBody,
                    ),
                  ],
                ),
              ),
              _AcceptanceRow(
                checked: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed ? _complete : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: FaroColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: Text(FaroStrings.acceptanceCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FaroLogo(size: 60),
        const SizedBox(height: 18),
        Text(
          FaroStrings.onboardingHeadline,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 26,
            height: 1.15,
            color: FaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          FaroStrings.onboardingSubhead,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontStyle: FontStyle.italic,
            fontSize: 14,
            height: 1.4,
            color: FaroColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Principle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Principle({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 22, color: FaroColors.editorialBrown),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 16,
                    height: 1.25,
                    color: FaroColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: FaroColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptanceRow extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool?> onChanged;
  const _AcceptanceRow({required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: FaroColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                FaroStrings.acceptanceText,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: FaroColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
