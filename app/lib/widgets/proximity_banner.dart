import 'package:flutter/material.dart';

import '../core/i18n/faro_strings.dart';
import '../models/occurrence.dart';

DateTime _systemNow() => DateTime.now();

/// Banner editorial mostrado quando há relatos recentes na proximidade do
/// usuário. Tom **informativo, não alarmista** — sem "PERIGO" / "URGENTE" /
/// "EVITE" no copy. Pareado com o teste de tom em
/// `test/widgets/proximity_banner_test.dart`.
///
/// Renderiza dentro de um `Positioned` próprio porque é overlay no Stack do
/// mapa. Pra reuso fora desse contexto, embrulhe num `Stack` próprio.
class ProximityBanner extends StatelessWidget {
  final List<Occurrence> alerts;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  /// Permite injetar relógio nos testes — sem isso a string "há X min"
  /// depende de `DateTime.now()` e fica instável no CI.
  final DateTime Function() now;

  const ProximityBanner({
    super.key,
    required this.alerts,
    required this.onTap,
    required this.onDismiss,
    this.now = _systemNow,
  });

  @override
  Widget build(BuildContext context) {
    final n = alerts.length;
    final freshest = alerts.first;
    final diff = now().difference(freshest.date);
    final when = diff.inMinutes < 60
        ? FaroStrings.bannerWhenMinutes(diff.inMinutes)
        : FaroStrings.bannerWhenHours(diff.inHours);

    final headline = n == 1
        ? FaroStrings.bannerOneTitle
        : FaroStrings.bannerManyTitle(n);
    final subtext = n == 1
        ? FaroStrings.bannerOneSubtext(
            freshest.mainReason ?? FaroStrings.bannerReportFallback, when)
        : FaroStrings.bannerManySubtext(
            freshest.mainReason ?? FaroStrings.bannerReportFallbackLower, when);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 12,
      right: 12,
      child: Material(
        color: const Color(0xFFC46A2C),
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 22, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 14.5,
                          height: 1.2,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtext,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: FaroStrings.bannerDismiss,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
