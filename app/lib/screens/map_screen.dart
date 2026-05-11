import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import '../services/location_service.dart';
import '../services/occurrences_service.dart';
import '../widgets/occurrence_detail_sheet.dart';
import '../widgets/occurrence_tile.dart';
import 'help_screen.dart';

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
  final _location = LocationService();
  bool _locating = false;

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

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
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
    final occurrences = ref.watch(recentOccurrencesProvider);

    return Scaffold(
      body: Stack(
        children: [
          _Map(
            initialCamera: _salvador,
            mapType: _mapType,
            occurrences: occurrences.maybeWhen(data: (v) => v, orElse: () => const []),
            onCreated: (c) => _map = c,
            onTap: _openDetail,
          ),
          const _Header(),
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
          _Sheet(occurrences: occurrences, onTapTile: _openDetail),
        ],
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
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<Occurrence> onTap;

  const _Map({
    required this.initialCamera,
    required this.mapType,
    required this.occurrences,
    required this.onCreated,
    required this.onTap,
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
      markers: _markers(),
      onMapCreated: onCreated,
    );
  }

  Set<Marker> _markers() {
    return occurrences.map((o) {
      return Marker(
        markerId: MarkerId(o.id),
        position: LatLng(o.latitude, o.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hue(_classify(o.date))),
        onTap: () => onTap(o),
      );
    }).toSet();
  }

  RiskLevel _classify(DateTime d) {
    final h = DateTime.now().difference(d).inHours;
    if (h < 2) return RiskLevel.confirmedActivity;
    if (h < 12) return RiskLevel.lightActivity;
    return RiskLevel.noRecentReports;
  }

  double _hue(RiskLevel r) {
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.travel_explore, size: 18, color: Color(0xFF2A4A7A)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Faro · relatos próximos a você',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14.5,
                  height: 1.2,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 22, color: Color(0xFF555555)),
              tooltip: 'Como o Faro funciona',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
  final ValueChanged<Occurrence> onTapTile;

  const _Sheet({required this.occurrences, required this.onTapTile});

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
              scrollController: scrollController,
              onTapTile: onTapTile,
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
  final ScrollController scrollController;
  final ValueChanged<Occurrence> onTapTile;

  const _SheetContent({
    required this.items,
    required this.scrollController,
    required this.onTapTile,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        const _Handle(),
        _SummaryHeader(count: items.length),
        const Divider(height: 1),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Text(
              'Sem relatos nas últimas 24h. Isso não significa que está seguro — significa que ninguém reportou nada.',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF555555)),
            ),
          )
        else
          ...sorted.map(
            (o) => Column(
              children: [
                OccurrenceTile(occurrence: o, onTap: () => onTapTile(o)),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ),
          ),
        const _Footer(),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int count;
  const _SummaryHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'Sem relatos recentes'
                : '$count relato${count > 1 ? "s" : ""} próximos',
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
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Text(
        'Fonte: Fogo Cruzado · atualização contínua',
        style: TextStyle(
          fontSize: 11.5,
          color: Color(0xFF8A8A8A),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
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
