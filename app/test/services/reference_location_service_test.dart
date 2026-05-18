import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/services/messaging_service.dart';
import 'package:projeto_seg/services/reference_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake do MessagingService que NÃO chama FCM. Só registra o que foi
/// pedido pra testarmos a integração lógica do ReferenceLocationService.
class _FakeMessaging extends MessagingService {
  final List<String> subscribed = [];
  final List<String> unsubscribed = [];

  @override
  Future<void> subscribeToTopic(String topic) async {
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    unsubscribed.add(topic);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReferenceLocationService svc;
  late _FakeMessaging fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fake = _FakeMessaging();
    svc = ReferenceLocationService.test(prefs: prefs, messaging: fake);
  });

  group('current', () {
    test('null quando não há nada salvo', () async {
      expect(await svc.current(), isNull);
    });

    test('lê o local salvo com label', () async {
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Hotel Pelourinho'));
      final r = await svc.current();
      expect(r, isNotNull);
      expect(r!.label, 'Hotel Pelourinho');
      expect(r.lat, -12.9714);
      expect(r.lng, -38.5014);
    });

    test('label vazia cai pro fallback ao reler', () async {
      // simula state corrompido onde label some
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('ref_loc_lat_v1', -12.9);
      await prefs.setDouble('ref_loc_lng_v1', -38.5);
      // sem label
      final r = await svc.current();
      expect(r, isNotNull);
      expect(r!.label, 'Local salvo');
    });
  });

  group('save', () {
    test('inscreve no tópico FCM correspondente ao geohash5', () async {
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Hotel'));
      expect(fake.subscribed, hasLength(1));
      expect(fake.subscribed.first, startsWith('reference_'));
      expect(fake.subscribed.first.length, 'reference_'.length + 5);
    });

    test('trocar de local desinscreve do antigo e inscreve no novo', () async {
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Pelourinho'));
      await svc.save(const ReferenceLocation(
        lat: -12.8895, lng: -38.3260, label: 'Lauro de Freitas'));

      expect(fake.subscribed, hasLength(2));
      expect(fake.unsubscribed, hasLength(1));
      // o tópico antigo é o primeiro subscribed, e foi o único desinscrito
      expect(fake.unsubscribed.first, fake.subscribed.first);
    });

    test('salvar no MESMO ponto não dispara unsubscribe (idempotente)', () async {
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Hotel'));
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Hotel renomeado'));
      expect(fake.unsubscribed, isEmpty);
    });
  });

  group('clear', () {
    test('apaga prefs e desinscreve do tópico ativo', () async {
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Hotel'));
      await svc.clear();
      expect(await svc.current(), isNull);
      expect(fake.unsubscribed, hasLength(1));
    });

    test('clear sem nada salvo é no-op', () async {
      await svc.clear();
      expect(fake.unsubscribed, isEmpty);
    });
  });

  group('resumeOnBoot', () {
    test('re-assina o tópico quando há local salvo', () async {
      await svc.save(const ReferenceLocation(
        lat: -12.9714, lng: -38.5014, label: 'Hotel'));
      final topicOnSave = fake.subscribed.last;

      await svc.resumeOnBoot();
      expect(fake.subscribed, hasLength(2));
      expect(fake.subscribed.last, topicOnSave);
    });

    test('no-op quando não há local salvo', () async {
      await svc.resumeOnBoot();
      expect(fake.subscribed, isEmpty);
    });
  });
}
