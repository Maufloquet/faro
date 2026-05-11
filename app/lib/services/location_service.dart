import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Tenta obter a posição atual. Lança [LocationException] com motivo claro
  /// se não conseguir — chamador decide como comunicar ao usuário.
  Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException('Ative a localização do dispositivo nas configurações.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('Permissão de localização negada.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Localização bloqueada. Habilite nas configurações do app.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
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
  const LocationException(this.message);

  @override
  String toString() => message;
}
