import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/design/tokens.dart';
import '../core/i18n/faro_strings.dart';
import '../models/osm_infra.dart';
import '../screens/trajectory_screen.dart';
import 'map_floating_button.dart';

/// Botão circular que abre o sheet de camadas. Usa o base
/// [MapFloatingButton] pra herdar sombra/borda editorial.
class LayersButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveLayers;
  const LayersButton({
    super.key,
    required this.onTap,
    this.hasActiveLayers = false,
  });

  @override
  Widget build(BuildContext context) {
    return MapFloatingButton(
      icon: Icons.layers_outlined,
      active: hasActiveLayers,
      onTap: onTap,
    );
  }
}

/// Estado das camadas — tipo de mapa + toggles de overlay.
class LayersSelection {
  final MapType mapType;
  final bool showBusStops;
  final Set<OsmInfraKind> activeInfra;

  const LayersSelection({
    required this.mapType,
    required this.showBusStops,
    this.activeInfra = const {},
  });

  bool isInfraActive(OsmInfraKind kind) => activeInfra.contains(kind);

  bool get hasAnyOverlay => showBusStops || activeInfra.isNotEmpty;
}

/// Bottom sheet modal que controla camadas do mapa.
class LayersSheet extends StatefulWidget {
  final MapType initialMapType;
  final bool initialShowBusStops;
  final Set<OsmInfraKind> initialActiveInfra;

  const LayersSheet({
    super.key,
    required this.initialMapType,
    required this.initialShowBusStops,
    required this.initialActiveInfra,
  });

  static Future<LayersSelection?> show(
    BuildContext context, {
    required MapType mapType,
    required bool showBusStops,
    required Set<OsmInfraKind> activeInfra,
  }) {
    return showModalBottomSheet<LayersSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LayersSheet(
        initialMapType: mapType,
        initialShowBusStops: showBusStops,
        initialActiveInfra: activeInfra,
      ),
    );
  }

  @override
  State<LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<LayersSheet> {
  late MapType _mapType;
  late bool _showBusStops;
  late Set<OsmInfraKind> _activeInfra;

  @override
  void initState() {
    super.initState();
    _mapType = widget.initialMapType;
    _showBusStops = widget.initialShowBusStops;
    _activeInfra = {...widget.initialActiveInfra};
  }

  LayersSelection _currentSelection() => LayersSelection(
        mapType: _mapType,
        showBusStops: _showBusStops,
        activeInfra: {..._activeInfra},
      );

  void _toggleInfra(OsmInfraKind kind, bool on) {
    setState(() {
      if (on) {
        _activeInfra.add(kind);
      } else {
        _activeInfra.remove(kind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _SectionLabel(label: FaroStrings.layersMapType),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SegmentChoice(
                            label: FaroStrings.layersMapTypeNormal,
                            selected: _mapType == MapType.normal,
                            onTap: () =>
                                setState(() => _mapType = MapType.normal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SegmentChoice(
                            label: FaroStrings.layersMapTypeHybrid,
                            selected: _mapType == MapType.hybrid,
                            onTap: () =>
                                setState(() => _mapType = MapType.hybrid),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(label: FaroStrings.layersLayers),
                    const SizedBox(height: 4),
                    _LayerSwitch(
                      value: _showBusStops,
                      onChanged: (v) => setState(() => _showBusStops = v),
                      title: FaroStrings.layersBusStops,
                      subtitle: FaroStrings.layersBusStopsHint,
                    ),
                    _LayerSwitch(
                      value: _activeInfra.contains(OsmInfraKind.police),
                      onChanged: (v) =>
                          _toggleInfra(OsmInfraKind.police, v),
                      title: FaroStrings.layersPolice,
                      subtitle: FaroStrings.layersPoliceHint,
                    ),
                    _LayerSwitch(
                      value: _activeInfra.contains(OsmInfraKind.hospitals),
                      onChanged: (v) =>
                          _toggleInfra(OsmInfraKind.hospitals, v),
                      title: FaroStrings.layersHospitals,
                      subtitle: FaroStrings.layersHospitalsHint,
                    ),
                    _LayerSwitch(
                      value:
                          _activeInfra.contains(OsmInfraKind.commerce24h),
                      onChanged: (v) =>
                          _toggleInfra(OsmInfraKind.commerce24h, v),
                      title: FaroStrings.layersCommerce24h,
                      subtitle: FaroStrings.layersCommerce24hHint,
                    ),
                    _LayerSwitch(
                      value:
                          _activeInfra.contains(OsmInfraKind.streetLamps),
                      onChanged: (v) =>
                          _toggleInfra(OsmInfraKind.streetLamps, v),
                      title: FaroStrings.layersStreetLamps,
                      subtitle: FaroStrings.layersStreetLampsHint,
                    ),
                    if (_activeInfra.isNotEmpty || _showBusStops) ...[
                      const SizedBox(height: 6),
                      Text(
                        FaroStrings.layersInfraSourceNote,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: FaroColors.textSoft,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _SectionLabel(label: FaroStrings.layersView),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop(_currentSelection());
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TrajectoryScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.history,
                                size: 20, color: FaroColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    FaroStrings.layersTrajectoryTitle,
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        color: FaroColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    FaroStrings.layersTrajectoryHint,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: FaroColors.textSoft),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 20, color: FaroColors.textSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_currentSelection()),
                  style: FilledButton.styleFrom(
                    backgroundColor: FaroColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: Text(FaroStrings.layersApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: FaroColors.textSoft,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _LayerSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  const _LayerSwitch({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: FaroColors.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        title,
        style: const TextStyle(
            fontSize: 14.5, color: FaroColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: FaroColors.textSoft),
      ),
    );
  }
}

class _SegmentChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FaroColors.primary : FaroColors.sandChip,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : FaroColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
