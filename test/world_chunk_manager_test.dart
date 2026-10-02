import 'package:flutter_test/flutter_test.dart';
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
  });
}
