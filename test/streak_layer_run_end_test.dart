// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'audio_controller_test.dart';

/// A mounted, running shift on an empty street with a mock audio backend.
Future<CourierGame> _runningGame(GameAudioController audio) async {
  final game = CourierGame(audioController: audio);
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  game.nextChunkX = 1e12;
  for (final o in game.activeObstacles.toList()) {
    o.removeFromParent();
  }
  game.activeObstacles.clear();
  game.update(0);
  await Future<void>.delayed(Duration.zero);
  game.update(0);
  return game;
}

/// One frame with the event loop given a chance to run the audio calls'
/// continuations, the way separate real frames do.
Future<void> _frame(CourierGame game) async {
  game.update(1 / 60);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('The streak layer on the way out of a shift', () {
    test('a lost shift fades the layer out and forgets the streak', () async {
      final backend = MockAudioBackend();
      final audio = GameAudioController(backend: backend);
      final game = await _runningGame(audio);

      // A 3x streak raises the layer while the shift is live.
      game.gameState.stuntStreak = 3;
      for (var i = 0; i < 12; i++) {
        await _frame(game);
      }
      expect(backend.isLayerPlaying, isTrue);
      expect(backend.layerVolume, greaterThan(0.0));

      // The last package goes.
      while (game.gameState.status != GameStatus.gameOver) {
        game.gameState.applyHazardDamage();
      }
      expect(game.gameState.stuntStreak, equals(0));

      // The death beat and the results card keep feeding the audio, so the
      // layer fades out while the music plays on.
      for (var i = 0; i < 60; i++) {
        await _frame(game);
      }
      expect(backend.isLayerPlaying, isFalse,
          reason: 'a lost shift must not leave the streak layer riding the music');

      // And the dead streak cannot be brought back by an unmute.
      await audio.toggleMute();
      await audio.toggleMute();
      expect(backend.isLayerPlaying, isFalse,
          reason: 'a streak that died with the shift must stay forgotten');
    });
  });
}
