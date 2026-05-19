import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../services/analytics_service.dart';
import 'about_screen.dart';

/// Tela de ajuda — explica o produto sem ser onboarding obrigatório.
///
/// Acessível via ícone "?" na app bar do mapa. Inspirada no padrão
/// {name}_help_screen.dart adotado em outros apps do autor.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('help');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FaroStrings.helpTitle, style: const TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: FaroStrings.helpAboutTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _Hero(),
          const SizedBox(height: 28),
          _FeatureCard(
            icon: Icons.map_outlined,
            title: FaroStrings.helpNotCrimeMapTitle,
            body: FaroStrings.helpNotCrimeMapBody,
          ),
          _FeatureCard(
            icon: Icons.warning_amber_rounded,
            title: FaroStrings.helpNeverSafeTitle,
            body: FaroStrings.helpNeverSafeBody,
          ),
          _FeatureCard(
            icon: Icons.layers_outlined,
            title: FaroStrings.helpSourcesTitle,
            body: FaroStrings.helpSourcesBody,
          ),
          _FeatureCard(
            icon: Icons.lock_outline,
            title: FaroStrings.helpPrivacyTitle,
            body: FaroStrings.helpPrivacyBody,
          ),
          const SizedBox(height: 24),
          const _AudienceHeader(),
          const SizedBox(height: 12),
          _AudienceCard(
            icon: Icons.directions_bus_outlined,
            title: FaroStrings.helpBusTitle,
            body: FaroStrings.helpBusBody,
          ),
          _AudienceCard(
            icon: Icons.local_taxi_outlined,
            title: FaroStrings.helpDriverTitle,
            body: FaroStrings.helpDriverBody,
          ),
          _AudienceCard(
            icon: Icons.delivery_dining_outlined,
            title: FaroStrings.helpDeliveryTitle,
            body: FaroStrings.helpDeliveryBody,
          ),
          _AudienceCard(
            icon: Icons.place_outlined,
            title: FaroStrings.helpTouristTitle,
            body: FaroStrings.helpTouristBody,
          ),
          const SizedBox(height: 16),
          const _Privacy(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FaroStrings.helpHeroTitle,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 28,
              height: 1.15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            FaroStrings.helpHeroBody,
            style: const TextStyle(fontSize: 14.5, height: 1.45, color: FaroColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _FeatureCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FaroColors.sand,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
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
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(fontSize: 13.5, height: 1.5, color: FaroColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceHeader extends StatelessWidget {
  const _AudienceHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FaroStrings.helpAudienceHeader,
          style: const TextStyle(
            fontFamily: FaroFonts.serifEditorial,
            fontSize: 20,
            color: FaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          FaroStrings.helpAudienceSubhead,
          style: const TextStyle(
            fontSize: 13,
            color: FaroColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _AudienceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _AudienceCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: FaroColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: FaroFonts.serifEditorial,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: FaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: FaroColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        FaroStrings.helpPrivacyFooter,
        style: const TextStyle(fontSize: 12.5, height: 1.55, color: FaroColors.textMuted),
      ),
    );
  }
}
