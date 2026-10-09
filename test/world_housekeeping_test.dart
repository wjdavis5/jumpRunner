// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/coach_hint_component.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/delivery_drone_component.dart';
import 'package:jump_runner/game/components/lightning_flash_component.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/components/rain_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

/// The four things that are in the world for the whole shift.
bool _isPermanent(Component c) =>
    c is CourierPlayer ||
    c is ParallaxCityComponent ||
    c is RainComponent ||
    c is LightningFlashComponent;

/// Things that keep their place on screen on purpose: the assist drone
/// flies beside the courier and a coaching hint can wait at the screen edge.
bool _holdsItsPlace(Component c) => c is DeliveryDroneComponent || c is CoachHintComponent;

class _Seen {
  _Seen(this.component, this.bornAt, this.x);
  final Component component;
  final double bornAt;
  double x;
  double stillFor = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Everything the street generator builds has to be moved along by the game
  // loop and taken away once it is behind the courier. That is one hand-
  // written loop per kind of piece, and there are thirty-eight kinds. Subway
  // stations were missing from the scroll loops for as long as they existed:
  // each one sat off-screen for the rest of the shift. Nothing failed, so
  // nothing noticed. This plays three long shifts and watches every
  // component in the world, whatever its type, so the next piece that is
  // added without its loop is caught the first time it spawns.
  const seeds = [1, 2, 3];
  const meters = 3200.0;

  // Measured over these shifts: the longest-lived piece is a pickup at about
  // 16 s (a chunk built 1,440 px out, crossing at 200 px/s), and nothing on
  // the street holds the same x for longer than half a second.
  const longestLife = 30.0;
  const longestStill = 6.0;

  for (final seed in seeds) {
    test('nothing is left standing or left behind over ${meters.round()} m (street $seed)',
        () async {
      final game = CourierGame(
        audioController: GameAudioController()..isMuted = true,
        chunkManager: WorldChunkManager(random: math.Random(seed)),
      );
      game.onGameResize(Vector2(960, 540));
      await game.load();
      game.mount();
      game.update(0);
      await game.ready();
      game.gameState.startRun();
      game.restartRun();

      final seen = <Component, _Seen>{};
      final kinds = <Type>{};
      var clock = 0.0;
      var peak = 0;
      const dt = 1 / 60;
      for (var f = 0; game.gameState.distanceMeters < meters && f < 60 * 400; f++) {
        // A courier who cannot lose, hopping on a timer.
        if (game.gameState.packages < GameState.defaultMaxPackages) {
          game.gameState.packages = GameState.defaultMaxPackages;
        }
        if (f % 45 == 0) game.player.pressJump();
        if (f % 45 == 6) game.player.releaseJump();
        game.update(dt);
        clock += dt;
        if (f % 3 == 0) await Future<void>.delayed(Duration.zero);

        final children = game.world.children;
        peak = math.max(peak, children.length);
        for (final c in children) {
          if (_isPermanent(c)) continue;
          // The assist drone is kept alive by every drone cargo the courier
          // collects, so a shift can legitimately carry one for minutes; its
          // departure and removal are pinned in delivery_drone_test.dart.
          if (c is DeliveryDroneComponent) continue;
          final x = c is PositionComponent ? c.position.x : double.nan;
          final record = seen.putIfAbsent(c, () {
            kinds.add(c.runtimeType);
            return _Seen(c, clock, x);
          });

          final age = clock - record.bornAt;
          if (age > longestLife) {
            fail('${c.runtimeType} has been in the world for ${age.toStringAsFixed(0)} s '
                '(x = ${x.toStringAsFixed(0)}) at ${game.gameState.distanceMeters.round()} m. '
                'Is it removed once it is off the left of the screen?');
          }

          if (_holdsItsPlace(c) || x.isNaN) continue;
          if ((record.x - x).abs() < 0.001) {
            record.stillFor += dt;
            if (record.stillFor > longestStill) {
              fail('${c.runtimeType} has not moved from x = ${x.toStringAsFixed(0)} for '
                  '${record.stillFor.toStringAsFixed(0)} s while the street scrolls, at '
                  '${game.gameState.distanceMeters.round()} m. Is it in the scroll section '
                  'of CourierGame\'s update?');
            }
          } else {
            record.stillFor = 0;
          }
          record.x = x;
        }
        // Forget what has gone, so the map does not grow with the shift.
        if (f % 600 == 0) seen.removeWhere((c, _) => !c.isMounted);
      }

      expect(game.gameState.distanceMeters, greaterThanOrEqualTo(meters));
      // The check only means something if the street was a busy one.
      expect(kinds.length, greaterThan(35));
      // About 70 at the busiest; a leak of one kind of piece would pass 150
      // inside a kilometre or two.
      expect(peak, lessThan(150));
    });
  }
}
