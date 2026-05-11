import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/filters/time_window.dart';
import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import '../services/bairros_directory.dart';
import '../services/location_service.dart';
import '../services/marker_factory.dart';
import '../services/occurrences_service.dart';
import '../widgets/occurrence_detail_sheet.dart';
import '../widgets/occurrence_tile.dart';
import 'areas_screen.dart';
import 'help_screen.dart';
import 'search_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _salvador = CameraPosition(
    target: LatLng(-12.9714, -38.5014),
    zoom: 12,
  );

  GoogleMapController? _map;
  MapType _mapType = MapType.hybrid;
  TimeWindow _window = TimeWindow.semana;
  Set<String> _activeReasons = const {};
  final _location = LocationService();
  bool _locating = false;
  final _markerFactory = MarkerFactory();
  Map<RiskLevel, BitmapDescriptor>? _markerIcons;

  /// Limite de zoom que separa heatmap (zoom-out) de marcadores individuais.
  /// Salvador inteira cabe em ~12; bairro em ~14-15. Em 14.5 fica natural:
  /// vista de cidade/zona mostra heatmap, zoom de rua mostra markers.
  static const double _heatmapZoomThreshold = 14.5;
  double _zoom = 12;

  bool get _showHeatmap => _zoom < _heatmapZoomThreshold;

  bool _matchesFilters(Occurrence o) {
    if (!_window.includes(o.date)) return false;
    if (_activeReasons.isEmpty) return true;
    return _activeReasons.contains(o.mainReason);
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    // Auto-centro silencioso: só se permissão já foi concedida em sessão anterior
    WidgetsBinding.instance.addPostFrameCallback((_) => _silentCenter());
  }

  Future<void> _loadMarkers() async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final icons = await _markerFactory.all(devicePixelRatio: dpr);
    if (mounted) setState(() => _markerIcons = icons);
  }

  Future<void> _silentCenter() async {
    final pos = await _location.currentIfAlreadyAuthorized();
    if (pos == null || !mounted) return;
    final controller = _map;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
      ),
    );
  }

  Future<void> _focusOn(Occurrence o) async {
    final controller = _map;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(o.latitude, o.longitude), zoom: 16),
      ),
    );
  }

  Future<void> _openDetail(Occurrence o) async {
    await _focusOn(o);
    if (!mounted) return;
    await OccurrenceDetailSheet.show(context, o);
  }

  Future<void> _focusOnArea(double lat, double lng) async {
    final controller = _map;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 15),
      ),
    );
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Bairro>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null) return;
    await _focusOnArea(result.lat, result.lng);
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
  }

  void _onCameraMove(CameraPosition pos) {
    final wasHeatmap = _showHeatmap;
    _zoom = pos.zoom;
    // Só rebuilda quando cruza o limiar — evita rebuild a cada pan/zoom.
    if (wasHeatmap != _showHeatmap) {
      setState(() {});
    }
  }

  Future<void> _centerOnMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await _location.currentPosition();
      final controller = _map;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 15),
          ),
        );
      }
    } on LocationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 3)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível obter sua localização agora.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = ref.watch(recentOccurrencesProvider);
    final windowed = raw.whenData((list) => list.where((o) => _window.includes(o.date)).toList());
    final filtered = raw.whenData((list) => list.where(_matchesFilters).toList());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
      body: Stack(
        children: [
          _Map(
            initialCamera: _salvador,
            mapType: _mapType,
            occurrences: filtered.maybeWhen(data: (v) => v, orElse: () => const []),
            markerIcons: _markerIcons,
            asHeatmap: _showHeatmap,
            onCreated: (c) => _map = c,
            onTap: _openDetail,
            onCameraMove: _onCameraMove,
          ),
          _Header(onFocusArea: _focusOnArea, onSearch: _openSearch),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeWindowChips(
                  selected: _window,
                  onSelect: (w) => setState(() => _window = w),
                ),
                const SizedBox(height: 8),
                _ReasonChips(
                  pool: windowed.maybeWhen(data: (v) => v, orElse: () => const []),
                  active: _activeReasons,
                  onToggle: (reason) => setState(() {
                    final next = Set<String>.from(_activeReasons);
                    if (next.contains(reason)) {
                      next.remove(reason);
                    } else {
                      next.add(reason);
                    }
                    _activeReasons = next;
                  }),
                  onClear: () => setState(() => _activeReasons = const {}),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * 0.18 + 12,
            child: Column(
              children: [
                _MapTypeToggle(
                  isHybrid: _mapType == MapType.hybrid,
                  onTap: _toggleMapType,
                ),
                const SizedBox(height: 10),
                _LocateButton(loading: _locating, onTap: _centerOnMe),
              ],
            ),
          ),
          _Sheet(
            occurrences: filtered,
            window: _window,
            onTapTile: _openDetail,
            onExpandWindow: _window != TimeWindow.tudo
                ? () => setState(() => _window = TimeWindow.tudo)
                : null,
          ),
        ],
      ),
    ),
    );
  }
}

class _ReasonChips extends StatelessWidget {
  final List<Occurrence> pool;
  final Set<String> active;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  const _ReasonChips({
    required this.pool,
    required this.active,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final o in pool) {
      final r = o.mainReason;
      if (r == null) continue;
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length + (active.isEmpty ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (active.isNotEmpty && i == 0) {
            return _PillChip(
              label: 'Limpar',
              icon: Icons.close,
              color: const Color(0xFF8A3F3F),
              isSelected: false,
              onTap: onClear,
            );
          }
          final entry = entries[i - (active.isEmpty ? 0 : 1)];
          final isSelected = active.contains(entry.key);
          return _PillChip(
            label: '${entry.key} · ${entry.value}',
            isSelected: isSelected,
            onTap: () => onToggle(entry.key),
          );
        },
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;
  const _PillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? (color ?? const Color(0xFF8A6A3A))
        : Colors.white;
    final fg = isSelected ? Colors.white : const Color(0xFF2A2A2A);
    return Material(
      color: bg,
      elevation: 1.5,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeWindowChips extends StatelessWidget {
  final TimeWindow selected;
  final ValueChanged<TimeWindow> onSelect;
  const _TimeWindowChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TimeWindow.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final w = TimeWindow.values[i];
          final isSelected = w == selected;
          return Material(
            color: isSelected ? const Color(0xFF2A4A7A) : Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(w),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  w.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapTypeToggle extends StatelessWidget {
  final bool isHybrid;
  final VoidCallback onTap;
  const _MapTypeToggle({required this.isHybrid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(
            isHybrid ? Icons.map_outlined : Icons.satellite_alt_outlined,
            size: 22,
            color: const Color(0xFF2A4A7A),
          ),
        ),
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LocateButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFF2A4A7A),
                  ),
                )
              : const Icon(
                  Icons.my_location,
                  size: 22,
                  color: Color(0xFF2A4A7A),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// Map
// ============================================================================

class _Map extends StatelessWidget {
  final CameraPosition initialCamera;
  final MapType mapType;
  final List<Occurrence> occurrences;
  final Map<RiskLevel, BitmapDescriptor>? markerIcons;
  final bool asHeatmap;
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<Occurrence> onTap;
  final ValueChanged<CameraPosition> onCameraMove;

  const _Map({
    required this.initialCamera,
    required this.mapType,
    required this.occurrences,
    required this.markerIcons,
    required this.asHeatmap,
    required this.onCreated,
    required this.onTap,
    required this.onCameraMove,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialCamera,
      mapType: mapType,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      markers: asHeatmap ? const {} : _markers(),
      circles: asHeatmap ? const {} : _uncertaintyCircles(),
      heatmaps: asHeatmap ? _heatmaps() : const {},
      onMapCreated: onCreated,
      onCameraMove: onCameraMove,
    );
  }

  Set<Circle> _uncertaintyCircles() {
    // Desenha círculo de incerteza ao redor de ocorrências com geocoding
    // de centroide de cidade. Reforça visualmente \"aconteceu nessa região,
    // não nesse ponto exato\" — consistente com nosso princípio editorial
    // de \"nunca afirmar certeza\".
    return occurrences.where((o) => o.isCityCentroid).map((o) {
      final risk = classifyAge(o.date);
      return Circle(
        circleId: CircleId('uncertainty-${o.id}'),
        center: LatLng(o.latitude, o.longitude),
        radius: 1500, // metros — boa aproximação do raio de um bairro médio
        fillColor: risk.color.withValues(alpha: 0.10),
        strokeColor: risk.color.withValues(alpha: 0.40),
        strokeWidth: 1,
      );
    }).toSet();
  }

  Set<Marker> _markers() {
    final icons = markerIcons;
    return occurrences.map((o) {
      final risk = classifyAge(o.date);
      final icon = icons?[risk] ?? BitmapDescriptor.defaultMarkerWithHue(_fallbackHue(risk));
      return Marker(
        markerId: MarkerId(o.id),
        position: LatLng(o.latitude, o.longitude),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () => onTap(o),
      );
    }).toSet();
  }

  Set<Heatmap> _heatmaps() {
    if (occurrences.isEmpty) return const {};
    final points = occurrences
        .map((o) => WeightedLatLng(LatLng(o.latitude, o.longitude)))
        .toList(growable: false);
    return {
      Heatmap(
        heatmapId: const HeatmapId('faro_occurrences'),
        data: points,
        radius: HeatmapRadius.fromPixels(80),
        opacity: 0.85,
        // Paleta estilo \"surge\" do Uber: transparente nas bordas, amarelo
        // suave em densidade baixa, laranja em densidade média, vermelho
        // intenso onde concentra. Sem verde nem azul-base — evita tingir
        // o mapa inteiro.
        gradient: HeatmapGradient([
          HeatmapGradientColor(Color(0x00FFE082), 0.0),
          HeatmapGradientColor(Color(0xFFFFD56A), 0.15),
          HeatmapGradientColor(Color(0xFFFFA646), 0.35),
          HeatmapGradientColor(Color(0xFFFF6B3D), 0.6),
          HeatmapGradientColor(Color(0xFFD93030), 0.85),
          HeatmapGradientColor(Color(0xFF8B0000), 1.0),
        ]),
      ),
    };
  }

  double _fallbackHue(RiskLevel r) {
    switch (r) {
      case RiskLevel.highCorroborated:
      case RiskLevel.confirmedActivity:
        return BitmapDescriptor.hueRed;
      case RiskLevel.lightActivity:
        return BitmapDescriptor.hueOrange;
      case RiskLevel.noRecentReports:
      case RiskLevel.noData:
        return BitmapDescriptor.hueAzure;
    }
  }
}

// ============================================================================
// Header
// ============================================================================

class _Header extends StatelessWidget {
  final void Function(double lat, double lng)? onFocusArea;
  final VoidCallback? onSearch;
  const _Header({this.onFocusArea, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Color(0xFF2A4A7A)),
                      const SizedBox(width: 8),
                      Text(
                        'Buscar bairro em Salvador',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.insights_outlined, size: 22, color: Color(0xFF555555)),
              tooltip: 'Atividade por área',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AreasScreen(onFocus: onFocusArea)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 22, color: Color(0xFF555555)),
              tooltip: 'Como o Faro funciona',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Bottom Sheet
// ============================================================================

class _Sheet extends StatelessWidget {
  final AsyncValue<List<Occurrence>> occurrences;
  final TimeWindow window;
  final ValueChanged<Occurrence> onTapTile;
  final VoidCallback? onExpandWindow;

  const _Sheet({
    required this.occurrences,
    required this.window,
    required this.onTapTile,
    this.onExpandWindow,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.18,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2)),
            ],
          ),
          child: occurrences.when(
            data: (items) => _SheetContent(
              items: items,
              window: window,
              scrollController: scrollController,
              onTapTile: onTapTile,
              onExpandWindow: onExpandWindow,
            ),
            loading: () => const _SheetSimple(message: 'Carregando relatos…'),
            error: (e, _) => _SheetSimple(message: 'Erro ao carregar: $e'),
          ),
        );
      },
    );
  }
}

class _SheetContent extends StatelessWidget {
  final List<Occurrence> items;
  final TimeWindow window;
  final ScrollController scrollController;
  final ValueChanged<Occurrence> onTapTile;
  final VoidCallback? onExpandWindow;

  const _SheetContent({
    required this.items,
    required this.window,
    required this.scrollController,
    required this.onTapTile,
    this.onExpandWindow,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
    final mostRecent = sorted.isNotEmpty ? sorted.first.date : null;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        const _Handle(),
        _SummaryHeader(count: items.length, window: window),
        const Divider(height: 1),
        if (sorted.isEmpty)
          _EmptyState(window: window, onExpandWindow: onExpandWindow)
        else
          ...sorted.map(
            (o) => Column(
              children: [
                OccurrenceTile(occurrence: o, onTap: () => onTapTile(o)),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ),
          ),
        _Footer(mostRecent: mostRecent),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TimeWindow window;
  final VoidCallback? onExpandWindow;
  const _EmptyState({required this.window, this.onExpandWindow});

  @override
  Widget build(BuildContext context) {
    final scope = window == TimeWindow.tudo ? 'no histórico carregado' : 'em ${window.label.toLowerCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sem relatos $scope.',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15.5,
              height: 1.3,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Isso não significa que está seguro — significa que ninguém reportou nada nessa janela. Mantenha atenção.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF555555)),
          ),
          if (onExpandWindow != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onExpandWindow,
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Ver tudo o que temos'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int count;
  final TimeWindow window;
  const _SummaryHeader({required this.count, required this.window});

  @override
  Widget build(BuildContext context) {
    final scope = window == TimeWindow.tudo ? '' : ' · ${window.label.toLowerCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'Sem relatos$scope'
                : '$count relato${count > 1 ? "s" : ""}$scope',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              height: 1.2,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sem garantia de segurança. Apenas o que foi reportado.',
            style: TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF7A7A7A)),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final DateTime? mostRecent;
  const _Footer({this.mostRecent});

  @override
  Widget build(BuildContext context) {
    final freshness = _freshness(mostRecent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fonte: Fogo Cruzado',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF8A8A8A),
              fontStyle: FontStyle.italic,
            ),
          ),
          if (freshness != null) ...[
            const SizedBox(height: 3),
            Text(
              freshness,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF8A8A8A),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _freshness(DateTime? d) {
    if (d == null) return null;
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return 'Último relato há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Último relato há ${diff.inHours}h';
    return 'Último relato há ${diff.inDays}d';
  }
}

class _SheetSimple extends StatelessWidget {
  final String message;
  const _SheetSimple({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Handle(),
        const SizedBox(height: 18),
        Text(message, style: const TextStyle(color: Color(0xFF555555))),
      ],
    );
  }
}
