import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/filters/time_window.dart';
import '../core/stats/area_activity.dart';
import '../core/text/string_format.dart';
import '../services/analytics_service.dart';
import '../services/occurrences_service.dart';

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
      data: (list) => rankAreas(list, topN: 5, minCount: 5),
      orElse: () => <AreaActivity>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atividade por área', style: TextStyle(fontFamily: 'Georgia')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _Disclaimer(),
          const SizedBox(height: 16),
          _WindowSelector(
            selected: _window,
            onSelect: (w) => setState(() => _window = w),
          ),
          const SizedBox(height: 20),
          if (areas.isEmpty)
            const _EmptyState()
          else
            ...areas.asMap().entries.map(
                  (e) => _AreaCard(
                    rank: e.key + 1,
                    area: e.value,
                    onFocus: widget.onFocus,
                  ),
                ),
        ],
      ),
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
        color: const Color(0xFFFBF6EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DFD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF7A5C2C)),
              const SizedBox(width: 8),
              Text(
                'Isto NÃO é um ranking de risco',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A5C2C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Mais relatos numa área podem indicar mais policiamento ativo, mais cobertura de mídia ou mais pessoas reportando — não necessariamente mais crime real. Use como contexto, não como julgamento.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF3A3A3A)),
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
              color: isSelected ? const Color(0xFF2A4A7A) : Colors.white,
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
        border: Border.all(color: const Color(0xFFE6E6DC)),
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
                    color: Color(0xFF7A5C2C),
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
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                '${area.count} relatos',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF7A7A7A),
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
                      color: Color(0xFF8A6A3A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3A)),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A7A7A)),
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
                  color: Color(0xFF8A8A8A),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Sem áreas com volume suficiente nesta janela.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15.5,
              height: 1.3,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Para entrar nesta lista, uma área precisa ter pelo menos 5 relatos no período. Isso evita listar bairros com 1 ou 2 ocorrências isoladas.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}
