import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../core/text/string_format.dart';
import '../models/crossing_event.dart';
import '../services/analytics_service.dart';
import '../services/crossing_history_service.dart';

/// Tela "Seu trajeto" — histórico **local** de cruzamentos do usuário com
/// zonas onde houve relato recente. Lista cronológica agrupada por dia.
///
/// Tudo o que aparece aqui foi gerado pelo BackgroundLocationService no
/// próprio celular. Nada vem do servidor. Nada é enviado pra fora.
class TrajectoryScreen extends ConsumerStatefulWidget {
  const TrajectoryScreen({super.key});

  @override
  ConsumerState<TrajectoryScreen> createState() => _TrajectoryScreenState();
}

class _TrajectoryScreenState extends ConsumerState<TrajectoryScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('trajectory');
  }

  @override
  Widget build(BuildContext context) {
    final asyncEvents = ref.watch(crossingHistoryStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          FaroStrings.trajTitle,
          style: const TextStyle(fontFamily: FaroFonts.serifEditorial),
        ),
        elevation: 0,
      ),
      body: asyncEvents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: _buildList,
      ),
    );
  }

  Widget _buildList(List<CrossingEvent> events) {
    if (events.isEmpty) return const _EmptyState();

    final groups = _groupByDay(events);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          FaroSpacing.xl, FaroSpacing.md, FaroSpacing.xl, FaroSpacing.xl3),
      itemCount: groups.length + 1, // +1 pro disclaimer no topo
      itemBuilder: (_, i) {
        if (i == 0) return const _PrivacyNote();
        final group = groups[i - 1];
        return Padding(
          padding: const EdgeInsets.only(top: FaroSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DayHeader(label: group.label),
              const SizedBox(height: FaroSpacing.sm),
              ...group.events.map((e) => _EventCard(event: e)),
            ],
          ),
        );
      },
    );
  }

  List<_DayGroup> _groupByDay(List<CrossingEvent> events) {
    final now = DateTime.now();
    final byDay = <String, List<CrossingEvent>>{};
    for (final e in events) {
      final key = _dayKey(e.at);
      byDay.putIfAbsent(key, () => []).add(e);
    }
    final groups = <_DayGroup>[];
    final sortedKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in sortedKeys) {
      final first = byDay[key]!.first;
      groups.add(_DayGroup(_dayLabel(first.at, now), byDay[key]!));
    }
    return groups;
  }

  String _dayKey(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  String _dayLabel(DateTime d, DateTime now) {
    final dl = d.toLocal();
    final nl = now.toLocal();
    final delta = DateTime(nl.year, nl.month, nl.day)
        .difference(DateTime(dl.year, dl.month, dl.day))
        .inDays;
    if (delta == 0) return FaroStrings.trajToday;
    if (delta == 1) return FaroStrings.trajYesterday;
    if (delta < 7) return FaroStrings.trajDaysAgo(delta);
    return '${dl.day.toString().padLeft(2, '0')}/${dl.month.toString().padLeft(2, '0')}';
  }
}

class _DayGroup {
  final String label;
  final List<CrossingEvent> events;
  _DayGroup(this.label, this.events);
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: FaroColors.textSoft,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CrossingEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final local = event.at.toLocal();
    final hourLabel =
        '${local.hour.toString().padLeft(2, '0')}h${local.minute.toString().padLeft(2, '0')}';
    final bairro = titleCasePtBr(event.neighborhood);
    final whatWord = FaroStrings.trajReportCount(event.reportCount);

    return Container(
      margin: const EdgeInsets.only(top: FaroSpacing.sm),
      padding: const EdgeInsets.all(FaroSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FaroColors.sandChip,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hourLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.editorialBrown,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: FaroSpacing.md),
              Expanded(
                child: Text(
                  bairro.isNotEmpty ? bairro : FaroStrings.trajApproxLocation,
                  style: const TextStyle(
                    fontFamily: FaroFonts.serifEditorial,
                    fontSize: 16,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
              Text(
                whatWord,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: FaroColors.textSoft,
                ),
              ),
            ],
          ),
          if (event.topReasons.isNotEmpty) ...[
            const SizedBox(height: FaroSpacing.sm),
            Text(
              event.topReasons.join(' · '),
              style: const TextStyle(
                fontSize: 12.5,
                color: FaroColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: FaroSpacing.xs),
          Text(
            FaroStrings.trajPassedSafe,
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: FaroColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FaroSpacing.md),
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
              const Icon(Icons.lock_outline, size: 16, color: FaroColors.editorialBrown),
              const SizedBox(width: FaroSpacing.sm),
              Text(
                FaroStrings.trajPrivacyTitle,
                style: const TextStyle(
                  fontFamily: FaroFonts.serifEditorial,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: FaroColors.editorialBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: FaroSpacing.sm),
          Text(
            FaroStrings.trajPrivacyBody,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: FaroColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          FaroSpacing.xl, FaroSpacing.xl3, FaroSpacing.xl, FaroSpacing.xl3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PrivacyNote(),
          const SizedBox(height: FaroSpacing.xl),
          Text(
            FaroStrings.trajEmptyTitle,
            style: const TextStyle(
              fontFamily: FaroFonts.serifEditorial,
              fontSize: 18,
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: FaroSpacing.sm),
          Text(
            FaroStrings.trajEmptyBody,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: FaroColors.textMuted,
            ),
          ),
          const SizedBox(height: FaroSpacing.sm),
          Text(
            '${FaroStrings.silenceDisclaimer}.',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: FaroColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FaroSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: FaroColors.textSoft),
            const SizedBox(height: FaroSpacing.sm),
            Text(
              FaroStrings.trajErrorBody(message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: FaroColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
