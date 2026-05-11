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
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}
