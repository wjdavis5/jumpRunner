import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Moving Traffic & Urban Hazards (Issue #25)', () {
    test('SkateMessenger has calibrated size, sprite path, and relative velocity', () {
      final size = ObstacleComponent.defaultSizeForType(ObstacleType.skateMessenger);
      expect(size.x, equals(46));
      expect(size.y, equals(42));
      expect(
        ObstacleComponent.spritePathForType(ObstacleType.skateMessenger),
        isNull,
      );
      expect(
        ObstacleComponent.defaultRelativeVelocityForType(ObstacleType.skateMessenger),
        equals(65.0),
      );
    });

    test('PigeonFlock has calibrated size, sprite path, and default properties', () {
      final size = ObstacleComponent.defaultSizeForType(ObstacleType.pigeonFlock);
      expect(size.x, equals(44));
      expect(size.y, equals(28));
      expect(
        ObstacleComponent.spritePathForType(ObstacleType.pigeonFlock),
        isNull,
      );
      expect(
        ObstacleComponent.defaultRelativeVelocityForType(ObstacleType.pigeonFlock),
        equals(0.0),
      );
    });

    test('SkateMessenger advances relative velocity in update loop', () {
      final skater = ObstacleComponent(
        type: ObstacleType.skateMessenger,
        position: Vector2(500, 418),
      );

      expect(skater.relativeVelocityX, equals(65.0));
      expect(skater.position.x, equals(500.0));

      skater.update(0.1);
      // 500 - (65 * 0.1) = 493.5
      expect(skater.position.x, closeTo(493.5, 0.001));

      skater.update(0.2);
      // 493.5 - (65 * 0.2) = 480.5
      expect(skater.position.x, closeTo(480.5, 0.001));
    });

    test('PigeonFlock stays grounded until courier approaches proximity trigger', () {
      final pigeons = ObstacleComponent(
        type: ObstacleType.pigeonFlock,
        position: Vector2(600, 432),
      );

      expect(pigeons.isFlocking, isFalse);
      expect(pigeons.velocityY, equals(0.0));

      // Courier is at x = 120. When pigeons at x = 600, distance is 480 (> 180)
      pigeons.update(0.1);
      expect(pigeons.isFlocking, isFalse);
      expect(pigeons.position.y, equals(432.0));

      // Move flock into proximity range (< 180 + 120 = 300)
      pigeons.position.x = 280.0;
      pigeons.update(0.1);

      expect(pigeons.isFlocking, isTrue);
      expect(pigeons.velocityY, lessThan(0.0)); // ascending
      expect(pigeons.position.y, lessThan(432.0)); // moved upward
    });

    test('PigeonFlock continues ascending and recycles past upper boundary', () {
      final pigeons = ObstacleComponent(
        type: ObstacleType.pigeonFlock,
        position: Vector2(250, 432),
      );

      pigeons.update(0.01);
      expect(pigeons.isFlocking, isTrue);

      // Simulate ascending flight upwards
      pigeons.position.y = -160.0;
      expect(pigeons.shouldRecycle, isTrue);
    });

    test('SkateMessenger and PigeonFlock render procedural fallback without errors', () {
      final skater = ObstacleComponent(
        type: ObstacleType.skateMessenger,
        position: Vector2(200, 400),
      );

      final pigeons = ObstacleComponent(
        type: ObstacleType.pigeonFlock,
        position: Vector2(200, 400),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Should render without throwing
      skater.update(0.05);
      skater.render(canvas);

      pigeons.update(0.05);
      pigeons.render(canvas);

      // Trigger flocking and render flap animation
      pigeons.position.x = 250.0;
      pigeons.update(0.05);
      expect(pigeons.isFlocking, isTrue);
      pigeons.render(canvas);

      recorder.endRecording();
    });

    test('Collision with CourierPlayer damages player and sets hurt state', () async {
      final player = CourierPlayer(groundY: 460.0);
      player.position = Vector2(120, 412);
      await player.onLoad();

      final skater = ObstacleComponent(
        type: ObstacleType.skateMessenger,
        position: Vector2(120, 418),
      );
      await skater.onLoad();

      expect(player.isInvulnerable, isFalse);
      skater.onCollisionStart({Vector2(120, 418)}, player);

      expect(skater.hasCollidedWithPlayer, isTrue);
      expect(player.isInvulnerable, isTrue);
      expect(player.state, equals(CourierState.hurt));
    });

    test('WorldChunkManager restricts dynamic hazards before 800m / 340 px/s milestone', () {
      final manager = WorldChunkManager(random: math.Random(1));

      for (int i = 0; i < 20; i++) {
        final chunk = manager.generateChunk(
          startX: i * 960.0,
          speed: 220.0,
          distanceMeters: 100.0,
        );

        for (final obs in chunk.obstacles) {
          expect(obs.type, isNot(ObstacleType.skateMessenger));
          expect(obs.type, isNot(ObstacleType.pigeonFlock));
        }
      }
    });

    test('WorldChunkManager introduces dynamic hazards at or beyond 800m milestone', () {
      final manager = WorldChunkManager(random: math.Random(1));
      bool foundDynamicHazard = false;

      // Run multiple chunks beyond 800m
      for (int i = 0; i < 50; i++) {
        final chunk = manager.generateChunk(
          startX: i * 960.0,
          speed: 360.0,
          distanceMeters: 900.0,
        );

        for (final obs in chunk.obstacles) {
          if (obs.type == ObstacleType.skateMessenger ||
              obs.type == ObstacleType.pigeonFlock) {
            foundDynamicHazard = true;
            break;
          }
        }
        if (foundDynamicHazard) break;
      }

      expect(foundDynamicHazard, isTrue);
    });

    test('WorldChunkManager provides extra clearance for oncoming skateMessenger', () {
      final manager = WorldChunkManager(random: math.Random(1));
      final minClearance = manager.calculateMinClearance(350.0);

      // Verify that clearance calculation scales with speed
      expect(minClearance, greaterThanOrEqualTo(180.0));
    });
  });
}
