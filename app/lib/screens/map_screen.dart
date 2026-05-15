import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/filters/time_window.dart';
import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import '../services/analytics_service.dart';
import '../services/bairros_directory.dart';
import '../services/cluster_marker_factory.dart';
import '../services/location_service.dart';
import '../services/marker_factory.dart';
import '../services/messaging_service.dart';
import '../services/occurrences_service.dart';
import '../widgets/occurrence_detail_sheet.dart';
import '../widgets/occurrence_tile.dart';
import 'areas_screen.dart';
import 'help_screen.dart';
import 'search_screen.dart';

/// Nó do mapa pós-clustering. Pode ser um relato isolado ou um cluster
/// agregando vários relatos próximos.
class _MapNode {
  final double lat;
  final double lng;
  final List<Occurrence> members; // length 1 = single, >1 = cluster
  _MapNode(this.lat, this.lng, this.members);

  bool get isCluster => members.length > 1;
  int get count => members.length;

  /// Cluster herda o risco do relato mais recente (maior RiskLevel).
  RiskLevel get risk {
    RiskLevel max = RiskLevel.noRecentReports;
    for (final m in members) {
      final r = classifyAge(m.date);
      if (r.index > max.index) max = r;
    }
    return max;
  }
}

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
  final _messaging = MessagingService();
  bool _locating = false;
  bool _messagingReady = false;
  final _markerFactory = MarkerFactory();
  final _clusterFactory = ClusterMarkerFactory();
  Map<RiskLevel, BitmapDescriptor>? _markerIcons;
  Map<String, BitmapDescriptor>? _clusterIcons;

  /// Limite de zoom que separa heatmap (zoom-out) de marcadores individuais.
  /// Salvador inteira cabe em ~12; bairro em ~14-15. Em 14.5 fica natural:
  /// vista de cidade/zona mostra heatmap, zoom de rua mostra markers.
  static const double _heatmapZoomThreshold = 14.5;
  /// Zoom acima do qual NÃO agrupamos mais — usuário pediu street-level,
  /// queremos ver cada relato individualmente.
  static const double _clusterCeilingZoom = 17.0;
  double _zoom = 12;

  bool get _showHeatmap => _zoom < _heatmapZoomThreshold;
  bool get _shouldCluster => _zoom >= _heatmapZoomThreshold && _zoom < _clusterCeilingZoom;

  // Posição atual do usuário pra cálculos de proximidade.
  LatLng? _userPos;
  bool _alertDismissed = false;

  // Telemetria de zoom: log apenas quando bate um novo máximo de sessão.
  double _maxZoomLogged = 0;
  // Última quantidade de alertas de proximidade reportada — evita logar
  // repetidamente o mesmo banner enquanto o usuário olha.
  int _lastAlertCountLogged = 0;

  /// Raio (em km) pra considerar relato "próximo" do usuário.
  static const double _proximityRadiusKm = 1.0;
  static const Duration _proximityRecency = Duration(hours: 6);

  bool _matchesFilters(Occurrence o) {
    if (!_window.includes(o.date)) return false;
    if (_activeReasons.isEmpty) return true;
    return _activeReasons.contains(o.mainReason);
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    AnalyticsService.instance.logScreen('map');
    // Auto-centro silencioso: só se permissão já foi concedida em sessão anterior
    WidgetsBinding.instance.addPostFrameCallback((_) => _silentCenter());
  }

  Future<void> _loadMarkers() async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final icons = await _markerFactory.all(devicePixelRatio: dpr);
    final clusters = await _clusterFactory.all(devicePixelRatio: dpr);
    if (mounted) {
      setState(() {
        _markerIcons = icons;
        _clusterIcons = clusters;
      });
    }
  }

  /// Agrupa ocorrências em nós (single ou cluster) pra um dado zoom.
  /// Acima de [_clusterCeilingZoom], todos viram nós individuais.
  /// Entre [_heatmapZoomThreshold] e [_clusterCeilingZoom], células
  /// dimensionadas pra ~80px na tela agrupam relatos próximos.
  List<_MapNode> _buildNodes(List<Occurrence> occurrences) {
    if (!_shouldCluster || occurrences.isEmpty) {
      return [for (final o in occurrences) _MapNode(o.latitude, o.longitude, [o])];
    }
    // 1° de latitude ≈ 111320m. 1 pixel em zoom Z ≈ 156543 * cos(lat) / 2^Z metros.
    // Pra ~80px de raio de agregação:
    final lat0 = _salvador.target.latitude;
    final metersPerPixel = 156543.034 * math.cos(lat0 * math.pi / 180.0) / math.pow(2, _zoom);
    final cellMeters = 80 * metersPerPixel;
    final cellDeg = cellMeters / 111320.0;

    final cells = <String, List<Occurrence>>{};
    for (final o in occurrences) {
      final key = '${(o.latitude / cellDeg).floor()},${(o.longitude / cellDeg).floor()}';
      cells.putIfAbsent(key, () => []).add(o);
    }
    final nodes = <_MapNode>[];
    for (final group in cells.values) {
      if (group.length == 1) {
        final o = group.first;
        nodes.add(_MapNode(o.latitude, o.longitude, group));
      } else {
        // Centroide simples (média de lat/lng)
        final lat = group.fold(0.0, (a, o) => a + o.latitude) / group.length;
        final lng = group.fold(0.0, (a, o) => a + o.longitude) / group.length;
        nodes.add(_MapNode(lat, lng, group));
      }
    }
    return nodes;
  }

  Future<void> _silentCenter() async {
    final pos = await _location.currentIfAlreadyAuthorized();
    if (pos == null || !mounted) return;
    setState(() => _userPos = LatLng(pos.latitude, pos.longitude));
    final controller = _map;
    if (controller != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
        ),
      );
    }
    _ensureMessaging(pos.latitude, pos.longitude);
  }

  /// Setup do FCM: pede permissão (1x), assina tópico da região atual.
  /// Idempotente — pode ser chamado várias vezes.
  Future<void> _ensureMessaging(double lat, double lng) async {
    if (!_messagingReady) {
      final ok = await _messaging.initialize();
      if (!ok) return;
      _messagingReady = true;
    }
    final cell = geohash5Of(lat, lng);
    await _messaging.subscribeToRegion(cell);
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

  Future<void> _openDetail(Occurrence o, OccurrenceOpenEntry entry) async {
    AnalyticsService.instance.occurrenceOpen(
      entry: entry,
      source: o.source,
      age: DateTime.now().difference(o.date),
    );
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

  List<Occurrence> _proximityAlerts(List<Occurrence> all) {
    final pos = _userPos;
    if (pos == null) return const [];
    final cutoff = DateTime.now().subtract(_proximityRecency);
    return all
        .where((o) => o.date.isAfter(cutoff))
        .where((o) => _haversineKm(pos, LatLng(o.latitude, o.longitude)) <= _proximityRadiusKm)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Distância aproximada em km entre dois pontos (Haversine).
  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = (1 - _cos(dLat)) / 2 +
        _cos(lat1) * _cos(lat2) * (1 - _cos(dLng)) / 2;
    return 2 * r * _asin(_sqrt(h));
  }

  double _toRad(double d) => d * 3.141592653589793 / 180.0;
  double _cos(double v) => math.cos(v);
  double _asin(double v) => math.asin(v);
  double _sqrt(double v) => math.sqrt(v);

  /// Zoom efetivamente refletido no último rebuild — usado pra decidir se o
  /// onCameraIdle precisa disparar setState (clusters dependem do zoom).
  double _renderedZoom = 12;

  void _onCameraMove(CameraPosition pos) {
    final wasHeatmap = _showHeatmap;
    _zoom = pos.zoom;
    // Telemetria: registra novo máximo de sessão, arredondado pra evitar spam.
    if (_zoom > _maxZoomLogged + 1) {
      _maxZoomLogged = _zoom;
      AnalyticsService.instance.maxZoomReached(_zoom);
    }
    // Só rebuilda quando cruza o limiar — evita rebuild a cada pan/zoom.
    if (wasHeatmap != _showHeatmap) {
      setState(() {});
    }
  }

  /// Disparado quando o usuário solta o mapa. Atualiza clusters se o zoom
  /// mudou o suficiente pra valer um rebuild.
  void _onCameraIdle() {
    if ((_zoom - _renderedZoom).abs() > 0.3) {
      _renderedZoom = _zoom;
      setState(() {});
    }
  }

  /// Tap em cluster: aproxima a câmera no centroide. Se já está perto do
  /// teto de cluster, foca rasante pra individualizar.
  Future<void> _onTapCluster(_MapNode node) async {
    final controller = _map;
    if (controller == null) return;
    final targetZoom = (_zoom + 2).clamp(_heatmapZoomThreshold + 0.5, 18.0);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(node.lat, node.lng), zoom: targetZoom),
      ),
    );
  }

  Future<void> _centerOnMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await _location.currentPosition();
      if (mounted) setState(() => _userPos = LatLng(pos.latitude, pos.longitude));
      final controller = _map;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 15),
          ),
        );
      }
      _ensureMessaging(pos.latitude, pos.longitude);
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
    final filteredList = filtered.maybeWhen(data: (v) => v, orElse: () => const <Occurrence>[]);
    final nodes = _buildNodes(filteredList);
    final allList = raw.maybeWhen(data: (v) => v, orElse: () => const <Occurrence>[]);
    final alerts = _alertDismissed ? const <Occurrence>[] : _proximityAlerts(allList);

    // Loga o banner apenas na transição 0→N (mesma sessão, mesmo conjunto
    // não loga de novo). Evita poluir Analytics com cada rebuild.
    if (alerts.length != _lastAlertCountLogged) {
      _lastAlertCountLogged = alerts.length;
      if (alerts.isNotEmpty) {
        AnalyticsService.instance.proximityAlertShown(alerts.length);
      }
    }

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
            occurrences: filteredList,
            nodes: nodes,
            markerIcons: _markerIcons,
            clusterIcons: _clusterIcons,
            asHeatmap: _showHeatmap,
            onCreated: (c) => _map = c,
            onTap: (o) => _openDetail(o, OccurrenceOpenEntry.marker),
            onTapCluster: _onTapCluster,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          _Header(onFocusArea: _focusOnArea, onSearch: _openSearch),
          if (alerts.isNotEmpty)
            _ProximityBanner(
              alerts: alerts,
              onTap: () {
                AnalyticsService.instance.proximityAlertTapped();
                _openDetail(alerts.first, OccurrenceOpenEntry.proximityBanner);
              },
              onDismiss: () => setState(() => _alertDismissed = true),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64 + (alerts.isNotEmpty ? 76 : 0),
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeWindowChips(
                  selected: _window,
                  onSelect: (w) {
                    setState(() => _window = w);
                    AnalyticsService.instance.filterApplied(
                      kind: 'time_window',
                      value: w.name,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ReasonChips(
                  pool: windowed.maybeWhen(data: (v) => v, orElse: () => const []),
                  active: _activeReasons,
                  onToggle: (reason) {
                    setState(() {
                      final next = Set<String>.from(_activeReasons);
                      if (next.contains(reason)) {
                        next.remove(reason);
                      } else {
                        next.add(reason);
                      }
                      _activeReasons = next;
                    });
                    AnalyticsService.instance.filterApplied(kind: 'reason');
                  },
                  onClear: () {
                    setState(() => _activeReasons = const {});
                    AnalyticsService.instance.filterApplied(
                      kind: 'reason',
                      value: 'clear',
                    );
                  },
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
            onTapTile: (o) => _openDetail(o, OccurrenceOpenEntry.list),
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
  final List<_MapNode> nodes;
  final Map<RiskLevel, BitmapDescriptor>? markerIcons;
  final Map<String, BitmapDescriptor>? clusterIcons;
  final bool asHeatmap;
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<Occurrence> onTap;
  final ValueChanged<_MapNode> onTapCluster;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;

  const _Map({
    required this.initialCamera,
    required this.mapType,
    required this.occurrences,
    required this.nodes,
    required this.markerIcons,
    required this.clusterIcons,
    required this.asHeatmap,
    required this.onCreated,
    required this.onTap,
    required this.onTapCluster,
    required this.onCameraMove,
    required this.onCameraIdle,
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
      // Heatmap nativo funciona bem no iOS. No Android o suporte é
      // inconsistente — usamos cluster circles como fallback. Em zoom-in
      // (asHeatmap=false), só os círculos de incerteza dos centroides.
      circles: asHeatmap ? _clusterCircles() : _uncertaintyCircles(),
      heatmaps: asHeatmap ? _heatmaps() : const {},
      onMapCreated: onCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
    );
  }

  Set<Circle> _clusterCircles() {
    if (occurrences.isEmpty) return const {};
    // Agrupa por célula de ~5km (1° latitude ≈ 111km, então 0.045° ≈ 5km)
    final clusters = <String, List<Occurrence>>{};
    for (final o in occurrences) {
      final key =
          '${(o.latitude / 0.045).floor()},${(o.longitude / 0.045).floor()}';
      clusters.putIfAbsent(key, () => []).add(o);
    }

    final result = <Circle>{};
    for (final entry in clusters.entries) {
      final items = entry.value;
      final count = items.length;
      // Centroide ponderado
      final lat = items.map((o) => o.latitude).fold(0.0, (a, b) => a + b) / count;
      final lng = items.map((o) => o.longitude).fold(0.0, (a, b) => a + b) / count;

      // Paleta surge-style: amarelo claro → laranja → vermelho conforme densidade
      Color color;
      if (count >= 20) {
        color = const Color(0xFF8B0000);
      } else if (count >= 10) {
        color = const Color(0xFFD93030);
      } else if (count >= 5) {
        color = const Color(0xFFFF6B3D);
      } else if (count >= 2) {
        color = const Color(0xFFFFA646);
      } else {
        color = const Color(0xFFFFD56A);
      }

      // Raio escala com a contagem, com piso e teto
      final radius = (500 + count * 60.0).clamp(500.0, 2500.0);

      result.add(Circle(
        circleId: CircleId('cluster-${entry.key}'),
        center: LatLng(lat, lng),
        radius: radius,
        fillColor: color.withValues(alpha: 0.40),
        strokeColor: color.withValues(alpha: 0.70),
        strokeWidth: 1,
      ));
    }
    return result;
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
    final clusters = clusterIcons;
    final result = <Marker>{};
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.isCluster) {
        // Cluster: badge com count. Se os ícones de cluster ainda não
        // resolveram (1º frame após startup), cai pra um single marker
        // colorido pela risk-level máxima do grupo.
        final key = ClusterMarkerFactory.keyFor(node.count, node.risk);
        final icon = clusters?[key] ??
            icons?[node.risk] ??
            BitmapDescriptor.defaultMarkerWithHue(_fallbackHue(node.risk));
        result.add(Marker(
          markerId: MarkerId('cluster-$i-${node.lat.toStringAsFixed(4)}-${node.lng.toStringAsFixed(4)}'),
          position: LatLng(node.lat, node.lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => onTapCluster(node),
        ));
      } else {
        final o = node.members.first;
        final risk = classifyAge(o.date);
        final icon = icons?[risk] ?? BitmapDescriptor.defaultMarkerWithHue(_fallbackHue(risk));
        result.add(Marker(
          markerId: MarkerId(o.id),
          position: LatLng(o.latitude, o.longitude),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => onTap(o),
        ));
      }
    }
    return result;
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

// ============================================================================
// Proximity banner — alerta editorial quando há relato recente próximo
// ============================================================================

class _ProximityBanner extends StatelessWidget {
  final List<Occurrence> alerts;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _ProximityBanner({
    required this.alerts,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final n = alerts.length;
    final freshest = alerts.first;
    final diff = DateTime.now().difference(freshest.date);
    String when;
    if (diff.inMinutes < 60) {
      when = 'há ${diff.inMinutes} min';
    } else {
      when = 'há ${diff.inHours}h';
    }
    final headline = n == 1
        ? 'Novo relato perto de você'
        : '$n relatos próximos nas últimas 6h';
    final subtext = n == 1
        ? '${freshest.mainReason ?? "Relato"} · $when'
        : 'Mais recente: ${freshest.mainReason ?? "relato"} · $when';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 12,
      right: 12,
      child: Material(
        color: const Color(0xFFC46A2C),
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 22, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 14.5,
                          height: 1.2,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtext,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dispensar',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
