import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../core/text/string_format.dart';
import '../models/occurrence.dart';
import '../services/analytics_service.dart';
import '../services/contestation_service.dart';

/// Tela de contestação de relato.
///
/// Princípio §10 do relatório: contestação é direito, com fricção
/// calibrada — 5 motivos pré-prontos + campo "outro" pra detalhar.
/// Filtra contestações automatizadas sem esconder o botão.
class ContestationScreen extends ConsumerStatefulWidget {
  final Occurrence occurrence;
  const ContestationScreen({super.key, required this.occurrence});

  @override
  ConsumerState<ContestationScreen> createState() => _ContestationScreenState();
}

class _ContestationScreenState extends ConsumerState<ContestationScreen> {
  ContestationReason? _reason;
  final _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('contestation');
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(contestationServiceProvider).submit(
            occurrenceId: widget.occurrence.id,
            reason: _reason!,
            detail: _detailController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ContestationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FaroStrings.contestSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final where = titleCasePtBr(widget.occurrence.neighborhood) +
        (widget.occurrence.city != null && widget.occurrence.neighborhood != null
            ? ' · ${titleCasePtBr(widget.occurrence.city)}'
            : titleCasePtBr(widget.occurrence.city ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: Text(FaroStrings.contestTitle, style: const TextStyle(fontFamily: 'Georgia')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _Disclaimer(),
          const SizedBox(height: 18),
          Text(
            FaroStrings.contestReport,
            style: const TextStyle(
              fontSize: 12.5,
              color: FaroColors.textSoft,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            where.isEmpty ? FaroStrings.occNoLocation : where,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              height: 1.3,
              color: FaroColors.textPrimary,
            ),
          ),
          if (widget.occurrence.mainReason != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.occurrence.mainReason!,
              style: const TextStyle(fontSize: 13.5, color: FaroColors.textMuted),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            FaroStrings.contestReasonHeader,
            style: const TextStyle(
              fontSize: 12.5,
              color: FaroColors.textSoft,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          ...ContestationReason.values.map((r) {
            final selected = _reason == r;
            return InkWell(
              onTap: _submitting ? null : () => setState(() => _reason = r),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? FaroColors.primary : FaroColors.textHint,
                    ),
                    const SizedBox(width: 12),
                    Text(r.label, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _detailController,
            enabled: !_submitting,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: FaroStrings.contestDetailsLabel,
              hintText: FaroStrings.contestDetailsHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _reason != null && !_submitting ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: FaroColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(FaroStrings.contestSend),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Text(
        FaroStrings.contestDisclaimer,
        style: const TextStyle(fontSize: 12.5, height: 1.55, color: FaroColors.textSecondary),
      ),
    );
  }
}
