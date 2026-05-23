import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../services/analytics_service.dart';
import '../services/background_location_service.dart';
import '../services/local_notification_service.dart';
import '../services/reference_location_service.dart';
import '../widgets/account_card.dart';
import '../widgets/safe_arrival_button.dart';
import 'account_actions_screen.dart';
import 'profile_screen.dart';

/// Tela /sobre/ — transparência editorial pública.
///
/// Lista fontes de dados, princípios e contato. Acessível pela tela de
/// ajuda. Mantém o tom editorial: honesta sobre limitações.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('about');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FaroStrings.aboutTitle, style: const TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const AccountCard(),
          const SizedBox(height: 12),
          const _ProfileEntry(),
          const SizedBox(height: 12),
          const _PrivacyEntry(),
          const SizedBox(height: 12),
          const SafeArrivalButton(),
          const SizedBox(height: 12),
          const _BackgroundAlertsToggle(),
          const SizedBox(height: 12),
          const _ReferenceLocationCard(),
          const SizedBox(height: 18),
          _Section(
            title: FaroStrings.aboutSectionWhatWeAreTitle,
            body: FaroStrings.aboutSectionWhatWeAreBody,
          ),
          _Section(
            title: FaroStrings.aboutSectionWhatWeAreNotTitle,
            body: FaroStrings.aboutSectionWhatWeAreNotBody,
          ),
          _Section(
            title: FaroStrings.aboutSectionNoSignupTitle,
            body: FaroStrings.aboutSectionNoSignupBody,
          ),
          _Section(
            title: FaroStrings.aboutSectionSourcesTitle,
            body: FaroStrings.aboutSectionSourcesBody,
          ),
          _Section(
            title: FaroStrings.aboutSectionPrivacyTitle,
            body: FaroStrings.aboutSectionPrivacyBody,
          ),
          const _TechDetailsExpansion(),
          const SizedBox(height: 18),
          _Section(
            title: FaroStrings.aboutSectionHowToUseTitle,
            body: FaroStrings.aboutSectionHowToUseBody,
          ),
          _Section(
            title: FaroStrings.aboutSectionContactTitle,
            body: FaroStrings.aboutSectionContactBody,
          ),
          const SizedBox(height: 24),
          const _Version(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 17,
              height: 1.25,
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: FaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundAlertsToggle extends StatefulWidget {
  const _BackgroundAlertsToggle();

  @override
  State<_BackgroundAlertsToggle> createState() => _BackgroundAlertsToggleState();
}

class _BackgroundAlertsToggleState extends State<_BackgroundAlertsToggle> {
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await BackgroundLocationService.isOptedIn();
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  Future<void> _toggle(bool target) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (!target) {
        await BackgroundLocationService.setOptIn(false);
        await BackgroundLocationService.instance.stop();
        if (mounted) setState(() => _enabled = false);
        return;
      }

      final locOk = await _ensureAlwaysLocation();
      if (!locOk) {
        if (mounted) _showInfo(FaroStrings.aboutPermLocationAlwaysNeeded);
        return;
      }

      await LocalNotificationService.instance.initialize();
      final notifOk = await LocalNotificationService.instance.requestPermission();
      if (!notifOk) {
        if (mounted) _showInfo(FaroStrings.aboutPermNotifNeeded);
        return;
      }

      await BackgroundLocationService.setOptIn(true);
      final started = await BackgroundLocationService.instance.start();
      if (!mounted) return;
      setState(() => _enabled = started);
      if (!started) _showInfo(FaroStrings.aboutBgAlertsStartFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ensureAlwaysLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return false;
    }
    if (perm == LocationPermission.whileInUse) {
      // iOS: pedir Always explicitamente (segundo prompt do sistema)
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always;
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7D5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8CCAE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.notifications_active_outlined,
                size: 22, color: FaroColors.editorialBrown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FaroStrings.aboutBgAlertsTitle,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 15,
                    color: FaroColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _enabled
                      ? FaroStrings.aboutBgAlertsBodyOn
                      : FaroStrings.aboutBgAlertsBodyOff,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: FaroColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _busy ? null : _toggle,
            activeThumbColor: FaroColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Card que permite o usuário definir 1 endereço fixo de referência
/// (hotel, casa, trabalho) e receber alerta quando há relato perto **mesmo
/// se estiver longe do local agora**. Útil pra turista hospedado em
/// algum lugar e quer saber do entorno do hotel ao longo do dia.
class _ReferenceLocationCard extends StatefulWidget {
  const _ReferenceLocationCard();

  @override
  State<_ReferenceLocationCard> createState() => _ReferenceLocationCardState();
}

class _ReferenceLocationCardState extends State<_ReferenceLocationCard> {
  ReferenceLocation? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ReferenceLocationService.instance.current();
    if (!mounted) return;
    setState(() => _current = r);
  }

  Future<void> _saveFromCurrentLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Permissão whileInUse já é suficiente pra captura pontual.
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showInfo(FaroStrings.aboutRefLocationNeeded);
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final label = await _askLabel();
      if (label == null) return; // usuário cancelou

      await ReferenceLocationService.instance.save(
        ReferenceLocation(lat: pos.latitude, lng: pos.longitude, label: label),
      );
      await _load();
      if (mounted) _showInfo(FaroStrings.aboutRefSaved);
    } catch (e) {
      _showInfo(FaroStrings.aboutRefSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askLabel() async {
    final controller = TextEditingController(
      text: _current?.label ?? FaroStrings.aboutRefDialogDefault,
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          FaroStrings.aboutRefDialogTitle,
          style: const TextStyle(fontFamily: FaroFonts.serifEditorial, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: FaroStrings.aboutRefDialogHint,
            border: const OutlineInputBorder(),
          ),
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(FaroStrings.aboutRefCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FaroColors.primary),
            onPressed: () {
              final v = controller.text.trim();
              Navigator.of(ctx).pop(v.isEmpty ? FaroStrings.aboutRefDialogFallback : v);
            },
            child: Text(FaroStrings.aboutRefSave),
          ),
        ],
      ),
    );
  }

  Future<void> _remove() async {
    await ReferenceLocationService.instance.clear();
    await _load();
    if (mounted) _showInfo(FaroStrings.aboutRefRemoved);
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final r = _current;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_outlined,
                    size: 22, color: FaroColors.editorialBrown),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FaroStrings.aboutRefTitle,
                      style: const TextStyle(
                        fontFamily: FaroFonts.serifEditorial,
                        fontSize: 15,
                        color: FaroColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r == null
                          ? FaroStrings.aboutRefEmpty
                          : FaroStrings.aboutRefActive(r.label),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: FaroColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (r != null)
                TextButton(
                  onPressed: _busy ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: FaroColors.destructive,
                  ),
                  child: Text(FaroStrings.aboutRefRemove),
                ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _busy ? null : _saveFromCurrentLocation,
                style: FilledButton.styleFrom(
                  backgroundColor: FaroColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.my_location, size: 16),
                label: Text(
                  r == null ? FaroStrings.aboutRefUseCurrent : FaroStrings.aboutRefSwap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bloco colapsável com detalhes técnicos que interessam a poucos:
/// como o risco é classificado, viés algorítmico, fonte da densidade
/// populacional. Mantido aqui pra transparência editorial — só não
/// é exibido por padrão pra não inflar a tela "Sobre" pra quem quer
/// a visão geral.
class _TechDetailsExpansion extends StatelessWidget {
  const _TechDetailsExpansion();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Text(
          FaroStrings.aboutTechDetailsTitle,
          style: const TextStyle(
            fontFamily: FaroFonts.serifEditorial,
            fontSize: 17,
            color: FaroColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            FaroStrings.aboutTechDetailsSubtitle,
            style: const TextStyle(fontSize: 12.5, color: FaroColors.textSoft),
          ),
        ),
        iconColor: FaroColors.editorialBrown,
        collapsedIconColor: FaroColors.editorialBrown,
        children: [
          _Section(
            title: FaroStrings.aboutTechRiskTitle,
            body: FaroStrings.aboutTechRiskBody,
          ),
          _Section(
            title: FaroStrings.aboutTechBiasTitle,
            body: FaroStrings.aboutTechBiasBody,
          ),
          _Section(
            title: FaroStrings.aboutTechDensityTitle,
            body: FaroStrings.aboutTechDensityBody,
          ),
        ],
      ),
    );
  }
}

class _PrivacyEntry extends StatelessWidget {
  const _PrivacyEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountActionsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacidade e dados',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Termos, política, exportar e apagar conta.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FaroColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FaroColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada pra `ProfileScreen` — mora no /Sobre/ pra não poluir o
/// nav principal. Visível pra qualquer usuário (anonymous ou Google).
class _ProfileEntry extends StatelessWidget {
  const _ProfileEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meu perfil',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Personalize resumo diário e sugestões — tudo opcional.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FaroColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FaroColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        FaroStrings.aboutVersion,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF8A8A8A),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
