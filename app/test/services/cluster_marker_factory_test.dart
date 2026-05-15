import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/theme/app_theme.dart';
import 'package:projeto_seg/services/cluster_marker_factory.dart';

void main() {
  group('ClusterMarkerFactory.displayCount', () {
    test('counts 2-9 são exibidos exatos', () {
      for (var n = 2; n <= 9; n++) {
        expect(ClusterMarkerFactory.displayCount(n), n.toString());
      }
    });

    test('counts >= 10 viram 9+', () {
      expect(ClusterMarkerFactory.displayCount(10), '9+');
      expect(ClusterMarkerFactory.displayCount(50), '9+');
      expect(ClusterMarkerFactory.displayCount(999), '9+');
    });
  });

  group('ClusterMarkerFactory.keyFor', () {
    test('combina risk e displayCount', () {
      expect(
        ClusterMarkerFactory.keyFor(3, RiskLevel.highCorroborated),
        'highCorroborated:3',
      );
      expect(
        ClusterMarkerFactory.keyFor(99, RiskLevel.lightActivity),
        'lightActivity:9+',
      );
    });

    test('counts no mesmo bucket geram mesma chave', () {
      expect(
        ClusterMarkerFactory.keyFor(10, RiskLevel.confirmedActivity),
        ClusterMarkerFactory.keyFor(50, RiskLevel.confirmedActivity),
      );
    });
  });
}
