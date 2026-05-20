import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../core/text/string_format.dart';
import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import '../screens/contestation_screen.dart';
import '../services/density_service.dart';
import 'risk_dot.dart';

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
    final what = occurrence.mainReason == null
        ? FaroStrings.occReportFallback
        : FaroStrings.reasonLabel(occurrence.mainReason!);
    final when = _absoluteTime(occurrence.date);
    final relative = _relativeTime(occurrence.date);
    final population = DensityService.instance.populationFor(
      occurrence.neighborhood,
    );
    final isEstimatedPop =
        DensityService.instance.isEstimated(occurrence.neighborhood) ?? false;
    final populationLine = _populationLine(population, isEstimatedPop);

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
                        where.isNotEmpty ? where : FaroStrings.occNoLocation,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
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
                      if (populationLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Tooltip(
                            message: isEstimatedPop
                                ? 'População estimada: pop da Prefeitura-Bairro (Censo 2010) dividida entre os bairros listados.'
                                : 'População do Censo IBGE 2022 (dado publicado para este bairro).',
                            child: Text(
                              populationLine,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: FaroColors.textHint,
                                fontStyle: FontStyle.italic,
                              ),
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
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    height: 1.4,
                    color: FaroColors.textSecondary,
                  ),
                ),
              ),
            ],
            _LabeledRow(label: FaroStrings.occLabelReason, value: what),
            const Divider(height: 1),
            _LabeledRow(label: FaroStrings.occLabelWhen, value: '$when · $relative'),
            const Divider(height: 1),
            _LabeledRow(
              label: FaroStrings.occLabelVisual,
              value: FaroStrings.riskLabel(risk),
              valueColor: risk.color,
            ),
            const Divider(height: 1),
            _SourceRow(occurrence: occurrence),
            if (occurrence.hasBusLines) ...[
              const Divider(height: 1),
              _LabeledRow(
                label: FaroStrings.occLabelBusLine,
                value: occurrence.busLines.join(', '),
                hint: FaroStrings.occLabelBusLineHint,
              ),
            ],
            if (occurrence.isCityCentroid) ...[
              const Divider(height: 1),
              _LabeledRow(
                label: FaroStrings.occLabelLocation,
                value: FaroStrings.occApproxValue,
                hint: FaroStrings.occApproxHint,
                valueColor: FaroColors.editorialOcher,
              ),
            ],
            if (occurrence.hasContestations) ...[
              const SizedBox(height: 18),
              _ContestationNotice(occurrence: occurrence),
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
                    label: Text(FaroStrings.occReadFullStory),
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
                label: Text(FaroStrings.occChallenge),
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
    if (diff.inMinutes < 60) return FaroStrings.occRelMinutes(diff.inMinutes);
    if (diff.inHours < 24) return FaroStrings.occRelHours(diff.inHours);
    return FaroStrings.occRelDays(diff.inDays);
  }

  String _absoluteTime(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${FaroStrings.occAbsoluteAt} ${two(local.hour)}:${two(local.minute)}';
  }

  String? _populationLine(int? population, bool isEstimated) {
    if (population == null || population <= 0) return null;
    final prefix = isEstimated ? '~' : '';
    if (population >= 1000) {
      final thousands = (population / 1000).toStringAsFixed(0);
      return '$prefix$thousands mil habitantes';
    }
    return '$prefix$population habitantes';
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FaroStrings.occOpenLinkFailed)),
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
        SnackBar(
          content: Text(FaroStrings.occChallengeSubmitted),
          duration: const Duration(seconds: 3),
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
        return _LabeledRow(
          label: FaroStrings.occLabelSource,
          value: FaroStrings.occFogoCruzadoLabel,
          hint: FaroStrings.occSourceFcHint,
        );
      case OccurrenceSource.media:
        final providerName = occurrence.sourceName ?? FaroStrings.occMediaFallback;
        return _LabeledRow(
          label: FaroStrings.occLabelSource,
          value: providerName,
          hint: FaroStrings.occSourceMediaHint,
        );
      case OccurrenceSource.userReport:
        return _LabeledRow(
          label: FaroStrings.occLabelSource,
          value: FaroStrings.occSourceUserValue,
          hint: FaroStrings.occSourceUserHint,
        );
      case OccurrenceSource.unknown:
        return _LabeledRow(
          label: FaroStrings.occLabelSource,
          value: FaroStrings.occSourceUnknown,
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
      child: Text(
        FaroStrings.occDisclaimer,
        style: const TextStyle(fontSize: 12.5, height: 1.5, color: FaroColors.textMuted),
      ),
    );
  }
}

class _ContestationNotice extends StatelessWidget {
  final Occurrence occurrence;
  const _ContestationNotice({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final n = occurrence.contestationDistinctUsers;
    final contested = occurrence.contested;

    // Tom calibrado por nível: poucas contestações = nota neutra,
    // acima do threshold (contested=true) = atenção visível.
    final message = contested
        ? 'Este relato foi questionado por $n usuários distintos.'
        : (n == 1
            ? 'Um usuário questionou este relato.'
            : '$n usuários questionaram este relato.');
    final bg = contested ? const Color(0xFFFCEDE3) : FaroColors.sand;
    final border = contested ? FaroColors.editorialOcher : FaroColors.sandBorder;
    final icon = contested ? Icons.flag_outlined : Icons.info_outline;
    final iconColor = contested ? FaroColors.editorialOcher : FaroColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: FaroColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
