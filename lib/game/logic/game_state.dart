import 'package:flutter/foundation.dart';

import '../models/daily_shift.dart';
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

  int get maxPackages => (activeDailyShift?.modifier == DailyModifier.fragileFreight)
      ? 1
      : defaultMaxPackages;

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

  int _lastMilestoneIndex = 0;

  ValueChanged<MilestoneEvent>? onMilestone;
  ValueChanged<StuntEvent>? onStunt;
  ValueChanged<ShiftContract>? onContractCompleted;
  VoidCallback? onGameOver;
  VoidCallback? onPackageRestored;
  VoidCallback? onDamageTaken;

  /// Begins or resets an active courier run.
  void startRun({DailyShift? dailyShift}) {
    activeDailyShift = dailyShift;
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
    status = GameStatus.running;
    contractManager.reset();
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

  /// Applies damage from a hazard collision.
  ///
  /// Resets active stunt streaks and multiplier on impact.
  /// Returns `true` if player survived with remaining packages; `false` on game over.
  bool applyHazardDamage() {
    if (status != GameStatus.running) return false;

    packages--;
    stuntStreak = 0;
    stuntStreakTimer = 0.0;
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
