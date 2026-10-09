import 'dart:math' as math;

import '../components/obstacle_component.dart';
import '../components/pickup_component.dart';
import 'chunk_declutter.dart';
import 'jump_physics.dart';

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

/// Data model for a street municipal postal drop collection mailbox.
class PostalMailboxData {
  const PostalMailboxData({
    required this.x,
    required this.y,
    this.width = 42.0,
    this.height = 54.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for an industrial rooftop air conditioning condenser fan unit with thermal draft updraft.
class AcCondenserData {
  const AcCondenserData({
    required this.x,
    required this.y,
    this.width = 72.0,
    this.height = 48.0,
    this.updraftImpulse = 380.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double updraftImpulse;
}

/// Data model for an elevated rooftop glass skylight atrium dome.
class GlassSkylightData {
  const GlassSkylightData({
    required this.x,
    required this.y,
    this.width = 80.0,
    this.height = 36.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a sidewalk flower vendor kiosk.
class FlowerKioskData {
  const FlowerKioskData({
    required this.x,
    required this.y,
    this.width = 68.0,
    this.height = 58.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for an elevated rooftop wooden water tower.
class WaterTowerData {
  const WaterTowerData({
    required this.x,
    required this.y,
    this.width = 86.0,
    this.height = 110.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a sidewalk newspaper kiosk hurdle.
class NewsstandData {
  const NewsstandData({
    required this.x,
    required this.y,
    this.width = 80.0,
    this.height = 62.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a sidewalk outdoor cafe bistro table hurdle.
class CafeBistroData {
  const CafeBistroData({
    required this.x,
    required this.y,
    this.width = 78.0,
    this.height = 56.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a sidewalk street busker jazz musician fixture.
class StreetBuskerData {
  const StreetBuskerData({
    required this.x,
    required this.y,
    this.width = 84.0,
    this.height = 68.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a sidewalk street corner open fire hydrant fixture.
class FireHydrantData {
  const FireHydrantData({
    required this.x,
    required this.y,
    this.width = 86.0,
    this.height = 54.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for a rooftop tenement laundry clothesline fixture.
class ClotheslineData {
  const ClotheslineData({
    required this.x,
    required this.y,
    this.width = 96.0,
    this.height = 48.0,
    this.roofY = 460.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double roofY;
}

/// Data model for a sidewalk subway ventilation exhaust grate fixture.
class SubwayExhaustGrateData {
  const SubwayExhaustGrateData({
    required this.x,
    required this.y,
    this.width = 88.0,
    this.height = 14.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Data model for an aerial high-voltage catenary power line zipline.
class CatenaryZiplineData {
  const CatenaryZiplineData({
    required this.x,
    required this.y,
    this.spanWidth = 240.0,
    this.cableDrop = 24.0,
    this.sag = 10.0,
    this.groundY = 460.0,
  });

  final double x;
  final double y;
  final double spanWidth;
  final double cableDrop;
  final double sag;
  final double groundY;
}

/// Data model for a street transit bus stop shelter fixture.
class BusShelterData {
  const BusShelterData({
    required this.x,
    required this.y,
    this.width = 96.0,
    this.height = 54.0,
    this.groundY = 460.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double groundY;
}

/// Data model for an alleyway industrial roll-up security shutter door fixture.
class SecurityShutterData {
  const SecurityShutterData({
    required this.x,
    required this.y,
    this.width = 48.0,
    this.height = 80.0,
    this.groundY = 460.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double groundY;
}

/// Data model for a street construction portable rotary cement mixer fixture.
class CementMixerData {
  const CementMixerData({
    required this.x,
    required this.y,
    this.width = 64.0,
    this.height = 56.0,
    this.groundY = 460.0,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double groundY;
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
    this.postalMailboxes = const [],
    this.acCondensers = const [],
    this.glassSkylights = const [],
    this.flowerKiosks = const [],
    this.waterTowers = const [],
    this.newsstands = const [],
    this.cafeBistros = const [],
    this.streetBuskers = const [],
    this.fireHydrants = const [],
    this.clotheslines = const [],
    this.subwayExhaustGrates = const [],
    this.catenaryZiplines = const [],
    this.busShelters = const [],
    this.securityShutters = const [],
    this.cementMixers = const [],
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
  final List<PostalMailboxData> postalMailboxes;
  final List<AcCondenserData> acCondensers;
  final List<GlassSkylightData> glassSkylights;
  final List<FlowerKioskData> flowerKiosks;
  final List<WaterTowerData> waterTowers;
  final List<NewsstandData> newsstands;
  final List<CafeBistroData> cafeBistros;
  final List<StreetBuskerData> streetBuskers;
  final List<FireHydrantData> fireHydrants;
  final List<ClotheslineData> clotheslines;
  final List<SubwayExhaustGrateData> subwayExhaustGrates;
  final List<CatenaryZiplineData> catenaryZiplines;
  final List<BusShelterData> busShelters;
  final List<SecurityShutterData> securityShutters;
  final List<CementMixerData> cementMixers;
}

/// Procedural chunk generator managing speed scaling, obstacle spacing, and pickup arcs.
///
/// Ensures guaranteed clearance between hazards so that every obstacle pattern is
/// humanly jumpable across all velocity brackets (from 200 px/s up to 550 px/s).
class WorldChunkManager {
  WorldChunkManager({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// Chance that a chunk with room for one becomes a subway station. A
  /// field so a QA build can raise it; play uses the default.
  double subwayStationChance = defaultSubwayStationChance;

  /// About 1.3 stations per 1,000 m. It was 0.35 until a station could no
  /// longer follow a van whose landing would be on its third rail; that
  /// rule turns away about one station in five, and this makes them up.
  static const double defaultSubwayStationChance = 0.45;

  static const double baseSpeed = 200.0;
  static const double maxSpeed = 550.0;
  static const double speedRampDistance = 2000.0;

  /// Opening stretch that teaches jump timing: one small hazard per chunk.
  static const double warmupEndMeters = 100.0;

  /// Shift ramp-up tail: obstacle density reaches full roster past this point.
  static const double rampEndMeters = 250.0;

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

  /// How long a full, held leap stays in the air, in seconds: about 1.3.
  /// Measured from the jump physics, with the small extra lift a Caffeine
  /// Surge gives, so the room left for it holds with or without one.
  static final double fullLeapAirtime = _measureFullLeapAirtime();

  static double _measureFullLeapAirtime() {
    const dt = 1.0 / 240.0;
    final leap = JumpPhysicsSimulator()..startJump(impulseMultiplier: 1.10);
    var seconds = 0.0;
    while (!leap.isGrounded && seconds < 5.0) {
      leap.update(dt);
      seconds += dt;
    }
    return seconds;
  }

  /// The latest a leap can start, in seconds ahead of a van, and still
  /// clear it. Measured at 0.06 s at the start of a shift and 0.15 s at
  /// speed; the earlier figure leaves the most room.
  static const double latestLeapStart = 0.10;

  /// The time a courier gets between landing a leap and having to press
  /// for whatever comes next.
  static const double landingReaction = 0.25;

  /// Whether [type] can only be cleared by the full, held leap. A hop
  /// clears everything else.
  static bool needsFullLeap(ObstacleType type) =>
      type == ObstacleType.van || type == ObstacleType.subwayTrain;

  /// The clear street a hazard of [type] needs behind it.
  ///
  /// [calculateMinClearance] is three quarters of a second of street, which
  /// is room to land a hop (0.76 s in the air, started ahead of the hazard)
  /// and react. A van cannot be hopped, and the leap that clears it is in
  /// the air for 1.3 s. Pressed late, that leap came down on the next
  /// hazard or within a few frames of it: for up to four in ten of the
  /// press timings that clear a van, nothing the player did next could
  /// save the package behind it. So behind such a hazard the street stays
  /// clear to the furthest point the leap can land, plus time to react.
  double clearanceAfter(ObstacleType type, double speed) {
    final usual = calculateMinClearance(speed);
    if (!needsFullLeap(type)) return usual;
    final closing = math.max(speed, baseSpeed) + ObstacleComponent.defaultRelativeVelocityForType(type);
    final furthestLanding = fullLeapAirtime * math.max(speed, baseSpeed) -
        latestLeapStart * closing -
        ObstacleComponent.defaultSizeForType(type).x;
    return math.max(usual, furthestLanding + landingReaction * math.max(speed, baseSpeed));
  }

  /// How far ahead of a hazard that needs a leap the leap has to start, in
  /// seconds: the run-up a van needs in front of it.
  static const double leapRunUp = 0.15;

  /// The street between the far edge of [ahead] and the near edge of [next]
  /// at the moment the courier reaches [ahead].
  ///
  /// [clearanceAfter], and two things more. A hazard that needs a leap gets
  /// that leap's run-up in front of it: a hop can be pressed up to the last
  /// moment, a leap over a van cannot, and a courier who landed from the
  /// hazard ahead with the usual room had a tenth of a second to start one.
  /// And behind a hazard that takes a full leap, one that rolls toward the
  /// courier keeps coming while the courier is in the air, so it is set
  /// back by what it covers in that time.
  double clearanceBetween(ObstacleType ahead, ObstacleType next, double speed) {
    var clearance = clearanceAfter(ahead, speed);
    if (needsFullLeap(next)) clearance += leapRunUp * math.max(speed, baseSpeed);
    if (needsFullLeap(ahead)) {
      clearance += ObstacleComponent.defaultRelativeVelocityForType(next) *
          (fullLeapAirtime + landingReaction);
    }
    return clearance;
  }

  /// Records that a hazard of [type] ends at [endX].
  ///
  /// Whatever is built next keeps the usual clearance from
  /// [_lastObstacleEndX], so for a hazard that takes a full leap that point
  /// is moved out by the extra street its landing needs.
  void _hazardEndsAt(double endX, ObstacleType type, double speed) {
    _lastObstacleEndX = endX + clearanceAfter(type, speed) - calculateMinClearance(speed);
    _lastHazardType = type;
  }

  /// How long a courier who runs off the end of something [height] px up
  /// takes to reach the street: the moment's grace at the edge, then the
  /// fall.
  static double dropSeconds(double height) {
    final physics = JumpPhysicsSimulator();
    return physics.coyoteDuration + math.sqrt(2 * height / physics.gravity);
  }

  /// The street a hazard of [next] needs, beyond the usual clearance,
  /// behind a rail, a scaffold or a solar array the courier comes off
  /// [height] px up.
  ///
  /// The usual three quarters of a second covers the drop from a scaffold
  /// (0.6 s) and little else. That is enough for anything a hop clears: a
  /// hop can be pressed on landing. A van needs its leap started ahead of
  /// it, and a courier who ran off the end of a scaffold came down a tenth
  /// of a second from the van: the only way past was to have jumped from
  /// the deck. So a van stands far enough back to land, react and leap.
  double roomAfterDrop(ObstacleType next, double height, double speed) {
    if (!needsFullLeap(next)) return 0.0;
    final street = math.max(speed, baseSpeed);
    final needed = (dropSeconds(height) + landingReaction + leapRunUp) * street;
    return math.max(0.0, needed - calculateMinClearance(speed));
  }

  /// Records that a street piece which is not itself a hazard (a rail, a
  /// scaffold, a solar array) ends at [endX], its top [height] px above
  /// the street.
  void _pieceEndsAt(double endX, {required double height}) {
    _lastObstacleEndX = endX;
    _lastHazardType = null;
    _lastPieceHeight = height;
  }

  /// What an ordinary street can serve once it is up to speed: the five
  /// fixed hazards plus the two that move.
  ///
  /// This was `ObstacleType.values`, which meant the same thing until the
  /// third rail and the subway train were added to the enum for stations.
  /// From then on two street hazards in nine past 800 m were a live rail or
  /// a train on the open street, with no station anywhere near.
  static const List<ObstacleType> streetHazards = [
    ObstacleType.scooter,
    ObstacleType.dog,
    ObstacleType.hydrant,
    ObstacleType.mailbox,
    ObstacleType.van,
    ObstacleType.skateMessenger,
    ObstacleType.pigeonFlock,
  ];

  /// How far ahead of the courier a chunk starts when the game builds it.
  static const double chunkSpawnLead = 1320.0;

  /// Width of the third rail hazard.
  static const double thirdRailWidth = 58.0;

  /// The least room left between two hazards where they are built, however
  /// far apart they will have drifted by the time they arrive.
  static const double minBuiltGap = 20.0;

  /// How much ground a hazard rolling toward the courier at [approach] px/s
  /// makes up on the hazard ahead of it, which ends [aheadEndOffset] px into
  /// the chunk and rolls at [aheadApproach], by the time that one reaches
  /// the courier. Negative when the one ahead is the faster: they drift
  /// apart.
  double closingDistance({
    required double aheadEndOffset,
    required double speed,
    required double approach,
    double aheadApproach = 0.0,
  }) {
    final seconds =
        (chunkSpawnLead + aheadEndOffset) / (math.max(speed, baseSpeed) + aheadApproach);
    return seconds > 0 ? (approach - aheadApproach) * seconds : 0.0;
  }

  /// The nearest and the furthest a station's third rail stands from the
  /// start of its chunk.
  static const double stationRailEarliest = 220.0;
  static const double stationRailLatest = 300.0;

  /// How far behind the start of the third rail the subway train is built,
  /// for a rail [railOffset] px into its chunk on a street moving at [speed].
  ///
  /// When the courier has just passed the rail, the train is still the usual
  /// clearance away, measured at the speed the two are closing.
  double subwayTrainSetback({required double railOffset, required double speed}) {
    final street = math.max(speed, baseSpeed);
    final approach = ObstacleComponent.defaultRelativeVelocityForType(ObstacleType.subwayTrain);
    final secondsUntilRailIsPassed = (chunkSpawnLead + railOffset + thirdRailWidth) / street;
    return thirdRailWidth +
        calculateMinClearance(street + approach) +
        approach * secondsUntilRailIsPassed;
  }

  double _lastObstacleEndX = -9999.0;

  /// The hazard [_lastObstacleEndX] belongs to, or null when the last thing
  /// built was a street piece that is not a hazard.
  ObstacleType? _lastHazardType;

  /// How high the top of that street piece is, when it was one.
  double _lastPieceHeight = 0.0;

  /// Where the previous chunk ended, in the coordinates it was generated in.
  double? _lastChunkEndX;

  /// Resets the generator state for a new run.
  void reset() {
    _lastObstacleEndX = -9999.0;
    _lastHazardType = null;
    _lastPieceHeight = 0.0;
    _lastChunkEndX = null;
  }

  /// Procedurally generates a slice of world terrain of [chunkWidth] pixels starting at [startX].
  ChunkData generateChunk({
    required double startX,
    double chunkWidth = 960.0,
    required double speed,
    double groundY = 460.0,
    double distanceMeters = 0.0,
    bool isVipActive = false,
    bool heavySkateTraffic = false,
  }) {
    final obstacles = <ObstacleData>[];
    final pickups = <PickupData>[];
    final scaffoldings = <ScaffoldingData>[];
    final ramps = <RampData>[];
    final grindRails = <GrindRailData>[];
    final steamVents = <SteamVentData>[];
    final solarPanels = <SolarPanelData>[];
    final windTunnels = <HvacWindTunnelData>[];

    // Carry the previous hazard's position into this chunk's coordinates.
    // The game spawns every chunk at about the same screen x, because the
    // street has scrolled a chunk's width since the last one. Without this
    // shift the remembered position sat a full chunk too far right, the
    // clearance check found "no room", and most chunks got no hazard at all.
    // Callers that pass ever-growing world x are unaffected: the shift is 0.
    final previousChunkEnd = _lastChunkEndX;
    if (previousChunkEnd != null) {
      _lastObstacleEndX += startX - previousChunkEnd;
    }
    _lastChunkEndX = startX + chunkWidth;

    // The hazard ahead of this chunk, and where it leaves the street free
    // again, before this chunk's own hazards replace them.
    final hazardAheadOfChunk = _lastHazardType;
    final streetFreeFrom = _lastObstacleEndX;

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

          _pieceEndsAt(railX + railWidth, height: groundY - scaffoldingY);
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

          _pieceEndsAt(panelX + panelWidth, height: groundY - scaffoldingY);
          cursorX = _lastObstacleEndX + minClearance + 1.0;
        } else {
          _pieceEndsAt(scaffoldingX + scaffoldingWidth, height: groundY - scaffoldingY);
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

      _pieceEndsAt(railX + railWidth, height: groundY - railY);
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

      _hazardEndsAt(obstacleX + obsSize.x, obstacleType, speed);
      cursorX = _lastObstacleEndX + minClearance + 1.0;
    }

    // The coins laid along a solar array or a wind tunnel are the ones added
    // between these two marks. A chunk that turns out to be a subway station
    // takes the kit and its coins back out.
    final rooftopKitCoinsFrom = pickups.length;

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

      _pieceEndsAt(panelX + panelWidth, height: groundY - panelY);
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

      // The van can be leapt instead of ridden over on the wind, so the
      // street past it stays clear for that landing too.
      _hazardEndsAt(gX + gSize.x, groundType, speed);
      _lastObstacleEndX =
          math.max(_lastObstacleEndX, tunnelX + tunnelHousingWidth + tunnelWindLength);
      cursorX = _lastObstacleEndX + minClearance + 1.0;
    }
    final rooftopKitCoinsTo = pickups.length;

    // Introduce dynamic hazards (skate messenger, pigeon flock) at distance/speed milestones.
    // The warm-up stretch only serves small tap-hop hazards so new couriers
    // learn jump timing before vans and dense patterns appear.
    final bool isWarmup = distanceMeters < warmupEndMeters;
    final int maxObstaclesPerChunk = isWarmup
        ? 1
        : distanceMeters < rampEndMeters
            ? 2
            : 3;
    final availableTypes = isWarmup
        ? const [ObstacleType.scooter, ObstacleType.dog]
        : (distanceMeters >= 800.0 || speed >= 340.0)
            ? streetHazards
            : const [
                ObstacleType.scooter,
                ObstacleType.dog,
                ObstacleType.hydrant,
                ObstacleType.mailbox,
                ObstacleType.van,
              ];

    // Pick 1 to 2 obstacle placements per chunk to avoid cluttered bottlenecks
    int obstaclesPlaced = 0;
    // How fast the hazard placed before this one rolls toward the courier,
    // and the random extra spacing rolled after it (null before the first).
    var approachOfHazardAhead = 0.0;
    double? varietyAfterHazardAhead;
    while (cursorX < endX && obstaclesPlaced < maxObstaclesPerChunk) {
      final typeIndex = _random.nextInt(availableTypes.length);
      var type = availableTypes[typeIndex];
      // Skate Commute daily shift: past the warm-up, about half of all street
      // hazards are oncoming skaters, whatever the distance. The extra roll is
      // only made on such a shift, so regular generation is unchanged.
      if (heavySkateTraffic && !isWarmup && _random.nextDouble() < 0.5) {
        type = ObstacleType.skateMessenger;
      }
      final size = ObstacleComponent.defaultSizeForType(type);

      // A hazard that rolls toward the courier (the skater) changes its
      // distance from its neighbours all the way in: it makes up ground on
      // a standing hazard ahead of it and pulls away from one behind. The
      // clearance has to be there when the courier meets them, so the gap
      // built here is the clearance plus what this hazard will make up on
      // the one ahead (or less what it will lose) by the time that one
      // arrives. Measured before this: skaters arrived a median 214 px
      // behind the hazard ahead where 400 was meant, one in five under 150.
      final approach = ObstacleComponent.defaultRelativeVelocityForType(type);
      // What this hazard needs on top of the room its neighbour ahead
      // already keeps behind it: see [clearanceBetween].
      final hazardAhead = _lastHazardType;
      final leapRoom = hazardAhead == null
          ? roomAfterDrop(type, _lastPieceHeight, speed)
          : clearanceBetween(hazardAhead, type, speed) - clearanceAfter(hazardAhead, speed);
      final builtGap = math.max(
            minBuiltGap,
            minClearance +
                closingDistance(
                  aheadEndOffset: _lastObstacleEndX - startX,
                  speed: speed,
                  approach: approach,
                  aheadApproach: approachOfHazardAhead,
                ),
          ) +
          leapRoom;
      final variety = varietyAfterHazardAhead;
      final obstacleX = variety == null
          ? math.max(cursorX, _lastObstacleEndX + builtGap + 1.0)
          : _lastObstacleEndX + builtGap + variety;
      // Where this hazard will be, in today's coordinates, when it reaches
      // the courier: the reward above it is hung there, not where it starts.
      // Never before the start of the chunk, which is the only part of the
      // street sure to be off screen while it is being built.
      final meetingX = math.max(
        startX + 20.0,
        obstacleX -
            approach *
                ((chunkSpawnLead + obstacleX - startX) / (math.max(speed, baseSpeed) + approach)),
      );
      // A hazard belongs to the chunk it is met in. The room kept behind a
      // leap can put the next one past the end of this chunk, and then it
      // is the next chunk's to place.
      if (meetingX >= endX) break;
      approachOfHazardAhead = approach;

      final obstacleY = groundY - size.y;
      final obstacle = ObstacleData(
        type: type,
        x: obstacleX,
        y: obstacleY,
        width: size.x,
        height: size.y,
      );
      obstacles.add(obstacle);
      obstaclesPlaced++;
      _hazardEndsAt(obstacle.x + obstacle.width, type, speed);

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
          x: meetingX + size.x / 2 - 14,
          y: obstacleY - 60.0 - (_random.nextDouble() * 30.0),
        ),
      );

      // Advance cursor past obstacle + guaranteed clearance (granting extra buffer for oncoming skate messengers)
      final extraClearance = (type == ObstacleType.skateMessenger) ? 60.0 : 0.0;
      final varietyAfter = extraClearance + (_random.nextDouble() * 120.0);
      varietyAfterHazardAhead = varietyAfter;
      cursorX = _lastObstacleEndX + minClearance + varietyAfter;
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
        _random.nextDouble() < subwayStationChance &&
        scaffoldings.isEmpty &&
        grindRails.isEmpty &&
        steamVents.isEmpty &&
        dropZones.isEmpty &&
        // At speed a station needs its whole chunk to fit the train behind
        // the third rail, so the rail cannot be moved back past its usual
        // place to make room. When the hazard ahead still needs the street
        // there (a van's leap, or a hop late in the last chunk, would come
        // down on the rail), the chunk stays a street.
        (hazardAheadOfChunk == null ||
            streetFreeFrom + minClearance + 1.0 <= startX + stationRailLatest)) {
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

      // A station is the platform, the third rail and the train, and nothing
      // from the street above. A solar array could be left standing over the
      // train, its deck ten pixels lower than the train's roof.
      solarPanels.clear();
      windTunnels.clear();
      pickups.removeRange(rooftopKitCoinsFrom, rooftopKitCoinsTo);

      // In a subway station, spawn authentic subterranean hazards:
      // An electrified third rail on track
      obstacles.clear();
      // The rail stands 220 to 300 px into the station, and no nearer the
      // hazard ahead than any two hazards stand.
      final railFrom = hazardAheadOfChunk == null
          ? stationRailEarliest
          : math.max(stationRailEarliest, streetFreeFrom + minClearance + 1.0 - startX);
      final thirdRailX =
          startX + railFrom + (_random.nextDouble() * (stationRailLatest - railFrom));
      obstacles.add(
        ObstacleData(
          type: ObstacleType.thirdRail,
          x: thirdRailX,
          y: groundY - 24.0,
          width: 58.0,
          height: 24.0,
        ),
      );

      // And an oncoming express subway train further along the station with generous clearance.
      // "Generous" has to be judged where the courier meets them, not where
      // they are built: the train rolls toward the courier on top of the
      // street's own speed, and the 280-340 px it used to be given was gone
      // by the time the pair arrived. At 300 px/s the train was just ahead
      // of the rail, at 400 on top of it and at 550 just behind: one block
      // up to 230 px wide. It is set back by the ground it will make up
      // before the rail has gone by, plus the room any two hazards get.
      final trainX = thirdRailX +
          subwayTrainSetback(railOffset: thirdRailX - startX, speed: speed) +
          (_random.nextDouble() * 60.0);
      obstacles.add(
        ObstacleData(
          type: ObstacleType.subwayTrain,
          x: trainX,
          y: groundY - 64.0,
          width: 110.0,
          height: 64.0,
        ),
      );

      // The next chunk keeps its distance from the train, which is the last
      // hazard here now that the street's own have been cleared away. The
      // train is leapt where the courier meets it, well short of where it
      // is built.
      final trainApproach =
          ObstacleComponent.defaultRelativeVelocityForType(ObstacleType.subwayTrain);
      final trainMeetingX = trainX -
          trainApproach *
              ((chunkSpawnLead + trainX - startX) / (math.max(speed, baseSpeed) + trainApproach));
      _hazardEndsAt(trainMeetingX + 110.0, ObstacleType.subwayTrain, speed);
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

    // Street Construction Sawhorse Barricade (after the warm-up stretch, outside subway stations, food trucks, and scaffolding)
    if (distanceMeters >= warmupEndMeters &&
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

    final List<PostalMailboxData> postalMailboxes = [];

    // Street Municipal Postal Collection Mailbox (after 60m, outside subway stations, food trucks, barricades)
    if (distanceMeters >= 60.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const mailboxWidth = 42.0;
      const mailboxHeight = 54.0;
      for (var offset = 90.0; offset <= chunkWidth - 140.0; offset += 50.0) {
        final mbX = startX + offset;
        final isClear = obstacles.every(
          (o) => (mbX + mailboxWidth < o.x - 30.0) || (mbX > o.x + o.width + 30.0),
        ) && crosswalks.every(
          (cw) => (mbX + mailboxWidth < cw.x - 20.0) || (mbX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (mbX + mailboxWidth < t.x - 20.0) || (mbX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (mbX + mailboxWidth < fe.x - 20.0) || (mbX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (mbX + mailboxWidth < fts.x - 30.0) || (mbX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (mbX + mailboxWidth < b.x - 30.0) || (mbX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (mbX + mailboxWidth < sd.x - 30.0) || (mbX > sd.x + sd.width + 30.0),
        );

        if (isClear) {
          postalMailboxes.add(
            PostalMailboxData(
              x: mbX,
              y: groundY - mailboxHeight,
              width: mailboxWidth,
              height: mailboxHeight,
            ),
          );
          break;
        }
      }
    }

    final List<AcCondenserData> acCondensers = [];

    // Industrial Rooftop AC Condenser Fan Updraft (after 100m, outside subway stations, food trucks, barricades, satellite dishes, mailboxes)
    if (distanceMeters >= 100.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const condenserWidth = 72.0;
      const condenserHeight = 48.0;
      for (var offset = 100.0; offset <= chunkWidth - 160.0; offset += 50.0) {
        final acX = startX + offset;
        final isClear = obstacles.every(
          (o) => (acX + condenserWidth < o.x - 30.0) || (acX > o.x + o.width + 30.0),
        ) && crosswalks.every(
          (cw) => (acX + condenserWidth < cw.x - 20.0) || (acX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (acX + condenserWidth < t.x - 20.0) || (acX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (acX + condenserWidth < fe.x - 20.0) || (acX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (acX + condenserWidth < fts.x - 30.0) || (acX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (acX + condenserWidth < b.x - 30.0) || (acX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (acX + condenserWidth < sd.x - 30.0) || (acX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (acX + condenserWidth < mb.x - 30.0) || (acX > mb.x + mb.width + 30.0),
        );

        if (isClear) {
          acCondensers.add(
            AcCondenserData(
              x: acX,
              y: groundY - condenserHeight,
              width: condenserWidth,
              height: condenserHeight,
              updraftImpulse: 380.0,
            ),
          );
          break;
        }
      }
    }

    final List<GlassSkylightData> glassSkylights = [];

    // Elevated Rooftop Architectural Glass Skylight Dome (after 140m, outside subway stations and scaffolding)
    if (distanceMeters >= 140.0 &&
        _random.nextDouble() < 0.35 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const skylightWidth = 80.0;
      const skylightHeight = 36.0;
      for (var offset = 100.0; offset <= chunkWidth - 160.0; offset += 50.0) {
        final gsX = startX + offset;
        final isClear = obstacles.every(
          (o) => (gsX + skylightWidth < o.x - 30.0) || (gsX > o.x + o.width + 30.0),
        ) && crosswalks.every(
          (cw) => (gsX + skylightWidth < cw.x - 20.0) || (gsX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (gsX + skylightWidth < t.x - 20.0) || (gsX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (gsX + skylightWidth < fe.x - 20.0) || (gsX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (gsX + skylightWidth < fts.x - 30.0) || (gsX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (gsX + skylightWidth < b.x - 30.0) || (gsX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (gsX + skylightWidth < sd.x - 30.0) || (gsX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (gsX + skylightWidth < mb.x - 30.0) || (gsX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (gsX + skylightWidth < ac.x - 30.0) || (gsX > ac.x + ac.width + 30.0),
        );

        if (isClear) {
          glassSkylights.add(
            GlassSkylightData(
              x: gsX,
              y: groundY - skylightHeight,
              width: skylightWidth,
              height: skylightHeight,
            ),
          );
          break;
        }
      }
    }

    final List<FlowerKioskData> flowerKiosks = [];
    if (startX > 80.0 && _random.nextDouble() < 0.28) {
      const kioskWidth = 68.0;
      const kioskHeight = 58.0;
      for (var attempt = 0; attempt < 8; attempt++) {
        final fkX = startX + 120.0 + _random.nextDouble() * (chunkWidth - 260.0);
        final isClear = obstacles.every(
          (o) => (fkX + kioskWidth < o.x - 30.0) || (fkX > o.x + o.width + 30.0),
        ) && foodCarts.every(
          (fc) => (fkX + kioskWidth < fc.x - 30.0) || (fkX > fc.x + fc.width + 30.0),
        ) && subwayStations.every(
          (s) => (fkX + kioskWidth < s.x - 30.0) || (fkX > s.x + s.width + 30.0),
        ) && crosswalks.every(
          (cw) => (fkX + kioskWidth < cw.x - 20.0) || (fkX > cw.x + cw.width + 20.0),
        ) && stormDrains.every(
          (sd) => (fkX + kioskWidth < sd.x - 20.0) || (fkX > sd.x + sd.width + 20.0),
        ) && solarPanels.every(
          (sp) => (fkX + kioskWidth < sp.x - 20.0) || (fkX > sp.x + sp.width + 20.0),
        ) && puddles.every(
          (p) => (fkX + kioskWidth < p.x - 20.0) || (fkX > p.x + p.width + 20.0),
        ) && windTunnels.every(
          (wt) => (fkX + kioskWidth < wt.x - 20.0) || (fkX > wt.x + wt.housingWidth + 20.0),
        ) && turnstiles.every(
          (t) => (fkX + kioskWidth < t.x - 20.0) || (fkX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (fkX + kioskWidth < fe.x - 20.0) || (fkX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (fkX + kioskWidth < fts.x - 30.0) || (fkX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (fkX + kioskWidth < b.x - 30.0) || (fkX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (fkX + kioskWidth < sd.x - 30.0) || (fkX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (fkX + kioskWidth < mb.x - 30.0) || (fkX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (fkX + kioskWidth < ac.x - 30.0) || (fkX > ac.x + ac.width + 30.0),
        ) && glassSkylights.every(
          (gs) => (fkX + kioskWidth < gs.x - 30.0) || (fkX > gs.x + gs.width + 30.0),
        );

        if (isClear) {
          flowerKiosks.add(
            FlowerKioskData(
              x: fkX,
              y: groundY - kioskHeight,
              width: kioskWidth,
              height: kioskHeight,
            ),
          );
          break;
        }
      }
    }

    final List<WaterTowerData> waterTowers = [];
    if (distanceMeters >= 120.0 &&
        _random.nextDouble() < 0.26 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const towerWidth = 86.0;
      const towerHeight = 110.0;
      for (var offset = 140.0; offset <= chunkWidth - 220.0; offset += 60.0) {
        final wtX = startX + offset;
        final isClear = obstacles.every(
          (o) => (wtX + towerWidth < o.x - 30.0) || (wtX > o.x + o.width + 30.0),
        ) && foodCarts.every(
          (fc) => (wtX + towerWidth < fc.x - 30.0) || (wtX > fc.x + fc.width + 30.0),
        ) && crosswalks.every(
          (cw) => (wtX + towerWidth < cw.x - 20.0) || (wtX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (wtX + towerWidth < t.x - 20.0) || (wtX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (wtX + towerWidth < fe.x - 20.0) || (wtX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (wtX + towerWidth < fts.x - 30.0) || (wtX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (wtX + towerWidth < b.x - 30.0) || (wtX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (wtX + towerWidth < sd.x - 30.0) || (wtX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (wtX + towerWidth < mb.x - 30.0) || (wtX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (wtX + towerWidth < ac.x - 30.0) || (wtX > ac.x + ac.width + 30.0),
        ) && glassSkylights.every(
          (gs) => (wtX + towerWidth < gs.x - 30.0) || (wtX > gs.x + gs.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (wtX + towerWidth < fk.x - 30.0) || (wtX > fk.x + fk.width + 30.0),
        );

        if (isClear) {
          waterTowers.add(
            WaterTowerData(
              x: wtX,
              y: groundY - towerHeight,
              width: towerWidth,
              height: towerHeight,
            ),
          );
          break;
        }
      }
    }

    final List<NewsstandData> newsstands = [];
    if (distanceMeters >= 90.0 &&
        _random.nextDouble() < 0.28 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const standWidth = 80.0;
      const standHeight = 62.0;
      for (var offset = 120.0; offset <= chunkWidth - 200.0; offset += 55.0) {
        final nsX = startX + offset;
        final isClear = obstacles.every(
          (o) => (nsX + standWidth < o.x - 30.0) || (nsX > o.x + o.width + 30.0),
        ) && foodCarts.every(
          (fc) => (nsX + standWidth < fc.x - 30.0) || (nsX > fc.x + fc.width + 30.0),
        ) && crosswalks.every(
          (cw) => (nsX + standWidth < cw.x - 20.0) || (nsX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (nsX + standWidth < t.x - 20.0) || (nsX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (nsX + standWidth < fe.x - 20.0) || (nsX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (nsX + standWidth < fts.x - 30.0) || (nsX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (nsX + standWidth < b.x - 30.0) || (nsX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (nsX + standWidth < sd.x - 30.0) || (nsX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (nsX + standWidth < mb.x - 30.0) || (nsX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (nsX + standWidth < ac.x - 30.0) || (nsX > ac.x + ac.width + 30.0),
        ) && glassSkylights.every(
          (gs) => (nsX + standWidth < gs.x - 30.0) || (nsX > gs.x + gs.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (nsX + standWidth < fk.x - 30.0) || (nsX > fk.x + fk.width + 30.0),
        ) && waterTowers.every(
          (wt) => (nsX + standWidth < wt.x - 30.0) || (nsX > wt.x + wt.width + 30.0),
        );

        if (isClear) {
          newsstands.add(
            NewsstandData(
              x: nsX,
              y: groundY - standHeight,
              width: standWidth,
              height: standHeight,
            ),
          );
          break;
        }
      }
    }

    final List<CafeBistroData> cafeBistros = [];
    if (distanceMeters >= 95.0 &&
        _random.nextDouble() < 0.28 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const bistroWidth = 78.0;
      const bistroHeight = 56.0;
      for (var offset = 140.0; offset <= chunkWidth - 190.0; offset += 50.0) {
        final bistroX = startX + offset;
        final isClear = obstacles.every(
          (o) => (bistroX + bistroWidth < o.x - 30.0) || (bistroX > o.x + o.width + 30.0),
        ) && foodCarts.every(
          (fc) => (bistroX + bistroWidth < fc.x - 30.0) || (bistroX > fc.x + fc.width + 30.0),
        ) && crosswalks.every(
          (cw) => (bistroX + bistroWidth < cw.x - 20.0) || (bistroX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (bistroX + bistroWidth < t.x - 20.0) || (bistroX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (bistroX + bistroWidth < fe.x - 20.0) || (bistroX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (bistroX + bistroWidth < fts.x - 30.0) || (bistroX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (bistroX + bistroWidth < b.x - 30.0) || (bistroX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (bistroX + bistroWidth < sd.x - 30.0) || (bistroX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (bistroX + bistroWidth < mb.x - 30.0) || (bistroX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (bistroX + bistroWidth < ac.x - 30.0) || (bistroX > ac.x + ac.width + 30.0),
        ) && glassSkylights.every(
          (gs) => (bistroX + bistroWidth < gs.x - 30.0) || (bistroX > gs.x + gs.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (bistroX + bistroWidth < fk.x - 30.0) || (bistroX > fk.x + fk.width + 30.0),
        ) && waterTowers.every(
          (wt) => (bistroX + bistroWidth < wt.x - 30.0) || (bistroX > wt.x + wt.width + 30.0),
        ) && newsstands.every(
          (ns) => (bistroX + bistroWidth < ns.x - 30.0) || (bistroX > ns.x + ns.width + 30.0),
        );

        if (isClear) {
          cafeBistros.add(
            CafeBistroData(
              x: bistroX,
              y: groundY - bistroHeight,
              width: bistroWidth,
              height: bistroHeight,
            ),
          );
          break;
        }
      }
    }

    final List<StreetBuskerData> streetBuskers = [];
    if (distanceMeters >= 110.0 &&
        _random.nextDouble() < 0.26 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const buskerWidth = 84.0;
      const buskerHeight = 68.0;
      for (var offset = 150.0; offset <= chunkWidth - 180.0; offset += 55.0) {
        final buskerX = startX + offset;
        final isClear = obstacles.every(
          (o) => (buskerX + buskerWidth < o.x - 30.0) || (buskerX > o.x + o.width + 30.0),
        ) && foodCarts.every(
          (fc) => (buskerX + buskerWidth < fc.x - 30.0) || (buskerX > fc.x + fc.width + 30.0),
        ) && crosswalks.every(
          (cw) => (buskerX + buskerWidth < cw.x - 20.0) || (buskerX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (buskerX + buskerWidth < t.x - 20.0) || (buskerX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (buskerX + buskerWidth < fe.x - 20.0) || (buskerX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (buskerX + buskerWidth < fts.x - 30.0) || (buskerX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (buskerX + buskerWidth < b.x - 30.0) || (buskerX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (buskerX + buskerWidth < sd.x - 30.0) || (buskerX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (buskerX + buskerWidth < mb.x - 30.0) || (buskerX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (buskerX + buskerWidth < ac.x - 30.0) || (buskerX > ac.x + ac.width + 30.0),
        ) && glassSkylights.every(
          (gs) => (buskerX + buskerWidth < gs.x - 30.0) || (buskerX > gs.x + gs.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (buskerX + buskerWidth < fk.x - 30.0) || (buskerX > fk.x + fk.width + 30.0),
        ) && waterTowers.every(
          (wt) => (buskerX + buskerWidth < wt.x - 30.0) || (buskerX > wt.x + wt.width + 30.0),
        ) && newsstands.every(
          (ns) => (buskerX + buskerWidth < ns.x - 30.0) || (buskerX > ns.x + ns.width + 30.0),
        ) && cafeBistros.every(
          (cb) => (buskerX + buskerWidth < cb.x - 30.0) || (buskerX > cb.x + cb.width + 30.0),
        );

        if (isClear) {
          streetBuskers.add(
            StreetBuskerData(
              x: buskerX,
              y: groundY - buskerHeight,
              width: buskerWidth,
              height: buskerHeight,
            ),
          );
          break;
        }
      }
    }

    final List<FireHydrantData> fireHydrants = [];
    if (distanceMeters >= 85.0 &&
        _random.nextDouble() < 0.28 &&
        subwayStations.isEmpty &&
        scaffoldings.isEmpty) {
      const hydrantWidth = 86.0;
      const hydrantHeight = 54.0;
      for (var offset = 130.0; offset <= chunkWidth - 190.0; offset += 50.0) {
        final hydX = startX + offset;
        final isClear = obstacles.every(
          (o) => (hydX + hydrantWidth < o.x - 30.0) || (hydX > o.x + o.width + 30.0),
        ) && foodCarts.every(
          (fc) => (hydX + hydrantWidth < fc.x - 30.0) || (hydX > fc.x + fc.width + 30.0),
        ) && crosswalks.every(
          (cw) => (hydX + hydrantWidth < cw.x - 20.0) || (hydX > cw.x + cw.width + 20.0),
        ) && turnstiles.every(
          (t) => (hydX + hydrantWidth < t.x - 20.0) || (hydX > t.x + t.width + 20.0),
        ) && fireEscapes.every(
          (fe) => (hydX + hydrantWidth < fe.x - 20.0) || (hydX > fe.x + fe.width + 20.0),
        ) && foodTruckSlicks.every(
          (fts) => (hydX + hydrantWidth < fts.x - 30.0) || (hydX > fts.x + fts.width + 30.0),
        ) && barricades.every(
          (b) => (hydX + hydrantWidth < b.x - 30.0) || (hydX > b.x + b.width + 30.0),
        ) && satelliteDishes.every(
          (sd) => (hydX + hydrantWidth < sd.x - 30.0) || (hydX > sd.x + sd.width + 30.0),
        ) && postalMailboxes.every(
          (mb) => (hydX + hydrantWidth < mb.x - 30.0) || (hydX > mb.x + mb.width + 30.0),
        ) && acCondensers.every(
          (ac) => (hydX + hydrantWidth < ac.x - 30.0) || (hydX > ac.x + ac.width + 30.0),
        ) && glassSkylights.every(
          (gs) => (hydX + hydrantWidth < gs.x - 30.0) || (hydX > gs.x + gs.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (hydX + hydrantWidth < fk.x - 30.0) || (hydX > fk.x + fk.width + 30.0),
        ) && waterTowers.every(
          (wt) => (hydX + hydrantWidth < wt.x - 30.0) || (hydX > wt.x + wt.width + 30.0),
        ) && newsstands.every(
          (ns) => (hydX + hydrantWidth < ns.x - 30.0) || (hydX > ns.x + ns.width + 30.0),
        ) && cafeBistros.every(
          (cb) => (hydX + hydrantWidth < cb.x - 30.0) || (hydX > cb.x + cb.width + 30.0),
        ) && streetBuskers.every(
          (sb) => (hydX + hydrantWidth < sb.x - 30.0) || (hydX > sb.x + sb.width + 30.0),
        );

        if (isClear) {
          fireHydrants.add(
            FireHydrantData(
              x: hydX,
              y: groundY - hydrantHeight,
              width: hydrantWidth,
              height: hydrantHeight,
            ),
          );
          break;
        }
      }
    }

    final List<ClotheslineData> clotheslines = [];
    if (distanceMeters >= 75.0 && _random.nextDouble() < 0.32 && subwayStations.isEmpty) {
      const clotheslineWidth = 96.0;
      const clotheslineHeight = 48.0;

      // Try placing on rooftop scaffolding first if available
      var placedOnScaffolding = false;
      for (final s in scaffoldings) {
        if (s.width >= 180.0) {
          final clX = s.x + 30.0 + _random.nextDouble() * (s.width - clotheslineWidth - 60.0);
          final clY = s.y - clotheslineHeight;
          clotheslines.add(
            ClotheslineData(
              x: clX,
              y: clY,
              width: clotheslineWidth,
              height: clotheslineHeight,
              roofY: s.y,
            ),
          );
          placedOnScaffolding = true;
          break;
        }
      }

      // If not placed on scaffolding, attempt ground level placement with clearance checks
      if (!placedOnScaffolding) {
        for (var attempt = 0; attempt < 8; attempt++) {
          final clX = startX + 80.0 + _random.nextDouble() * (chunkWidth - 240.0);
          final isClear = obstacles.every(
            (o) => (clX + clotheslineWidth < o.x - 30.0) || (clX > o.x + o.width + 30.0),
          ) && flowerKiosks.every(
            (fk) => (clX + clotheslineWidth < fk.x - 30.0) || (clX > fk.x + fk.width + 30.0),
          ) && waterTowers.every(
            (wt) => (clX + clotheslineWidth < wt.x - 30.0) || (clX > wt.x + wt.width + 30.0),
          ) && newsstands.every(
            (ns) => (clX + clotheslineWidth < ns.x - 30.0) || (clX > ns.x + ns.width + 30.0),
          ) && cafeBistros.every(
            (cb) => (clX + clotheslineWidth < cb.x - 30.0) || (clX > cb.x + cb.width + 30.0),
          ) && streetBuskers.every(
            (sb) => (clX + clotheslineWidth < sb.x - 30.0) || (clX > sb.x + sb.width + 30.0),
          ) && fireHydrants.every(
            (fh) => (clX + clotheslineWidth < fh.x - 30.0) || (clX > fh.x + fh.width + 30.0),
          );

          if (isClear) {
            clotheslines.add(
              ClotheslineData(
                x: clX,
                y: groundY - clotheslineHeight,
                width: clotheslineWidth,
                height: clotheslineHeight,
                roofY: groundY,
              ),
            );
            break;
          }
        }
      }
    }

    final List<SubwayExhaustGrateData> subwayExhaustGrates = [];
    if (distanceMeters >= 80.0 && _random.nextDouble() < 0.28 && subwayStations.isEmpty) {
      const grateWidth = 88.0;
      const grateHeight = 14.0;

      for (var attempt = 0; attempt < 8; attempt++) {
        final grX = startX + 80.0 + _random.nextDouble() * (chunkWidth - 220.0);
        final isClear = obstacles.every(
          (o) => (grX + grateWidth < o.x - 30.0) || (grX > o.x + o.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (grX + grateWidth < fk.x - 30.0) || (grX > fk.x + fk.width + 30.0),
        ) && waterTowers.every(
          (wt) => (grX + grateWidth < wt.x - 30.0) || (grX > wt.x + wt.width + 30.0),
        ) && newsstands.every(
          (ns) => (grX + grateWidth < ns.x - 30.0) || (grX > ns.x + ns.width + 30.0),
        ) && cafeBistros.every(
          (cb) => (grX + grateWidth < cb.x - 30.0) || (grX > cb.x + cb.width + 30.0),
        ) && streetBuskers.every(
          (sb) => (grX + grateWidth < sb.x - 30.0) || (grX > sb.x + sb.width + 30.0),
        ) && fireHydrants.every(
          (fh) => (grX + grateWidth < fh.x - 30.0) || (grX > fh.x + fh.width + 30.0),
        ) && clotheslines.every(
          (cl) => (grX + grateWidth < cl.x - 30.0) || (grX > cl.x + cl.width + 30.0),
        );

        if (isClear) {
          subwayExhaustGrates.add(
            SubwayExhaustGrateData(
              x: grX,
              y: groundY - grateHeight,
              width: grateWidth,
              height: grateHeight,
            ),
          );
          break;
        }
      }
    }

    final List<CatenaryZiplineData> catenaryZiplines = [];
    if (distanceMeters >= 120.0 && _random.nextDouble() < 0.28 && subwayStations.isEmpty) {
      const zipSpan = 240.0;
      const zipDrop = 24.0;

      for (var attempt = 0; attempt < 8; attempt++) {
        final zX = startX + 60.0 + _random.nextDouble() * (chunkWidth - 360.0);
        final zY = 200.0 + _random.nextDouble() * 40.0;

        final isClear = craneSwings.every(
          (c) => (zX + zipSpan < c.x - 40.0) || (zX > c.x + 260.0 + 40.0),
        );

        if (isClear) {
          catenaryZiplines.add(
            CatenaryZiplineData(
              x: zX,
              y: zY,
              spanWidth: zipSpan,
              cableDrop: zipDrop,
              groundY: groundY,
            ),
          );
          break;
        }
      }
    }

    final List<BusShelterData> busShelters = [];
    if (distanceMeters >= 75.0 && _random.nextDouble() < 0.28 && subwayStations.isEmpty) {
      const shelterWidth = 96.0;
      const shelterHeight = 54.0;

      for (var attempt = 0; attempt < 8; attempt++) {
        final bsX = startX + 80.0 + _random.nextDouble() * (chunkWidth - 240.0);
        final isClear = obstacles.every(
          (o) => (bsX + shelterWidth < o.x - 30.0) || (bsX > o.x + o.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (bsX + shelterWidth < fk.x - 30.0) || (bsX > fk.x + fk.width + 30.0),
        ) && newsstands.every(
          (ns) => (bsX + shelterWidth < ns.x - 30.0) || (bsX > ns.x + ns.width + 30.0),
        ) && cafeBistros.every(
          (cb) => (bsX + shelterWidth < cb.x - 30.0) || (bsX > cb.x + cb.width + 30.0),
        ) && streetBuskers.every(
          (sb) => (bsX + shelterWidth < sb.x - 30.0) || (bsX > sb.x + sb.width + 30.0),
        ) && fireHydrants.every(
          (fh) => (bsX + shelterWidth < fh.x - 30.0) || (bsX > fh.x + fh.width + 30.0),
        ) && subwayExhaustGrates.every(
          (seg) => (bsX + shelterWidth < seg.x - 30.0) || (bsX > seg.x + seg.width + 30.0),
        );

        if (isClear) {
          busShelters.add(
            BusShelterData(
              x: bsX,
              y: groundY - shelterHeight,
              width: shelterWidth,
              height: shelterHeight,
              groundY: groundY,
            ),
          );
          break;
        }
      }
    }

    final List<SecurityShutterData> securityShutters = [];
    if (distanceMeters >= 90.0 && _random.nextDouble() < 0.26 && subwayStations.isEmpty) {
      const shutterWidth = 48.0;
      const shutterHeight = 80.0;

      for (var attempt = 0; attempt < 8; attempt++) {
        final sX = startX + 70.0 + _random.nextDouble() * (chunkWidth - 200.0);
        final isClear = obstacles.every(
          (o) => (sX + shutterWidth < o.x - 30.0) || (sX > o.x + o.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (sX + shutterWidth < fk.x - 30.0) || (sX > fk.x + fk.width + 30.0),
        ) && newsstands.every(
          (ns) => (sX + shutterWidth < ns.x - 30.0) || (sX > ns.x + ns.width + 30.0),
        ) && cafeBistros.every(
          (cb) => (sX + shutterWidth < cb.x - 30.0) || (sX > cb.x + cb.width + 30.0),
        ) && streetBuskers.every(
          (sb) => (sX + shutterWidth < sb.x - 30.0) || (sX > sb.x + sb.width + 30.0),
        ) && fireHydrants.every(
          (fh) => (sX + shutterWidth < fh.x - 30.0) || (sX > fh.x + fh.width + 30.0),
        ) && subwayExhaustGrates.every(
          (seg) => (sX + shutterWidth < seg.x - 30.0) || (sX > seg.x + seg.width + 30.0),
        ) && busShelters.every(
          (bs) => (sX + shutterWidth < bs.x - 30.0) || (sX > bs.x + bs.width + 30.0),
        );

        if (isClear) {
          securityShutters.add(
            SecurityShutterData(
              x: sX,
              y: groundY - shutterHeight,
              width: shutterWidth,
              height: shutterHeight,
              groundY: groundY,
            ),
          );
          break;
        }
      }
    }

    final List<CementMixerData> cementMixers = [];
    if (distanceMeters >= 85.0 && _random.nextDouble() < 0.25 && subwayStations.isEmpty) {
      const mixerWidth = 64.0;
      const mixerHeight = 56.0;

      for (var attempt = 0; attempt < 8; attempt++) {
        final mX = startX + 75.0 + _random.nextDouble() * (chunkWidth - 210.0);
        final isClear = obstacles.every(
          (o) => (mX + mixerWidth < o.x - 30.0) || (mX > o.x + o.width + 30.0),
        ) && flowerKiosks.every(
          (fk) => (mX + mixerWidth < fk.x - 30.0) || (mX > fk.x + fk.width + 30.0),
        ) && newsstands.every(
          (ns) => (mX + mixerWidth < ns.x - 30.0) || (mX > ns.x + ns.width + 30.0),
        ) && cafeBistros.every(
          (cb) => (mX + mixerWidth < cb.x - 30.0) || (mX > cb.x + cb.width + 30.0),
        ) && streetBuskers.every(
          (sb) => (mX + mixerWidth < sb.x - 30.0) || (mX > sb.x + sb.width + 30.0),
        ) && fireHydrants.every(
          (fh) => (mX + mixerWidth < fh.x - 30.0) || (mX > fh.x + fh.width + 30.0),
        ) && subwayExhaustGrates.every(
          (seg) => (mX + mixerWidth < seg.x - 30.0) || (mX > seg.x + seg.width + 30.0),
        ) && busShelters.every(
          (bs) => (mX + mixerWidth < bs.x - 30.0) || (mX > bs.x + bs.width + 30.0),
        ) && securityShutters.every(
          (ss) => (mX + mixerWidth < ss.x - 30.0) || (mX > ss.x + ss.width + 30.0),
        );

        if (isClear) {
          cementMixers.add(
            CementMixerData(
              x: mX,
              y: groundY - mixerHeight,
              width: mixerWidth,
              height: mixerHeight,
              groundY: groundY,
            ),
          );
          break;
        }
      }
    }

    // Thin out optional street set pieces that would be drawn on top of each
    // other or on a hazard. Puddles (a ground decal), cyclists (they ride
    // through) and crane masts (background structure) may share space.
    // Features are listed rarest first: the rare ones claim their spot and the
    // thinning falls on the features the street already shows most often.
    StreetPiece street(double x, double y, double width, double height, [void Function()? remove]) =>
        StreetPiece(x: x, width: width, baseY: y + height, remove: remove);
    declutterStreet(
      groundY: groundY,
      anchors: [
        for (final p in obstacles) street(p.x, p.y, p.width, p.height),
        for (final p in dropZones) street(p.x, p.y, p.width, p.height),
        for (final p in turnstiles) street(p.x, p.y, p.width, p.height),
        for (final p in ramps) street(p.x, p.y, p.width, p.height),
        for (final p in scaffoldings) street(p.x, p.y, p.width, p.height),
        for (final p in grindRails) street(p.x, p.y, p.width, p.height),
      ],
      optionalByPriority: [
        for (final p in streetBuskers.toList()) street(p.x, p.y, p.width, p.height, () => streetBuskers.remove(p)),
        for (final p in fireHydrants.toList()) street(p.x, p.y, p.width, p.height, () => fireHydrants.remove(p)),
        for (final p in cafeBistros.toList()) street(p.x, p.y, p.width, p.height, () => cafeBistros.remove(p)),
        for (final p in newsstands.toList()) street(p.x, p.y, p.width, p.height, () => newsstands.remove(p)),
        for (final p in waterTowers.toList()) street(p.x, p.y, p.width, p.height, () => waterTowers.remove(p)),
        for (final p in stormDrains.toList()) street(p.x, p.y, p.width, p.height, () => stormDrains.remove(p)),
        for (final p in steamVents.toList()) street(p.x, p.y, p.width, p.height, () => steamVents.remove(p)),
        for (final p in solarPanels.toList()) street(p.x, p.y, p.width, p.height, () => solarPanels.remove(p)),
        for (final p in foodCarts.toList()) street(p.x, p.y, p.width, p.height, () => foodCarts.remove(p)),
        for (final p in foodTruckSlicks.toList()) street(p.x, p.y, p.width, p.height, () => foodTruckSlicks.remove(p)),
        for (final p in glassSkylights.toList()) street(p.x, p.y, p.width, p.height, () => glassSkylights.remove(p)),
        for (final p in fireEscapes.toList()) street(p.x, p.y, p.width, p.height, () => fireEscapes.remove(p)),
        for (final p in acCondensers.toList()) street(p.x, p.y, p.width, p.height, () => acCondensers.remove(p)),
        for (final p in flowerKiosks.toList()) street(p.x, p.y, p.width, p.height, () => flowerKiosks.remove(p)),
        for (final p in barricades.toList()) street(p.x, p.y, p.width, p.height, () => barricades.remove(p)),
        for (final p in postalMailboxes.toList()) street(p.x, p.y, p.width, p.height, () => postalMailboxes.remove(p)),
        for (final p in droneCargos.toList()) street(p.x, p.y, p.width, p.height, () => droneCargos.remove(p)),
        for (final p in securityShutters.toList()) street(p.x, p.y, p.width, p.height, () => securityShutters.remove(p)),
        for (final p in cementMixers.toList()) street(p.x, p.y, p.width, p.height, () => cementMixers.remove(p)),
        for (final p in busShelters.toList()) street(p.x, p.y, p.width, p.height, () => busShelters.remove(p)),
        for (final p in subwayExhaustGrates.toList()) street(p.x, p.y, p.width, p.height, () => subwayExhaustGrates.remove(p)),
        for (final p in satelliteDishes.toList()) street(p.x, p.y, p.width, p.height, () => satelliteDishes.remove(p)),
        for (final p in clotheslines.toList()) street(p.x, p.y, p.width, p.height, () => clotheslines.remove(p)),
      ],
    );

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
      postalMailboxes: postalMailboxes,
      acCondensers: acCondensers,
      glassSkylights: glassSkylights,
      flowerKiosks: flowerKiosks,
      waterTowers: waterTowers,
      newsstands: newsstands,
      cafeBistros: cafeBistros,
      streetBuskers: streetBuskers,
      fireHydrants: fireHydrants,
      clotheslines: clotheslines,
      subwayExhaustGrates: subwayExhaustGrates,
      catenaryZiplines: catenaryZiplines,
      busShelters: busShelters,
      securityShutters: securityShutters,
      cementMixers: cementMixers,
    );
  }
}
