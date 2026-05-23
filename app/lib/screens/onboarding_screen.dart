import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/faro_logo.dart';
import 'map_screen.dart';

/// Onboarding em passos. Página 0 (princípios + aceite) é bloqueante.
/// Páginas 1-3 (perfil) são opcionais — cada uma tem botão "pular" e
/// "depois" sai pro mapa salvando o que já foi preenchido.
///
/// Decisão de design: a tela única continua sendo a porta de entrada
/// editorial. Os 3 passos seguintes são leves (3 selects), curtos, e
/// claramente marcados como opcionais — pra não inflar abandono.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const _prefsKey = 'onboarding_completed_v1';

  /// Roda no app start. Se já viu, vai direto pro mapa.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefsKey) ?? false);
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _agreed = false;
  int _pageIndex = 0;
  final _controller = PageController();

  // Drafts dos campos do perfil. Salvos no fim ou ao pular.
  Set<TransportMode> _transportModes = {};
  Set<HourBand> _typicalHours = {};
  String _mainNeighborhood = '';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('onboarding');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _persistFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen._prefsKey, true);
  }

  Future<void> _persistProfile() async {
    // Mesmo perfil parcialmente preenchido vale salvar — usuário pode
    // ter escolhido só "ônibus" e nada mais. App funciona com qualquer
    // subset.
    if (_transportModes.isEmpty &&
        _typicalHours.isEmpty &&
        _mainNeighborhood.trim().isEmpty) {
      return;
    }
    final next = UserProfile(
      transportModes: _transportModes.toList(),
      typicalHours: _typicalHours.toList(),
      mainNeighborhood:
          _mainNeighborhood.trim().isEmpty ? null : _mainNeighborhood.trim(),
    );
    try {
      await ref.read(userProfileServiceProvider).save(next);
    } catch (_) {
      // Falha silenciosa — usuário não deve ser bloqueado por erro
      // de Firestore na entrada. Pode preencher de novo em /Sobre.
    }
  }

  Future<void> _finish() async {
    await _persistFlag();
    await _persistProfile();
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MapScreen()),
    ));
  }

  Future<void> _advance() async {
    if (_pageIndex >= 3) {
      await _finish();
      return;
    }
    setState(() => _pageIndex++);
    unawaited(_controller.animateToPage(
      _pageIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
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
              if (_pageIndex == 0)
                _Header()
              else
                _StepIndicator(current: _pageIndex, total: 4),
              const SizedBox(height: 18),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PrinciplesPage(
                      agreed: _agreed,
                      onAgreedChanged: (v) =>
                          setState(() => _agreed = v ?? false),
                    ),
                    _TransportPage(
                      selected: _transportModes,
                      onChanged: (s) => setState(() => _transportModes = s),
                    ),
                    _HoursPage(
                      selected: _typicalHours,
                      onChanged: (s) => setState(() => _typicalHours = s),
                    ),
                    _NeighborhoodPage(
                      initial: _mainNeighborhood,
                      onChanged: (v) => _mainNeighborhood = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FooterButtons(
                pageIndex: _pageIndex,
                canAdvance: _pageIndex == 0 ? _agreed : true,
                onAdvance: _advance,
                onSkip: _pageIndex == 0 ? _finish : _finish,
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

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            height: 3,
            decoration: BoxDecoration(
              color: active ? FaroColors.primary : FaroColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _PrinciplesPage extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool?> onAgreedChanged;
  const _PrinciplesPage({required this.agreed, required this.onAgreedChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        _AcceptanceRow(checked: agreed, onChanged: onAgreedChanged),
      ],
    );
  }
}

class _StepPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _StepPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 22,
            height: 1.2,
            color: FaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: FaroColors.textSoft,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(child: child),
      ],
    );
  }
}

class _TransportPage extends StatelessWidget {
  final Set<TransportMode> selected;
  final ValueChanged<Set<TransportMode>> onChanged;
  const _TransportPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      title: 'Como você anda pela cidade?',
      subtitle: 'Marque tudo o que você usa. Opcional — pode pular.',
      child: ListView(
        children: TransportMode.values
            .map(
              (m) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.label),
                value: selected.contains(m),
                onChanged: (v) {
                  final next = {...selected};
                  if (v == true) {
                    next.add(m);
                  } else {
                    next.remove(m);
                  }
                  onChanged(next);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HoursPage extends StatelessWidget {
  final Set<HourBand> selected;
  final ValueChanged<Set<HourBand>> onChanged;
  const _HoursPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      title: 'Quando costuma andar na rua?',
      subtitle:
          'Pra entender quando o resumo do dia faz mais sentido pra você.',
      child: ListView(
        children: HourBand.values
            .map(
              (h) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(h.label),
                value: selected.contains(h),
                onChanged: (v) {
                  final next = {...selected};
                  if (v == true) {
                    next.add(h);
                  } else {
                    next.remove(h);
                  }
                  onChanged(next);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NeighborhoodPage extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _NeighborhoodPage({required this.initial, required this.onChanged});

  @override
  State<_NeighborhoodPage> createState() => _NeighborhoodPageState();
}

class _NeighborhoodPageState extends State<_NeighborhoodPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _controller.addListener(() => widget.onChanged(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      title: 'Qual seu bairro principal?',
      subtitle:
          'Casa, trabalho, escola. Resumo diário foca no que rola por aí.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Ex: Pituba, Liberdade, Centro…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Você pode mudar isso depois em "Meu perfil" no menu.',
            style: TextStyle(
              fontSize: 12,
              color: FaroColors.textHint,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButtons extends StatelessWidget {
  final int pageIndex;
  final bool canAdvance;
  final VoidCallback onAdvance;
  final VoidCallback onSkip;
  const _FooterButtons({
    required this.pageIndex,
    required this.canAdvance,
    required this.onAdvance,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isPrinciples = pageIndex == 0;
    final isLast = pageIndex == 3;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canAdvance ? onAdvance : null,
            style: FilledButton.styleFrom(
              backgroundColor: FaroColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: Text(
              isLast
                  ? 'Terminar'
                  : isPrinciples
                      ? FaroStrings.acceptanceCta
                      : 'Avançar',
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: FaroColors.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(fontSize: 13.5),
            ),
            child: Text(
              isPrinciples ? FaroStrings.acceptanceSkip : 'Pular e ir pro mapa',
            ),
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
