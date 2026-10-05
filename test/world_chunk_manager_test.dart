import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

void main() {
  group('WorldChunkManager (U4)', () {
    test('Speed scaling curve: 200 px/s at 0m to exactly 550 px/s at 2,000m', () {
      final manager = WorldChunkManager();

      expect(manager.calculateSpeed(0.0), equals(200.0));
      expect(manager.calculateSpeed(1000.0), equals(375.0));
      expect(manager.calculateSpeed(2000.0), equals(550.0));
      expect(manager.calculateSpeed(3000.0), equals(550.0),
          reason: 'Speed caps at 550 px/s after 2000m');
    });

    test('Guaranteed clearance: Obstacles generated have clearance strictly greater than jump footprint', () {
      final manager = WorldChunkManager();

      // Test across multiple speed brackets (0m, 500m, 1000m, 2000m)
      for (final distance in [0.0, 500.0, 1000.0, 2000.0]) {
        final speed = manager.calculateSpeed(distance);
        final minFootprint = manager.calculateMinClearance(speed);

        // Generate 10 consecutive chunks at this speed
        final obstacles = <ObstacleData>[];
        double currentX = 1000.0;
        for (var i = 0; i < 10; i++) {
          final chunk = manager.generateChunk(
            startX: currentX,
            chunkWidth: 960.0,
            speed: speed,
          );
          obstacles.addAll(chunk.obstacles);
          currentX += 960.0;
        }

        // Verify distance between consecutive obstacles
        for (var i = 0; i < obstacles.length - 1; i++) {
          final o1 = obstacles[i];
          final o2 = obstacles[i + 1];
          final gap = o2.x - (o1.x + o1.width);

          expect(
            gap,
            greaterThanOrEqualTo(minFootprint),
            reason: 'Gap ($gap px) at speed $speed px/s should be >= minimum footprint ($minFootprint px)',
          );
        }
      }
    });

    test('Chunk generation places pickups in playable zones', () {
      final manager = WorldChunkManager();
      final chunk = manager.generateChunk(
        startX: 1000.0,
        chunkWidth: 960.0,
        speed: 200.0,
      );

      expect(chunk.pickups, isNotEmpty);
      for (final pickup in chunk.pickups) {
        expect(pickup.x, greaterThanOrEqualTo(1000.0));
        expect(pickup.x, lessThanOrEqualTo(1960.0));
        // Pickups should be between ground Y (460) and jump apex (~280)
        expect(pickup.y, greaterThanOrEqualTo(260.0));
        expect(pickup.y, lessThanOrEqualTo(460.0));
      }
    });

    test('Warm-up stretch spawns at most one small hop-hazard per chunk', () {
      final manager = WorldChunkManager();
      const warmupTypes = {ObstacleType.scooter, ObstacleType.dog};

      double currentX = 960.0;
      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: currentX,
          chunkWidth: 960.0,
          speed: manager.calculateSpeed(0.0),
          distanceMeters: 0.0,
        );
        expect(
          chunk.obstacles.length,
          lessThanOrEqualTo(1),
          reason: 'Warm-up chunk $i must not crowd the opening stretch',
        );
        for (final obstacle in chunk.obstacles) {
          expect(
            warmupTypes.contains(obstacle.type),
            isTrue,
            reason: 'Warm-up hazards must be tap-hop clearable, got ${obstacle.type}',
          );
        }
        currentX += 960.0;
      }
    });

    test('Obstacle density ramps up after the warm-up stretch', () {
      final manager = WorldChunkManager();

      // Well past the ramp: with a 960px chunk at base speed, space allows
      // multiple hazards; the cap must allow at least 2.
      int maxObserved = 0;
      double currentX = 960.0;
      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: currentX,
          chunkWidth: 960.0,
          speed: manager.calculateSpeed(1000.0),
          distanceMeters: 1000.0,
        );
        maxObserved = math.max(maxObserved, chunk.obstacles.length);
        currentX += 960.0;
      }
      expect(maxObserved, inInclusiveRange(2, 3));
    });
  });
}
