import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../models/user_report.dart';

/// Folha de detalhe de um relato de usuário (Camada 4).
///
/// Deixa explícito que é um relato NÃO confirmado — visual e texto
/// diferentes da ocorrência de fonte oficial, pra o usuário nunca
/// confundir boato com notícia apurada. Os botões de confirmar/contestar
/// entram no Bloco 2.
class ReportDetailSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }

  String _meta(UserReport r) {
    final parts = <String>[];
    final when = _age(r.createdAt);
    if (when != null) parts.add(when);
    if (r.confirmCount > 0) {
      parts.add(r.confirmCount == 1
          ? '1 confirmação'
          : '${r.confirmCount} confirmações');
    } else {
      parts.add('Ainda sem confirmação');
    }
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
