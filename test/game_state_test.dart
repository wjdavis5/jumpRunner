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
  });
}
