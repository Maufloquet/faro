import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/i18n/faro_strings.dart';
import '../core/text/string_format.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';

/// Tela de bairros favoritados. Lista cards com nome (Bairro · Cidade),
/// data de adição, e botões "Ver no mapa" / "Remover".
///
/// Estado vazio explica como favoritar.
class FavoritesScreen extends ConsumerStatefulWidget {
  /// Callback opcional — quando o usuário toca em "Ver no mapa", o
  /// MapScreen é centralizado nessa coordenada via callback de
  /// navegação. Mesmo padrão do AreasScreen.onFocus.
  final void Function(double lat, double lng)? onFocus;

  const FavoritesScreen({super.key, this.onFocus});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('favorites');
  }

  Future<void> _remove(FavoriteNeighborhood fav) async {
    await ref.read(favoritesServiceProvider).remove(fav.id);
    ref.invalidate(favoritesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(FaroStrings.favoritesRemoved(fav.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          FaroStrings.favoritesTitle,
          style: FaroTextStyles.headlineMedium(
            color: FaroColors.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: favs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _FavoriteCard(
              fav: list[i],
              onRemove: () => _remove(list[i]),
              onFocus: widget.onFocus,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_border,
              size: 36, color: FaroColors.textHint),
          const SizedBox(height: 14),
          Text(
            FaroStrings.favoritesEmptyTitle,
            style: FaroTextStyles.headlineMedium(
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            FaroStrings.favoritesEmptyBody,
            style: FaroTextStyles.body(
              fontSize: 13.5,
              color: FaroColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteNeighborhood fav;
  final VoidCallback onRemove;
  final void Function(double, double)? onFocus;
  const _FavoriteCard({
    required this.fav,
    required this.onRemove,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final name = titleCasePtBr(fav.name);
    final city = titleCasePtBr(fav.city ?? '');
    final where = city.isEmpty ? name : '$name · $city';
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.favorite,
                  size: 18, color: FaroColors.editorialOcher),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FaroTextStyles.title(
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(FaroStrings.favoritesActionRemove),
                style: TextButton.styleFrom(
                  foregroundColor: FaroColors.destructive,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              if (onFocus != null)
                FilledButton.icon(
                  onPressed: () {
                    onFocus!(fav.centroidLat, fav.centroidLng);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text(FaroStrings.areasViewOnMap),
                  style: FilledButton.styleFrom(
                    backgroundColor: FaroColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
