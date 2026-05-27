import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../models/user_report.dart';
import '../services/report_service.dart';

/// Folha de detalhe de um relato de usuário (Camada 4).
///
/// Deixa explícito que é um relato NÃO confirmado — visual e texto
/// diferentes da ocorrência de fonte oficial, pra o usuário nunca
/// confundir boato com notícia apurada. Traz a validação coletiva:
/// confirmar/contestar em 2 toques (escondida no próprio relato).
class ReportDetailSheet extends ConsumerStatefulWidget {
  final UserReport report;

  const ReportDetailSheet({super.key, required this.report});

  static Future<void> show(BuildContext context, UserReport report) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportDetailSheet(report: report),
    );
  }

  @override
  ConsumerState<ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends ConsumerState<ReportDetailSheet> {
  bool _voting = false;

  Future<void> _vote(ReportVote vote) async {
    if (_voting) return;
    setState(() => _voting = true);
    try {
      await HapticFeedback.selectionClick();
      await ref
          .read(reportServiceProvider)
          .vote(reportId: widget.report.id, vote: vote);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível votar. Tente de novo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Versão ao vivo do relato (contagens/status mudam após votos);
    // cai pro objeto inicial enquanto o stream não resolve.
    final live = ref
        .watch(reportByIdProvider(widget.report.id))
        .maybeWhen(data: (r) => r, orElse: () => null);
    final report = live ?? widget.report;
    final myVote =
        ref.watch(myReportVoteProvider(widget.report.id)).maybeWhen(
              data: (v) => v,
              orElse: () => null,
            );
    final isMine =
        ref.read(reportServiceProvider).currentUid == report.createdBy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _UnconfirmedBadge(),
            const SizedBox(height: 12),
            Text(
              report.type.label,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 19,
                height: 1.2,
                color: FaroColors.textPrimary,
              ),
            ),
            if (report.description != null &&
                report.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                report.description!,
                style: const TextStyle(
                    fontSize: 14, height: 1.45, color: FaroColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _meta(report),
              style: const TextStyle(fontSize: 12.5, color: FaroColors.textSoft),
            ),
            const SizedBox(height: 18),
            if (isMine)
              _MineNote()
            else
              _VoteRow(
                myVote: myVote,
                busy: _voting,
                onConfirm: () => _vote(ReportVote.confirm),
                onContest: () => _vote(ReportVote.contest),
              ),
          ],
        ),
      ),
    );
  }

  String _meta(UserReport r) {
    final parts = <String>[];
    final when = _age(r.createdAt);
    if (when != null) parts.add(when);
    parts.add(r.confirmCount == 0
        ? 'Ainda sem confirmação'
        : r.confirmCount == 1
            ? '1 confirmação'
            : '${r.confirmCount} confirmações');
    return parts.join(' · ');
  }

  String? _age(DateTime? d) {
    if (d == null) return null;
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Agora há pouco';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours} h';
    return 'Há ${diff.inDays} d';
  }
}

class _VoteRow extends StatelessWidget {
  final ReportVote? myVote;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onContest;

  const _VoteRow({
    required this.myVote,
    required this.busy,
    required this.onConfirm,
    required this.onContest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Você está perto e viu?',
          style: TextStyle(
            fontSize: 12.5,
            color: FaroColors.textSoft,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _VoteButton(
                icon: Icons.check_circle_outline,
                label: 'Confirmo',
                selected: myVote == ReportVote.confirm,
                color: FaroColors.primary,
                busy: busy,
                onTap: onConfirm,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VoteButton(
                icon: Icons.cancel_outlined,
                label: 'Não procede',
                selected: myVote == ReportVote.contest,
                color: FaroColors.destructive,
                busy: busy,
                onTap: onContest,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : FaroColors.sandBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: selected ? Colors.white : color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : FaroColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Este é o seu relato. Outras pessoas perto é que confirmam.',
      style: TextStyle(fontSize: 12.5, color: FaroColors.textSoft),
    );
  }
}

class _UnconfirmedBadge extends StatelessWidget {
  const _UnconfirmedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_pin_circle_outlined,
              size: 15, color: FaroColors.textMuted),
          SizedBox(width: 6),
          Text(
            'Relato de usuário · não confirmado',
            style: TextStyle(
              fontSize: 11.5,
              color: FaroColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
