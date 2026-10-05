// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const double _dt = 1.0 / 60.0;

/// Loads and mounts the real game the way the engine does, so components
/// spawn, load, collide and recycle exactly as they do on a device.
Future<CourierGame> _mountedGame(int seed) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: WorldChunkManager(random: math.Random(seed)),
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  return game;
}

void _space(CourierGame game, {required bool down}) {
  game.onKeyEvent(
    down
        ? const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            timeStamp: Duration.zero,
          )
        : const KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            timeStamp: Duration.zero,
          ),
    down ? {LogicalKeyboardKey.space} : const {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A long autoplayed shift through the real game loop. It exists to catch
  // what per-feature tests cannot: a set piece that throws once it is live in
  // the world, strands the courier off-screen, or never gets recycled.
  for (final seed in const [1, 2]) {
    test('Autoplayed 1,500 m shift stays healthy (seed $seed)', () async {
      final game = await _mountedGame(seed);
      game.gameState.startRun();
      game.restartRun();

      const targetMeters = 1500.0;
      double elapsed = 0.0;
      double releaseAt = -1.0;
      double lastDistance = 0.0;
      int frames = 0;
      int peakWorldChildren = 0;

      while (game.gameState.distanceMeters < targetMeters && elapsed < 600.0) {
        // Keep the shift alive so the soak reaches mid-game content.
        if (game.gameState.packages < GameState.defaultMaxPackages) {
          game.gameState.packages = GameState.defaultMaxPackages;
        }

        // Autoplayer: jump the nearest hazard ahead, holding for tall ones.
        final player = game.player;
        final courierX = player.position.x + player.size.x / 2;
        ObstacleComponent? nearest;
        for (final o in game.activeObstacles) {
          final center = o.position.x + o.size.x / 2;
          if (center > courierX &&
              (nearest == null || center < nearest.position.x + nearest.size.x / 2)) {
            nearest = o;
          }
        }
        if (nearest != null && player.simulator.isGrounded && releaseAt < 0) {
          final tall = nearest.size.y > 50 || nearest.size.x > 80;
          final lead = game.currentSpeed * (tall ? 0.60 : 0.385);
          final center = nearest.position.x + nearest.size.x / 2;
          if (center - courierX <= lead + nearest.size.x / 2) {
            _space(game, down: true);
            releaseAt = elapsed + (tall ? 0.30 : 0.05);
          }
        }
        if (releaseAt >= 0 && elapsed >= releaseAt) {
          _space(game, down: false);
          releaseAt = -1.0;
        }

        game.update(_dt);
        elapsed += _dt;
        frames++;
        // Yield so freshly spawned components finish loading and mount.
        if (frames % 3 == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        final at = '${game.gameState.distanceMeters.toStringAsFixed(0)}m';
        expect(game.gameState.status, equals(GameStatus.running), reason: 'run stopped at $at');
        expect(
          game.gameState.distanceMeters,
          greaterThanOrEqualTo(lastDistance),
          reason: 'distance went backwards at $at',
        );
        lastDistance = game.gameState.distanceMeters;

        expect(game.currentSpeed.isFinite, isTrue, reason: 'speed at $at');
        expect(
          player.position.x,
          inInclusiveRange(-64.0, 960.0),
          reason: 'courier left the screen horizontally at $at (${player.state})',
        );
        expect(
          player.position.y,
          inInclusiveRange(-1200.0, CourierGame.groundY - player.size.y + 0.5),
          reason: 'courier out of vertical bounds at $at (${player.state})',
        );

        peakWorldChildren = math.max(peakWorldChildren, game.world.children.length);
      }

      expect(
        game.gameState.distanceMeters,
        greaterThanOrEqualTo(targetMeters),
        reason: 'shift stalled after ${elapsed.toStringAsFixed(0)}s',
      );
      // Everything that scrolls off must be recycled; a leak grows without bound.
      expect(peakWorldChildren, lessThan(200));
      expect(game.activeObstacles.length, lessThan(40));
    });
  }

  // The autoplayer above jumps hazards cleanly, so it rarely lands on a
  // rail, clips an awning or grabs a crane hook. Random presses and holds
  // do all of that, all the time. Whatever the street does with the courier
  // it has to give them back: on 16 streets of 3,000 m the longest the
  // courier spent in any one state other than running was 1.6 s, and they
  // were never wholly off the screen.
  for (final seed in const [3, 7, 11]) {
    test('Random presses never strand the courier (seed $seed)', () async {
      final game = await _mountedGame(seed);
      game.gameState.startRun();
      game.restartRun();
      final state = game.gameState;
      final player = game.player;
      final rng = math.Random(1000 + seed);

      var held = false;
      var nextChange = 0;
      var inState = player.state;
      var sinceChange = 0.0;
      var lastDistance = 0.0;
      var lastTips = 0;
      var peakWorldChildren = 0;

      for (var f = 0; state.distanceMeters < 1500.0 && f < 60 * 300; f++) {
        state.packages = state.maxPackages;
        if (f >= nextChange) {
          // Half the presses are taps, half are held for up to 0.75 s.
          if (held) {
            game.letGoOfJump('soak');
            nextChange = f + 2 + rng.nextInt(50);
          } else {
            game.holdJump('soak');
            nextChange = f + 1 + (rng.nextBool() ? rng.nextInt(4) : rng.nextInt(45));
          }
          held = !held;
        }
        game.update(_dt);
        if (f % 3 == 0) await Future<void>.delayed(Duration.zero);

        final at = '${state.distanceMeters.toStringAsFixed(0)} m (${player.state.name})';
        expect(state.status, equals(GameStatus.running), reason: 'shift stopped at $at');
        expect(state.distanceMeters, greaterThanOrEqualTo(lastDistance), reason: 'distance fell at $at');
        expect(state.tips, greaterThanOrEqualTo(lastTips), reason: 'tips fell at $at');
        lastDistance = state.distanceMeters;
        lastTips = state.tips;

        final x = player.position.x;
        final y = player.position.y;
        expect(x.isFinite && y.isFinite, isTrue, reason: 'position at $at');
        expect(x + player.size.x, greaterThan(0.0), reason: 'off the left of the screen at $at');
        expect(x, lessThan(960.0), reason: 'off the right of the screen at $at');
        expect(y, greaterThan(0.0), reason: 'off the top of the screen at $at');
        expect(y, lessThanOrEqualTo(CourierGame.groundY - player.size.y + 0.5), reason: 'under the street at $at');
        // Running is done from the courier's own spot.
        if (player.state == CourierState.running) {
          expect(x, closeTo(120.0, 0.5), reason: 'running away from home at $at');
        }

        if (player.state == inState) {
          sinceChange += _dt;
        } else {
          inState = player.state;
          sinceChange = 0.0;
        }
        if (inState != CourierState.running) {
          expect(sinceChange, lessThan(6.0), reason: 'stuck ${inState.name} at $at');
        }
        peakWorldChildren = math.max(peakWorldChildren, game.world.children.length);
      }

      expect(state.distanceMeters, greaterThanOrEqualTo(1500.0), reason: 'the shift stalled');
      expect(peakWorldChildren, lessThan(200));
    });
  }
}
