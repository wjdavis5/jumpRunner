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
    this.isVip = false,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final bool isVip;
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

/// Data model for an urban sidewalk thermal steam vent.
class SteamVentData {
  const SteamVentData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.updraftHeight = 220.0,
    this.updraftVelocity = 380.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double updraftHeight;
  final double updraftVelocity;
}

/// A generated chunk slice containing obstacles, collectible pickups,
/// optional elevated aerial routes, customer doorstep drop zones, metallic grind rails,
/// and thermal steam vents.
class SubwayStationData {
  const SubwayStationData({
    required this.x,
    required this.width,
    this.stationName = '8th Ave Express',
  });

  final double x;
  final double width;
  final String stationName;
}

/// Data for spawning an overhead industrial construction crane swing.
class CraneSwingData {
  const CraneSwingData({
    required this.x,
    this.y = 40.0,
    this.width = 260.0,
    this.height = 320.0,
    this.cableLength = 175.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double cableLength;
}

/// Data model for an urban delivery cyclist companion riding in traffic.
class CyclistData {
  const CyclistData({
    required this.x,
    required this.y,
    this.width = 76.0,
    this.height = 54.0,
    this.relativeSpeed = 0.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double relativeSpeed;
}

/// Data model for an urban pigeon flock roosting on a sidewalk or ledge.
class PigeonFlockData {
  const PigeonFlockData({
    required this.x,
    required this.y,
    this.pigeonCount = 6,
  });

  final double x;
  final double y;
  final int pigeonCount;
}

/// Data model for an urban street intersection crosswalk.
class CrosswalkData {
  const CrosswalkData({
    required this.x,
    required this.y,
    this.width = 140.0,
    this.signalCountdown = 9,
  });

  final double x;
  final double y;
  final double width;
  final int signalCountdown;
}

/// Data model for a street food vendor cart with umbrella bounce cushion.
class FoodCartData {
  const FoodCartData({
    required this.x,
    required this.y,
    this.width = 88.0,
    this.height = 78.0,
    this.bounceImpulse = 400.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double bounceImpulse;
}

/// Data model for an urban street storm drain vault grate.
class StormDrainData {
  const StormDrainData({
    required this.x,
    required this.y,
    this.width = 56.0,
    this.height = 18.0,
    this.coinsSpawned = 3,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int coinsSpawned;
}

/// Data model for an elevated rooftop photovoltaic solar panel array.
class SolarPanelData {
  const SolarPanelData({
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

/// Data model for an urban sidewalk rainwater puddle.
class PuddleData {
  const PuddleData({
    required this.x,
    required this.y,
    this.width = 74.0,
    this.height = 14.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for an industrial HVAC turbine exhaust wind tunnel.
class HvacWindTunnelData {
  const HvacWindTunnelData({
    required this.x,
    required this.y,
    this.housingWidth = 54.0,
    this.housingHeight = 54.0,
    this.windLength = 260.0,
  });

  final double x;
  final double y;
  final double housingWidth;
  final double housingHeight;
  final double windLength;
}

/// Data model for a street-level subway entrance turnstile.
class SubwayTurnstileData {
  const SubwayTurnstileData({
    required this.x,
    required this.y,
    this.width = 58.0,
    this.height = 52.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for an autonomous aerial cargo drone carrying a suspended supply crate.
class DroneCargoData {
  const DroneCargoData({
    required this.x,
    required this.y,
    this.width = 48.0,
    this.height = 42.0,
    this.relativeSpeed = -20.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double relativeSpeed;
}

/// Data model for an apartment building facade fire escape with drop ladder.
class FireEscapeData {
  const FireEscapeData({
    required this.x,
    required this.y,
    this.width = 84.0,
    this.height = 140.0,
    this.launchImpulse = 420.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double launchImpulse;
}

/// Data model for a parked gourmet food truck with an asphalt grease spill slick.
class FoodTruckSlickData {
  const FoodTruckSlickData({
    required this.x,
    required this.y,
    this.width = 120.0,
    this.height = 88.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a street construction sawhorse barricade.
class BarricadeSawhorseData {
  const BarricadeSawhorseData({
    required this.x,
    required this.y,
    this.width = 68.0,
    this.height = 44.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a rooftop parabolic satellite communications dish.
class SatelliteDishData {
  const SatelliteDishData({
    required this.x,
    required this.y,
    this.width = 56.0,
    this.height = 50.0,
    this.launchImpulse = 540.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double launchImpulse;
}

class ChunkData {
  const ChunkData({
    required this.obstacles,
    required this.pickups,
    this.scaffoldings = const [],
    this.ramps = const [],
    this.dropZones = const [],
    this.grindRails = const [],
    this.steamVents = const [],
    this.subwayStations = const [],
    this.craneSwings = const [],
    this.cyclists = const [],
    this.pigeonFlocks = const [],
    this.crosswalks = const [],
    this.foodCarts = const [],
    this.stormDrains = const [],
    this.solarPanels = const [],
    this.puddles = const [],
    this.windTunnels = const [],
    this.turnstiles = const [],
    this.droneCargos = const [],
    this.fireEscapes = const [],
    this.foodTruckSlicks = const [],
    this.barricades = const [],
    this.satelliteDishes = const [],
  });

  final List<ObstacleData> obstacles;
  final List<PickupData> pickups;
  final List<ScaffoldingData> scaffoldings;
  final List<RampData> ramps;
  final List<DropZoneData> dropZones;
  final List<GrindRailData> grindRails;
  final List<SteamVentData> steamVents;
  final List<SubwayStationData> subwayStations;
  final List<CraneSwingData> craneSwings;
  final List<CyclistData> cyclists;
  final List<PigeonFlockData> pigeonFlocks;
  final List<CrosswalkData> crosswalks;
  final List<FoodCartData> foodCarts;
  final List<StormDrainData> stormDrains;
  final List<SolarPanelData> solarPanels;
  final List<PuddleData> puddles;
  final List<HvacWindTunnelData> windTunnels;
  final List<SubwayTurnstileData> turnstiles;
  final List<DroneCargoData> droneCargos;
  final List<FireEscapeData> fireEscapes;
  final List<FoodTruckSlickData> foodTruckSlicks;
  final List<BarricadeSawhorseData> barricades;
  final List<SatelliteDishData> satelliteDishes;
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
    bool isVipActive = false,
  }) {
    final obstacles = <ObstacleData>[];
    final pickups = <PickupData>[];
    final scaffoldings = <ScaffoldingData>[];
    final ramps = <RampData>[];
    final grindRails = <GrindRailData>[];
    final steamVents = <SteamVentData>[];
    final solarPanels = <SolarPanelData>[];
    final windTunnels = <HvacWindTunnelData>[];

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

        // Optionally attach an elevated catwalk grind rail or rooftop solar panel array extending off the scaffolding deck
        final remainingScaffoldSpace = endX - (scaffoldingX + scaffoldingWidth);
        if (_random.nextDouble() < 0.40 && remainingScaffoldSpace >= 160.0) {
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
        } else if (_random.nextDouble() < 0.40 && remainingScaffoldSpace >= 180.0) {
          final panelX = scaffoldingX + scaffoldingWidth + 12.0;
          final panelWidth = math.min(220.0, endX - panelX);
          final panelY = scaffoldingY; // Level with scaffolding deck
          solarPanels.add(SolarPanelData(
            x: panelX,
            y: panelY,
            width: panelWidth,
            height: 18.0,
          ));

          // Gold coins along the solar panel
          for (double sx = panelX + 30.0; sx < panelX + panelWidth - 20.0; sx += 60.0) {
            pickups.add(PickupData(
              type: PickupType.coin,
              x: sx,
              y: panelY - 26.0,
            ));
          }

          _lastObstacleEndX = panelX + panelWidth;
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

    // Urban Sidewalk Steam Vent: Spawns after 150m when no scaffolding or rail occupies the stretch
    if (scaffoldings.isEmpty &&
        grindRails.isEmpty &&
        distanceMeters >= 150.0 &&
        _random.nextDouble() < 0.25 &&
        (endX - cursorX) >= 280.0) {
      final ventX = cursorX;
      const ventWidth = 48.0;
      const ventHeight = 16.0;
      final ventY = groundY - ventHeight;

      steamVents.add(SteamVentData(
        x: ventX,
        y: ventY,
        width: ventWidth,
        height: ventHeight,
      ));

      // Updraft trail coins ascending vertically through the plume
      pickups.add(PickupData(type: PickupType.coin, x: ventX + 16.0, y: groundY - 70.0));
      pickups.add(PickupData(type: PickupType.coin5, x: ventX + 16.0, y: groundY - 140.0));
      pickups.add(PickupData(type: PickupType.coin, x: ventX + 16.0, y: groundY - 200.0));

      // Place a wide street hazard downfield to glide over
      final obstacleX = ventX + 130.0;
      const obstacleType = ObstacleType.van;
      final obsSize = ObstacleComponent.defaultSizeForType(obstacleType);
      obstacles.add(ObstacleData(
        type: obstacleType,
        x: obstacleX,
        y: groundY - obsSize.y,
        width: obsSize.x,
        height: obsSize.y,
      ));

      _lastObstacleEndX = obstacleX + obsSize.x;
      cursorX = _lastObstacleEndX + minClearance + 1.0;
    }

    // Rooftop Photovoltaic Solar Panel Array: Spawns after 110m when no scaffolding or rail occupies the stretch
    if (scaffoldings.isEmpty &&
        grindRails.isEmpty &&
        steamVents.isEmpty &&
        distanceMeters >= 110.0 &&
        _random.nextDouble() < 0.32 &&
        (endX - cursorX) >= 260.0) {
      final panelWidth = 200.0 + _random.nextDouble() * 60.0;
      final panelX = cursorX;
      final panelY = groundY - 54.0;

      solarPanels.add(SolarPanelData(
        x: panelX,
        y: panelY,
        width: panelWidth,
        height: 18.0,
      ));

      // Rewarding coins floating along the solar panel
      for (double sx = panelX + 25.0; sx < panelX + panelWidth - 15.0; sx += 55.0) {
        pickups.add(PickupData(
          type: PickupType.coin,
          x: sx,
          y: panelY - 26.0,
        ));
      }

      // Ground hazard underneath the solar panel for player to slide over
      final groundType = ObstacleType.values[_random.nextInt(4)];
      final gSize = ObstacleComponent.defaultSizeForType(groundType);
      final gX = panelX + (panelWidth / 2) - (gSize.x / 2);
      obstacles.add(ObstacleData(
        type: groundType,
        x: gX,
        y: groundY - gSize.y,
        width: gSize.x,
        height: gSize.y,
      ));

      _lastObstacleEndX = panelX + panelWidth;
      cursorX = _lastObstacleEndX + minClearance + 1.0;
    }

    // Industrial HVAC Exhaust Wind Tunnel: Spawns after 160m when no scaffolding, rail, steam vent, or solar panel occupies stretch
    if (scaffoldings.isEmpty &&
        grindRails.isEmpty &&
        steamVents.isEmpty &&
        solarPanels.isEmpty &&
        distanceMeters >= 160.0 &&
        _random.nextDouble() < 0.32 &&
        (endX - cursorX) >= 340.0) {
      final tunnelX = cursorX;
      const tunnelHousingWidth = 54.0;
      const tunnelHousingHeight = 54.0;
      const tunnelWindLength = 260.0;
      final tunnelY = groundY - 110.0;

      windTunnels.add(HvacWindTunnelData(
        x: tunnelX,
        y: tunnelY,
        housingWidth: tunnelHousingWidth,
        housingHeight: tunnelHousingHeight,
        windLength: tunnelWindLength,
      ));

      // Rewarding coins along the aerodynamic wind slipstream
      for (double wx = tunnelX + tunnelHousingWidth + 30.0;
          wx < tunnelX + tunnelHousingWidth + tunnelWindLength - 20.0;
          wx += 65.0) {
        pickups.add(PickupData(
          type: PickupType.coin,
          x: wx,
          y: tunnelY + (tunnelHousingHeight / 2) - 10.0,
        ));
      }

      // Ground hazard underneath the wind tunnel stream for courier to hover glide over
      const groundType = ObstacleType.van;
      final gSize = ObstacleComponent.defaultSizeForType(groundType);
      final gX = tunnelX + tunnelHousingWidth + 80.0;
      obstacles.add(ObstacleData(
        type: groundType,
        x: gX,
        y: groundY - gSize.y,
        width: gSize.x,
        height: gSize.y,
      ));

      _lastObstacleEndX = tunnelX + tunnelHousingWidth + tunnelWindLength;
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
      final arcPickupType = (roll < 0.08 && distanceMeters >= 180.0 && !isVipActive)
          ? PickupType.vipPackage
          : (roll < 0.16 && distanceMeters >= 150.0)
              ? PickupType.drone
              : (roll < 0.32)
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

    // Occasional VIP package or package restore in mid-to-high difficulty chunks
    if (!isVipActive && distanceMeters >= 180.0 && _random.nextDouble() < 0.18) {
      pickups.add(
        PickupData(
          type: PickupType.vipPackage,
          x: startX + chunkWidth * 0.75,
          y: groundY - 45.0,
        ),
      );
    } else if (_random.nextDouble() < 0.15 && speed > 300.0) {
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
    if (isVipActive ||
        ((distanceMeters >= 70.0 && _random.nextDouble() < 0.45) &&
            scaffoldings.isEmpty &&
            grindRails.isEmpty &&
            steamVents.isEmpty)) {
      const zoneWidth = 68.0;
      double? chosenX;

      // Scan candidate slots across chunk to find a clear zone
      for (var offset = 140.0; offset <= chunkWidth - 180.0; offset += 50.0) {
        final candidateX = startX + offset;
        final isClear = obstacles.every(
          (o) => (candidateX + zoneWidth < o.x - 45.0) || (candidateX > o.x + o.width + 45.0),
        );
        if (isClear) {
          chosenX = candidateX;
          break;
        }
      }

      // If VIP mission is active, guarantee a placement even if it means clearing a conflicting obstacle
      if (chosenX == null && isVipActive) {
        chosenX = startX + 220.0;
        obstacles.removeWhere(
          (o) => (chosenX! + zoneWidth >= o.x - 45.0) && (chosenX <= o.x + o.width + 45.0),
        );
      }

      if (chosenX != null) {
        final spawnVip = isVipActive || (distanceMeters >= 220.0 && _random.nextDouble() < 0.25);
        dropZones.add(
          DropZoneData(
            x: chosenX,
            y: groundY - 70.0,
            width: zoneWidth,
            height: 70.0,
            isVip: spawnVip,
          ),
        );
      }
    }

    final List<SubwayStationData> subwayStations = [];

    // Subterranean Subway Tunnel Stations (after 200m, exclusive with aerial scaffolding, rails, and steam vents)
    if (distanceMeters >= 200.0 &&
        _random.nextDouble() < 0.35 &&
        scaffoldings.isEmpty &&
        grindRails.isEmpty &&
        steamVents.isEmpty &&
        dropZones.isEmpty) {
      final stationNames = [
        '8th Ave Express',
        'Broadway Metro',
        'Grand Central Line',
        'Times Square Transit',
        'Lexington Ave Local',
      ];
      final stationName = stationNames[_random.nextInt(stationNames.length)];
      subwayStations.add(
        SubwayStationData(
          x: startX,
          width: chunkWidth,
          stationName: stationName,
        ),
      );

      // In a subway station, spawn authentic subterranean hazards:
      // An electrified third rail on track
      obstacles.clear();
      final thirdRailX = startX + 220.0 + (_random.nextDouble() * 80.0);
      obstacles.add(
        ObstacleData(
          type: ObstacleType.thirdRail,
          x: thirdRailX,
          y: groundY - 24.0,
          width: 58.0,
          height: 24.0,
        ),
      );

      // And an oncoming express subway train further along the station with generous clearance
      final trainX = thirdRailX + 280.0 + (_random.nextDouble() * 60.0);
      obstacles.add(
        ObstacleData(
          type: ObstacleType.subwayTrain,
          x: trainX,
          y: groundY - 64.0,
          width: 110.0,
          height: 64.0,
        ),
      );
    }

    final List<CraneSwingData> craneSwings = [];

    // Industrial Construction Crane Swings (after 240m, exclusive with aerial scaffolding, rails, and subway)
    if (distanceMeters >= 240.0 &&
        _random.nextDouble() < 0.35 &&
        scaffoldings.isEmpty &&
        grindRails.isEmpty &&
        subwayStations.isEmpty) {
      final craneX = startX + 160.0 + (_random.nextDouble() * 80.0);
      craneSwings.add(
        CraneSwingData(
          x: craneX,
          y: 40.0,
          width: 260.0,
          height: 320.0,
          cableLength: 175.0,
        ),
      );
    }

    final List<CyclistData> cyclists = [];

    // Friendly Delivery Cyclist Companion (after 100m, on street outside subway stations and scaffolding)
    if (distanceMeters >= 100.0 &&
        _random.nextDouble() < 0.45 &&
        scaffoldings.isEmpty &&
        subwayStations.isEmpty &&
        craneSwings.isEmpty) {
      const cyclistWidth = 76.0;
      const cyclistHeight = 54.0;
      for (var offset = 140.0; offset <= chunkWidth - 180.0; offset += 50.0) {
        final cyclistX = startX + offset;
        final isClearFromObstacles = obstacles.every(
          (o) => (cyclistX + cyclistWidth < o.x - 45.0) || (cyclistX > o.x + o.width + 45.0),
        );

        if (isClearFromObstacles) {
          cyclists.add(
            CyclistData(
              x: cyclistX,
              y: groundY - cyclistHeight,
              width: cyclistWidth,
              height: cyclistHeight,
              relativeSpeed: 15.0 + (_random.nextDouble() * 15.0),
            ),
          );
          break;
        }
      }
    }

    final List<PigeonFlockData> pigeonFlocks = [];

    // Roosting Urban Pigeon Flocks (after 80m, roosting on sidewalk or scaffolding ledge)
    if (distanceMeters >= 80.0 && _random.nextDouble() < 0.40) {
      if (scaffoldings.isNotEmpty && _random.nextBool()) {
        final sc = scaffoldings.first;
        pigeonFlocks.add(
          PigeonFlockData(
            x: sc.x + 20.0,
            y: sc.y - 14.0,
            pigeonCount: 5 + _random.nextInt(3),
          ),
        );
      } else if (subwayStations.isEmpty) {
        final flockX = startX + 140.0 + (_random.nextDouble() * 200.0);
        // Ensure not overlapping directly on an obstacle
        final isClear = obstacles.every(
          (o) => (flockX + 70.0 < o.x - 30.0) || (flockX > o.x + o.width + 30.0),
        );
        if (isClear) {
          pigeonFlocks.add(
            PigeonFlockData(
              x: flockX,
              y: groundY - 14.0,
              pigeonCount: 5 + _random.nextInt(4),
            ),
          );
        }
      }
    }

    final List<CrosswalkData> crosswalks = [];

    // Street Crosswalk Intersections (after 90m, on street outside subway stations and scaffolding)
    if (distanceMeters >= 90.0 &&
        _random.nextDouble() < 0.40 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const crosswalkWidth = 140.0;
      for (var offset = 120.0; offset <= chunkWidth - 200.0; offset += 50.0) {
        final cwX = startX + offset;
        final isClear = obstacles.every(
          (o) => (cwX + crosswalkWidth < o.x - 35.0) || (cwX > o.x + o.width + 35.0),
        );
        if (isClear) {
          crosswalks.add(
            CrosswalkData(
              x: cwX,
              y: groundY - 56.0,
              width: crosswalkWidth,
              signalCountdown: 6 + _random.nextInt(8),
            ),
          );
          break;
        }
      }
    }

    final List<FoodCartData> foodCarts = [];

    // Street Food Vendor Carts (after 60m, on street outside subway stations and scaffolding)
    if (distanceMeters >= 60.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty &&
        crosswalks.isEmpty) {
      const cartWidth = 88.0;
      for (var offset = 100.0; offset <= chunkWidth - 180.0; offset += 50.0) {
        final fcX = startX + offset;
        final isClear = obstacles.every(
          (o) => (fcX + cartWidth < o.x - 30.0) || (fcX > o.x + o.width + 30.0),
        );
        if (isClear) {
          foodCarts.add(
            FoodCartData(
              x: fcX,
              y: groundY - 78.0,
              width: cartWidth,
              height: 78.0,
              bounceImpulse: 400.0,
            ),
          );
          break;
        }
      }
    }

    final List<StormDrainData> stormDrains = [];

    // Street Storm Drain Vault Grates (after 120m, on street outside subway stations and scaffolding)
    if (distanceMeters >= 120.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty &&
        crosswalks.isEmpty &&
        foodCarts.isEmpty) {
      const drainWidth = 56.0;
      for (var offset = 100.0; offset <= chunkWidth - 160.0; offset += 50.0) {
        final sdX = startX + offset;
        final isClear = obstacles.every(
          (o) => (sdX + drainWidth < o.x - 30.0) || (sdX > o.x + o.width + 30.0),
        );
        if (isClear) {
          stormDrains.add(
            StormDrainData(
              x: sdX,
              y: groundY - 18.0,
              width: drainWidth,
              height: 18.0,
              coinsSpawned: 3 + _random.nextInt(2),
            ),
          );
          break;
        }
      }
    }

    final List<PuddleData> puddles = [];

    // Sidewalk Water Puddles (after 50m, on street outside subway stations and scaffolding)
    if (distanceMeters >= 50.0 &&
        _random.nextDouble() < 0.40 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const puddleWidth = 74.0;
      for (var offset = 90.0; offset <= chunkWidth - 140.0; offset += 45.0) {
        final pudX = startX + offset;
        final isClear = obstacles.every(
          (o) => (pudX + puddleWidth < o.x - 25.0) || (pudX > o.x + o.width + 25.0),
        ) && crosswalks.every(
          (cw) => (pudX + puddleWidth < cw.x - 20.0) || (pudX > cw.x + cw.width + 20.0),
        ) && foodCarts.every(
          (fc) => (pudX + puddleWidth < fc.x - 20.0) || (pudX > fc.x + fc.width + 20.0),
        ) && stormDrains.every(
          (sd) => (pudX + puddleWidth < sd.x - 20.0) || (pudX > sd.x + sd.width + 20.0),
        );
        if (isClear) {
          puddles.add(
            PuddleData(
              x: pudX,
              y: groundY - 14.0,
              width: puddleWidth,
              height: 14.0,
            ),
          );
          break;
        }
      }
    }

    final List<SubwayTurnstileData> turnstiles = [];

    // Street Subway Entrance Turnstiles (after 75m, on street outside subway stations and scaffolding)
    if (distanceMeters >= 75.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const turnstileWidth = 58.0;
      for (var offset = 110.0; offset <= chunkWidth - 150.0; offset += 45.0) {
        final tX = startX + offset;
        final isClear = obstacles.every(
          (o) => (tX + turnstileWidth < o.x - 30.0) || (tX > o.x + o.width + 30.0),
        ) && crosswalks.every(
          (cw) => (tX + turnstileWidth < cw.x - 20.0) || (tX > cw.x + cw.width + 20.0),
        ) && foodCarts.every(
          (fc) => (tX + turnstileWidth < fc.x - 20.0) || (tX > fc.x + fc.width + 20.0),
        ) && stormDrains.every(
          (sd) => (tX + turnstileWidth < sd.x - 20.0) || (tX > sd.x + sd.width + 20.0),
        ) && puddles.every(
          (pud) => (tX + turnstileWidth < pud.x - 20.0) || (tX > pud.x + pud.width + 20.0),
        );
        if (isClear) {
          turnstiles.add(
            SubwayTurnstileData(
              x: tX,
              y: groundY - 52.0,
              width: turnstileWidth,
              height: 52.0,
            ),
          );
          break;
        }
      }
    }

    final List<DroneCargoData> droneCargos = [];

    // Aerial Delivery Cargo Drones (after 140m, in open aerial stretches)
    if (distanceMeters >= 140.0 &&
        _random.nextDouble() < 0.32 &&
        craneSwings.isEmpty &&
        subwayStations.isEmpty) {
      final droneX = startX + 180.0 + (_random.nextDouble() * 200.0);
      droneCargos.add(
        DroneCargoData(
          x: droneX,
          y: groundY - 210.0,
          width: 48.0,
          height: 42.0,
          relativeSpeed: -15.0 - (_random.nextDouble() * 15.0),
        ),
      );
    }

    final List<FireEscapeData> fireEscapes = [];

    // Building Facade Fire Escape Ladders (after 130m, outside scaffolding, subway, crane)
    if (distanceMeters >= 130.0 &&
        _random.nextDouble() < 0.35 &&
        scaffoldings.isEmpty &&
        subwayStations.isEmpty &&
        craneSwings.isEmpty) {
      const escapeWidth = 84.0;
      for (var offset = 120.0; offset <= chunkWidth - 180.0; offset += 50.0) {
        final feX = startX + offset;
        final isClear = obstacles.every(
          (o) => (feX + escapeWidth < o.x - 25.0) || (feX > o.x + o.width + 25.0),
        ) && crosswalks.every(
          (cw) => (feX + escapeWidth < cw.x - 20.0) || (feX > cw.x + cw.width + 20.0),
        ) && foodCarts.every(
          (fc) => (feX + escapeWidth < fc.x - 20.0) || (feX > fc.x + fc.width + 20.0),
        ) && turnstiles.every(
          (t) => (feX + escapeWidth < t.x - 20.0) || (feX > t.x + t.width + 20.0),
        );
        if (isClear) {
          fireEscapes.add(
            FireEscapeData(
              x: feX,
              y: groundY - 140.0,
              width: escapeWidth,
              height: 140.0,
              launchImpulse: 420.0,
            ),
          );
          break;
        }
      }
    }

    final List<FoodTruckSlickData> foodTruckSlicks = [];

    // Gourmet Food Truck Grease Slick (after 90m, outside subway stations, scaffolding, and carts)
    if (distanceMeters >= 90.0 &&
        _random.nextDouble() < 0.32 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty &&
        foodCarts.isEmpty) {
      const truckWidth = 120.0;
      for (var offset = 100.0; offset <= chunkWidth - 190.0; offset += 55.0) {
        final ftsX = startX + offset;
        final isClear = obstacles.every(
          (o) => (ftsX + truckWidth < o.x - 30.0) || (ftsX > o.x + o.width + 30.0),
        ) && crosswalks.every(
          (cw) => (ftsX + truckWidth < cw.x - 20.0) || (ftsX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (ftsX + truckWidth < t.x - 20.0) || (ftsX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (ftsX + truckWidth < fe.x - 20.0) || (ftsX > fe.x + fe.width + 20.0),
        );
        if (isClear) {
          foodTruckSlicks.add(
            FoodTruckSlickData(
              x: ftsX,
              y: groundY - 88.0,
              width: truckWidth,
              height: 88.0,
            ),
          );
          break;
        }
      }
    }

    final List<BarricadeSawhorseData> barricades = [];

    // Street Construction Sawhorse Barricade (after 70m, outside subway stations, food trucks, and scaffolding)
    if (distanceMeters >= 70.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const barricadeWidth = 68.0;
      for (var offset = 80.0; offset <= chunkWidth - 140.0; offset += 50.0) {
        final bX = startX + offset;
        final isClear = obstacles.every(
          (o) => (bX + barricadeWidth < o.x - 30.0) || (bX > o.x + o.width + 30.0),
        ) && crosswalks.every(
          (cw) => (bX + barricadeWidth < cw.x - 20.0) || (bX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (bX + barricadeWidth < t.x - 20.0) || (bX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (bX + barricadeWidth < fe.x - 20.0) || (bX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (bX + barricadeWidth < fts.x - 30.0) || (bX > fts.x + fts.width + 30.0),
        );
        if (isClear) {
          barricades.add(
            BarricadeSawhorseData(
              x: bX,
              y: groundY - 44.0,
              width: barricadeWidth,
              height: 44.0,
            ),
          );
          break;
        }
      }
    }

    final List<SatelliteDishData> satelliteDishes = [];

    // Rooftop / Scaffolding Parabolic Satellite Dish Leap Pad (after 130m)
    if (distanceMeters >= 130.0 && _random.nextDouble() < 0.35 && subwayStations.isEmpty) {
      const dishWidth = 56.0;
      const dishHeight = 50.0;

      // Option A: If elevated scaffolding is present, mount atop the scaffolding platform
      if (scaffoldings.isNotEmpty) {
        final sc = scaffoldings.first;
        if (sc.width >= 120.0) {
          final dishX = sc.x + sc.width - dishWidth - 14.0;
          satelliteDishes.add(
            SatelliteDishData(
              x: dishX,
              y: sc.y - dishHeight,
              width: dishWidth,
              height: dishHeight,
              launchImpulse: 540.0,
            ),
          );
        }
      } else {
        // Option B: Mount on clear rooftop/road surface with clear vertical airspace
        for (var offset = 120.0; offset <= chunkWidth - 160.0; offset += 55.0) {
          final sX = startX + offset;
          final isClear = obstacles.every(
            (o) => (sX + dishWidth < o.x - 35.0) || (sX > o.x + o.width + 35.0),
          ) && crosswalks.every(
            (cw) => (sX + dishWidth < cw.x - 25.0) || (sX > cw.x + cw.width + 25.0),
          ) && turnstiles.every(
            (t) => (sX + dishWidth < t.x - 25.0) || (sX > t.x + t.width + 25.0),
          ) && fireEscapes.every(
            (fe) => (sX + dishWidth < fe.x - 25.0) || (sX > fe.x + fe.width + 25.0),
          ) && foodTruckSlicks.every(
            (fts) => (sX + dishWidth < fts.x - 30.0) || (sX > fts.x + fts.width + 30.0),
          ) && barricades.every(
            (b) => (sX + dishWidth < b.x - 30.0) || (sX > b.x + b.width + 30.0),
          );

          if (isClear) {
            satelliteDishes.add(
              SatelliteDishData(
                x: sX,
                y: groundY - dishHeight,
                width: dishWidth,
                height: dishHeight,
                launchImpulse: 540.0,
              ),
            );
            break;
          }
        }
      }
    }

    return ChunkData(
      obstacles: obstacles,
      pickups: pickups,
      scaffoldings: scaffoldings,
      ramps: ramps,
      dropZones: dropZones,
      grindRails: grindRails,
      steamVents: steamVents,
      subwayStations: subwayStations,
      craneSwings: craneSwings,
      cyclists: cyclists,
      pigeonFlocks: pigeonFlocks,
      crosswalks: crosswalks,
      foodCarts: foodCarts,
      stormDrains: stormDrains,
      solarPanels: solarPanels,
      puddles: puddles,
      windTunnels: windTunnels,
      turnstiles: turnstiles,
      droneCargos: droneCargos,
      fireEscapes: fireEscapes,
      foodTruckSlicks: foodTruckSlicks,
      barricades: barricades,
      satelliteDishes: satelliteDishes,
    );
  }
}
