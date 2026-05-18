import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import 'map_screen.dart';

import '../core/design/tokens.dart';

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
                  children: const [
                    _Principle(
                      icon: Icons.warning_amber_rounded,
                      title: 'O Faro não diz que está seguro',
                      body:
                          'Mostramos relatos recentes na sua região. Silêncio nos dados não é silêncio nas ruas — mantenha sua atenção sempre.',
                    ),
                    _Principle(
                      icon: Icons.travel_explore,
                      title: 'É contexto, não veredito',
                      body:
                          'Combinamos dados públicos (Fogo Cruzado), notícias e (em breve) relatos de outros usuários. Cada fonte tem peso editorial diferente.',
                    ),
                    _Principle(
                      icon: Icons.lock_outline,
                      title: 'Sua localização fica com você',
                      body:
                          'Usamos GPS só pra mostrar o que está perto. Não armazenamos seu histórico individual de trajetos.',
                    ),
                    _Principle(
                      icon: Icons.person_off_outlined,
                      title: 'Sem cadastro, sem perfil',
                      body:
                          'Você não precisa criar conta. Não pedimos email, nome ou telefone. Seu uso é anônimo desde o primeiro toque.',
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
                  child: const Text('Entendi, abrir o mapa'),
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
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: FaroColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.travel_explore, size: 30, color: Colors.white),
        ),
        const SizedBox(height: 18),
        const Text(
          'Bem-vindo ao Faro',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 26,
            height: 1.15,
            color: FaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Antes de começar, quatro coisas que você precisa saber:',
          style: TextStyle(
            fontFamily: 'Georgia',
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
                    fontFamily: 'Georgia',
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
            const Expanded(
              child: Text(
                'Entendo que o Faro é uma ferramenta de informação, não de garantia. Continuo responsável pelas minhas decisões.',
                style: TextStyle(
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
