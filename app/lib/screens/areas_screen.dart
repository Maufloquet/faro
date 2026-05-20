import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/filters/time_window.dart';
import '../core/i18n/faro_strings.dart';
import '../core/stats/area_activity.dart';
import '../core/stats/temporal_activity.dart';
import '../core/stats/transport_activity.dart';
import '../core/text/string_format.dart';
import '../models/occurrence.dart';
import '../services/analytics_service.dart';
import '../services/occurrences_service.dart';
import '../widgets/favorite_button.dart';
import '../services/density_service.dart';
import '../widgets/safe_arrival_counter.dart';
import '../widgets/temporal_chart.dart';

/// Tela "Atividade recente por área".
///
/// Editorialmente: NÃO é um ranking de bairros perigosos. É um snapshot
/// temporal de onde teve mais movimentação reportada. Threshold mínimo
/// + disclaimer fixo no topo previne uso como gradação moral.
class AreasScreen extends ConsumerStatefulWidget {
  /// Callback opcional pra centralizar o mapa na área quando o usuário
  /// toca em "Ver no mapa". Recebe lat/lng do centroide.
  final void Function(double lat, double lng)? onFocus;
  const AreasScreen({super.key, this.onFocus});

  @override
  ConsumerState<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends ConsumerState<AreasScreen> {
  TimeWindow _window = TimeWindow.semana;
  /// Modal selecionado nos chips da aba "Em transporte".
  /// `null` = todos; `'onibus'` ou `'metro'` filtra.
  String? _transportModal;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('areas');
  }

  @override
  Widget build(BuildContext context) {
    final raw = ref.watch(recentOccurrencesProvider);
    final filtered = raw.whenData(
      (list) => list.where((o) => _window.includes(o.date)).toList(),
    );
    final areas = filtered.maybeWhen(
      data: (list) => rankAreas(list),
      orElse: () => <AreaActivity>[],
    );
    final filteredList = filtered.maybeWhen(
      data: (v) => v,
      orElse: () => const <Occurrence>[],
    );
    final transportAreas =
        rankTransportAreas(filteredList, modal: _transportModal);
    final modalCounts = countByModal(filteredList);
    final hourBuckets = rankByHour(filteredList);
    final weekdayBuckets = rankByWeekday(filteredList);
    final peak = peakHour(hourBuckets);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            FaroStrings.areasTitle,
            style: const TextStyle(fontFamily: FaroFonts.serifEditorial),
          ),
          elevation: 0,
          bottom: TabBar(
            indicatorColor: FaroColors.primary,
            labelColor: FaroColors.primary,
            unselectedLabelColor: FaroColors.textSoft,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: FaroStrings.areasTabNeighborhoods),
              Tab(text: FaroStrings.areasTabTransport),
              Tab(text: FaroStrings.areasTabPatterns),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  const _Disclaimer(),
                  const SizedBox(height: 12),
                  _WindowSelector(
                    selected: _window,
                    onSelect: (w) => setState(() => _window = w),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AreasTab(areas: areas, onFocus: widget.onFocus),
                  _TransportTab(
                    areas: transportAreas,
                    modal: _transportModal,
                    busCount: modalCounts.bus,
                    metroCount: modalCounts.metro,
                    onModalChange: (m) => setState(() => _transportModal = m),
                    onFocus: widget.onFocus,
                  ),
                  _PatternsTab(
                    hasData: filteredList.isNotEmpty,
                    hourEntries: TemporalEntries.fromHours(hourBuckets),
                    weekdayEntries: TemporalEntries.fromWeekdays(weekdayBuckets),
                    peakHour: peak,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Abas ───────────────────────────────────────────────────────────────

class _AreasTab extends StatelessWidget {
  final List<AreaActivity> areas;
  final void Function(double, double)? onFocus;
  const _AreasTab({required this.areas, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: areas.length,
      itemBuilder: (_, i) => _AreaCard(
        rank: i + 1,
        area: areas[i],
        onFocus: onFocus,
      ),
    );
  }
}

class _TransportTab extends StatelessWidget {
  final List<TransportAreaActivity> areas;
  final String? modal; // null=todos, 'onibus', 'metro'
  final int busCount;
  final int metroCount;
  final ValueChanged<String?> onModalChange;
  final void Function(double, double)? onFocus;

  const _TransportTab({
    required this.areas,
    required this.modal,
    required this.busCount,
    required this.metroCount,
    required this.onModalChange,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final showEmpty = areas.isEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        const _TransportHeader(),
        const SizedBox(height: 10),
        _TransportFilterChips(
          modal: modal,
          busCount: busCount,
          metroCount: metroCount,
          onChange: onModalChange,
        ),
        const SizedBox(height: 12),
        if (showEmpty)
          const _TransportEmptyState()
        else
          ...areas.map((a) => _TransportAreaCard(activity: a, onFocus: onFocus)),
      ],
    );
  }
}

class _PatternsTab extends StatelessWidget {
  final bool hasData;
  final List<({String tag, int count})> hourEntries;
  final List<({String tag, int count})> weekdayEntries;
  final int? peakHour;
  const _PatternsTab({
    required this.hasData,
    required this.hourEntries,
    required this.weekdayEntries,
    required this.peakHour,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Text(
          FaroStrings.areasNoPatternsBody,
          style: const TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _TemporalSection(
          hourEntries: hourEntries,
          weekdayEntries: weekdayEntries,
          peakHour: peakHour,
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: FaroColors.editorialBrown),
              const SizedBox(width: 8),
              Text(
                FaroStrings.notARiskRanking,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FaroColors.editorialBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            FaroStrings.areasDisclaimerBody,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: FaroColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WindowSelector extends StatelessWidget {
  final TimeWindow selected;
  final ValueChanged<TimeWindow> onSelect;
  const _WindowSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TimeWindow.values.map((w) {
        final isSelected = w == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: isSelected ? FaroColors.primary : Colors.white,
              elevation: 1.5,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(w),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      FaroStrings.timeWindowLabel(w),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF2A2A2A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final int rank;
  final AreaActivity area;
  final void Function(double, double)? onFocus;
  const _AreaCard({required this.rank, required this.area, this.onFocus});

  @override
  Widget build(BuildContext context) {
    final name = titleCasePtBr(area.name);
    final per10k = DensityService.instance.per10kInhabitants(
      bairro: area.name,
      count: area.count,
    );
    final isEstimated = DensityService.instance.isEstimated(area.name) ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FaroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBDF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.editorialBrown,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 17,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
              Text(
                FaroStrings.areasReportCount(area.count),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: FaroColors.textSoft,
                ),
              ),
              FavoriteButton(
                name: area.name,
                city: null,
                lat: area.centroidLat,
                lng: area.centroidLng,
              ),
            ],
          ),
          if (per10k != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 40),
              child: Tooltip(
                message: isEstimated
                    ? 'Estimativa: população da Prefeitura-Bairro dividida entre os bairros. Quando o Censo 2022 publicar agregação bairro-granular, esse valor será substituído pelo dado oficial.'
                    : 'Censo IBGE 2022, dado publicado para este bairro.',
                child: Text(
                  '${isEstimated ? '~' : ''}${per10k.toStringAsFixed(1)} relatos por 10 mil habitantes',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: FaroColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ...area.reasonBreakdown.take(3).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: FaroColors.editorialOcher,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      FaroStrings.reasonLabel(entry.key),
                      style: const TextStyle(fontSize: 13, color: FaroColors.textSecondary),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontSize: 12.5, color: FaroColors.textSoft),
                  ),
                ],
              ),
            );
          }),
          SafeArrivalCounter(lat: area.centroidLat, lng: area.centroidLng),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                FaroStrings.areasLastReport(_relative(area.mostRecent)),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: FaroColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (onFocus != null)
                TextButton.icon(
                  onPressed: () {
                    onFocus!(area.centroidLat, area.centroidLng);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text(FaroStrings.areasViewOnMap),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return FaroStrings.occRelMinutes(diff.inMinutes);
    if (diff.inHours < 24) return FaroStrings.occRelHours(diff.inHours);
    return FaroStrings.occRelDays(diff.inDays);
  }
}

class _TransportEmptyState extends StatelessWidget {
  const _TransportEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.directions_bus_outlined,
                  size: 18, color: FaroColors.editorialBrown),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FaroStrings.areasTransportEmptyTitle,
                  style: const TextStyle(
                    fontFamily: FaroFonts.serifEditorial,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            FaroStrings.areasTransportEmptyBody,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: FaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportHeader extends StatelessWidget {
  const _TransportHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_outlined, size: 18, color: FaroColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FaroStrings.areasTransportHeaderTitle,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            FaroStrings.areasTransportHeaderBody,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: FaroColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TransportFilterChips extends StatelessWidget {
  final String? modal;
  final int busCount;
  final int metroCount;
  final ValueChanged<String?> onChange;

  const _TransportFilterChips({
    required this.modal,
    required this.busCount,
    required this.metroCount,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _ModalChip(
          label: '${FaroStrings.areasTransportFilterAll} · ${busCount + metroCount}',
          selected: modal == null,
          onTap: () => onChange(null),
        ),
        _ModalChip(
          label: '🚌 ${FaroStrings.areasTransportFilterBus} · $busCount',
          selected: modal == 'onibus',
          onTap: () => onChange(modal == 'onibus' ? null : 'onibus'),
        ),
        if (metroCount > 0)
          _ModalChip(
            label: '🚇 ${FaroStrings.areasTransportFilterMetro} · $metroCount',
            selected: modal == 'metro',
            onTap: () => onChange(modal == 'metro' ? null : 'metro'),
          ),
      ],
    );
  }
}

class _ModalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FaroColors.primary : FaroColors.sandChip,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : FaroColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportAreaCard extends StatelessWidget {
  final TransportAreaActivity activity;
  final void Function(double, double)? onFocus;
  const _TransportAreaCard({required this.activity, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    final name = titleCasePtBr(activity.neighborhood);
    final city = titleCasePtBr(activity.city ?? '');
    final where = city.isEmpty ? name : '$name · $city';
    final modalSummary = FaroStrings.areasTransportModalCount(
      activity.onibusCount,
      activity.metroCount,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FaroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 16,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
              Text(
                modalSummary,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: FaroColors.textSoft,
                ),
              ),
              FavoriteButton(
                name: activity.neighborhood,
                city: activity.city,
                lat: activity.centroidLat,
                lng: activity.centroidLng,
              ),
            ],
          ),
          if (activity.reasonBreakdown.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              activity.reasonBreakdown
                  .take(3)
                  .map((e) => FaroStrings.reasonLabel(e.key))
                  .join(' · '),
              style: const TextStyle(fontSize: 12.5, color: FaroColors.textMuted),
            ),
          ],
          SafeArrivalCounter(
            lat: activity.centroidLat,
            lng: activity.centroidLng,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                FaroStrings.areasLastReport(_relative(activity.mostRecent)),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: FaroColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (onFocus != null)
                TextButton.icon(
                  onPressed: () {
                    onFocus!(activity.centroidLat, activity.centroidLng);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text(FaroStrings.areasViewOnMap),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return FaroStrings.occRelMinutes(diff.inMinutes);
    if (diff.inHours < 24) return FaroStrings.occRelHours(diff.inHours);
    return FaroStrings.occRelDays(diff.inDays);
  }
}

class _TemporalSection extends StatelessWidget {
  final List<({String tag, int count})> hourEntries;
  final List<({String tag, int count})> weekdayEntries;
  final int? peakHour;

  const _TemporalSection({
    required this.hourEntries,
    required this.weekdayEntries,
    required this.peakHour,
  });

  @override
  Widget build(BuildContext context) {
    final peakLabel = peakHour == null
        ? null
        : '${peakHour!.toString().padLeft(2, '0')}h–${(peakHour! + 1).toString().padLeft(2, '0')}h';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FaroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: FaroColors.editorialBrown),
              const SizedBox(width: 8),
              Text(
                FaroStrings.areasPatternsTitle,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: FaroColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (peakLabel != null)
            Text(
              FaroStrings.areasPatternsPeak(peakLabel),
              style: const TextStyle(fontSize: 12.5, color: FaroColors.textMuted),
            ),
          const SizedBox(height: 4),
          Text(
            FaroStrings.areasPatternsHint,
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: FaroColors.textHint, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          TemporalChart(label: FaroStrings.areasChartByHour, entries: hourEntries),
          const SizedBox(height: 14),
          TemporalChart(label: FaroStrings.areasChartByWeekday, entries: weekdayEntries),
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FaroStrings.areasEmptyTitle,
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 15.5,
              height: 1.3,
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            FaroStrings.areasEmptyBody,
            style: const TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
          ),
        ],
      ),
    );
  }
}
