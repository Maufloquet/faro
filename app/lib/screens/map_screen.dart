import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/driving/driving_mode.dart';
import '../core/filters/time_window.dart';
import '../core/geo/haversine.dart';
import '../core/i18n/faro_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/bus_stop.dart';
import '../models/occurrence.dart';
import '../models/osm_infra.dart';
import '../models/user_report.dart';
import '../services/analytics_service.dart';
import '../services/bairros_directory.dart';
import '../services/cluster_engine.dart';
import '../services/cluster_marker_factory.dart';
import '../services/driving_arrow_factory.dart';
import '../services/location_service.dart';
import '../services/marker_factory.dart';
import '../services/messaging_service.dart';
import '../services/occurrences_service.dart';
import '../services/osm_service.dart';
import '../services/report_service.dart';
import '../widgets/driving_mode_button.dart';
import '../widgets/faro_drawer.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/layers_sheet.dart';
import '../widgets/map_floating_button.dart';
import '../widgets/occurrence_detail_sheet.dart';
import '../widgets/occurrence_tile.dart';
import '../widgets/proximity_banner.dart';
import '../widgets/report_detail_sheet.dart';
import 'report_screen.dart';
import 'search_screen.dart';

import '../core/design/tokens.dart';

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
  // Abre no recorte do dia — o mapa começa mostrando o que é de hoje.
  // O usuário expande pra 7d/30d/Tudo pelo filtro quando quiser.
  TimeWindow _window = TimeWindow.hoje;
  Set<String> _activeReasons = const {};
  final _location = LocationService();
  final _messaging = MessagingService();
  bool _locating = false;
  bool _messagingReady = false;
  final _markerFactory = MarkerFactory();
  final _clusterFactory = ClusterMarkerFactory();
  final _drivingArrowFactory = DrivingArrowFactory();
  Map<RiskLevel, BitmapDescriptor>? _markerIcons;
  Map<String, BitmapDescriptor>? _clusterIcons;
  BitmapDescriptor? _drivingArrowIcon;

  /// Heading (rumo) reportado pelo GPS na última leitura. Em graus, 0 = norte.
  /// Só é confiável em movimento — usamos `_drivingArrowRotation` que zera
  /// quando o usuário está parado, evitando giros aleatórios.
  double _drivingArrowRotation = 0;

  double _zoom = 12;

  bool get _showHeatmap => _zoom < kHeatmapZoomThreshold;

  // Posição atual do usuário pra cálculos de proximidade.
  LatLng? _userPos;
  // Dismiss do banner de proximidade — guarda os IDs dispensados pra que
  // novas ocorrências (com ID diferente) façam o banner reaparecer.
  // O dismiss não é permanente: expira em `_dismissTtl` pra cobrir o caso
  // de o usuário ficar parado na zona quente sem novos relatos.
  Set<String> _dismissedAlertIds = const {};
  DateTime? _dismissedAt;
  static const Duration _dismissTtl = Duration(minutes: 10);

  /// Estado default quando ainda não temos GPS — Faro é focado em Salvador
  /// no MVP. Sem isso, relatos do pool global (que agora inclui RJ/PE/SP
  /// pela Camada 2 expandida) apareciam misturados antes da permissão
  /// de localização ser concedida.
  static const String _defaultStateName = 'Bahia';

  /// Raio de exibição quando temos GPS. 200km cobre a RMS toda (Salvador
  /// + Camaçari + Lauro + Simões) com folga, e ainda funciona pra usuário
  /// em qualquer outra capital coberta (corta relatos de outras regiões).
  static const double _regionRadiusKm = 200;

  // Telemetria de zoom: log apenas quando bate um novo máximo de sessão.
  double _maxZoomLogged = 0;
  // Última quantidade de alertas de proximidade reportada — evita logar
  // repetidamente o mesmo banner enquanto o usuário olha.
  int _lastAlertCountLogged = 0;

  /// Raio (em km) pra considerar relato "próximo" do usuário.
  static const double _proximityRadiusKm = 1.0;
  static const Duration _proximityRecency = Duration(hours: 6);

  /// Toggle de pontos de ônibus (Camada 6 — OSM). Só aparece em zoom alto
  /// pra não poluir vista panorâmica.
  bool _showBusStops = false;
  static const double _busStopMinZoom = 15.0;

  /// Camadas de infraestrutura urbana (Camada 6 — OSM). Cada categoria
  /// tem zoom mínimo próprio: postes só fazem sentido bem aproximado.
  Set<OsmInfraKind> _activeInfra = const {};
  static const Map<OsmInfraKind, double> _infraMinZoom = {
    OsmInfraKind.police: 13.0,
    OsmInfraKind.hospitals: 13.0,
    OsmInfraKind.commerce24h: 14.0,
    OsmInfraKind.streetLamps: 16.5,
  };

  /// Modo direção: stream contínuo de posição que move a câmera. Inicia
  /// quando o usuário ativa o toggle no drawer; cancela ao desativar.
  StreamSubscription<Position>? _drivingSub;
  /// Velocidade atual reportada pelo GPS (m/s). Usada pelo filtro "à
  /// minha frente" pra decidir se está parado (mostra tudo) ou em
  /// movimento (corta o que está atrás).
  double _drivingSpeed = 0;

  bool _matchesFilters(Occurrence o) {
    if (!_window.includes(o.date)) return false;
    if (!_passesRegionFilter(o)) return false;
    if (_activeReasons.isNotEmpty && !_activeReasons.contains(o.mainReason)) {
      return false;
    }
    if (!_passesAheadFilter(o)) return false;
    return true;
  }

  /// Filtro regional — corta relatos de outros estados/regiões que
  /// aparecem no pool global desde que a Camada 2 expandiu pra
  /// RJ/PE/SP. Lógica:
  ///   - Com GPS: relato precisa estar dentro de `_regionRadiusKm` da
  ///     posição do usuário. Cobre RMS toda quando o usuário está em
  ///     Salvador, e funciona em qualquer outra capital coberta.
  ///   - Sem GPS (permissão pendente, primeiro boot): default editorial
  ///     `_defaultStateName` = Bahia. App é focado em Salvador no MVP.
  bool _passesRegionFilter(Occurrence o) {
    final pos = _userPos;
    if (pos == null) {
      return (o.state ?? '').toLowerCase() ==
          _defaultStateName.toLowerCase();
    }
    final km = haversineKm(pos.latitude, pos.longitude, o.latitude, o.longitude);
    return km <= _regionRadiusKm;
  }

  /// Mesmo recorte regional do `_passesRegionFilter`, mas pra relatos de
  /// usuário (Camada 4). Sem GPS, mostra tudo — relatos são poucos e o
  /// usuário acabou de criar o seu; não queremos escondê-lo só porque o
  /// fix de localização ainda não chegou.
  bool _reportInRegion(UserReport r) {
    final pos = _userPos;
    if (pos == null) return true;
    final km = haversineKm(pos.latitude, pos.longitude, r.lat, r.lng);
    return km <= _regionRadiusKm;
  }

  /// Abre a tela de relato. GPS é resolvido lá dentro.
  Future<void> _openReportScreen() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReportScreen()),
    );
  }

  /// Filtro "à minha frente" — só ativo em modo carro/bike E em
  /// movimento (≥ 3 m/s). Corta ocorrências que ficam mais de 90° pra
  /// trás do heading atual. Parado ou modo off, sempre passa.
  bool _passesAheadFilter(Occurrence o) {
    final mode = ref.read(drivingModeProvider);
    if (mode == DrivingMode.off) return true;
    if (_drivingSpeed < 3) return true; // parado: vê tudo ao redor
    final pos = _userPos;
    if (pos == null) return true;
    final bearingToOcc = bearingDeg(
        pos.latitude, pos.longitude, o.latitude, o.longitude);
    final delta = _angleDelta(_drivingArrowRotation, bearingToOcc);
    return delta <= 90; // hemisfério à frente
  }

  /// Menor diferença angular entre dois headings em graus (0–180).
  double _angleDelta(double a, double b) {
    final raw = ((b - a) % 360 + 360) % 360;
    return raw > 180 ? 360 - raw : raw;
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    AnalyticsService.instance.logScreen('map');
    // Auto-centro silencioso: só se permissão já foi concedida em sessão anterior
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentCenter();
      // Se o usuário voltou ao app com modo direção já ativo, retoma o follow.
      if (ref.read(drivingModeProvider) != DrivingMode.off) {
        _startDrivingFollow();
      }
    });
  }

  @override
  void dispose() {
    _drivingSub?.cancel();
    super.dispose();
  }

  /// Inicia o stream de GPS que move a câmera. Só roda em modo direção.
  /// Distância mínima de 10m evita queimar bateria com micro-movimentos.
  Future<void> _startDrivingFollow() async {
    if (_drivingSub != null) return; // já está rodando
    // Garante permissão antes de abrir o stream; se negar, modo direção
    // não tem efeito visível (mas ainda fica ligado pra o usuário ver).
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
    } catch (_) {
      return;
    }

    // Leitura imediata: stream com distanceFilter:10 não emite até o
    // usuário se mover 10m. Se ele ativa parado, ficaria sem seta nenhuma
    // (o dot nativo também sumiu). Pedimos uma posição one-shot pra
    // pintar a seta na hora.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      if (!mounted) return;
      setState(() => _userPos = LatLng(pos.latitude, pos.longitude));
      await _animateDriving(pos.latitude, pos.longitude, bearing: 0);
    } catch (_) {
      // Ignora: o stream abaixo eventualmente cobre.
    }

    _drivingSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      if (!mounted) return;
      double? newHeading;
      if (pos.speed >= 3 && pos.heading >= 0) {
        newHeading = pos.heading;
      }
      setState(() {
        _userPos = LatLng(pos.latitude, pos.longitude);
        _drivingSpeed = pos.speed.isNaN ? 0 : pos.speed;
        // Heading parado é ruidoso (gira aleatório). Só atualizamos se
        // a velocidade reportada indica deslocamento real (≥ 3 m/s ≈ 11 km/h).
        if (newHeading != null) _drivingArrowRotation = newHeading;
      });
      await _animateDriving(
        pos.latitude,
        pos.longitude,
        bearing: newHeading ?? _drivingArrowRotation,
      );
    });
  }

  /// Anima a câmera de acordo com o perfil ativo. Carro/moto: zoom de
  /// rua + tilt 3D + bearing sincronizado. Bike: zoom mais próximo,
  /// vista plana, norte fixo (heading de bike é ruidoso).
  Future<void> _animateDriving(double lat, double lng,
      {required double bearing}) async {
    final controller = _map;
    if (controller == null) return;
    final mode = ref.read(drivingModeProvider);
    final isCar = mode == DrivingMode.car;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: isCar ? 17.5 : 18.0,
          tilt: isCar ? 50.0 : 0.0,
          bearing: isCar ? bearing : 0.0,
        ),
      ),
    );
  }

  void _stopDrivingFollow() {
    _drivingSub?.cancel();
    _drivingSub = null;
    if (mounted) setState(() => _drivingArrowRotation = 0);
    // Volta a câmera pra a vista normal: sem tilt e norte pra cima.
    final controller = _map;
    final pos = _userPos;
    if (controller != null && pos != null) {
      unawaited(controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pos, zoom: 15),
        ),
      ));
    }
  }

  Future<void> _loadMarkers() async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final icons = await _markerFactory.all(devicePixelRatio: dpr);
    final clusters = await _clusterFactory.all(devicePixelRatio: dpr);
    final arrow = await _drivingArrowFactory.build(devicePixelRatio: dpr);
    if (mounted) {
      setState(() {
        _markerIcons = icons;
        _clusterIcons = clusters;
        _drivingArrowIcon = arrow;
      });
    }
  }

  /// Agrupa ocorrências em nós (single ou cluster) pra o zoom atual.
  /// Função pura — testada em `services/cluster_engine.dart`.
  List<MapNode> _buildNodes(List<Occurrence> occurrences) => clusterOccurrences(
        occurrences: occurrences,
        zoom: _zoom,
        referenceLat: _salvador.target.latitude,
      );

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
    unawaited(_ensureMessaging(pos.latitude, pos.longitude));
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
    unawaited(AnalyticsService.instance.occurrenceOpen(
      entry: entry,
      source: o.source,
      age: DateTime.now().difference(o.date),
    ));
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

  Future<void> _openFilterSheet(List<Occurrence> pool) async {
    final result = await FilterSheet.show(
      context,
      window: _window,
      reasons: _activeReasons,
      pool: pool,
    );
    if (result == null || !mounted) return;
    setState(() {
      _window = result.window;
      _activeReasons = result.reasons;
    });
    unawaited(AnalyticsService.instance.filterApplied(
      kind: 'filter_sheet',
      value: '${result.window.name}|${result.reasons.length}',
    ));
  }

  Future<void> _openLayersSheet() async {
    final result = await LayersSheet.show(
      context,
      mapType: _mapType,
      showBusStops: _showBusStops,
      activeInfra: _activeInfra,
    );
    if (result == null || !mounted) return;
    setState(() {
      _mapType = result.mapType;
      _showBusStops = result.showBusStops;
      _activeInfra = result.activeInfra;
    });
    final infraTag = result.activeInfra.isEmpty
        ? 'none'
        : (result.activeInfra.map((k) => k.firestoreId).toList()..sort())
            .join('+');
    unawaited(AnalyticsService.instance.filterApplied(
      kind: 'layers',
      value:
          '${result.mapType.name}|busStops=${result.showBusStops}|infra=$infraTag',
    ));
  }

  List<Occurrence> _proximityAlerts(List<Occurrence> all) {
    final pos = _userPos;
    if (pos == null) return const [];
    final cutoff = DateTime.now().subtract(_proximityRecency);
    final nearby = all
        .where((o) => o.date.isAfter(cutoff))
        .where((o) =>
            haversineKm(pos.latitude, pos.longitude, o.latitude, o.longitude) <=
            _proximityRadiusKm)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Dismiss expira por tempo OU quando o conjunto de IDs próximos muda
    // (chegou relato novo na célula). Antes, `_alertDismissed = true`
    // suprimia o banner pra sempre na sessão — usuário fechava 1 vez e
    // perdia o aviso de relatos chegando depois.
    final dismissAge = _dismissedAt == null
        ? null
        : DateTime.now().difference(_dismissedAt!);
    final dismissExpired = dismissAge != null && dismissAge >= _dismissTtl;
    final nearbyIds = nearby.map((o) => o.id).toSet();
    final dismissCoversAll =
        _dismissedAlertIds.isNotEmpty &&
        nearbyIds.every(_dismissedAlertIds.contains);

    if (dismissExpired || !dismissCoversAll) {
      // Reset implícito: o próximo build sai do estado dispensado sem
      // precisar de timer/listener — barato e idempotente.
      _dismissedAlertIds = const {};
      _dismissedAt = null;
      return nearby;
    }
    return const [];
  }

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
  Future<void> _onTapCluster(MapNode node) async {
    final controller = _map;
    if (controller == null) return;
    final targetZoom = (_zoom + 2).clamp(kHeatmapZoomThreshold + 0.5, 18.0);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(node.lat, node.lng), zoom: targetZoom),
      ),
    );
  }

  static const _locPrimerKey = 'loc_primer_shown_v1';

  /// Priming de permissão: antes do prompt do SO (que só aparece uma vez e,
  /// se negado, é difícil reverter), explica POR QUE o Faro quer a
  /// localização. Mostra só na 1ª vez e só se ainda não foi concedida.
  /// Retorna false se o usuário recusar aqui — aí nem chamamos o prompt.
  Future<bool> _maybePrimeLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      return true; // já concedida, sem priming
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_locPrimerKey) == true) return true; // já explicamos
    await prefs.setBool(_locPrimerKey, true);
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usar sua localização'),
        content: const Text(
          'O Faro usa sua localização pra mostrar os relatos perto de você e '
          'avisar quando algo for relatado na sua região. Você pode recusar e '
          'continuar usando o mapa normalmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _centerOnMe() async {
    if (_locating) return;
    if (!await _maybePrimeLocation()) return;
    if (!mounted) return;
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
      unawaited(_ensureMessaging(pos.latitude, pos.longitude));
    } on LocationException catch (e) {
      if (!mounted) return;
      await _showLocationErrorDialog(e);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FaroStrings.mapLocationFailed),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Dialog específico por tipo de erro de GPS — guia o usuário pra ação
  /// concreta (abrir Settings, tentar de novo, etc) em vez de snackbar
  /// genérico que some em 3s e não diz o que fazer.
  Future<void> _showLocationErrorDialog(LocationException e) async {
    final String actionLabel;
    final Future<void> Function()? action;
    switch (e.kind) {
      case LocationErrorKind.serviceOff:
      case LocationErrorKind.permissionBlocked:
        actionLabel = FaroStrings.locationErrorOpenSettings;
        action = () => Geolocator.openAppSettings().then((_) => null);
        break;
      case LocationErrorKind.permissionDenied:
      case LocationErrorKind.timeout:
      case LocationErrorKind.unknown:
        actionLabel = FaroStrings.locationErrorTryAgain;
        action = () => _centerOnMe();
        break;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FaroStrings.locationErrorTitle),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(FaroStrings.locationErrorDismiss),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (action != null) await action();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reage à troca de perfil de direção: liga/desliga o stream e
    // anima a câmera pra o novo perfil quando vai car↔bike.
    ref.listen<DrivingMode>(drivingModeProvider, (prev, next) {
      if (next == DrivingMode.off) {
        _stopDrivingFollow();
      } else if (prev == DrivingMode.off) {
        _startDrivingFollow();
      } else {
        // Estava car e virou bike (ou vice-versa): re-anima com a
        // câmera do novo perfil. Não reinicia o stream.
        final pos = _userPos;
        if (pos != null) {
          _animateDriving(pos.latitude, pos.longitude,
              bearing: _drivingArrowRotation);
        }
      }
    });

    final raw = ref.watch(recentOccurrencesProvider);
    final windowed = raw.whenData((list) => list.where((o) => _window.includes(o.date)).toList());
    final filtered = raw.whenData((list) => list.where(_matchesFilters).toList());
    final filteredList = filtered.maybeWhen(data: (v) => v, orElse: () => const <Occurrence>[]);
    final nodes = _buildNodes(filteredList);
    final allList = raw.maybeWhen(data: (v) => v, orElse: () => const <Occurrence>[]);
    final alerts = _proximityAlerts(allList);

    // Pontos de ônibus: só carrega o provider quando o toggle está ativo
    // (lazy). Markers só são renderizados acima do zoom mínimo pra não
    // poluir vista panorâmica.
    final showStopsNow = _showBusStops && _zoom >= _busStopMinZoom;
    final busStops = showStopsNow
        ? ref.watch(busStopsProvider).maybeWhen(
              data: (v) => v,
              orElse: () => const <BusStop>[],
            )
        : const <BusStop>[];

    // Relatos de usuário (Camada 4) — camada distinta, recortada na região.
    // Mostrados em qualquer zoom (são poucos e o usuário quer ver o seu).
    final reports = ref
        .watch(activeReportsProvider)
        .maybeWhen(data: (v) => v, orElse: () => const <UserReport>[])
        .where(_reportInRegion)
        .toList();

    // Camadas de infraestrutura — cada uma respeita seu próprio zoom mínimo.
    final infraByKind = <OsmInfraKind, List<OsmInfra>>{};
    for (final kind in _activeInfra) {
      final minZoom = _infraMinZoom[kind] ?? 13.0;
      if (_zoom < minZoom) continue;
      final list = ref.watch(osmInfraProvider(kind)).maybeWhen(
            data: (v) => v,
            orElse: () => const <OsmInfra>[],
          );
      if (list.isNotEmpty) infraByKind[kind] = list;
    }

    // Loga o banner apenas na transição 0→N (mesma sessão, mesmo conjunto
    // não loga de novo). Evita poluir Analytics com cada rebuild.
    if (alerts.length != _lastAlertCountLogged) {
      _lastAlertCountLogged = alerts.length;
      if (alerts.isNotEmpty) {
        AnalyticsService.instance.proximityAlertShown(alerts.length);
      }
    }

    // Dica "Hoje vazio": dados já carregaram, filtro é Hoje e não há nada na
    // janela. Convida a abrir 7 dias em vez de deixar o mapa parecer quebrado.
    final showTodayHint = raw.hasValue &&
        _window == TimeWindow.hoje &&
        filteredList.isEmpty;
    // Legenda do heatmap: só quando ele está visível e há dado pra colorir.
    final showHeatmapLegend = _showHeatmap && filteredList.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
      drawer: FaroDrawer(onFocusArea: _focusOnArea),
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
            busStops: busStops,
            infraByKind: infraByKind,
            reports: reports,
            onTapReport: (r) => ReportDetailSheet.show(context, r),
            drivingActive: ref.watch(drivingModeProvider) != DrivingMode.off,
            drivingArrowIcon: _drivingArrowIcon,
            drivingPos: _userPos,
            drivingRotation: ref.watch(drivingModeProvider) == DrivingMode.car
                ? _drivingArrowRotation
                : 0,
            onCreated: (c) => _map = c,
            onTap: (o) => _openDetail(o, OccurrenceOpenEntry.marker),
            onTapCluster: _onTapCluster,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          Builder(
            builder: (ctx) => _Header(
              onFocusArea: _focusOnArea,
              onSearch: _openSearch,
              onMenu: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          if (alerts.isNotEmpty)
            ProximityBanner(
              alerts: alerts,
              onTap: () {
                AnalyticsService.instance.proximityAlertTapped();
                _openDetail(alerts.first, OccurrenceOpenEntry.proximityBanner);
              },
              onDismiss: () => setState(() {
                // Guarda os IDs vistos pra que novos relatos reapareçam,
                // e marca o momento — expira em `_dismissTtl`.
                _dismissedAlertIds = alerts.map((o) => o.id).toSet();
                _dismissedAt = DateTime.now();
              }),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64 + (alerts.isNotEmpty ? 76 : 0),
            left: 12,
            child: FilterPill(
              window: _window,
              activeReasons: _activeReasons,
              onTap: () => _openFilterSheet(
                windowed.maybeWhen(data: (v) => v, orElse: () => const []),
              ),
            ),
          ),
          if (showTodayHint)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  64 +
                  (alerts.isNotEmpty ? 76 : 0) +
                  50,
              left: 0,
              right: 0,
              child: Center(
                child: _EmptyTodayHint(
                  onExpand: () =>
                      setState(() => _window = TimeWindow.semana),
                ),
              ),
            ),
          if (showHeatmapLegend)
            Positioned(
              left: 12,
              bottom: MediaQuery.of(context).size.height * 0.18 + 18,
              child: const _HeatmapLegend(),
            ),
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * 0.18 + 12,
            child: Column(
              children: [
                // Ação primária — destacada em azul pra se distinguir dos
                // botões utilitários (camadas/localizar/direção) e ficar
                // claro que é "relatar uma ocorrência".
                MapFloatingButton(
                  icon: Icons.add_location_alt_outlined,
                  active: true,
                  tooltip: 'Relatar ocorrência',
                  onTap: _openReportScreen,
                ),
                const SizedBox(height: 12),
                DrivingModeButton(
                  mode: ref.watch(drivingModeProvider),
                  onTap: () =>
                      ref.read(drivingModeProvider.notifier).toggleQuick(),
                ),
                const SizedBox(height: 12),
                LayersButton(
                  hasActiveLayers: _mapType == MapType.hybrid ||
                      _showBusStops ||
                      _activeInfra.isNotEmpty,
                  onTap: _openLayersSheet,
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

class _LocateButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LocateButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Quando loading, mostramos o spinner sobre o botão base. Mantemos
    // o tap desabilitado pra evitar requests concorrentes.
    return Stack(
      alignment: Alignment.center,
      children: [
        MapFloatingButton(
          icon: Icons.my_location,
          tooltip: 'Centralizar em mim',
          onTap: loading ? null : onTap,
        ),
        if (loading)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: FaroColors.primary,
            ),
          ),
      ],
    );
  }
}

/// Dica discreta quando o filtro "Hoje" não tem nada na região — evita que
/// o mapa pareça quebrado e oferece abrir a janela de 7 dias num toque.
class _EmptyTodayHint extends StatelessWidget {
  final VoidCallback onExpand;
  const _EmptyTodayHint({required this.onExpand});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onExpand,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FaroColors.sandBorder.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: FaroColors.primary.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_outlined,
                  size: 16, color: FaroColors.textSoft),
              SizedBox(width: 8),
              Text('Poucos relatos hoje',
                  style: TextStyle(fontSize: 13, color: FaroColors.textPrimary)),
              SizedBox(width: 8),
              Text('Ver 7 dias',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FaroColors.primary)),
              Icon(Icons.chevron_right, size: 16, color: FaroColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legenda do mapa de calor — barra de gradiente + rótulo deixando claro
/// que a cor é DENSIDADE DE RELATOS, não um veredito de perigo.
class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: FaroColors.primary.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Intensidade de relatos',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: FaroColors.textPrimary)),
          const SizedBox(height: 5),
          Container(
            width: 124,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD56A),
                  Color(0xFFFF8A3D),
                  Color(0xFFE94A30),
                  Color(0xFF8B0000),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('menos',
                  style: TextStyle(fontSize: 9.5, color: FaroColors.textSoft)),
              SizedBox(width: 78),
              Text('mais',
                  style: TextStyle(fontSize: 9.5, color: FaroColors.textSoft)),
            ],
          ),
        ],
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
  final List<MapNode> nodes;
  final Map<RiskLevel, BitmapDescriptor>? markerIcons;
  final Map<String, BitmapDescriptor>? clusterIcons;
  final bool asHeatmap;
  final List<BusStop> busStops;
  final Map<OsmInfraKind, List<OsmInfra>> infraByKind;
  final List<UserReport> reports;
  final bool drivingActive;
  final BitmapDescriptor? drivingArrowIcon;
  final LatLng? drivingPos;
  final double drivingRotation;
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<Occurrence> onTap;
  final ValueChanged<MapNode> onTapCluster;
  final ValueChanged<UserReport> onTapReport;
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
    required this.busStops,
    required this.infraByKind,
    required this.reports,
    required this.drivingActive,
    required this.drivingArrowIcon,
    required this.drivingPos,
    required this.drivingRotation,
    required this.onCreated,
    required this.onTap,
    required this.onTapCluster,
    required this.onTapReport,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialCamera,
      mapType: mapType,
      // Em modo direção, escondemos o dot azul nativo pra não duplicar
      // com a seta de carro custom.
      myLocationEnabled: !drivingActive,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      // Relatos de usuário aparecem em qualquer zoom (inclusive sobre o
      // heatmap): são poucos, distintos, e o usuário quer ver o seu.
      markers: asHeatmap
          ? {..._reportMarkers()}
          : {
              ..._markers(),
              ..._busStopMarkers(),
              ..._infraMarkers(),
              ..._reportMarkers(),
              ..._drivingMarker(),
            },
      // Heatmap nativo do google_maps_flutter ≥ 2.6 funciona em iOS e
      // Android. Em vista panorâmica (asHeatmap=true) só o heatmap, sem
      // círculos por cima — evita aquele visual de "bolas" sobrepostas.
      // Em zoom-in (asHeatmap=false), apenas círculos de incerteza dos
      // centroides de cidade.
      circles: asHeatmap ? const {} : _uncertaintyCircles(),
      heatmaps: asHeatmap ? _heatmaps() : const {},
      onMapCreated: onCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
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

  /// Marcadores de relato de usuário (Camada 4). Cor violeta + alpha
  /// reduzido sinaliza "não confirmado" — visualmente distinto dos
  /// marcadores de ocorrência (vermelho/laranja/azul por idade).
  Set<Marker> _reportMarkers() {
    if (reports.isEmpty) return const {};
    final icon =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    return {
      for (final r in reports)
        Marker(
          markerId: MarkerId('report-${r.id}'),
          position: LatLng(r.lat, r.lng),
          icon: icon,
          alpha: 0.78,
          anchor: const Offset(0.5, 0.5),
          onTap: () => onTapReport(r),
        ),
    };
  }

  Set<Marker> _drivingMarker() {
    if (!drivingActive) return const {};
    final pos = drivingPos;
    final icon = drivingArrowIcon;
    if (pos == null || icon == null) return const {};
    return {
      Marker(
        markerId: const MarkerId('driving-arrow'),
        position: pos,
        icon: icon,
        rotation: drivingRotation,
        anchor: const Offset(0.5, 0.5),
        flat: true, // gira com o bitmap, não com a câmera
        zIndexInt: 999,
      ),
    };
  }

  Set<Marker> _busStopMarkers() {
    if (busStops.isEmpty) return const {};
    // Marker pequeno e neutro — ônibus é contexto, não evento.
    final icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    return {
      for (final s in busStops)
        Marker(
          markerId: MarkerId('bus-${s.id}'),
          position: LatLng(s.lat, s.lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          alpha: 0.7,
          flat: true,
          infoWindow: InfoWindow(
            title: s.name ?? FaroStrings.mapBusStop,
            snippet: _busStopTags(s),
          ),
        ),
    };
  }

  String _busStopTags(BusStop s) {
    final tags = <String>[];
    if (s.shelter) tags.add(FaroStrings.mapBusStopShelter);
    if (s.bench) tags.add(FaroStrings.mapBusStopBench);
    if (s.lit) tags.add(FaroStrings.mapBusStopLit);
    return tags.isEmpty ? FaroStrings.mapBusStopNoInfra : tags.join(' · ');
  }

  Set<Marker> _infraMarkers() {
    if (infraByKind.isEmpty) return const {};
    final result = <Marker>{};
    for (final entry in infraByKind.entries) {
      final kind = entry.key;
      final list = entry.value;
      if (list.isEmpty) continue;
      final icon = _iconForInfraKind(kind);
      final alpha = kind == OsmInfraKind.streetLamps ? 0.55 : 0.85;
      for (final item in list) {
        result.add(Marker(
          markerId: MarkerId('${kind.firestoreId}-${item.id}'),
          position: LatLng(item.lat, item.lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          alpha: alpha,
          flat: true,
          infoWindow: InfoWindow(
            title: item.name ?? _defaultTitleForKind(kind),
            snippet: _infoSnippetForInfra(kind, item),
          ),
        ));
      }
    }
    return result;
  }

  BitmapDescriptor _iconForInfraKind(OsmInfraKind kind) {
    switch (kind) {
      case OsmInfraKind.police:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case OsmInfraKind.hospitals:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      case OsmInfraKind.commerce24h:
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen);
      case OsmInfraKind.streetLamps:
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow);
    }
  }

  String _defaultTitleForKind(OsmInfraKind kind) {
    switch (kind) {
      case OsmInfraKind.police:
        return FaroStrings.mapPolice;
      case OsmInfraKind.hospitals:
        return FaroStrings.mapHospital;
      case OsmInfraKind.commerce24h:
        return FaroStrings.mapCommerce24h;
      case OsmInfraKind.streetLamps:
        return FaroStrings.mapStreetLamp;
    }
  }

  String? _infoSnippetForInfra(OsmInfraKind kind, OsmInfra item) {
    switch (kind) {
      case OsmInfraKind.police:
        return item.operator ?? item.phone;
      case OsmInfraKind.hospitals:
        if (item.emergency == true) return FaroStrings.mapHospitalEmergency;
        return item.operator;
      case OsmInfraKind.commerce24h:
        return item.brand ?? item.shop ?? item.amenity;
      case OsmInfraKind.streetLamps:
        return null;
    }
  }

  Set<Heatmap> _heatmaps() {
    if (occurrences.isEmpty) return const {};
    // Peso por recência: relatos novos pesam mais. Sem isso, um relato
    // de 25 dias atrás influencia tanto quanto um de hoje — o heatmap
    // vira foto antiga. Decaimento simples por horas até 30 dias.
    final now = DateTime.now();
    final points = occurrences.map((o) {
      final hours = now.difference(o.date).inHours.clamp(0, 24 * 30);
      // 1.0 (agora) → ~0.2 (30 dias). Linear é mais previsível que log
      // pra ajustar visualmente.
      final weight = 1.0 - 0.8 * (hours / (24.0 * 30.0));
      return WeightedLatLng(LatLng(o.latitude, o.longitude), weight: weight);
    }).toList(growable: false);
    return {
      Heatmap(
        heatmapId: const HeatmapId('faro_occurrences'),
        data: points,
        // Raio grande funde blobs vizinhos em manchas contínuas (estilo
        // surge do Uber) em vez de bolinhas individuais. TETO É 50: o
        // HeatmapTileProvider do android-maps-utils exige raio em [10,50]
        // e lança IllegalArgumentException fora disso — o que fazia o
        // heatmap NÃO renderizar no Android (estava 60, antes 80). Não
        // subir daqui.
        radius: const HeatmapRadius.fromPixels(50),
        // Paleta surge: transparente nas pontas, amarelo→laranja→vermelho
        // sem verde nem azul. Mais paradas próximas dão transição suave
        // sem hard edges entre faixas.
        gradient: const HeatmapGradient([
          HeatmapGradientColor(Color(0x00FFE082), 0.0),
          HeatmapGradientColor(Color(0x33FFD56A), 0.08),
          HeatmapGradientColor(Color(0x99FFC04D), 0.20),
          HeatmapGradientColor(Color(0xCCFFA646), 0.35),
          HeatmapGradientColor(Color(0xE6FF8A3D), 0.50),
          HeatmapGradientColor(Color(0xF2FF6B3D), 0.65),
          HeatmapGradientColor(Color(0xFFE94A30), 0.80),
          HeatmapGradientColor(Color(0xFFD93030), 0.92),
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
  final VoidCallback? onMenu;
  const _Header({this.onFocusArea, this.onSearch, this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, size: 22, color: FaroColors.textPrimary),
              tooltip: FaroStrings.drawerOpenMenu,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: onMenu,
            ),
            Expanded(
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: FaroColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        FaroStrings.mapSearchHint,
                        style: TextStyle(
                          fontSize: 14,
                          color: FaroColors.textPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
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
            loading: () => _SheetSimple(message: FaroStrings.sheetLoading),
            error: (e, _) => _SheetSimple(message: FaroStrings.sheetError('$e')),
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
    final scope = window == TimeWindow.tudo
        ? FaroStrings.sheetScopeAll
        : FaroStrings.sheetScopeIn(FaroStrings.timeWindowLabel(window).toLowerCase());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FaroStrings.sheetEmptyTitle(scope),
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 15.5,
              height: 1.3,
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            FaroStrings.sheetEmptyBody,
            style: const TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
          ),
          if (onExpandWindow != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onExpandWindow,
              icon: const Icon(Icons.history, size: 16),
              label: Text(FaroStrings.sheetEmptyButton),
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
    final scope = window == TimeWindow.tudo
        ? ''
        : ' · ${FaroStrings.timeWindowLabel(window).toLowerCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? FaroStrings.sheetSummaryEmpty(scope)
                : FaroStrings.sheetSummaryCount(count, scope),
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 17,
              height: 1.2,
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            FaroStrings.sheetSummaryDisclaimer,
            style: const TextStyle(fontSize: 12, height: 1.3, color: FaroColors.textSoft),
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
          Text(
            FaroStrings.sheetFooterSource,
            style: const TextStyle(
              fontSize: 11.5,
              color: FaroColors.textHint,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (freshness != null) ...[
            const SizedBox(height: 3),
            Text(
              freshness,
              style: const TextStyle(
                fontSize: 11.5,
                color: FaroColors.textHint,
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
    if (diff.inMinutes < 60) return FaroStrings.sheetFooterFreshMinutes(diff.inMinutes);
    if (diff.inHours < 24) return FaroStrings.sheetFooterFreshHours(diff.inHours);
    return FaroStrings.sheetFooterFreshDays(diff.inDays);
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
        Text(message, style: const TextStyle(color: FaroColors.textMuted)),
      ],
    );
  }
}
