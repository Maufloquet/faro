import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Tipos de erro de localização. Caller usa pra decidir UI:
///   - serviceOff: mostrar "Ative a localização" + botão pra abrir
///     Settings do device.
///   - permissionDenied: prompt foi mostrado, usuário recusou. UI pode
///     pedir de novo no próximo toque.
///   - permissionBlocked: deniedForever — só o usuário desbloqueia em
///     Settings → Apps. UI mostra explicação + botão pra abrir app settings.
///   - timeout: GPS sem fix dentro do prazo. UI pede pra tentar de novo.
///   - unknown: outra falha (ex: GPS desligado no nível do sistema).
enum LocationErrorKind {
  serviceOff,
  permissionDenied,
  permissionBlocked,
  timeout,
  unknown,
}

class LocationService {
  /// Tenta obter a posição atual. Lança [LocationException] com motivo claro
  /// e [LocationErrorKind] pra UI montar dialog específico.
  Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Ative a localização do dispositivo nas configurações.',
        kind: LocationErrorKind.serviceOff,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Permissão de localização negada.',
          kind: LocationErrorKind.permissionDenied,
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Localização bloqueada. Habilite nas configurações do app.',
        kind: LocationErrorKind.permissionBlocked,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      throw const LocationException(
        'GPS sem sinal no momento. Tente em alguns segundos.',
        kind: LocationErrorKind.timeout,
      );
    } catch (e) {
      throw LocationException('Não foi possível obter sua localização. ($e)');
    }
  }

  /// Variante silenciosa: retorna null se permissão ainda não foi concedida
  /// (sem mostrar prompt). Usada no auto-centro no boot, pra não invadir
  /// o usuário antes de ele explicitar interesse.
  Future<Position?> currentIfAlreadyAuthorized() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class LocationException implements Exception {
  final String message;
  final LocationErrorKind kind;
  const LocationException(this.message, {this.kind = LocationErrorKind.unknown});

  @override
  String toString() => message;
}
