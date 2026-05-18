import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/filters/time_window.dart';
import '../core/stats/area_activity.dart';
import '../core/stats/bus_line_activity.dart';
import '../core/stats/temporal_activity.dart';
import '../core/text/string_format.dart';
import '../models/occurrence.dart';
import '../services/analytics_service.dart';
import '../services/occurrences_service.dart';
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
    final busLines = filtered.maybeWhen(
      data: rankBusLines,
      orElse: () => <BusLineActivity>[],
    );
    final filteredList = filtered.maybeWhen(
      data: (v) => v,
      orElse: () => const <Occurrence>[],
    );
    final hourBuckets = rankByHour(filteredList);
    final weekdayBuckets = rankByWeekday(filteredList);
    final peak = peakHour(hourBuckets);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Atividade por área',
            style: TextStyle(fontFamily: FaroFonts.serifEditorial),
          ),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: FaroColors.primary,
            labelColor: FaroColors.primary,
            unselectedLabelColor: FaroColors.textSoft,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Bairros'),
              Tab(text: 'Linhas'),
              Tab(text: 'Padrões'),
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
                  _BusLinesTab(lines: busLines),
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

class _BusLinesTab extends StatelessWidget {
  final List<BusLineActivity> lines;
  const _BusLinesTab({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Text(
          'Sem linhas de ônibus citadas nesta janela. Linhas só aparecem '
          'quando uma matéria cita explicitamente o número/código da '
          'linha (ex.: "linha 1234"). Janelas curtas costumam ter poucos.',
          style: TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        const _BusLinesHeader(),
        const SizedBox(height: 12),
        ...lines.map((line) => _BusLineCard(activity: line)),
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
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Text(
          'Sem dados no período. Aumente a janela acima pra ver o padrão.',
          style: TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: FaroColors.editorialBrown),
              SizedBox(width: 8),
              Text(
                'Isto NÃO é um ranking de risco',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FaroColors.editorialBrown,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Mais relatos numa área podem indicar mais policiamento ativo, mais cobertura de mídia ou mais pessoas reportando — não necessariamente mais crime real. Use como contexto, não como julgamento.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: FaroColors.textSecondary),
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
                      w.label,
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
                    fontFamily: 'Georgia',
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
                    fontFamily: 'Georgia',
                    fontSize: 17,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${area.count} relatos',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: FaroColors.textSoft,
                ),
              ),
            ],
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
                      entry.key,
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Último relato: ${_relative(area.mostRecent)}',
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
                  label: const Text('Ver no mapa'),
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
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }
}

class _BusLinesHeader extends StatelessWidget {
  const _BusLinesHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E0EC)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_outlined, size: 18, color: FaroColors.primary),
              SizedBox(width: 8),
              Text(
                'Linhas de ônibus citadas',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FaroColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Linhas mencionadas em matérias de jornal sobre relatos do período. NÃO é ranking de linha perigosa — pessoa que depende da linha não pode trocar. Use pra se preparar (escolher horário, descer um ponto antes ou depois).',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: FaroColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BusLineCard extends StatelessWidget {
  final BusLineActivity activity;
  const _BusLineCard({required this.activity});

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FaroColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activity.line,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'citada em ${activity.count} ${activity.count == 1 ? "relato" : "relatos"}',
                  style: const TextStyle(fontSize: 13, color: FaroColors.textSecondary),
                ),
              ),
            ],
          ),
          if (activity.neighborhoodBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Bairros: ${activity.neighborhoodBreakdown.take(3).map((e) => titleCasePtBr(e.key)).join(" · ")}',
              style: const TextStyle(fontSize: 12.5, color: FaroColors.textMuted),
            ),
          ],
          if (activity.reasonBreakdown.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Tipos: ${activity.reasonBreakdown.take(3).map((e) => e.key).join(" · ")}',
              style: const TextStyle(fontSize: 12.5, color: FaroColors.textMuted),
            ),
          ],
        ],
      ),
    );
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
          const Row(
            children: [
              Icon(Icons.schedule, size: 18, color: FaroColors.editorialBrown),
              SizedBox(width: 8),
              Text(
                'Quando acontecem',
                style: TextStyle(
                  fontFamily: 'Georgia',
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
              'Horário com mais relatos: $peakLabel',
              style: const TextStyle(fontSize: 12.5, color: FaroColors.textMuted),
            ),
          const SizedBox(height: 4),
          const Text(
            'Padrão temporal dos relatos do período. NÃO é "evite esse horário" — quem precisa sair à noite não tem essa escolha. Use pra escolher quando der flexibilidade.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: FaroColors.textHint, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          TemporalChart(label: 'POR HORA DO DIA', entries: hourEntries),
          const SizedBox(height: 14),
          TemporalChart(label: 'POR DIA DA SEMANA', entries: weekdayEntries),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sem áreas com volume suficiente nesta janela.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15.5,
              height: 1.3,
              color: FaroColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Para entrar nesta lista, uma área precisa ter pelo menos 5 relatos no período. Isso evita listar bairros com 1 ou 2 ocorrências isoladas.',
            style: TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
          ),
        ],
      ),
    );
  }
}
