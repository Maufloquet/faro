import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/text/string_format.dart';
import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import '../screens/contestation_screen.dart';
import 'risk_dot.dart';

import '../core/design/tokens.dart';

/// Sheet modal mostrado quando o usuário toca em um marker ou item da lista.
///
/// Apresenta o relato de forma editorial: sem dramatizar, sem afirmar
/// segurança, com a fonte explícita.
class OccurrenceDetailSheet extends StatelessWidget {
  final Occurrence occurrence;

  const OccurrenceDetailSheet({super.key, required this.occurrence});

  static Future<void> show(BuildContext context, Occurrence o) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OccurrenceDetailSheet(occurrence: o),
    );
  }

  @override
  Widget build(BuildContext context) {
    final risk = _classify(occurrence.date);
    final where = titleCasePtBr(occurrence.neighborhood);
    final city = titleCasePtBr(occurrence.city);
    final what = occurrence.mainReason ?? 'Relato';
    final when = _absoluteTime(occurrence.date);
    final relative = _relativeTime(occurrence.date);

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: RiskDot(level: risk, size: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        where.isNotEmpty ? where : 'Sem localização específica',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 22,
                          height: 1.2,
                          color: FaroColors.textPrimary,
                        ),
                      ),
                      if (city.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            city,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: FaroColors.textSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (occurrence.externalTitle != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  occurrence.externalTitle!,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    height: 1.4,
                    color: FaroColors.textSecondary,
                  ),
                ),
              ),
            ],
            _LabeledRow(label: 'Tipo de relato', value: what),
            const Divider(height: 1),
            _LabeledRow(label: 'Quando', value: '$when · $relative'),
            const Divider(height: 1),
            _LabeledRow(
              label: 'Estado visual',
              value: risk.label,
              valueColor: risk.color,
            ),
            const Divider(height: 1),
            _SourceRow(occurrence: occurrence),
            if (occurrence.hasBusLines) ...[
              const Divider(height: 1),
              _LabeledRow(
                label: 'Linha de ônibus',
                value: occurrence.busLines.join(', '),
                hint: 'Linha mencionada na matéria. Pode ser apenas uma referência geográfica — não significa que toda corrida desta linha tem o mesmo risco.',
              ),
            ],
            if (occurrence.isCityCentroid) ...[
              const Divider(height: 1),
              const _LabeledRow(
                label: 'Localização',
                value: 'Aproximada (centro da cidade)',
                hint: 'Notícia não menciona bairro específico. Pin posicionado no centro da cidade.',
                valueColor: FaroColors.editorialOcher,
              ),
            ],
            const SizedBox(height: 24),
            const _DisclaimerBox(),
            const SizedBox(height: 14),
            if (occurrence.externalUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openExternal(context, occurrence.externalUrl!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ler matéria completa'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FaroColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openContestation(context),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Contestar relato'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  RiskLevel _classify(DateTime d) {
    final h = DateTime.now().difference(d).inHours;
    if (h < 2) return RiskLevel.confirmedActivity;
    if (h < 12) return RiskLevel.lightActivity;
    return RiskLevel.noRecentReports;
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }

  String _absoluteTime(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} às ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _openContestation(BuildContext context) async {
    Navigator.of(context).pop(); // fecha o sheet primeiro
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final submitted = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => ContestationScreen(occurrence: occurrence)),
    );
    if (submitted == true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contestação enviada. Será revisada em até 2h.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

class _SourceRow extends StatelessWidget {
  final Occurrence occurrence;
  const _SourceRow({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    switch (occurrence.source) {
      case OccurrenceSource.fogoCruzado:
        return const _LabeledRow(
          label: 'Fonte',
          value: 'Fogo Cruzado',
          hint: 'Banco público de violência armada (RJ, PE, BA, PA)',
        );
      case OccurrenceSource.media:
        final providerName = occurrence.sourceName ?? 'Mídia';
        return _LabeledRow(
          label: 'Fonte',
          value: providerName,
          hint: 'Notícia coletada e classificada automaticamente',
        );
      case OccurrenceSource.userReport:
        return const _LabeledRow(
          label: 'Fonte',
          value: 'Relato de usuário',
          hint: 'Reportado por outro usuário do app',
        );
      case OccurrenceSource.unknown:
        return const _LabeledRow(
          label: 'Fonte',
          value: 'Não identificada',
        );
    }
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  const _LabeledRow({
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: FaroColors.textSoft,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    color: valueColor ?? FaroColors.textPrimary,
                  ),
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      hint!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: FaroColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerBox extends StatelessWidget {
  const _DisclaimerBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FaroColors.sand,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: const Text(
        'Relato baseado em fonte pública. O Faro não garante segurança em nenhuma região — só comunica o que foi reportado. Erros acontecem.',
        style: TextStyle(fontSize: 12.5, height: 1.5, color: FaroColors.textMuted),
      ),
    );
  }
}
