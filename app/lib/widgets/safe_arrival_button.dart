import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/i18n/faro_strings.dart';
import '../services/safe_arrival_service.dart';

/// Botão minimalista "Cheguei bem". Anti-engajamento de propósito:
/// um toque, snackbar de confirmação, fecha. Não abre tela nem pede
/// dados adicionais.
///
/// Princípio: o usuário deveria querer sair do app — "cheguei bem"
/// significa que a viagem acabou bem, não que tem mais o que olhar.
class SafeArrivalButton extends ConsumerStatefulWidget {
  /// Se true, fecha o drawer/sheet após registrar (UX típico drawer).
  final bool popAfter;
  const SafeArrivalButton({super.key, this.popAfter = false});

  @override
  ConsumerState<SafeArrivalButton> createState() => _SafeArrivalButtonState();
}

class _SafeArrivalButtonState extends ConsumerState<SafeArrivalButton> {
  bool _busy = false;

  Future<void> _record() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(safeArrivalServiceProvider);
      final result = await svc.record();
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FaroStrings.safeArrivalLocationDenied)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FaroStrings.safeArrivalConfirmed),
          backgroundColor: FaroColors.editorialBrown,
        ),
      );
      if (widget.popAfter && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 20, color: FaroColors.editorialBrown),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  FaroStrings.safeArrivalAction,
                  style: FaroTextStyles.title(
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            FaroStrings.safeArrivalHint,
            style: FaroTextStyles.body(
              fontSize: 12.5,
              color: FaroColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _record,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(FaroStrings.safeArrivalAction),
              style: FilledButton.styleFrom(
                backgroundColor: FaroColors.editorialBrown,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
