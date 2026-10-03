import 'package:flutter/foundation.dart';

/// Status of the current run lifecycle.
enum GameStatus {
  idle,
  running,
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

/// Central state machine managing the package HP mechanism, shift milestones, and score.
///
/// Rules:
/// - Couriers start with 3 package lives.
/// - Hazards decrement 1 package life.
/// - Reaching 0 packages triggers GameOver.
/// - Every 500m milestone restores 1 lost package; if already at 3 packages, awards $50 tip bonus.
class GameState extends ChangeNotifier {
  static const int defaultMaxPackages = 3;
  static const double milestoneIntervalMeters = 500.0;
  static const int milestoneBonusTips = 50;

  static const double defaultEnergyDrinkDuration = 5.0;

  int get maxPackages => defaultMaxPackages;

  int packages = defaultMaxPackages;
  int tips = 0;
  double distanceMeters = 0.0;
  GameStatus status = GameStatus.idle;

  /// Remaining duration in seconds for the Cold Brew Energy Drink buff.
  double energyDrinkTimer = 0.0;

  /// Returns true if the courier is currently energized by an energy drink.
  bool get isEnergyBoostActive => energyDrinkTimer > 0;

  int _lastMilestoneIndex = 0;

  ValueChanged<MilestoneEvent>? onMilestone;
  VoidCallback? onGameOver;
  VoidCallback? onPackageRestored;
  VoidCallback? onDamageTaken;

  /// Begins or resets an active courier run.
  void startRun() {
    packages = defaultMaxPackages;
    tips = 0;
    distanceMeters = 0.0;
    _lastMilestoneIndex = 0;
    energyDrinkTimer = 0.0;
    status = GameStatus.running;
    notifyListeners();
  }

  /// Activates or extends the Cold Brew Energy Drink buff.
  void activateEnergyDrink([double duration = defaultEnergyDrinkDuration]) {
    if (status != GameStatus.running) return;
    // Refresh or extend buff up to a 10s maximum cap
    energyDrinkTimer = (energyDrinkTimer + duration).clamp(0.0, 10.0);
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

  /// Adds collected tips to current run bank.
  ///
  /// Awards double tips while [isEnergyBoostActive] is true.
  void addTip(int amount) {
    if (status != GameStatus.running) return;
    final earned = isEnergyBoostActive ? amount * 2 : amount;
    tips += earned;
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
  /// Returns `true` if player survived with remaining packages; `false` on game over.
  bool applyHazardDamage() {
    if (status != GameStatus.running) return false;

    packages--;
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

    final currentMilestone = (distanceMeters ~/ milestoneIntervalMeters);
    if (currentMilestone > _lastMilestoneIndex) {
      while (_lastMilestoneIndex < currentMilestone) {
        _lastMilestoneIndex++;
        if (packages < maxPackages) {
          packages++;
          onMilestone?.call(
            MilestoneEvent(
              milestoneIndex: _lastMilestoneIndex,
              distanceMeters: _lastMilestoneIndex * milestoneIntervalMeters,
              restoredPackage: true,
              bonusTips: 0,
            ),
          );
        } else {
          tips += milestoneBonusTips;
          onMilestone?.call(
            MilestoneEvent(
              milestoneIndex: _lastMilestoneIndex,
              distanceMeters: _lastMilestoneIndex * milestoneIntervalMeters,
              restoredPackage: false,
              bonusTips: milestoneBonusTips,
            ),
          );
        }
      }
    }
    notifyListeners();
  }
}
