import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/qa_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The QA switches change how a shift starts and whether it can end. They
  // are build-time constants; a build that was not given them must behave as
  // if they did not exist. (The test run itself is such a build.)
  group('QA switches are off unless the build asks for them', () {
    test('both default to off', () {
      expect(QaFlags.startMeters, equals(0));
      expect(QaFlags.immortal, isFalse);
      expect(QaFlags.any, isFalse);
      // The page-address override only exists in a QA build.
      expect(QaFlags.effectiveStartMeters, equals(0));
      expect(QaFlags.forceSubway, isFalse);
      expect(QaFlags.streetRandom, isNull);
    });

    test('a shift starts at zero meters', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.restartRun();
      expect(game.gameState.distanceMeters, equals(0.0));
      // And the street is generated at its ordinary odds.
      expect(game.chunkManager.subwayStationChance, equals(0.35));
    });

    test('losing every package still ends the shift', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.restartRun();
      game.update(1 / 60);
      for (var i = 0; i < GameState.defaultMaxPackages; i++) {
        game.gameState.applyHazardDamage();
        game.update(1 / 60);
      }
      expect(game.gameState.status, equals(GameStatus.gameOver));
    });
  });
}
