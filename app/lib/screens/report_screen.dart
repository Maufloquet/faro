import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../models/user_report.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../services/report_service.dart';

/// Tela de abrir um relato (Camada 4 — UGC).
///
/// GPS é obrigatório por princípio editorial: um relato sem lugar não tem
/// valor e abre brecha pra boato à distância. Resolvemos a posição na
/// entrada; sem ela, o envio fica bloqueado com explicação e botão de tentar
/// de novo. O texto deixa claro que é um relato pessoal, ainda não
/// confirmado — não um veredito.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _location = LocationService();
  final _descController = TextEditingController();

  ReportType? _type;
  double? _lat;
  double? _lng;
  bool _locating = true;
  String? _locationError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('report');
    _resolveLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final pos = await _location.currentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locating = false;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.message;
        _locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Não foi possível obter sua localização.';
        _locating = false;
      });
    }
  }

  bool get _canSubmit =>
      _type != null && _lat != null && _lng != null && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reportServiceProvider).create(
            lat: _lat!,
            lng: _lng!,
            type: _type!,
            description: _descController.text,
          );
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Relato enviado. Vai aparecer no mapa como não confirmado até '
            'outras pessoas perto confirmarem.',
          ),
        ),
      );
    } on ReportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar. Tente de novo.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatar', style: TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _Disclaimer(),
          const SizedBox(height: 18),
          _LocationStatus(
            locating: _locating,
            error: _locationError,
            hasFix: _lat != null && _lng != null,
            onRetry: _resolveLocation,
          ),
          const SizedBox(height: 22),
          const Text(
            'O QUE VOCÊ VIU',
            style: TextStyle(
              fontSize: 12.5,
              color: FaroColors.textSoft,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          ...ReportType.values.map((t) {
            final selected = _type == t;
            return InkWell(
              onTap: _submitting ? null : () => setState(() => _type = t),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? FaroColors.primary : FaroColors.textHint,
                    ),
                    const SizedBox(width: 12),
                    Text(t.label, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 280,
            decoration: InputDecoration(
              labelText: 'Detalhe (opcional)',
              hintText: 'Em poucas palavras, o que está acontecendo.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: FaroColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar relato'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  final bool locating;
  final String? error;
  final bool hasFix;
  final VoidCallback onRetry;
  const _LocationStatus({
    required this.locating,
    required this.error,
    required this.hasFix,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (locating) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Localizando você…',
              style: TextStyle(fontSize: 13.5, color: FaroColors.textMuted)),
        ],
      );
    }
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FaroColors.sandSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FaroColors.sandBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precisamos da sua localização pra registrar o relato no '
              'lugar certo. $error',
              style: const TextStyle(
                  fontSize: 12.5, height: 1.5, color: FaroColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    return const Row(
      children: [
        Icon(Icons.my_location, size: 16, color: FaroColors.primary),
        SizedBox(width: 10),
        Text('Usando sua localização atual',
            style: TextStyle(fontSize: 13.5, color: FaroColors.textMuted)),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: const Text(
        'Seu relato entra como não confirmado. Ele só ganha peso quando '
        'outras pessoas perto confirmam. Relate só o que você viu — sem '
        'boato. O que ninguém confirmar some sozinho em poucas horas.',
        style: TextStyle(
            fontSize: 12.5, height: 1.55, color: FaroColors.textSecondary),
      ),
    );
  }
}
