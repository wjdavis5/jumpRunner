import 'package:flutter/foundation.dart';

import '../components/obstacle_component.dart';
import '../models/daily_shift.dart';
import '../models/run_booster.dart';
import '../models/shift_contract.dart';
import 'contract_manager.dart';

/// Status of the current run lifecycle.
enum GameStatus {
  idle,
  running,
  paused,
  gameOver,
}

/// Event dispatched when the courier reaches a 500-meter shift milestone.
class MilestoneEvent {
  const MilestoneEvent({
    required this.milestoneIndex,
    required this.distanceMeters,
    required this.restoredPackage,
    required this.bonusTips,
  });

  /// 1 for 500m, 2 for 1000m, 3 for 1500m, etc.
  final int milestoneIndex;

  /// Absolute distance in meters when this milestone fired.
  final double distanceMeters;

  /// True if a lost package was restored to the courier's bag.
  final bool restoredPackage;

  /// Dollar bonus awarded if courier already carried full 3 packages ($50).
  final int bonusTips;
}

/// Stunt event dispatched when pulling off a tight near-miss leap over an obstacle.
class StuntEvent {
  const StuntEvent({
    required this.streak,
    required this.multiplier,
    required this.bonusTips,
    required this.clearance,
  });

  /// Consecutive near-miss stunts completed without collision.
  final int streak;

  /// Current active stunt combo multiplier (e.g. 1.2x, 1.5x, 2.0x, 2.5x).
  final double multiplier;

  /// Bonus tips awarded for this stunt leap.
  final int bonusTips;

  /// Clearance margin in virtual pixels between courier and obstacle top.
  final double clearance;
}

/// Delivery event dispatched when successfully fulfilling a customer doorstep drop-off.
class DeliveryEvent {
  const DeliveryEvent({
    required this.ratingStars,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
    required this.multiplier,
    required this.didRestockPackage,
  });

  /// Customer rating stars awarded based on cargo condition (3 to 5 stars).
  final int ratingStars;

  /// Base tip value before streak or buff multipliers ($15, $25, or $35).
  final int baseTips;

  /// Total tip amount awarded after all active multipliers.
  final int totalTips;

  /// Current consecutive delivery streak count.
  final int streak;

  /// Active delivery streak multiplier (1.0x to 2.5x).
  final double multiplier;

  /// Whether a 3x streak successfully restored a lost package.
  final bool didRestockPackage;
}

/// Rail Ollie event dispatched when leaping off a grind rail into an aerial trick combo.
class RailOllieEvent {
  const RailOllieEvent({
    required this.grindDistanceMeters,
    required this.multiplier,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
  });

  /// Distance in meters traveled along the rail before the ollie pop.
  final double grindDistanceMeters;

  /// Active stunt combo multiplier applied to this ollie.
  final double multiplier;

  /// Base tips value before combo scaling ($20).
  final int baseTips;

  /// Total tips awarded for this rail ollie.
  final int totalTips;

  /// Current consecutive stunt streak count.
  final int streak;
}

/// Rail clear event dispatched when grinding across a rail to its trailing edge.
class RailClearEvent {
  const RailClearEvent({
    required this.grindDistanceMeters,
    required this.bonusTips,
  });

  /// Distance in meters traveled across the complete rail.
  final double grindDistanceMeters;

  /// Bonus tips awarded for completing the rail grind.
  final int bonusTips;
}

/// Vault event dispatched when executing an agile parkour vault over a low obstacle.
class VaultEvent {
  const VaultEvent({
    required this.obstacleType,
    required this.multiplier,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
  });

  /// Type of low obstacle vaulted (hydrant, mailbox, scooter).
  final ObstacleType obstacleType;

  /// Active stunt combo multiplier applied to this vault.
  final double multiplier;

  /// Base tips value ($15).
  final int baseTips;

  /// Total tips awarded for this vault after multipliers.
  final int totalTips;

  /// Current consecutive stunt streak count.
  final int streak;
}

/// Event dispatched when a courier catches a rising steam vent thermal updraft.
class SteamVentEvent {
  const SteamVentEvent({
    required this.multiplier,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
  });

  /// Active stunt combo multiplier applied to this boost.
  final double multiplier;

  /// Base tips value ($20).
  final int baseTips;

  /// Total tips awarded after multipliers.
  final int totalTips;

  /// Current consecutive stunt streak count.
  final int streak;
}

/// Event dispatched when completing a sustained aerodynamic glide traversal.
class GlideEvent {
  const GlideEvent({
    required this.glideDistanceMeters,
    required this.multiplier,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
  });

  /// Distance in meters traveled during the glide session.
  final double glideDistanceMeters;

  /// Active stunt combo multiplier applied to this glide.
  final double multiplier;

  /// Base tips value calculated from distance.
  final int baseTips;

  /// Total tips awarded after multipliers.
  final int totalTips;

  /// Current consecutive stunt streak count.
  final int streak;
}

/// Event dispatched when traversing a subterranean subway tunnel station.
class SubwayTransitEvent {
  const SubwayTransitEvent({
    required this.stationName,
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
  });

  /// Name of the subterranean transit station (e.g. "8th Ave Express").
  final String stationName;

  /// Base tip value before combo multipliers ($25).
  final int baseTips;

  /// Total tip amount awarded after all active multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this transit.
  final double multiplier;
}

/// Event dispatched when catapulting off an industrial construction crane swing cable.
class CraneSwingEvent {
  const CraneSwingEvent({
    required this.swingAngle,
    required this.multiplier,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
  });

  /// Deflection angle in radians at moment of release.
  final double swingAngle;

  /// Active stunt combo multiplier applied to this launch.
  final double multiplier;

  /// Base tips awarded for crane swing traversal ($35).
  final int baseTips;

  /// Total tips awarded after combo multipliers.
  final int totalTips;

  /// Current consecutive stunt streak count.
  final int streak;
}

/// Event dispatched when successfully fulfilling a VIP high-priority express delivery.
class VipDeliveryEvent {
  const VipDeliveryEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.remainingTimeSeconds,
    required this.stuntStreak,
  });

  /// Base tip value before surge and combo scaling ($60).
  final int baseTips;

  /// Total tip amount awarded after all active multipliers.
  final int totalTips;

  /// Surge multiplier applied (e.g. 3.0x base * stunt combo).
  final double multiplier;

  /// Remaining seconds on the VIP countdown when fulfilled.
  final double remainingTimeSeconds;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when launching an aerodynamic slingshot leap from a companion cyclist draft wake.
class DraftSlingshotEvent {
  const DraftSlingshotEvent({
    required this.multiplier,
    required this.baseTips,
    required this.totalTips,
    required this.streak,
  });

  /// Active stunt combo multiplier applied to this slingshot.
  final double multiplier;

  /// Base tips awarded for the slingshot ($30).
  final int baseTips;

  /// Total tips awarded after combo scaling.
  final int totalTips;

  /// Current consecutive stunt streak count.
  final int streak;
}

/// Event dispatched when leaping through a scattering pigeon flock mid-air.
class FlockScatterEvent {
  const FlockScatterEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($25).
  final int baseTips;

  /// Total tip amount awarded after active stunt combo multiplier.
  final int totalTips;

  /// Active stunt combo multiplier applied to this scatter.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when high-fiving a waiting pedestrian at a street crosswalk.
class HighFiveEvent {
  const HighFiveEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($20).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this high five.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when bouncing atop a street food cart's striped canvas umbrella cushion.
class FoodCartBounceEvent {
  const FoodCartBounceEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($25).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this bounce.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when a street storm drain vault grate erupts with steam and coins.
class StormDrainEvent {
  const StormDrainEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
    this.coinsSpawned = 3,
  });

  /// Base tip value before stunt combo scaling ($30).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;

  /// Number of golden coins erupted into the sky.
  final int coinsSpawned;
}

/// Event dispatched when completing a rooftop solar panel skate slide with an electric EMP surge.
class SolarSurgeEvent {
  const SolarSurgeEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
    this.coinsHarvested = 0,
  });

  /// Base tip value before stunt combo scaling ($35).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;

  /// Number of nearby coins vacuumed directly by the EMP shockwave.
  final int coinsHarvested;
}

/// Event dispatched when cleanly skimming or leaping over an urban sidewalk puddle.
class PuddleSkimEvent {
  const PuddleSkimEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($20).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when riding an industrial HVAC exhaust wind tunnel slipstream hover glide.
class WindTunnelGlideEvent {
  const WindTunnelGlideEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($25).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when validating a transit swipe or vaulting a street subway turnstile.
class TurnstileEvent {
  const TurnstileEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
    required this.isVault,
  });

  /// Base tip value before stunt combo scaling ($20 for swipe, $25 for vault).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;

  /// True if executed via hurdle vault; false if sprint card swipe.
  final bool isVault;
}

/// Event dispatched when intercepting an aerial cargo drone container mid-jump.
class DroneCatchEvent {
  const DroneCatchEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
    required this.restoredPackage,
  });

  /// Base tip value before stunt combo scaling ($35).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;

  /// Whether intercepting this cargo crate restored a lost package HP.
  final bool restoredPackage;
}

/// Event dispatched when grabbing and dropping a building facade fire escape ladder.
class FireEscapeEvent {
  const FireEscapeEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($30).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when initiating a high-speed drift slide across a street food truck grease slick.
class FoodTruckDriftEvent {
  const FoodTruckDriftEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($25).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when hurdle-vaulting over a street construction sawhorse barricade.
class BarricadeVaultEvent {
  const BarricadeVaultEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($20).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Event dispatched when launching off a rooftop parabolic satellite dish.
class SatelliteLaunchEvent {
  const SatelliteLaunchEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
    required this.launchImpulse,
  });

  /// Base tip value before stunt combo scaling ($35).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;

  /// Upward vertical impulse applied to the courier.
  final double launchImpulse;
}

/// Event dispatched when hurdle-vaulting over a street municipal postal collection mailbox.
class PostalMailboxEvent {
  const PostalMailboxEvent({
    required this.baseTips,
    required this.totalTips,
    required this.multiplier,
    required this.stuntStreak,
  });

  /// Base tip value before stunt combo scaling ($25).
  final int baseTips;

  /// Total tip amount awarded after active combo multipliers.
  final int totalTips;

  /// Active stunt combo multiplier applied to this event.
  final double multiplier;

  /// Current consecutive stunt streak count.
  final int stuntStreak;
}

/// Central state machine managing the package HP mechanism, shift milestones,
/// stunt combos, and score tracking.
///
/// Rules:
/// - Couriers start with 3 package lives.
/// - Hazards decrement 1 package life and reset active stunt combo streak.
/// - Reaching 0 packages triggers GameOver.
/// - Every 500m milestone restores 1 lost package; if already at 3 packages, awards $50 tip bonus.
/// - Near-miss jumps over hazards reward bonus tips and ramp up a stunt combo multiplier (up to 2.5x).
class GameState extends ChangeNotifier {
  GameState({ContractManager? contractManager})
      : contractManager = contractManager ?? ContractManager() {
    this.contractManager.onContractCompleted = (contract) {
      activeContractCelebration = contract;
      contractCelebrationTimer = contractBannerDuration;
      onContractCompleted?.call(contract);
      notifyListeners();
    };
  }

  static const int defaultMaxPackages = 3;
  static const double milestoneIntervalMeters = 500.0;
  static const int milestoneBonusTips = 50;

  static const double defaultEnergyDrinkDuration = 5.0;
  static const double defaultDroneDuration = 8.0;
  static const double milestoneBannerDuration = 3.0;
  static const double contractBannerDuration = 3.0;
  static const double stuntComboDuration = 4.0;
  static const int baseStuntTip = 5;

  final ContractManager contractManager;
  int damageTakenCount = 0;

  /// Active Daily Gig Shift challenge for this run, if started in Daily Shift mode.
  DailyShift? activeDailyShift;
  bool get isDailyShiftActive => activeDailyShift != null;
  bool hasCompletedDailyShiftInRun = false;

  /// Active single-run consumables equipped for this shift.
  Set<RunBooster> activeBoosters = const {};

  /// True if courier has a reinforced satchel equipped for +1 package capacity.
  bool get hasReinforcedSatchel => activeBoosters.contains(RunBooster.satchel);

  int get maxPackages => (activeDailyShift?.modifier == DailyModifier.fragileFreight)
      ? 1
      : (hasReinforcedSatchel ? 4 : defaultMaxPackages);

  int packages = defaultMaxPackages;
  int tips = 0;
  double distanceMeters = 0.0;
  GameStatus status = GameStatus.idle;

  /// Remaining duration in seconds for the Cold Brew Energy Drink buff.
  double energyDrinkTimer = 0.0;

  /// Returns true if the courier is currently energized by an energy drink.
  bool get isEnergyBoostActive => energyDrinkTimer > 0;

  /// Remaining duration in seconds for the Companion Delivery Drone buff.
  double droneTimer = 0.0;

  /// Returns true if the Companion Delivery Drone is currently active and assisting.
  bool get isDroneActive => droneTimer > 0;

  /// The active milestone event being celebrated by the UI banner.
  MilestoneEvent? activeMilestone;

  /// Remaining display duration in seconds for the shift milestone celebration banner.
  double milestoneBannerTimer = 0.0;

  /// True when the milestone celebration banner should be displayed.
  bool get isMilestoneBannerVisible => activeMilestone != null && milestoneBannerTimer > 0;

  /// The active completed contract being celebrated by the UI banner.
  ShiftContract? activeContractCelebration;

  /// Remaining display duration in seconds for the contract celebration banner.
  double contractCelebrationTimer = 0.0;

  /// True when the contract celebration banner should be displayed.
  bool get isContractCelebrationVisible =>
      activeContractCelebration != null && contractCelebrationTimer > 0;

  /// Current consecutive near-miss stunt streak.
  int stuntStreak = 0;

  /// Remaining countdown timer in seconds before active stunt streak decays.
  double stuntStreakTimer = 0.0;

  /// True when a stunt combo multiplier (> 1.0x) is currently active.
  bool get isComboActive => stuntStreak > 1 && stuntStreakTimer > 0;

  /// Calculates the current stunt combo multiplier according to streak depth.
  double get stuntMultiplier {
    if (stuntStreak <= 0) return 1.0;
    if (stuntStreak == 1) return 1.2;
    if (stuntStreak == 2) return 1.5;
    if (stuntStreak == 3) return 2.0;
    return 2.5;
  }

  /// Total customer doorstep deliveries successfully fulfilled in current run.
  int deliveriesInRun = 0;

  /// Current consecutive doorstep delivery streak without taking hazard damage.
  int deliveryStreak = 0;

  /// Calculates the active delivery streak multiplier (1.0x to 2.5x).
  double get deliveryMultiplier {
    if (deliveryStreak <= 1) return 1.0;
    if (deliveryStreak == 2) return 1.5;
    if (deliveryStreak == 3) return 2.0;
    return 2.5;
  }

  int _lastMilestoneIndex = 0;

  /// Total rail grinds and trick dismounts performed in current run.
  int grindsInRun = 0;

  /// Total agile parkour obstacle vaults performed in current run.
  int vaultsInRun = 0;

  /// Total steam vent updraft boosts caught in current run.
  int steamBoostsInRun = 0;

  /// Total sustained aerodynamic glides completed in current run.
  int glidesInRun = 0;

  /// Total subterranean subway stations traversed in current run.
  int subwayStationsInRun = 0;

  /// Total construction crane swing traversals executed in current run.
  int craneSwingsInRun = 0;

  /// Whether an urgent VIP Express mission is currently active.
  bool isVipMissionActive = false;

  /// Remaining countdown timer in seconds to fulfill the VIP delivery.
  double vipTimer = 0.0;

  /// Initial duration allocated for the active VIP delivery.
  double vipInitialDuration = 14.0;

  /// Surge multiplier awarded for completing the VIP delivery.
  double vipSurgeMultiplier = 3.0;

  /// Total VIP Express deliveries successfully completed in current run.
  int vipDeliveriesInRun = 0;

  /// Total aerodynamic bike companion draft slingshot leaps executed in current run.
  int bikeDraftSlingshotsInRun = 0;

  /// Total rooftop / sidewalk pigeon flock scatters triggered in current run.
  int pigeonScattersInRun = 0;

  /// Total crosswalk sprint-by pedestrian high-fives executed in current run.
  int highFivesInRun = 0;

  /// Total street food cart umbrella bounce cushion leaps executed in current run.
  int foodCartBouncesInRun = 0;

  /// Total street storm drain vault grate steam geyser eruptions triggered in current run.
  int drainGeysersInRun = 0;

  /// Total rooftop solar panel kinetic skate slides and surge discharges in current run.
  int solarSurgesInRun = 0;

  /// Total urban sidewalk puddle skims executed in current run.
  int puddleSkimsInRun = 0;

  /// Total industrial HVAC exhaust wind tunnel hover glides executed in current run.
  int windTunnelGlidesInRun = 0;

  /// Total street subway entrance turnstiles swiped or vaulted in current run.
  int turnstileVaultsInRun = 0;

  /// Total aerial cargo drone crates intercepted in current run.
  int droneCatchesInRun = 0;

  /// Total building facade fire escape ladders dropped in current run.
  int fireEscapeDropsInRun = 0;

  /// Total street food truck grease slick drift slides performed in current run.
  int foodTruckDriftsInRun = 0;

  /// Total street construction sawhorse barricade hurdle vaults performed in current run.
  int barricadeVaultsInRun = 0;

  /// Total rooftop satellite dish parabolic launches performed in current run.
  int satelliteLaunchesInRun = 0;

  /// Total street postal collection mailboxes vaulted in current run.
  int mailboxVaultsInRun = 0;

  /// Total seconds spent drafting behind companion cyclists in current run.
  double totalDraftDurationInRun = 0.0;

  /// Whether the courier is actively tucked inside a companion cyclist's slipstream draft wake.
  bool isDrafting = false;

  /// Updates active drafting state and notifies UI listeners when changed.
  void setDrafting(bool drafting) {
    if (isDrafting != drafting) {
      isDrafting = drafting;
      notifyListeners();
    }
  }

  ValueChanged<MilestoneEvent>? onMilestone;
  ValueChanged<StuntEvent>? onStunt;
  ValueChanged<DeliveryEvent>? onDeliveryCompleted;
  ValueChanged<RailOllieEvent>? onRailOllie;
  ValueChanged<RailClearEvent>? onRailClear;
  ValueChanged<VaultEvent>? onVault;
  ValueChanged<SteamVentEvent>? onSteamVent;
  ValueChanged<GlideEvent>? onGlide;
  ValueChanged<SubwayTransitEvent>? onSubwayTransit;
  ValueChanged<CraneSwingEvent>? onCraneSwing;
  ValueChanged<VipDeliveryEvent>? onVipDelivery;
  ValueChanged<DraftSlingshotEvent>? onBikeDraftSlingshot;
  ValueChanged<FlockScatterEvent>? onPigeonScatter;
  ValueChanged<HighFiveEvent>? onHighFive;
  ValueChanged<FoodCartBounceEvent>? onFoodCartBounce;
  ValueChanged<StormDrainEvent>? onStormDrain;
  ValueChanged<SolarSurgeEvent>? onSolarSurge;
  ValueChanged<PuddleSkimEvent>? onPuddleSkim;
  ValueChanged<WindTunnelGlideEvent>? onWindTunnelGlide;
  ValueChanged<TurnstileEvent>? onTurnstile;
  ValueChanged<DroneCatchEvent>? onDroneCatch;
  ValueChanged<FireEscapeEvent>? onFireEscapeDrop;
  ValueChanged<FoodTruckDriftEvent>? onFoodTruckDrift;
  ValueChanged<BarricadeVaultEvent>? onBarricadeVault;
  ValueChanged<SatelliteLaunchEvent>? onSatelliteLaunch;
  ValueChanged<PostalMailboxEvent>? onPostalMailboxVault;
  ValueChanged<ShiftContract>? onContractCompleted;
  VoidCallback? onGameOver;
  VoidCallback? onPackageRestored;
  VoidCallback? onDamageTaken;
  VoidCallback? onVipMissionExpired;

  /// Begins or resets an active courier run.
  void startRun({DailyShift? dailyShift, Set<RunBooster>? equippedBoosters}) {
    activeDailyShift = dailyShift;
    activeBoosters = equippedBoosters != null
        ? Set<RunBooster>.unmodifiable(equippedBoosters)
        : const {};
    hasCompletedDailyShiftInRun = false;
    packages = maxPackages;
    tips = 0;
    distanceMeters = 0.0;
    _lastMilestoneIndex = 0;
    damageTakenCount = 0;
    energyDrinkTimer = 0.0;
    droneTimer = 0.0;
    activeMilestone = null;
    milestoneBannerTimer = 0.0;
    activeContractCelebration = null;
    contractCelebrationTimer = 0.0;
    stuntStreak = 0;
    stuntStreakTimer = 0.0;
    deliveriesInRun = 0;
    deliveryStreak = 0;
    grindsInRun = 0;
    vaultsInRun = 0;
    steamBoostsInRun = 0;
    glidesInRun = 0;
    subwayStationsInRun = 0;
    craneSwingsInRun = 0;
    vipDeliveriesInRun = 0;
    isVipMissionActive = false;
    vipTimer = 0.0;
    bikeDraftSlingshotsInRun = 0;
    pigeonScattersInRun = 0;
    highFivesInRun = 0;
    foodCartBouncesInRun = 0;
    drainGeysersInRun = 0;
    solarSurgesInRun = 0;
    puddleSkimsInRun = 0;
    windTunnelGlidesInRun = 0;
    turnstileVaultsInRun = 0;
    droneCatchesInRun = 0;
    fireEscapeDropsInRun = 0;
    foodTruckDriftsInRun = 0;
    barricadeVaultsInRun = 0;
    satelliteLaunchesInRun = 0;
    mailboxVaultsInRun = 0;
    totalDraftDurationInRun = 0.0;
    isDrafting = false;
    status = GameStatus.running;
    contractManager.reset();

    // Trigger pre-run equipped consumables
    if (activeBoosters.contains(RunBooster.espresso)) {
      activateEnergyDrink(8.0);
    }
    if (activeBoosters.contains(RunBooster.droneBeacon)) {
      activateDrone(8.0);
    }

    notifyListeners();
  }

  /// Pauses an active courier run.
  void pauseRun() {
    if (status == GameStatus.running) {
      status = GameStatus.paused;
      notifyListeners();
    }
  }

  /// Resumes a paused courier run.
  void resumeRun() {
    if (status == GameStatus.paused) {
      status = GameStatus.running;
      notifyListeners();
    }
  }

  /// Activates or extends the Cold Brew Energy Drink buff.
  void activateEnergyDrink([double duration = defaultEnergyDrinkDuration]) {
    if (status != GameStatus.running) return;
    final effectiveDuration = (activeDailyShift?.modifier == DailyModifier.nightDash)
        ? duration * 1.5
        : duration;
    // Refresh or extend buff up to a 10s maximum cap
    energyDrinkTimer = (energyDrinkTimer + effectiveDuration).clamp(0.0, 10.0);
    contractManager.onEnergyBoostActivated();
    notifyListeners();
  }

  /// Updates the energy buff countdown timer.
  void updateEnergyTimer(double dt) {
    if (energyDrinkTimer > 0) {
      energyDrinkTimer -= dt;
      if (energyDrinkTimer <= 0) {
        energyDrinkTimer = 0.0;
      }
      notifyListeners();
    }
  }

  /// Activates or extends the Companion Delivery Drone buff.
  void activateDrone([double duration = defaultDroneDuration]) {
    if (status != GameStatus.running) return;
    // Refresh or extend buff up to a 16s maximum cap
    droneTimer = (droneTimer + duration).clamp(0.0, 16.0);
    notifyListeners();
  }

  /// Updates the drone buff countdown timer.
  void updateDroneTimer(double dt) {
    if (droneTimer > 0) {
      droneTimer -= dt;
      if (droneTimer <= 0) {
        droneTimer = 0.0;
      }
      notifyListeners();
    }
  }

  /// Begins an urgent VIP Express delivery mission with a ticking countdown.
  void startVipMission([double duration = 14.0]) {
    if (status != GameStatus.running) return;
    isVipMissionActive = true;
    vipInitialDuration = duration;
    vipTimer = duration;
    notifyListeners();
  }

  /// Updates the ticking countdown timer for an active VIP delivery mission.
  void updateVipTimer(double dt) {
    if (status != GameStatus.running || !isVipMissionActive) return;
    if (vipTimer > 0) {
      vipTimer -= dt;
      if (vipTimer <= 0) {
        vipTimer = 0.0;
        isVipMissionActive = false;
        onVipMissionExpired?.call();
      }
      notifyListeners();
    }
  }

  /// Updates the celebration banner countdown timer.
  void updateMilestoneTimer(double dt) {
    if (milestoneBannerTimer > 0) {
      milestoneBannerTimer -= dt;
      if (milestoneBannerTimer <= 0) {
        milestoneBannerTimer = 0.0;
        activeMilestone = null;
      }
      notifyListeners();
    }
  }

  /// Updates the contract celebration banner countdown timer.
  void updateContractTimer(double dt) {
    if (contractCelebrationTimer > 0) {
      contractCelebrationTimer -= dt;
      if (contractCelebrationTimer <= 0) {
        contractCelebrationTimer = 0.0;
        activeContractCelebration = null;
      }
      notifyListeners();
    }
  }

  /// Updates the stunt combo countdown timer.
  void updateStuntTimer(double dt) {
    if (stuntStreakTimer > 0) {
      stuntStreakTimer -= dt;
      if (stuntStreakTimer <= 0) {
        stuntStreakTimer = 0.0;
        stuntStreak = 0;
        notifyListeners();
      }
    }
  }

  /// Records a successful near-miss stunt leap over a street hazard.
  void recordStunt({double clearance = 20.0}) {
    if (status != GameStatus.running) return;

    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseStuntTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();

    final event = StuntEvent(
      streak: stuntStreak,
      multiplier: stuntMultiplier,
      bonusTips: awarded,
      clearance: clearance,
    );
    onStunt?.call(event);
    notifyListeners();
  }

  /// Records an explosive Rail Ollie combo pop from an active grind rail.
  ///
  /// Advances the stunt streak, scales bonus tips by stunt multiplier and energy boost,
  /// and triggers the stunt combo timer.
  RailOllieEvent? recordRailOllie({required double grindDistanceMeters}) {
    if (status != GameStatus.running) return null;

    grindsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    const baseTip = 20;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = RailOllieEvent(
      grindDistanceMeters: grindDistanceMeters,
      multiplier: stuntMultiplier,
      baseTips: baseTip,
      totalTips: awarded,
      streak: stuntStreak,
    );

    onRailOllie?.call(event);
    notifyListeners();
    return event;
  }

  /// Records a clean rail dismount after riding across a full rail span.
  RailClearEvent? recordRailClear({required double grindDistanceMeters}) {
    if (status != GameStatus.running) return null;

    grindsInRun++;
    const baseTip = 10;
    final awarded = isEnergyBoostActive ? baseTip * 2 : baseTip;
    tips += awarded;

    contractManager.onTipCollected(awarded);

    final event = RailClearEvent(
      grindDistanceMeters: grindDistanceMeters,
      bonusTips: awarded,
    );

    onRailClear?.call(event);
    notifyListeners();
    return event;
  }

  /// Records an agile parkour vault cleanly over a low street obstacle.
  ///
  /// Advances the stunt streak, scales bonus tips by stunt multiplier and energy boost,
  /// and triggers the stunt combo timer.
  VaultEvent? recordVault({required ObstacleType obstacleType}) {
    if (status != GameStatus.running) return null;

    vaultsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    const baseTip = 15;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = VaultEvent(
      obstacleType: obstacleType,
      multiplier: stuntMultiplier,
      baseTips: baseTip,
      totalTips: awarded,
      streak: stuntStreak,
    );

    onVault?.call(event);
    notifyListeners();
    return event;
  }

  /// Records catching a rising thermal steam vent updraft.
  ///
  /// Increments stunt streak, awards bonus tips, and resets the combo timer.
  SteamVentEvent? recordSteamVentBoost() {
    if (status != GameStatus.running) return null;

    steamBoostsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    const baseTip = 20;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = SteamVentEvent(
      multiplier: stuntMultiplier,
      baseTips: baseTip,
      totalTips: awarded,
      streak: stuntStreak,
    );

    onSteamVent?.call(event);
    notifyListeners();
    return event;
  }

  /// Records a sustained aerodynamic glide traversal across the cityscape.
  ///
  /// Awards scaling tips based on distance glided and advances stunt streak.
  GlideEvent? recordGlide({required double glideDistanceMeters}) {
    if (status != GameStatus.running || glideDistanceMeters < 5.0) return null;

    glidesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseTip = (glideDistanceMeters * 1.5).round().clamp(15, 60);
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = GlideEvent(
      glideDistanceMeters: glideDistanceMeters,
      multiplier: stuntMultiplier,
      baseTips: baseTip,
      totalTips: awarded,
      streak: stuntStreak,
    );

    onGlide?.call(event);
    notifyListeners();
    return event;
  }

  /// Records entering a subterranean subway transit corridor, awarding transit cash tips.
  SubwayTransitEvent? recordSubwayTransit({String? stationName}) {
    if (status != GameStatus.running) return null;

    subwayStationsInRun++;
    final name = stationName ?? '8th Ave Express';
    const baseTip = 25;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onTipCollected(awarded);

    final event = SubwayTransitEvent(
      stationName: name,
      baseTips: baseTip,
      totalTips: awarded,
      multiplier: stuntMultiplier,
    );

    onSubwayTransit?.call(event);
    notifyListeners();
    return event;
  }

  /// Records launching off an industrial construction crane swing cable.
  ///
  /// Increments stunt streak, awards bonus tips scaled by combo multipliers,
  /// and resets the stunt combo timer.
  CraneSwingEvent? recordCraneSwing({required double swingAngle}) {
    if (status != GameStatus.running) return null;

    craneSwingsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    const baseTip = 35;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = CraneSwingEvent(
      swingAngle: swingAngle,
      multiplier: stuntMultiplier,
      baseTips: baseTip,
      totalTips: awarded,
      streak: stuntStreak,
    );

    onCraneSwing?.call(event);
    notifyListeners();
    return event;
  }

  /// Adds collected tips to current run bank.
  ///
  /// Awards double tips while [isEnergyBoostActive] is true, and stacks with daily shift multipliers.
  void addTip(int amount) {
    if (status != GameStatus.running) return;
    int modifierMultiplier = 1;
    if (activeDailyShift?.modifier == DailyModifier.rainyRush) {
      modifierMultiplier = 2;
    } else if (activeDailyShift?.modifier == DailyModifier.fragileFreight) {
      modifierMultiplier = 3;
    }
    final adjusted = amount * modifierMultiplier;
    final earned = isEnergyBoostActive ? adjusted * 2 : adjusted;
    tips += earned;
    contractManager.onTipCollected(amount);
    notifyListeners();
  }

  /// Manually restores a package from a pickup box.
  bool restorePackage() {
    if (packages < defaultMaxPackages) {
      packages++;
      onPackageRestored?.call();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Records a successful doorstep delivery fulfillment at a drop-off zone.
  ///
  /// Awards rating stars (3-5 stars) according to intact cargo packages,
  /// scales tips by delivery streak multiplier and speed, and restocks a package
  /// on reaching a 3x clean delivery streak.
  DeliveryEvent? recordDoorstepDelivery({double speedMultiplier = 1.0}) {
    if (status != GameStatus.running) return null;

    deliveriesInRun++;
    deliveryStreak++;

    // Calculate rating based on carried packages
    final int ratingStars;
    final int baseTip;
    if (packages >= maxPackages) {
      ratingStars = 5;
      baseTip = 35;
    } else if (packages >= 2) {
      ratingStars = 4;
      baseTip = 25;
    } else {
      ratingStars = 3;
      baseTip = 15;
    }

    final mult = deliveryMultiplier;
    final speedScaled = (baseTip * mult * speedMultiplier).round();
    final awarded = isEnergyBoostActive ? speedScaled * 2 : speedScaled;
    tips += awarded;

    // Perk: 3x clean streak restores a package if damaged
    bool didRestock = false;
    if (deliveryStreak == 3 && packages < maxPackages) {
      packages++;
      didRestock = true;
      onPackageRestored?.call();
    }

    contractManager.onTipCollected(awarded);

    final event = DeliveryEvent(
      ratingStars: ratingStars,
      baseTips: baseTip,
      totalTips: awarded,
      streak: deliveryStreak,
      multiplier: mult,
      didRestockPackage: didRestock,
    );

    onDeliveryCompleted?.call(event);
    notifyListeners();
    return event;
  }

  /// Records a successful VIP high-priority express delivery fulfillment.
  ///
  /// Increments stunt streak, applies surge multiplier (3x) stacked with stunt combo,
  /// restocks a package life if damaged, and resets VIP mission active state.
  VipDeliveryEvent? recordVipDelivery() {
    if (status != GameStatus.running) return null;

    vipDeliveriesInRun++;
    deliveriesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    const baseTip = 60;
    final totalMultiplier = vipSurgeMultiplier * stuntMultiplier;
    final baseAward = (baseTip * totalMultiplier).round();
    final awarded = isEnergyBoostActive ? baseAward * 2 : baseAward;
    tips += awarded;

    // Restock a lost package life upon VIP drop success
    if (packages < maxPackages) {
      packages++;
      onPackageRestored?.call();
    }

    final remainingTime = vipTimer;
    isVipMissionActive = false;
    vipTimer = 0.0;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = VipDeliveryEvent(
      baseTips: baseTip,
      totalTips: awarded,
      multiplier: totalMultiplier,
      remainingTimeSeconds: remainingTime,
      stuntStreak: stuntStreak,
    );

    onVipDelivery?.call(event);
    notifyListeners();
    return event;
  }

  /// Records launching an aerodynamic slingshot jump from a companion cyclist draft wake.
  ///
  /// Increments stunt streak, awards bonus tips scaled by combo multipliers,
  /// and resets the stunt combo timer.
  DraftSlingshotEvent? recordDraftSlingshot() {
    if (status != GameStatus.running) return null;

    bikeDraftSlingshotsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    const baseTip = 30;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = DraftSlingshotEvent(
      multiplier: stuntMultiplier,
      baseTips: baseTip,
      totalTips: awarded,
      streak: stuntStreak,
    );

    onBikeDraftSlingshot?.call(event);
    notifyListeners();
    return event;
  }

  /// Records leaping through a scattering pigeon flock mid-air,
  /// awarding base tips scaled by combo multipliers and advancing the stunt streak.
  FlockScatterEvent? recordPigeonScatter({int baseTips = 25}) {
    if (status != GameStatus.running) return null;

    pigeonScattersInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = FlockScatterEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onPigeonScatter?.call(event);
    notifyListeners();
    return event;
  }

  /// Records high-fiving a waiting pedestrian while sprinting or vaulting past a street crosswalk,
  /// awarding base tips scaled by combo multipliers and advancing the stunt streak.
  HighFiveEvent? recordHighFive({int baseTips = 20}) {
    if (status != GameStatus.running) return null;

    highFivesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = HighFiveEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onHighFive?.call(event);
    notifyListeners();
    return event;
  }

  /// Records bouncing atop a street food cart's striped canvas umbrella cushion,
  /// awarding base tips scaled by combo multipliers and advancing the stunt streak.
  FoodCartBounceEvent? recordFoodCartBounce({int baseTips = 25}) {
    if (status != GameStatus.running) return null;

    foodCartBouncesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = FoodCartBounceEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onFoodCartBounce?.call(event);
    notifyListeners();
    return event;
  }

  /// Records triggering a street storm drain vault grate steam geyser eruption,
  /// awarding base tips scaled by combo multipliers, advancing the stunt streak,
  /// and launching airborne coins.
  StormDrainEvent? recordDrainGeyser({int baseTips = 30, int coinsSpawned = 3}) {
    if (status != GameStatus.running) return null;

    drainGeysersInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = StormDrainEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
      coinsSpawned: coinsSpawned,
    );

    onStormDrain?.call(event);
    notifyListeners();
    return event;
  }

  /// Records completing a rooftop solar panel kinetic skate slide and discharging a Solar Surge EMP,
  /// awarding base tips scaled by combo multipliers, advancing the stunt streak,
  /// and vacuuming nearby coins.
  SolarSurgeEvent? recordSolarSurge({int baseTips = 35, int coinsHarvested = 0}) {
    if (status != GameStatus.running) return null;

    solarSurgesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = SolarSurgeEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
      coinsHarvested: coinsHarvested,
    );

    onSolarSurge?.call(event);
    notifyListeners();
    return event;
  }

  /// Records cleanly leaping or skimming over an urban sidewalk puddle,
  /// awarding base tips scaled by combo multipliers and advancing the stunt streak.
  PuddleSkimEvent? recordPuddleSkim({int baseTips = 20}) {
    if (status != GameStatus.running) return null;

    puddleSkimsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = PuddleSkimEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onPuddleSkim?.call(event);
    notifyListeners();
    return event;
  }

  /// Records completing an aerodynamic hover glide through an industrial HVAC exhaust wind tunnel,
  /// awarding base tips scaled by combo multipliers and advancing the stunt streak.
  WindTunnelGlideEvent? recordWindTunnelGlide({int baseTips = 25}) {
    if (status != GameStatus.running) return null;

    windTunnelGlidesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = WindTunnelGlideEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onWindTunnelGlide?.call(event);
    notifyListeners();
    return event;
  }

  /// Records swiping or hurdle-vaulting through a street subway entrance turnstile,
  /// awarding base tips scaled by combo multipliers and advancing the stunt streak.
  TurnstileEvent? recordTurnstilePass({bool isVault = false}) {
    if (status != GameStatus.running) return null;

    turnstileVaultsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseTip = isVault ? 25 : 20;
    final baseAward = (baseTip * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = TurnstileEvent(
      baseTips: baseTip,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
      isVault: isVault,
    );

    onTurnstile?.call(event);
    notifyListeners();
    return event;
  }

  /// Records intercepting an aerial cargo drone container mid-jump,
  /// awarding base tips ($35) scaled by combo multipliers, restoring a lost package HP if damaged,
  /// advancing the stunt streak, and resetting the stunt streak timer.
  DroneCatchEvent? recordDroneCatch({int baseTips = 35}) {
    if (status != GameStatus.running) return null;

    droneCatchesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    var restored = false;
    if (packages < maxPackages) {
      packages++;
      restored = true;
      onPackageRestored?.call();
    }

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = DroneCatchEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
      restoredPackage: restored,
    );

    onDroneCatch?.call(event);
    notifyListeners();
    return event;
  }

  /// Records grabbing and dropping a building facade fire escape ladder,
  /// catapulting the courier upwards, awarding base tips ($30) scaled by combo multipliers,
  /// advancing the stunt streak, and resetting the stunt streak timer.
  FireEscapeEvent? recordFireEscapeDrop({int baseTips = 30}) {
    if (status != GameStatus.running) return null;

    fireEscapeDropsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = FireEscapeEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onFireEscapeDrop?.call(event);
    notifyListeners();
    return event;
  }

  /// Records initiating a high-speed drift slide across a street food truck grease slick,
  /// awarding base tips ($25) scaled by combo multipliers, advancing the stunt streak,
  /// and resetting the stunt streak timer.
  FoodTruckDriftEvent? recordFoodTruckDrift({int baseTips = 25}) {
    if (status != GameStatus.running) return null;

    foodTruckDriftsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = FoodTruckDriftEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onFoodTruckDrift?.call(event);
    notifyListeners();
    return event;
  }

  /// Records a clean hurdle vault over a street construction sawhorse barricade,
  /// awarding base tips ($20) scaled by combo multipliers, advancing the stunt streak,
  /// and resetting the stunt streak timer.
  BarricadeVaultEvent? recordBarricadeVault({int baseTips = 20}) {
    if (status != GameStatus.running) return null;

    barricadeVaultsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = BarricadeVaultEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onBarricadeVault?.call(event);
    notifyListeners();
    return event;
  }

  /// Records a high-altitude celestial launch off a rooftop parabolic satellite dish,
  /// awarding base tips ($35) scaled by combo multipliers, advancing the stunt streak,
  /// and resetting the stunt streak timer.
  SatelliteLaunchEvent? recordSatelliteLaunch({
    int baseTips = 35,
    double launchImpulse = 540.0,
  }) {
    if (status != GameStatus.running) return null;

    satelliteLaunchesInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = SatelliteLaunchEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
      launchImpulse: launchImpulse,
    );

    onSatelliteLaunch?.call(event);
    notifyListeners();
    return event;
  }

  /// Records a clean hurdle vault over a street postal collection mailbox,
  /// awarding base tips ($25) scaled by combo multipliers, advancing the stunt streak,
  /// and resetting the stunt streak timer.
  PostalMailboxEvent? recordMailboxVault({int baseTips = 25}) {
    if (status != GameStatus.running) return null;

    mailboxVaultsInRun++;
    stuntStreak++;
    stuntStreakTimer = stuntComboDuration;

    final baseAward = (baseTips * stuntMultiplier).round();
    final withDaily = (activeDailyShift?.modifier == DailyModifier.skateCommute)
        ? baseAward * 2
        : baseAward;
    final awarded = isEnergyBoostActive ? withDaily * 2 : withDaily;
    tips += awarded;

    contractManager.onStuntPerformed();
    contractManager.onTipCollected(awarded);

    final event = PostalMailboxEvent(
      baseTips: baseTips,
      totalTips: awarded,
      multiplier: stuntMultiplier,
      stuntStreak: stuntStreak,
    );

    onPostalMailboxVault?.call(event);
    notifyListeners();
    return event;
  }

  /// Applies damage from a hazard collision.
  ///
  /// Resets active stunt streaks, delivery streak, and multiplier on impact.
  /// Returns `true` if player survived with remaining packages; `false` on game over.
  bool applyHazardDamage() {
    if (status != GameStatus.running) return false;

    packages--;
    stuntStreak = 0;
    stuntStreakTimer = 0.0;
    deliveryStreak = 0;
    damageTakenCount++;
    contractManager.onDamageTaken();
    onDamageTaken?.call();

    if (packages <= 0) {
      packages = 0;
      status = GameStatus.gameOver;
      onGameOver?.call();
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Updates distance and evaluates celebratory 500m shift milestones.
  void updateDistance(double newDistance) {
    if (status != GameStatus.running) return;
    distanceMeters = newDistance;
    contractManager.onDistanceProgress(distanceMeters, damageCount: damageTakenCount);

    final currentMilestone = (distanceMeters ~/ milestoneIntervalMeters);
    if (currentMilestone > _lastMilestoneIndex) {
      while (_lastMilestoneIndex < currentMilestone) {
        _lastMilestoneIndex++;
        final bool shouldRestore = packages < maxPackages;
        if (shouldRestore) {
          packages++;
        } else {
          tips += milestoneBonusTips;
        }

        final event = MilestoneEvent(
          milestoneIndex: _lastMilestoneIndex,
          distanceMeters: _lastMilestoneIndex * milestoneIntervalMeters,
          restoredPackage: shouldRestore,
          bonusTips: shouldRestore ? 0 : milestoneBonusTips,
        );

        activeMilestone = event;
        milestoneBannerTimer = milestoneBannerDuration;
        onMilestone?.call(event);
      }
    }

    // Evaluate daily shift goal
    if (isDailyShiftActive &&
        !hasCompletedDailyShiftInRun &&
        distanceMeters >= activeDailyShift!.targetDistanceMeters) {
      hasCompletedDailyShiftInRun = true;
      tips += activeDailyShift!.completionBonusTips;
    }

    notifyListeners();
  }
}
