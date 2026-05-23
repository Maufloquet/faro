import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/narrative.dart';
import '../services/narrative_service.dart';

/// Faixa horizontal exibida no topo da AreasScreen com as narrativas
/// semanais ativas. Visível só quando o backend tem clusters de >=3
/// relatos relacionados — caso contrário a faixa esconde para não criar
/// destaque vazio.
///
/// Tom editorial: nunca veredito. `headline` vem pré-formada do servidor
/// (`narrativeAggregator.editorialHeadline`) com tom neutro. UI aqui
/// só renderiza.
class NarrativesStrip extends ConsumerWidget {
  const NarrativesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNarratives = ref.watch(activeNarrativesProvider);
    return asyncNarratives.maybeWhen(
      data: (narratives) {
        if (narratives.isEmpty) return const SizedBox.shrink();
        return _Strip(narratives: narratives);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Strip extends StatelessWidget {
  final List<Narrative> narratives;
  const _Strip({required this.narratives});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Esta semana',
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: narratives.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _NarrativeCard(narrative: narratives[i]),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final Narrative narrative;
  const _NarrativeCard({required this.narrative});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${narrative.count} relatos relacionados',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              narrative.headline,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.3,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
