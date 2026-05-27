import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/driving/driving_mode.dart';
import '../core/i18n/faro_strings.dart';
import '../core/i18n/locale_notifier.dart';
import '../services/location_service.dart';
import '../services/safe_arrival_service.dart';
import 'faro_logo.dart';
import '../screens/about_screen.dart';
import '../screens/areas_screen.dart';
import '../screens/driving_profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/help_screen.dart';
import '../screens/language_screen.dart';
import '../screens/trajectory_screen.dart';

/// Drawer lateral do mapa — paradigma Waze/Uber. Mapa-first: nunca cede
/// altura permanente pra navigation bar. Organizado em 3 seções editoriais
/// (Navegar / Configurações / Informações) pra ficar fácil escanear.
///
/// O drawer é fechado antes de cada `push` pra que o usuário volte ao
/// mapa após sair da sub-tela (em vez de cair de novo no menu aberto).
class FaroDrawer extends ConsumerWidget {
  final void Function(double lat, double lng)? onFocusArea;

  const FaroDrawer({super.key, this.onFocusArea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localeNotifierProvider);
    final currentLangCode = state.override ?? FaroStrings.currentCode;
    final drivingMode = ref.watch(drivingModeProvider);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const _SafeArrivalTile(),
                  const SizedBox(height: 4),
                  _SectionLabel(FaroStrings.drawerSectionNavigate),
                  _Item(
                    icon: Icons.map_outlined,
                    label: FaroStrings.menuMap,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _Item(
                    icon: Icons.insights_outlined,
                    label: FaroStrings.menuAreas,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AreasScreen(onFocus: onFocusArea),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.history,
                    label: FaroStrings.menuTrajectory,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrajectoryScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.favorite_outline,
                    label: FaroStrings.menuFavorites,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FavoritesScreen(onFocus: onFocusArea),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SectionLabel(FaroStrings.drawerSectionConfig),
                  _Item(
                    icon: Icons.translate,
                    label: FaroStrings.menuLanguage,
                    trailing: FaroStrings.languageNativeName(currentLangCode),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LanguageScreen(),
                        ),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.directions_car_outlined,
                    label: FaroStrings.menuDrivingMode,
                    trailing: _drivingModeLabel(drivingMode),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DrivingProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _SectionLabel(FaroStrings.drawerSectionInfo),
                  _Item(
                    icon: Icons.help_outline,
                    label: FaroStrings.menuHelp,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  _Item(
                    icon: Icons.info_outline,
                    label: FaroStrings.menuAbout,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

/// Ação destacada "Cheguei bem" no topo do menu — sinal positivo anônimo,
/// um toque. Fica aqui (e não enterrado no /Sobre) pra ser descoberto:
/// é a coisa que o usuário faz ao terminar bem um trajeto.
class _SafeArrivalTile extends ConsumerStatefulWidget {
  const _SafeArrivalTile();

  @override
  ConsumerState<_SafeArrivalTile> createState() => _SafeArrivalTileState();
}

class _SafeArrivalTileState extends ConsumerState<_SafeArrivalTile> {
  final _location = LocationService();
  bool _busy = false;

  /// Avisar que cheguei: pega a posição (sem travar se negar), abre o
  /// compartilhamento com a mensagem pronta pra mandar a um contato, e
  /// registra o sinal positivo anônimo de brinde.
  Future<void> _notify() async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      double? lat, lng;
      try {
        final pos = await _location.currentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
        // Sinal positivo anônimo (não bloqueia o compartilhar).
        unawaited(ref.read(safeArrivalServiceProvider).record(position: pos));
      } catch (_) {
        // Sem GPS: ainda mandamos a mensagem, só sem o link de mapa.
      }
      final msg = arrivalShareMessage(lat: lat, lng: lng);
      if (navigator.canPop()) navigator.pop(); // fecha o menu antes do share
      await Share.share(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _busy ? null : _notify,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FaroColors.sandBorder),
            ),
            child: Row(
              children: [
                _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: FaroColors.editorialBrown),
                      )
                    : const Icon(Icons.send_outlined,
                        size: 23, color: FaroColors.editorialBrown),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FaroStrings.safeArrivalAction,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 15.5,
                          color: FaroColors.textPrimary,
                        ),
                      ),
                      Text(
                        FaroStrings.safeArrivalDrawerHint,
                        style: const TextStyle(
                            fontSize: 12, color: FaroColors.textSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _drivingModeLabel(DrivingMode m) => switch (m) {
      DrivingMode.car => FaroStrings.drivingCar,
      DrivingMode.bike => FaroStrings.drivingBike,
      DrivingMode.off => FaroStrings.drivingOff,
    };

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        color: FaroColors.sandSoft,
        border: Border(bottom: BorderSide(color: FaroColors.sandBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaroLogo(size: 38),
              const SizedBox(width: 14),
              Text(
                'Faro',
                style: FaroTextStyles.headlineMedium(
                  color: FaroColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            FaroStrings.slogan,
            style: FaroTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FaroColors.editorialBrown,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            FaroStrings.drawerTagline,
            style: FaroTextStyles.tagline(
              fontSize: 11.5,
              color: FaroColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: FaroColors.textSoft,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: false,
      leading: Icon(icon, size: 22, color: FaroColors.editorialBrown),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 15,
          color: FaroColors.textPrimary,
        ),
      ),
      trailing: trailing == null
          ? const Icon(Icons.chevron_right, size: 18, color: FaroColors.textHint)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: FaroColors.textSoft,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 18, color: FaroColors.textHint),
              ],
            ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Text(
        FaroStrings.aboutVersion,
        style: const TextStyle(
          fontSize: 11,
          color: FaroColors.textHint,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
