import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/game/models/run_booster.dart';

Future<CourierGame> _loadedGame() async {
  final game = CourierGame();
  await game.onLoad();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Boosters are single-run supplies', () {
    test('A quick restart does not reuse the last shift\'s boosters for free', () async {
      final game = await _loadedGame();

      game.restartRun(equippedBoosters: {RunBooster.satchel, RunBooster.espresso});
      expect(game.gameState.maxPackages, equals(4));
      expect(game.gameState.isEnergyBoostActive, isTrue);

      // "Start next shift" on the results screen.
      game.restartRun();

      expect(game.activeBoosters, isEmpty);
      expect(game.gameState.activeBoosters, isEmpty);
      expect(game.gameState.maxPackages, equals(GameState.defaultMaxPackages));
      expect(game.gameState.packages, equals(GameState.defaultMaxPackages));
      expect(game.gameState.isEnergyBoostActive, isFalse);
    });
  });

  group('Daily shift carry-over', () {
    final daily = DailyShift.forDate(DateTime.utc(2026, 10, 4));

    test('A quick restart retries the same daily shift', () async {
      final game = await _loadedGame();
      game.restartRun(shift: daily);
      expect(game.gameState.isDailyShiftActive, isTrue);

      game.restartRun();
      expect(game.gameState.isDailyShiftActive, isTrue);
    });

    test('Returning to the depot ends it: the next regular shift is regular', () async {
      final game = await _loadedGame();
      game.restartRun(shift: daily);

      game.returnToDepot();
      expect(game.dailyShift, isNull);

      game.restartRun();
      expect(game.gameState.isDailyShiftActive, isFalse);
    });
  });

  group('Returning to the depot', () {
    test('The abandoned shift is cleared off the street', () async {
      final game = await _loadedGame();
      game.restartRun();
      for (var i = 0; i < 240; i++) {
        game.update(1.0 / 60.0);
      }
      game.player.jump();
      game.update(1.0 / 60.0);
      expect(game.activeObstacles.any((o) => o.position.x < 960.0), isTrue,
          reason: 'the run should have hazards on screen before leaving');

      game.returnToDepot();

      expect(game.gameState.status, equals(GameStatus.idle));
      expect(game.isRunning, isFalse);
      expect(game.activeObstacles.where((o) => o.position.x < 960.0), isEmpty);
      expect(game.activePickups.where((p) => p.position.x < 960.0), isEmpty);
      expect(game.firstRunCoach, isNull);
      expect(game.gameState.distanceMeters, equals(0.0));

      final player = game.player;
      expect(player.state, equals(CourierState.running));
      expect(player.position.x, equals(120.0));
      expect(player.position.y, equals(CourierGame.groundY - player.size.y));
    });

    test('Behind the title screen the street stays put and the skyline drifts', () async {
      final game = await _loadedGame();
      game.restartRun();
      for (var i = 0; i < 120; i++) {
        game.update(1.0 / 60.0);
      }
      game.returnToDepot();

      final obstacleXs = game.activeObstacles.map((o) => o.position.x).toList();
      final skyline = game.parallaxCity.skylineOffset;
      for (var i = 0; i < 60; i++) {
        game.update(1.0 / 60.0);
      }

      expect(game.activeObstacles.map((o) => o.position.x).toList(), equals(obstacleXs));
      expect(game.gameState.distanceMeters, equals(0.0));
      expect(game.parallaxCity.skylineOffset, isNot(equals(skyline)));
    });
  });
}
