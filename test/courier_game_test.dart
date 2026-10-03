import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/components/pickup_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';

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

    test('Energy drink pickup activates boost and enables coin magnet (R6)', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      expect(game.gameState.isEnergyBoostActive, isFalse);
      expect(game.player.isBoosted, isFalse);

      // 1. Manually trigger energy drink pickup
      game.gameState.activateEnergyDrink();
      game.update(0.1);

      expect(game.gameState.isEnergyBoostActive, isTrue);
      expect(game.player.isBoosted, isTrue);

      // 2. Test coin magnet pull
      final initialCoinPos = Vector2(game.player.position.x + 120.0, game.player.position.y);
      final coin = PickupComponent(
        type: PickupType.coin,
        position: initialCoinPos.clone(),
      );
      game.world.add(coin);
      game.activePickups.add(coin);

      // Record distance before magnet update
      final initialDist = (game.player.position - coin.position).length;

      // Advance game loop
      game.update(0.1);

      // Coin should have been pulled closer to player than simple scrolling alone
      final newDist = (game.player.position - coin.position).length;
      expect(newDist, lessThan(initialDist));
    });

    test('Keyboard P and Escape keys request pause, and paused status freezes game tick', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      int pauseRequestCount = 0;
      game.onPauseRequested = () => pauseRequestCount++;

      // Press P key
      final pResult = game.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyP},
      );
      expect(pResult, equals(KeyEventResult.handled));
      expect(pauseRequestCount, equals(1));

      // Press Escape key
      final escResult = game.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.escape},
      );
      expect(escResult, equals(KeyEventResult.handled));
      expect(pauseRequestCount, equals(2));

      // Freeze check: pause run
      game.gameState.pauseRun();
      final initialDistance = game.gameState.distanceMeters;
      final initialNextChunkX = game.nextChunkX;

      game.update(1.0); // 1 full second
      expect(game.gameState.distanceMeters, equals(initialDistance));
      expect(game.nextChunkX, equals(initialNextChunkX));
    });
  });
}
