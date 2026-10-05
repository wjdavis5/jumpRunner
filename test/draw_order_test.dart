// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/coach_hint_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/lightning_flash_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/rain_component.dart';
import 'package:jump_runner/game/components/speech_bubble_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/draw_order.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const double _frame = 1 / 60;

/// What may be drawn in front of the courier: sparks and dust, the game's
/// words, and the weather.
bool _mayCover(Component c) =>
    c is ParticleEffectComponent ||
    c is CoachHintComponent ||
    c is FloatingTextComponent ||
    c is SpeechBubbleComponent ||
    c is RainComponent ||
    c is LightningFlashComponent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Everything on the street sat at one draw priority, where whichever was
  // built later is drawn on top. The courier is built first. Measured on
  // four streets, every piece the courier overlapped was drawn over them:
  // passing a flower kiosk, a bus shelter or a food cart, or run down by a
  // van, the courier could not be seen at all.
  for (final seed in const [3, 7]) {
    test('Nothing on the street is drawn in front of the courier (seed $seed)', () async {
      final game = CourierGame(
        audioController: GameAudioController()..isMuted = true,
        chunkManager: WorldChunkManager(random: math.Random(seed)),
        personalRecordDistance: 900,
      );
      game.onGameResize(Vector2(960, 540));
      await game.load();
      game.mount();
      game.update(0);
      await game.ready();
      game.gameState.startRun();
      game.restartRun();
      // Past the warm-up, where every kind of street piece is built.
      game.gameState.distanceMeters = 300;

      final rng = math.Random(seed);
      final inFront = <String>{};
      final seen = <String>{};
      var held = false;
      var next = 0;
      for (var f = 0; f < 60 * 45; f++) {
        game.gameState.packages = game.gameState.maxPackages;
        if (f >= next) {
          held ? game.letGoOfJump('test') : game.holdJump('test');
          next = f + (held ? 10 + rng.nextInt(40) : 2 + rng.nextInt(30));
          held = !held;
        }
        game.update(_frame);
        if (f % 5 == 0) await Future<void>.delayed(Duration.zero);
        if (f % 10 != 0) continue;

        // Children are kept in the order they are drawn.
        final drawn = game.world.children.toList();
        final courier = drawn.indexOf(game.player);
        expect(courier, greaterThanOrEqualTo(0));
        for (var i = 0; i < drawn.length; i++) {
          seen.add(drawn[i].runtimeType.toString());
          if (i > courier && !_mayCover(drawn[i])) inFront.add(drawn[i].runtimeType.toString());
        }
      }

      expect(inFront, isEmpty, reason: 'drawn in front of the courier');
      expect(seen.length, greaterThan(15), reason: 'the street was nearly empty: $seen');
    });
  }

  test('Sparks are in front of the courier and words in front of the sparks', () {
    expect(courierPriority, greaterThan(0));
    expect(particlePriority, greaterThan(courierPriority));
    expect(wordsPriority, greaterThan(particlePriority));
    // Rain and the lightning flash set their own, in front of all of it.
    expect(RainComponent().priority, greaterThan(wordsPriority));
  });
}
