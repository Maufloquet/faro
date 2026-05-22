import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../services/favorites_service.dart';

/// Botão de coração compacto pra (de)favoritar um bairro a partir de
/// qualquer card. Mostra estado atual e dá feedback via SnackBar.
///
/// Variantes:
///  - `FavoriteButton` (ícone): pra header, drawer e contextos onde
///    espaço é apertado.
///  - `FavoriteToggleChip` (pill com label "Acompanhar"/"Acompanhando"):
///    pra card de área onde a feature precisa ser descoberta. Antes só
///    tinha o ícone solto e ninguém percebia que o bairro podia ser
///    seguido.
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

/// Variante pill do FavoriteButton — label visível "Acompanhar"/
/// "Acompanhando". Usar no rodapé de cards de área pra que a feature
/// seja descoberta. Hit area >= 44x44, contraste editorial.
class FavoriteToggleChip extends ConsumerStatefulWidget {
  final String name;
  final String? city;
  final double lat;
  final double lng;

  const FavoriteToggleChip({
    super.key,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
  });

  @override
  ConsumerState<FavoriteToggleChip> createState() => _FavoriteToggleChipState();
}

class _FavoriteToggleChipState extends ConsumerState<FavoriteToggleChip> {
  bool? _isFav;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(FavoriteToggleChip oldWidget) {
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
    final color =
        filled ? FaroColors.editorialOcher : FaroColors.textMuted;
    final label = filled
        ? FaroStrings.favoritesFollowingLabel
        : FaroStrings.favoritesFollowLabel;
    return InkWell(
      onTap: _isFav == null ? null : _toggle,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? FaroColors.editorialOcher.withAlpha(20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled
                ? FaroColors.editorialOcher.withAlpha(120)
                : FaroColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filled ? Icons.favorite : Icons.favorite_outline,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
