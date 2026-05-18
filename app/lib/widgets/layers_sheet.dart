import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../screens/trajectory_screen.dart';

import '../core/design/tokens.dart';

/// Botão circular que abre o sheet de camadas. Substitui os botões
/// individuais de "mapa/satélite" e "pontos de ônibus" — fica mais
/// limpo e prepara espaço pra camadas futuras (iluminação, hospitais 24h).
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
    return Material(
      color: hasActiveLayers ? FaroColors.primary : Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(
            Icons.layers_outlined,
            size: 22,
            color: hasActiveLayers ? Colors.white : FaroColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Estado das camadas — tipo de mapa + toggles de overlay.
class LayersSelection {
  final MapType mapType;
  final bool showBusStops;
  const LayersSelection({required this.mapType, required this.showBusStops});
}

/// Bottom sheet modal que controla camadas do mapa.
class LayersSheet extends StatefulWidget {
  final MapType initialMapType;
  final bool initialShowBusStops;

  const LayersSheet({
    super.key,
    required this.initialMapType,
    required this.initialShowBusStops,
  });

  static Future<LayersSelection?> show(
    BuildContext context, {
    required MapType mapType,
    required bool showBusStops,
  }) {
    return showModalBottomSheet<LayersSelection>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LayersSheet(
        initialMapType: mapType,
        initialShowBusStops: showBusStops,
      ),
    );
  }

  @override
  State<LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<LayersSheet> {
  late MapType _mapType;
  late bool _showBusStops;

  @override
  void initState() {
    super.initState();
    _mapType = widget.initialMapType;
    _showBusStops = widget.initialShowBusStops;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
            const Text(
              'Tipo de mapa',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FaroColors.textSoft,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SegmentChoice(
                    label: 'Padrão',
                    selected: _mapType == MapType.normal,
                    onTap: () => setState(() => _mapType = MapType.normal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentChoice(
                    label: 'Satélite',
                    selected: _mapType == MapType.hybrid,
                    onTap: () => setState(() => _mapType = MapType.hybrid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Camadas',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FaroColors.textSoft,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              value: _showBusStops,
              onChanged: (v) => setState(() => _showBusStops = v),
              activeThumbColor: FaroColors.primary,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Pontos de ônibus',
                style: TextStyle(fontSize: 14.5, color: FaroColors.textPrimary),
              ),
              subtitle: const Text(
                'Visíveis ao aproximar o mapa (zoom de rua)',
                style: TextStyle(fontSize: 12, color: FaroColors.textSoft),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ver',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FaroColors.textSoft,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).pop(
                  LayersSelection(mapType: _mapType, showBusStops: _showBusStops),
                );
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrajectoryScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: FaroColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seu trajeto',
                            style: TextStyle(fontSize: 14.5, color: FaroColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Áreas com relatos por onde você passou nos últimos 7 dias',
                            style: TextStyle(fontSize: 12, color: FaroColors.textSoft),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: FaroColors.textSoft),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  LayersSelection(mapType: _mapType, showBusStops: _showBusStops),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: FaroColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Aplicar'),
              ),
            ),
          ],
        ),
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
