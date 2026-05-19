import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/i18n/faro_strings.dart';
import '../services/messaging_service.dart';
import '../services/safe_arrival_service.dart';

/// Linha discreta que exibe quantos "Cheguei bem" foram registrados na
/// célula geohash5 do ponto nas últimas 24h.
///
/// Princípio: sinal POSITIVO precisa de visibilidade equivalente ao
/// sinal negativo. Mas sem virar "métrica" — discreto, baixo contraste,
/// fonte serif suave. Some quando count == 0 (não polui card).
class SafeArrivalCounter extends ConsumerStatefulWidget {
  final double lat;
  final double lng;
  const SafeArrivalCounter({super.key, required this.lat, required this.lng});

  @override
  ConsumerState<SafeArrivalCounter> createState() => _SafeArrivalCounterState();
}

class _SafeArrivalCounterState extends ConsumerState<SafeArrivalCounter> {
  Future<int>? _future;
  String? _cell;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(SafeArrivalCounter old) {
    super.didUpdateWidget(old);
    final newCell = geohash5Of(widget.lat, widget.lng);
    if (newCell != _cell) _fetch();
  }

  void _fetch() {
    _cell = geohash5Of(widget.lat, widget.lng);
    _future = ref.read(safeArrivalServiceProvider).countLast24h(_cell!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _future,
      builder: (_, snap) {
        final count = snap.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 13,
                color: FaroColors.editorialBrown.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  FaroStrings.safeArrivalCountToday(count),
                  style: FaroTextStyles.body(
                    fontSize: 12,
                    color: FaroColors.editorialBrown.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
