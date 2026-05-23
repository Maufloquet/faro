import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/design/tokens.dart';
import '../core/text/string_format.dart';
import '../models/route_plan.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';
import '../services/reference_location_service.dart';
import '../services/route_plan_service.dart';
import '../widgets/occurrence_detail_sheet.dart';

/// Avaliação de trajeto A → B. Mostra mapa com linha entre os dois
/// pontos + lista de relatos no corredor + headline editorial.
///
/// Origem default: ReferenceLocation (hotel/casa) se houver, senão a
/// posição atual do GPS. Destino: escolha entre os favoritos do user.
///
/// MVP: linha reta. Sem API de routing real (custo). Cobre a vizinhança
/// das rotas óbvias com folga aceitável (~500m de raio).
class RoutePlanScreen extends ConsumerStatefulWidget {
  const RoutePlanScreen({super.key});

  @override
  ConsumerState<RoutePlanScreen> createState() => _RoutePlanScreenState();
}

class _RoutePlanScreenState extends ConsumerState<RoutePlanScreen> {
  _Endpoint? _origin;
  FavoriteNeighborhood? _destination;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('route_plan');
    _bootstrapOrigin();
  }

  Future<void> _bootstrapOrigin() async {
    // 1) Se há referenceLocation (hotel/casa), usa.
    final refLoc = await ReferenceLocationService.instance.current();
    if (refLoc != null) {
      if (mounted) setState(() => _origin = _Endpoint.ref(refLoc));
      return;
    }
    // 2) Senão, tenta GPS.
    await _useGpsAsOrigin();
  }

  Future<void> _useGpsAsOrigin() async {
    if (_loadingGps) return;
    setState(() => _loadingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _origin = _Endpoint.gps(pos.latitude, pos.longitude));
    } catch (_) {
      // GPS pode estar desligado ou sem permissão — usuário precisa
      // escolher origem manualmente (V2 implementa busca por nome).
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  RoutePlan? get _plan {
    final o = _origin;
    final d = _destination;
    if (o == null || d == null) return null;
    return RoutePlan(
      originLat: o.lat,
      originLng: o.lng,
      originLabel: o.label,
      destinationLat: d.centroidLat,
      destinationLng: d.centroidLng,
      destinationLabel: d.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final eval = plan == null
        ? null
        : ref.watch(routeEvaluationProvider(plan));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliar trajeto',
            style: TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: Column(
        children: [
          _ControlsPanel(
            origin: _origin,
            destination: _destination,
            loadingGps: _loadingGps,
            onPickOriginGps: _useGpsAsOrigin,
            onPickDestination: _pickDestination,
            onClearDestination: () => setState(() => _destination = null),
          ),
          if (eval != null)
            eval.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Não foi possível avaliar: $e'),
              ),
              data: (e) => _HeadlineBanner(headline: e.headline()),
            ),
          Expanded(
            child: plan == null
                ? const _EmptyState()
                : _RouteMap(plan: plan),
          ),
          if (eval != null)
            eval.maybeWhen(
              data: (e) => _OccurrencesList(eval: e),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDestination() async {
    final favs = await ref.read(favoritesProvider.future);
    if (!mounted) return;
    if (favs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você ainda não tem bairros favoritos. Marque um pela busca pra usar como destino.',
          ),
        ),
      );
      return;
    }
    final chosen = await showModalBottomSheet<FavoriteNeighborhood>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: favs
              .map(
                (f) => ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: Text(f.name),
                  subtitle: Text(f.city ?? ''),
                  onTap: () => Navigator.of(ctx).pop(f),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (chosen != null) {
      setState(() => _destination = chosen);
    }
  }
}

class _Endpoint {
  final double lat;
  final double lng;
  final String label;
  const _Endpoint({required this.lat, required this.lng, required this.label});

  factory _Endpoint.ref(ReferenceLocation r) =>
      _Endpoint(lat: r.lat, lng: r.lng, label: r.label);
  factory _Endpoint.gps(double lat, double lng) =>
      _Endpoint(lat: lat, lng: lng, label: 'Posição atual');
}

class _ControlsPanel extends StatelessWidget {
  final _Endpoint? origin;
  final FavoriteNeighborhood? destination;
  final bool loadingGps;
  final VoidCallback onPickOriginGps;
  final VoidCallback onPickDestination;
  final VoidCallback onClearDestination;

  const _ControlsPanel({
    required this.origin,
    required this.destination,
    required this.loadingGps,
    required this.onPickOriginGps,
    required this.onPickDestination,
    required this.onClearDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        children: [
          _row(
            context,
            icon: Icons.my_location,
            title: 'Origem',
            value: origin?.label ?? 'Toque pra usar posição atual',
            trailing: loadingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: onPickOriginGps,
                    child: const Text('GPS'),
                  ),
          ),
          const SizedBox(height: 8),
          _row(
            context,
            icon: Icons.location_on_outlined,
            title: 'Destino',
            value: destination?.name ?? 'Toque pra escolher um favorito',
            trailing: destination == null
                ? TextButton(
                    onPressed: onPickDestination,
                    child: const Text('Escolher'),
                  )
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClearDestination,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context,
      {required IconData icon,
      required String title,
      required String value,
      required Widget trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: FaroColors.textSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FaroColors.textHint,
                    )),
                Text(value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: FaroColors.textPrimary,
                    )),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _HeadlineBanner extends StatelessWidget {
  final String headline;
  const _HeadlineBanner({required this.headline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FaroColors.sand,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          headline,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 14,
            height: 1.4,
            color: FaroColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  final RoutePlan plan;
  const _RouteMap({required this.plan});

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(plan.originLat, plan.originLng);
    final dest = LatLng(plan.destinationLat, plan.destinationLng);
    final mid = LatLng(
      (origin.latitude + dest.latitude) / 2,
      (origin.longitude + dest.longitude) / 2,
    );
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: mid, zoom: 12.5),
      myLocationButtonEnabled: false,
      compassEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('origin'),
          position: origin,
          infoWindow: InfoWindow(title: plan.originLabel ?? 'Origem'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: dest,
          infoWindow: InfoWindow(title: plan.destinationLabel ?? 'Destino'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [origin, dest],
          color: FaroColors.primary,
          width: 4,
        ),
      },
    );
  }
}

class _OccurrencesList extends StatelessWidget {
  final RouteEvaluation eval;
  const _OccurrencesList({required this.eval});

  @override
  Widget build(BuildContext context) {
    if (eval.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: eval.inCorridor.length,
        itemBuilder: (_, i) {
          final o = eval.inCorridor[i];
          final title = o.externalTitle ?? o.mainReason ?? 'Relato';
          final where = titleCasePtBr(o.neighborhood ?? o.city ?? '');
          return ListTile(
            dense: true,
            leading: const Icon(Icons.fiber_manual_record,
                size: 10, color: FaroColors.editorialBrown),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
            subtitle: Text(
              where.isNotEmpty ? where : '—',
              style: const TextStyle(fontSize: 11, color: FaroColors.textHint),
            ),
            onTap: () => OccurrenceDetailSheet.show(context, o),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Escolha origem e destino acima pra ver os relatos no caminho.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: FaroColors.textSoft,
          ),
        ),
      ),
    );
  }
}
