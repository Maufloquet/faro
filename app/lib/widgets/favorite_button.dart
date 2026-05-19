import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../services/favorites_service.dart';

/// Botão de coração compacto pra (de)favoritar um bairro a partir de
/// qualquer card. Mostra estado atual e dá feedback via SnackBar.
///
/// Uso típico no AreaCard / TransportAreaCard:
///   FavoriteButton(
///     name: 'Mata Escura',
///     city: 'Salvador',
///     lat: -12.91,
///     lng: -38.45,
///   )
class FavoriteButton extends ConsumerStatefulWidget {
  final String name;
  final String? city;
  final double lat;
  final double lng;
  final double size;

  const FavoriteButton({
    super.key,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
    this.size = 20,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool? _isFav;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) _check();
  }

  Future<void> _check() async {
    final fav =
        await ref.read(favoritesServiceProvider).isFavorite(widget.name);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggle() async {
    final svc = ref.read(favoritesServiceProvider);
    final id = normalizeNeighborhoodId(widget.name);
    if (_isFav == true) {
      await svc.remove(id);
      ref.invalidate(favoritesProvider);
      if (!mounted) return;
      setState(() => _isFav = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FaroStrings.favoritesRemoved(widget.name))),
      );
    } else {
      await svc.add(FavoriteNeighborhood(
        id: id,
        name: widget.name,
        city: widget.city,
        centroidLat: widget.lat,
        centroidLng: widget.lng,
        addedAt: DateTime.now(),
      ));
      ref.invalidate(favoritesProvider);
      if (!mounted) return;
      setState(() => _isFav = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FaroStrings.favoritesAdded(widget.name))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = _isFav == true;
    return IconButton(
      onPressed: _isFav == null ? null : _toggle,
      icon: Icon(
        filled ? Icons.favorite : Icons.favorite_outline,
        size: widget.size,
        color: filled ? FaroColors.editorialOcher : FaroColors.textHint,
      ),
      tooltip: filled
          ? FaroStrings.favoritesActionRemove
          : FaroStrings.favoritesActionAdd,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
    );
  }
}
