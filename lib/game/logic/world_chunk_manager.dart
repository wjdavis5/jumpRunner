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

/// Data model for an elevated scaffolding platform.
class ScaffoldingData {
  const ScaffoldingData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a construction launch ramp.
class RampData {
  const RampData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.launchImpulse = 520.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double launchImpulse;
}

/// Data model for a residential doorstep delivery drop-off zone.
class DropZoneData {
  const DropZoneData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for an elevated urban metallic grind rail.
class GrindRailData {
  const GrindRailData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// A generated chunk slice containing obstacles, collectible pickups,
/// optional elevated aerial routes, customer doorstep drop zones, and metallic grind rails.
class ChunkData {
  const ChunkData({
    required this.obstacles,
    required this.pickups,
    this.scaffoldings = const [],
    this.ramps = const [],
    this.dropZones = const [],
    this.grindRails = const [],
  });

  final List<ObstacleData> obstacles;
  final List<PickupData> pickups;
  final List<ScaffoldingData> scaffoldings;
  final List<RampData> ramps;
  final List<DropZoneData> dropZones;
  final List<GrindRailData> grindRails;
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
    final scaffoldings = <ScaffoldingData>[];
    final ramps = <RampData>[];
    final grindRails = <GrindRailData>[];

    final minClearance = calculateMinClearance(speed);
    final naturalStart = startX + 60.0 + _random.nextDouble() * 40.0;
    double cursorX = math.max(naturalStart, _lastObstacleEndX + minClearance + 1.0);
    final endX = startX + chunkWidth - 80.0;

    // Aerial Scaffolding Route: Spawns periodically after the first 150 meters
    final spawnAerial = (distanceMeters >= 150.0) && (_random.nextDouble() < 0.28);
    if (spawnAerial && (endX - cursorX) >= 420.0) {
      const rampWidth = 74.0;
      const rampHeight = 36.0;
      final rampX = cursorX;
      final rampY = groundY - rampHeight;
      ramps.add(RampData(
        x: rampX,
        y: rampY,
        width: rampWidth,
        height: rampHeight,
      ));

      final scaffoldingX = rampX + rampWidth + 10.0;
      final scaffoldingY = groundY - 120.0;
      final scaffoldingWidth = math.min(480.0, endX - scaffoldingX);

      if (scaffoldingWidth >= 200.0) {
        scaffoldings.add(ScaffoldingData(
          x: scaffoldingX,
          y: scaffoldingY,
          width: scaffoldingWidth,
          height: 12.0,
        ));

        // High-altitude gold rush along the scaffolding deck
        final coinCount = (scaffoldingWidth / 75.0).floor().clamp(2, 5);
        for (int i = 0; i < coinCount; i++) {
          final px = scaffoldingX + 35.0 + (i * 70.0);
          final pType = (i == (coinCount ~/ 2) && _random.nextDouble() < 0.4)
              ? PickupType.energyDrink
              : (_random.nextDouble() < 0.35 ? PickupType.coin5 : PickupType.coin);
          pickups.add(PickupData(
            type: pType,
            x: px,
            y: scaffoldingY - 32.0,
          ));
        }

        // Place a street-level obstacle underneath the scaffolding
        final groundType = ObstacleType.values[_random.nextInt(4)]; // scooter, dog, hydrant, mailbox
        final gSize = ObstacleComponent.defaultSizeForType(groundType);
        final gX = scaffoldingX + (scaffoldingWidth / 2) - (gSize.x / 2);
        obstacles.add(ObstacleData(
          type: groundType,
          x: gX,
          y: groundY - gSize.y,
          width: gSize.x,
          height: gSize.y,
        ));

        // Optionally attach an elevated catwalk grind rail extending off the scaffolding deck
        if (_random.nextDouble() < 0.40 && (endX - (scaffoldingX + scaffoldingWidth)) >= 160.0) {
          final railX = scaffoldingX + scaffoldingWidth + 12.0;
          final railWidth = math.min(220.0, endX - railX);
          final railY = scaffoldingY; // Level with scaffolding deck
          grindRails.add(GrindRailData(
            x: railX,
            y: railY,
            width: railWidth,
            height: 8.0,
          ));

          // Gold coins along the rail
          for (double rx = railX + 30.0; rx < railX + railWidth - 20.0; rx += 60.0) {
            pickups.add(PickupData(
              type: PickupType.coin,
              x: rx,
              y: railY - 26.0,
            ));
          }

          _lastObstacleEndX = railX + railWidth;
          cursorX = _lastObstacleEndX + minClearance + 1.0;
        } else {
          _lastObstacleEndX = scaffoldingX + scaffoldingWidth;
          cursorX = _lastObstacleEndX + minClearance + 1.0;
        }
      }
    }

    // Urban Street Grind Rail: Spawns after 90m when no scaffolding route is present
    if (scaffoldings.isEmpty &&
        distanceMeters >= 90.0 &&
        _random.nextDouble() < 0.35 &&
        (endX - cursorX) >= 260.0) {
      final railWidth = 200.0 + _random.nextDouble() * 60.0;
      final railX = cursorX;
      final railY = groundY - 48.0;

      grindRails.add(GrindRailData(
        x: railX,
        y: railY,
        width: railWidth,
        height: 8.0,
      ));

      // Rewarding coins floating along the grind rail
      for (double rx = railX + 25.0; rx < railX + railWidth - 15.0; rx += 55.0) {
        pickups.add(PickupData(
          type: PickupType.coin,
          x: rx,
          y: railY - 26.0,
        ));
      }

      // Ground hazard underneath the rail for player to grind over
      final groundType = ObstacleType.values[_random.nextInt(4)]; // scooter, dog, hydrant, mailbox
      final gSize = ObstacleComponent.defaultSizeForType(groundType);
      final gX = railX + (railWidth / 2) - (gSize.x / 2);
      obstacles.add(ObstacleData(
        type: groundType,
        x: gX,
        y: groundY - gSize.y,
        width: gSize.x,
        height: gSize.y,
      ));

      _lastObstacleEndX = railX + railWidth;
      cursorX = _lastObstacleEndX + minClearance + 1.0;
    }

    // Introduce dynamic hazards (skate messenger, pigeon flock) at distance/speed milestones
    final availableTypes = (distanceMeters >= 800.0 || speed >= 340.0)
        ? ObstacleType.values
        : const [
            ObstacleType.scooter,
            ObstacleType.dog,
            ObstacleType.hydrant,
            ObstacleType.mailbox,
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

    final List<DropZoneData> dropZones = [];

    // Customer Doorstep Delivery Drop-off Zones (after 70m, on ground sidewalk outside scaffolding/rails)
    if (distanceMeters >= 70.0 &&
        _random.nextDouble() < 0.45 &&
        scaffoldings.isEmpty &&
        grindRails.isEmpty) {
      final candidateX = startX + 180.0 + (_random.nextDouble() * (chunkWidth - 360.0));
      const zoneWidth = 68.0;
      final isClearFromObstacles = obstacles.every(
        (o) => (candidateX + zoneWidth < o.x - 70.0) || (candidateX > o.x + o.width + 70.0),
      );

      if (isClearFromObstacles) {
        dropZones.add(
          DropZoneData(
            x: candidateX,
            y: groundY - 70.0,
            width: zoneWidth,
            height: 70.0,
          ),
        );
      }
    }

    return ChunkData(
      obstacles: obstacles,
      pickups: pickups,
      scaffoldings: scaffoldings,
      ramps: ramps,
      dropZones: dropZones,
      grindRails: grindRails,
    );
  }
}
