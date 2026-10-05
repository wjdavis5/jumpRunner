import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/achievement_manager.dart';
import 'package:jump_runner/game/models/achievement.dart';

Future<CourierGame> _runningGame() async {
  final game = CourierGame(achievementManager: AchievementManager());
  await game.onLoad();
  game.gameState.startRun();
  game.restartRun();
  return game;
}

/// Lets the unawaited trophy evaluation finish.
Future<void> _drain() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Every trophy can be earned by playing', () {
    test('Master Acrobat unlocks on a streak of four stunts', () async {
      final game = await _runningGame();
      final unlocked = <String>[];
      game.achievementManager.onAchievementUnlocked = (a) => unlocked.add(a.id);

      // The stunt multiplier tops out at 2.5x, so the old check
      // (multiplier rounded, at least 4) could never pass.
      for (var i = 0; i < 4; i++) {
        game.gameState.recordStunt(clearance: 10.0);
      }
      expect(game.gameState.stuntStreak, equals(4));
      expect(game.gameState.stuntMultiplier, lessThan(4.0));

      // Reaching 500 m triggers a trophy evaluation in the game loop.
      game.gameState.updateDistance(500.0);
      game.update(1.0 / 60.0);
      await _drain();

      expect(game.achievementManager.isUnlocked('master_acrobat'), isTrue);
      expect(unlocked, contains('master_acrobat'));
    });

    test('Three stunts in a row is not enough', () async {
      final game = await _runningGame();
      for (var i = 0; i < 3; i++) {
        game.gameState.recordStunt(clearance: 10.0);
      }
      game.gameState.updateDistance(500.0);
      game.update(1.0 / 60.0);
      await _drain();

      expect(game.achievementManager.isUnlocked('master_acrobat'), isFalse);
      expect(game.achievementManager.isUnlocked('first_delivery'), isTrue);
    });

    test('The catalogue has no trophy the manager never awards', () async {
      final manager = AchievementManager();
      await manager.evaluateProgress(
        distanceMeters: 2500.0,
        stuntCombo: 4,
        lifetimeContracts: 10,
        lifetimeCareerTips: AchievementManager.bigTipperLifetimeTips,
        wetHazardsCleared: 5,
        subwayStationsInRun: 1,
        lifetimeDeliveries: AchievementManager.doorToDoorDeliveries,
        dailyStars: AchievementManager.regularDailyGoals,
      );
      expect(
        manager.unlockedIds,
        equals(Achievement.catalog.map((a) => a.id).toSet()),
      );
    });
  });
}
