import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/services/background_location_service.dart';
import 'package:projeto_seg/services/messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O service depende de plataforma (Geolocator, Firestore, notif) então
/// aqui testamos só o que dá pra isolar puro-Dart: opt-in flag, geohash
/// helper e singleton. Comportamento de stream é validado em integration
/// test no device (fora do CI por ora).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundLocationService.opt-in', () {
    test('default é false sem prefs', () async {
      expect(await BackgroundLocationService.isOptedIn(), isFalse);
    });

    test('setOptIn(true) persiste', () async {
      await BackgroundLocationService.setOptIn(true);
      expect(await BackgroundLocationService.isOptedIn(), isTrue);
    });

    test('setOptIn(false) reverte', () async {
      await BackgroundLocationService.setOptIn(true);
      await BackgroundLocationService.setOptIn(false);
      expect(await BackgroundLocationService.isOptedIn(), isFalse);
    });
  });

  group('BackgroundLocationService singleton', () {
    test('instância é estável', () {
      final a = BackgroundLocationService.instance;
      final b = BackgroundLocationService.instance;
      expect(identical(a, b), isTrue);
    });

    test('start retorna false quando não há opt-in', () async {
      await BackgroundLocationService.setOptIn(false);
      expect(await BackgroundLocationService.instance.start(), isFalse);
    });
  });

  group('geohash5Of (dedupe de célula)', () {
    test('movimento de poucos metros gera mesmo geohash5', () {
      // ~5km é a granularidade do geohash5. Dois pontos próximos no
      // mesmo bairro de Salvador devem produzir o mesmo hash.
      final a = geohash5Of(-12.9714, -38.5014);
      final b = geohash5Of(-12.9715, -38.5015);
      expect(a, equals(b));
    });

    test('movimento de bairros opostos pode gerar hash diferente', () {
      // Pituba vs Centro: ~7km. Pode (mas não obriga) a divergir no
      // 5º char. O contrato é "≥3 chars iguais", não "todos iguais".
      final pituba = geohash5Of(-13.0010, -38.4540);
      final centro = geohash5Of(-12.9714, -38.5104);
      expect(pituba.substring(0, 3), equals(centro.substring(0, 3)));
    });
  });
}
