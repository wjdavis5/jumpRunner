// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
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
}
