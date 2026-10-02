import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/courier_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CourierGame & Scaffolding (U1)', () {
    test('CourierGame initializes with fixed 16:9 resolution camera', () {
      final game = CourierGame();
      expect(CourierGame.virtualResolution.x, equals(960.0));
      expect(CourierGame.virtualResolution.y, equals(540.0));

      final viewport = game.camera.viewport;
      expect(viewport, isA<FixedResolutionViewport>());
      final fixedViewport = viewport as FixedResolutionViewport;
      expect(fixedViewport.resolution.x, equals(960.0));
      expect(fixedViewport.resolution.y, equals(540.0));
    });

    test('CourierGame has collision detection mixin active', () {
      final game = CourierGame();
      expect(game, isA<HasCollisionDetection>());
    });

    test('ParallaxCityComponent updates layers with correct speed differential', () {
      final parallax = ParallaxCityComponent(size: CourierGame.virtualResolution);

      expect(ParallaxCityComponent.baseSkylineSpeed, equals(20.0));
      expect(ParallaxCityComponent.baseMidgroundSpeed, equals(60.0));
      expect(ParallaxCityComponent.baseSidewalkSpeed, equals(200.0));

      // Advance 1 second
      parallax.update(1.0);

      expect(parallax.skylineOffset, closeTo(20.0, 0.001));
      expect(parallax.midgroundOffset, closeTo(60.0, 0.001));
      expect(parallax.sidewalkOffset, closeTo(200.0, 0.001));

      // Speed multiplier scaling
      parallax.speedMultiplier = 2.0;
      parallax.update(1.0);

      expect(parallax.skylineOffset, closeTo(20.0 + 40.0, 0.001));
      expect(parallax.midgroundOffset, closeTo(60.0 + 120.0, 0.001));
      expect(parallax.sidewalkOffset, closeTo(200.0 + 400.0, 0.001));
    });

    test('CourierGame onLoad attaches ParallaxCityComponent to world', () async {
      final game = CourierGame();
      await game.onLoad();

      final components = game.world.children.whereType<ParallaxCityComponent>();
      expect(components.length, equals(1));
    });
  });
}
