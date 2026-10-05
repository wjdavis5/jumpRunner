import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/parallax_city.dart';

void main() {
  group('Neon billboards (midground signage)', () {
    test('city carries a rotating set of courier-themed ads', () {
      expect(ParallaxCityComponent.billboardAdCount, greaterThanOrEqualTo(5));
    });

    test('glow intensity stays within [0, 1] across time and buildings', () {
      for (var building = 0; building < 8; building++) {
        for (var t = 0.0; t < 30.0; t += 0.13) {
          final glow = ParallaxCityComponent.billboardGlowFor(
            buildingIndex: building,
            time: t,
          );
          expect(glow, inInclusiveRange(0.0, 1.0),
              reason: 'glow out of range at building $building, t=$t');
        }
      }
    });

    test('glow is deterministic for identical inputs', () {
      final a = ParallaxCityComponent.billboardGlowFor(buildingIndex: 3, time: 12.34);
      final b = ParallaxCityComponent.billboardGlowFor(buildingIndex: 3, time: 12.34);
      expect(a, equals(b));
    });

    test('signage flickers: dropouts occur across a sweep', () {
      var dropouts = 0;
      for (var building = 0; building < 8; building++) {
        for (var t = 0.0; t < 30.0; t += 0.1) {
          if (ParallaxCityComponent.billboardGlowFor(
                buildingIndex: building,
                time: t,
              ) <
              0.5) {
            dropouts++;
          }
        }
      }
      expect(dropouts, greaterThan(0),
          reason: 'aging neon must occasionally flicker out');
    });

    test('most frames hold a healthy shimmer above the dropout floor', () {
      var healthy = 0;
      var total = 0;
      for (var building = 0; building < 8; building++) {
        for (var t = 0.0; t < 30.0; t += 0.1) {
          total++;
          if (ParallaxCityComponent.billboardGlowFor(
                buildingIndex: building,
                time: t,
              ) >=
              0.5) {
            healthy++;
          }
        }
      }
      expect(healthy / total, greaterThan(0.7),
          reason: 'signage must read clearly most of the time');
    });
  });
}
