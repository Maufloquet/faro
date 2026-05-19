import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/driving/driving_mode.dart';
import '../core/i18n/faro_strings.dart';
import '../services/analytics_service.dart';

class DrivingProfileScreen extends ConsumerStatefulWidget {
  const DrivingProfileScreen({super.key});

  @override
  ConsumerState<DrivingProfileScreen> createState() =>
      _DrivingProfileScreenState();
}

class _DrivingProfileScreenState extends ConsumerState<DrivingProfileScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('driving_profile');
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(drivingModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          FaroStrings.drivingProfileTitle,
          style: const TextStyle(fontFamily: 'Georgia'),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Option(
            icon: Icons.do_not_disturb_off_outlined,
            label: FaroStrings.drivingOff,
            selected: current == DrivingMode.off,
            onTap: () =>
                ref.read(drivingModeProvider.notifier).set(DrivingMode.off),
          ),
          const Divider(height: 1, indent: 56),
          _Option(
            icon: Icons.directions_car_outlined,
            label: FaroStrings.drivingCar,
            subtitle: FaroStrings.drivingCarHint,
            selected: current == DrivingMode.car,
            onTap: () =>
                ref.read(drivingModeProvider.notifier).set(DrivingMode.car),
          ),
          const Divider(height: 1, indent: 56),
          _Option(
            icon: Icons.directions_bike_outlined,
            label: FaroStrings.drivingBike,
            subtitle: FaroStrings.drivingBikeHint,
            selected: current == DrivingMode.bike,
            onTap: () =>
                ref.read(drivingModeProvider.notifier).set(DrivingMode.bike),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _Option({
    required this.icon,
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
      title: Row(
        children: [
          Icon(icon, size: 18, color: FaroColors.editorialBrown),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15.5,
                color: FaroColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4, left: 28),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: FaroColors.textSoft,
                ),
              ),
            ),
    );
  }
}
