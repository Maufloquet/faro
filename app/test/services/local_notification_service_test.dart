import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/services/local_notification_service.dart';

/// Testes "smoke" do LocalNotificationService. O plugin nativo não roda em
/// flutter_test, então só verificamos que a instância existe e o singleton
/// está coerente. Comportamento real é validado em smoke manual no device.
void main() {
  group('LocalNotificationService', () {
    test('singleton retorna sempre a mesma instância', () {
      final a = LocalNotificationService.instance;
      final b = LocalNotificationService.instance;
      expect(identical(a, b), isTrue);
    });

    test('showProximityCatchUp com count<=0 é no-op (não lança)', () async {
      // Não há erro mesmo sem initialize, pois sai cedo.
      await LocalNotificationService.instance.showProximityCatchUp(count: 0);
      await LocalNotificationService.instance.showProximityCatchUp(count: -3);
    });
  });
}
