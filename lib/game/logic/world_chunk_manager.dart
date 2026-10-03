import 'dart:math' as math;

import '../components/obstacle_component.dart';
import '../components/pickup_component.dart';

/// Data representation of an obstacle placement within a procedural chunk.
class ObstacleData {
  const ObstacleData({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final ObstacleType type;
  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data representation of a collectible pickup placement within a procedural chunk.
class PickupData {
  const PickupData({
    required this.type,
    required this.x,
    required this.y,
  });

  final PickupType type;
  final double x;
  final double y;
}

/// A generated chunk slice containing obstacles and collectible pickups.
class ChunkData {
  const ChunkData({
    required this.obstacles,
    required this.pickups,
  });

  final List<ObstacleData> obstacles;
  final List<PickupData> pickups;
}

/// Procedural chunk generator managing speed scaling, obstacle spacing, and pickup arcs.
///
/// Ensures guaranteed clearance between hazards so that every obstacle pattern is
/// humanly jumpable across all velocity brackets (from 200 px/s up to 550 px/s).
class WorldChunkManager {
  WorldChunkManager({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  static const double baseSpeed = 200.0;
  static const double maxSpeed = 550.0;
  static const double speedRampDistance = 2000.0;

  /// Calculates current horizontal scroll velocity based on total distance ran in meters.
  ///
  /// Increases linearly from 200 px/s at 0m to exactly 550 px/s at 2,000m.
  double calculateSpeed(double distanceMeters) {
    final progress = (distanceMeters / speedRampDistance).clamp(0.0, 1.0);
    return baseSpeed + (maxSpeed - baseSpeed) * progress;
  }

  /// Calculates the guaranteed minimum clearance distance between consecutive obstacles.
  ///
  /// Scaled dynamically based on velocity to guarantee safe landing footprint.
  double calculateMinClearance(double speed) {
    // Courier jump airtime is ~0.5s; minimum landing footprint scales with speed + safety reaction room
    return math.max(180.0, speed * 0.75);
  }

  double _lastObstacleEndX = -9999.0;

  /// Resets the generator state for a new run.
  void reset() {
    _lastObstacleEndX = -9999.0;
  }

  /// Procedurally generates a slice of world terrain of [chunkWidth] pixels starting at [startX].
  ChunkData generateChunk({
    required double startX,
    double chunkWidth = 960.0,
    required double speed,
    double groundY = 460.0,
    double distanceMeters = 0.0,
  }) {
    final obstacles = <ObstacleData>[];
    final pickups = <PickupData>[];

    final minClearance = calculateMinClearance(speed);
    final naturalStart = startX + 60.0 + _random.nextDouble() * 40.0;
    double cursorX = math.max(naturalStart, _lastObstacleEndX + minClearance + 1.0);
    final endX = startX + chunkWidth - 80.0;

    // Introduce dynamic hazards (skate messenger, pigeon flock) at distance/speed milestones
    final availableTypes = (distanceMeters >= 800.0 || speed >= 340.0)
        ? ObstacleType.values
        : const [
            ObstacleType.scooter,
            ObstacleType.dog,
            ObstacleType.hydrant,
            ObstacleType.van,
          ];

    // Pick 1 to 2 obstacle placements per chunk to avoid cluttered bottlenecks
    while (cursorX < endX) {
      final typeIndex = _random.nextInt(availableTypes.length);
      final type = availableTypes[typeIndex];
      final size = ObstacleComponent.defaultSizeForType(type);

      final obstacleY = groundY - size.y;
      final obstacle = ObstacleData(
        type: type,
        x: cursorX,
        y: obstacleY,
        width: size.x,
        height: size.y,
      );
      obstacles.add(obstacle);
      _lastObstacleEndX = obstacle.x + obstacle.width;

      // Reward jump: Place a coin or pickup above the hazard in jump arc
      final roll = _random.nextDouble();
      final arcPickupType = (roll < 0.10 && distanceMeters >= 150.0)
          ? PickupType.drone
          : (roll < 0.28)
              ? PickupType.energyDrink
              : (_random.nextDouble() < 0.3 ? PickupType.coin5 : PickupType.coin);
      pickups.add(
        PickupData(
          type: arcPickupType,
          x: cursorX + size.x / 2 - 14,
          y: obstacleY - 60.0 - (_random.nextDouble() * 30.0),
        ),
      );

      // Advance cursor past obstacle + guaranteed clearance (granting extra buffer for oncoming skate messengers)
      final extraClearance = (type == ObstacleType.skateMessenger) ? 60.0 : 0.0;
      cursorX += size.x + minClearance + extraClearance + (_random.nextDouble() * 120.0);
    }

    // Place extra trail coins in the gaps if no hazard is nearby
    double coinX = startX + 120.0;
    while (coinX < startX + chunkWidth - 100.0) {
      final isNearObstacle = obstacles.any(
        (o) => (coinX >= o.x - 40.0) && (coinX <= o.x + o.width + 40.0),
      );

      if (!isNearObstacle && _random.nextDouble() < 0.5) {
        pickups.add(
          PickupData(
            type: PickupType.coin,
            x: coinX,
            y: groundY - 35.0,
          ),
        );
      }
      coinX += 160.0;
    }

    // Occasional package restore in high difficulty chunks
    if (_random.nextDouble() < 0.15 && speed > 300.0) {
      pickups.add(
        PickupData(
          type: PickupType.packageRestore,
          x: startX + chunkWidth / 2,
          y: groundY - 40.0,
        ),
      );
    }

    return ChunkData(obstacles: obstacles, pickups: pickups);
  }
}
