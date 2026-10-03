import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

void main() {
  group('GameState & Shift Milestones (U5)', () {
    test('Initializes with 3 packages, 0 tips, 0m distance, and idle status', () {
      final state = GameState();
      expect(state.packages, equals(3));
      expect(state.maxPackages, equals(3));
      expect(state.tips, equals(0));
      expect(state.distanceMeters, equals(0.0));
      expect(state.status, equals(GameStatus.idle));
    });

    test('Damage reduces packages from 3 to 2', () {
      final state = GameState()..startRun();
      expect(state.packages, equals(3));

      final survived = state.applyHazardDamage();
      expect(survived, isTrue);
      expect(state.packages, equals(2));
      expect(state.status, equals(GameStatus.running));
    });

    test('Terminal death: reaching 0 packages triggers game over', () {
      final state = GameState()..startRun();
      bool gameOverFired = false;
      state.onGameOver = () => gameOverFired = true;

      state.applyHazardDamage(); // 3 -> 2
      state.applyHazardDamage(); // 2 -> 1
      final survived = state.applyHazardDamage(); // 1 -> 0

      expect(survived, isFalse);
      expect(state.packages, equals(0));
      expect(state.status, equals(GameStatus.gameOver));
      expect(gameOverFired, isTrue);
    });

    test('Shift milestone restoral (AE2): reaching 500m with 2 packages restores package to 3', () {
      final state = GameState()..startRun();
      state.applyHazardDamage(); // 3 -> 2
      expect(state.packages, equals(2));

      MilestoneEvent? milestoneEvent;
      state.onMilestone = (e) => milestoneEvent = e;

      // Advance distance to 500 meters
      state.updateDistance(500.0);

      expect(milestoneEvent, isNotNull);
      expect(milestoneEvent!.milestoneIndex, equals(1));
      expect(milestoneEvent!.restoredPackage, isTrue);
      expect(milestoneEvent!.bonusTips, equals(0));
      expect(state.packages, equals(3));
    });

    test(r'Shift milestone bonus (AE2): reaching 500m with full 3 packages awards $50 tip bonus without exceeding 3', () {
      final state = GameState()..startRun();
      expect(state.packages, equals(3));
      final initialTips = state.tips;

      MilestoneEvent? milestoneEvent;
      state.onMilestone = (e) => milestoneEvent = e;

      state.updateDistance(500.0);

      expect(milestoneEvent, isNotNull);
      expect(milestoneEvent!.milestoneIndex, equals(1));
      expect(milestoneEvent!.restoredPackage, isFalse);
      expect(milestoneEvent!.bonusTips, equals(50));
      expect(state.packages, equals(3));
      expect(state.tips, equals(initialTips + 50));
    });

    test('Coin pickups add tip amounts', () {
      final state = GameState()..startRun();
      state.addTip(1);
      state.addTip(5);
      expect(state.tips, equals(6));
    });

    test('Energy drink buff activates, ticks down, and doubles tip rewards (R6)', () {
      final state = GameState()..startRun();
      expect(state.isEnergyBoostActive, isFalse);
      expect(state.energyDrinkTimer, equals(0.0));

      // 1. Activate energy drink
      state.activateEnergyDrink();
      expect(state.isEnergyBoostActive, isTrue);
      expect(state.energyDrinkTimer, equals(5.0));

      // 2. Tip multiplier test: 2x tips during boost
      state.addTip(1); // 1 * 2 = 2
      state.addTip(5); // 5 * 2 = 10
      expect(state.tips, equals(12));

      // 3. Stacking / extending boost up to 10s max
      state.activateEnergyDrink(4.0);
      expect(state.energyDrinkTimer, equals(9.0));
      state.activateEnergyDrink(5.0);
      expect(state.energyDrinkTimer, equals(10.0)); // clamped to 10s

      // 4. Timer countdown
      state.updateEnergyTimer(6.0);
      expect(state.energyDrinkTimer, equals(4.0));
      expect(state.isEnergyBoostActive, isTrue);

      // 5. Expiration back to 1x multiplier
      state.updateEnergyTimer(5.0);
      expect(state.energyDrinkTimer, equals(0.0));
      expect(state.isEnergyBoostActive, isFalse);

      state.addTip(5); // back to 1x
      expect(state.tips, equals(17));
    });

    test('startRun resets active energy drink timer', () {
      final state = GameState()..startRun();
      state.activateEnergyDrink();
      expect(state.isEnergyBoostActive, isTrue);

      state.startRun();
      expect(state.isEnergyBoostActive, isFalse);
      expect(state.energyDrinkTimer, equals(0.0));
    });

    test('Milestone celebration banner triggers on milestone and auto-expires (R7)', () {
      final state = GameState()..startRun();
      expect(state.isMilestoneBannerVisible, isFalse);
      expect(state.activeMilestone, isNull);

      // Reaching 500m milestone
      state.updateDistance(500.0);
      expect(state.isMilestoneBannerVisible, isTrue);
      expect(state.activeMilestone, isNotNull);
      expect(state.activeMilestone!.milestoneIndex, equals(1));
      expect(state.milestoneBannerTimer, equals(3.0));

      // Timer tick down
      state.updateMilestoneTimer(1.5);
      expect(state.milestoneBannerTimer, equals(1.5));
      expect(state.isMilestoneBannerVisible, isTrue);

      // Expiration
      state.updateMilestoneTimer(2.0);
      expect(state.milestoneBannerTimer, equals(0.0));
      expect(state.activeMilestone, isNull);
      expect(state.isMilestoneBannerVisible, isFalse);
    });

    test('pauseRun and resumeRun lifecycle freeze state modifications', () {
      final state = GameState()..startRun();
      expect(state.status, equals(GameStatus.running));

      // Pause run
      state.pauseRun();
      expect(state.status, equals(GameStatus.paused));

      // In paused state, modifications are ignored
      state.addTip(10);
      expect(state.tips, equals(0));

      final survived = state.applyHazardDamage();
      expect(survived, isFalse);
      expect(state.packages, equals(3));

      state.updateDistance(100.0);
      expect(state.distanceMeters, equals(0.0));

      // Resume run
      state.resumeRun();
      expect(state.status, equals(GameStatus.running));

      state.addTip(10);
      expect(state.tips, equals(10));
    });
  });
}
