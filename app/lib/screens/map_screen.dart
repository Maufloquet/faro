import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import '../services/occurrences_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final occurrences = ref.watch(recentOccurrencesProvider);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _salvador,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: occurrences.maybeWhen(
              data: _markersFor,
              orElse: () => <Marker>{},
            ),
            onMapCreated: (_) {},
          ),
          const _Disclaimer(),
        ],
      ),
    );
  }

  Set<Marker> _markersFor(List<Occurrence> items) {
    return items.map((o) {
      final risk = _classifyAge(o.date);
      return Marker(
        markerId: MarkerId(o.id),
        position: LatLng(o.latitude, o.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(risk)),
        infoWindow: InfoWindow(
          title: o.neighborhood ?? o.city ?? 'Sem localização específica',
          snippet: '${o.mainReason ?? "Relato"} · ${_relativeTime(o.date)}',
        ),
      );
    }).toSet();
  }

  RiskLevel _classifyAge(DateTime date) {
    final hours = DateTime.now().difference(date).inHours;
    if (hours < 2) return RiskLevel.confirmedActivity;
    if (hours < 12) return RiskLevel.lightActivity;
    return RiskLevel.noRecentReports;
  }

  double _hueFor(RiskLevel risk) {
    switch (risk) {
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

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: const Text(
          'Relatos das últimas 24h. O app não garante segurança em nenhuma região.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF2A2A2A)),
        ),
      ),
    );
  }
}
