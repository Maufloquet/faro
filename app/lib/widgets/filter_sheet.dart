import 'package:flutter/material.dart';

import '../core/filters/time_window.dart';
import '../models/occurrence.dart';

import '../core/design/tokens.dart';

/// Pílula compacta que substitui as 2 fileiras de chips no topo do mapa.
/// Mostra estado atual ("7 dias · todos os tipos") e abre o sheet ao tocar.
///
/// Princípio: 1 controle visível no mapa em vez de 2 fileiras de chips.
class FilterPill extends StatelessWidget {
  final TimeWindow window;
  final Set<String> activeReasons;
  final VoidCallback onTap;
  const FilterPill({
    super.key,
    required this.window,
    required this.activeReasons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasReasons = activeReasons.isNotEmpty;
    final reasonsLabel = activeReasons.isEmpty
        ? 'todos os tipos'
        : activeReasons.length == 1
            ? activeReasons.first
            : '${activeReasons.first} +${activeReasons.length - 1}';

    return Material(
      color: hasReasons ? FaroColors.primary : Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: hasReasons ? Colors.white : FaroColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${window.label} · $reasonsLabel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasReasons ? Colors.white : FaroColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado da edição de filtros — TimeWindow + razões selecionadas.
class FilterSelection {
  final TimeWindow window;
  final Set<String> reasons;
  const FilterSelection(this.window, this.reasons);
}

/// Bottom sheet modal que edita TimeWindow + razões. Retorna a seleção
/// final via Navigator.pop. Recebe a [pool] de ocorrências pra exibir
/// contagem ao lado de cada razão.
class FilterSheet extends StatefulWidget {
  final TimeWindow initialWindow;
  final Set<String> initialReasons;
  final List<Occurrence> pool;

  const FilterSheet({
    super.key,
    required this.initialWindow,
    required this.initialReasons,
    required this.pool,
  });

  static Future<FilterSelection?> show(
    BuildContext context, {
    required TimeWindow window,
    required Set<String> reasons,
    required List<Occurrence> pool,
  }) {
    return showModalBottomSheet<FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilterSheet(
        initialWindow: window,
        initialReasons: reasons,
        pool: pool,
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late TimeWindow _window;
  late Set<String> _reasons;

  @override
  void initState() {
    super.initState();
    _window = widget.initialWindow;
    _reasons = Set<String>.from(widget.initialReasons);
  }

  @override
  Widget build(BuildContext context) {
    // Contagem por razão dentro da janela escolhida — atualiza ao trocar.
    final counts = <String, int>{};
    for (final o in widget.pool) {
      if (!_window.includes(o.date)) continue;
      final r = o.mainReason;
      if (r == null) continue;
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final reasonEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            const Text(
              'Período',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FaroColors.textSoft,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TimeWindow.values
                  .map((w) => _Chip(
                        label: w.label,
                        selected: w == _window,
                        onTap: () => setState(() => _window = w),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tipo de relato',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.textSoft,
                    letterSpacing: 0.3,
                  ),
                ),
                if (_reasons.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _reasons = {}),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Limpar', style: TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (reasonEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sem tipos com relatos neste período.',
                  style: TextStyle(fontSize: 13, color: FaroColors.textHint),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasonEntries.map((e) {
                  final selected = _reasons.contains(e.key);
                  return _Chip(
                    label: '${e.key} · ${e.value}',
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _reasons.remove(e.key);
                      } else {
                        _reasons.add(e.key);
                      }
                    }),
                  );
                }).toList(),
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  FilterSelection(_window, _reasons),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: FaroColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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
