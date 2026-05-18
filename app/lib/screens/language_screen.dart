import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../core/i18n/locale_notifier.dart';
import '../services/analytics_service.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('language');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localeNotifierProvider);
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final autoCode = FaroStrings.resolveAutoCode(deviceLocale);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          FaroStrings.languageTitle,
          style: const TextStyle(fontFamily: 'Georgia'),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Option(
            label: FaroStrings.languageAuto,
            subtitle: FaroStrings.languageAutoCurrent(
              FaroStrings.languageNativeName(autoCode),
            ),
            selected: state.override == null,
            onTap: () => ref
                .read(localeNotifierProvider.notifier)
                .set(null, deviceLocale),
          ),
          const Divider(height: 1, indent: 56),
          _Option(
            label: FaroStrings.languagePortuguese,
            selected: state.override == 'pt',
            onTap: () => ref
                .read(localeNotifierProvider.notifier)
                .set('pt', deviceLocale),
          ),
          const Divider(height: 1, indent: 56),
          _Option(
            label: FaroStrings.languageEnglish,
            selected: state.override == 'en',
            onTap: () => ref
                .read(localeNotifierProvider.notifier)
                .set('en', deviceLocale),
          ),
          const Divider(height: 1, indent: 56),
          _Option(
            label: FaroStrings.languageSpanish,
            selected: state.override == 'es',
            onTap: () => ref
                .read(localeNotifierProvider.notifier)
                .set('es', deviceLocale),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 22,
        color: selected ? FaroColors.primary : FaroColors.textHint,
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 15.5,
          color: FaroColors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: FaroColors.textSoft,
                ),
              ),
            ),
    );
  }
}
