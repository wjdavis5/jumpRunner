// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';

Future<CourierGame> _emptyStreet() async {
  final game = CourierGame(audioController: GameAudioController()..isMuted = true);
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

/// Plays one held leap at the given frame time and returns how high the
/// courier's feet got above the street.
Future<double> _leapPeak(double dt) async {
  final game = await _emptyStreet();
  final player = game.player;
  player.pressJump();
  var peak = 0.0;
  var held = 0.0;
  for (var t = 0.0; t < 1.2; t += dt) {
    game.update(dt);
    held += dt;
    if (held >= 0.3) player.releaseJump();
    final height = CourierGame.groundY - player.simulator.currentY;
    if (height > peak) peak = height;
  }
  return peak;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('One frame never simulates more than a tenth of a second', () {
    test('a half-second stall moves the street a tenth of a second, not half', () async {
      final game = await _emptyStreet();
      final before = game.gameState.distanceMeters;
      game.update(0.5);
      final moved = (game.gameState.distanceMeters - before) * 20.0; // 20 px per meter
      // 200 px/s at the start of a shift: 20 px for the allowed 0.1 s.
      expect(moved, closeTo(game.currentSpeed * game.maxFrameStep, 2.0));
      expect(moved, lessThan(game.currentSpeed * 0.2));
    });

    test('ordinary frames are untouched', () async {
      final game = await _emptyStreet();
      final before = game.gameState.distanceMeters;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      final moved = (game.gameState.distanceMeters - before) * 20.0;
      expect(moved, closeTo(200.0, 6.0));
    });

    test('a slow but steady 20 frames a second still runs in real time', () async {
      final game = await _emptyStreet();
      final before = game.gameState.distanceMeters;
      for (var i = 0; i < 20; i++) {
        game.update(1 / 20);
      }
      final moved = (game.gameState.distanceMeters - before) * 20.0;
      expect(moved, closeTo(200.0, 6.0));
    });
  });

  group('A long frame is simulated in short steps', () {
    test('a hazard dead ahead hits the courier instead of jumping past them', () async {
      final game = await _emptyStreet();
      var hits = 0;
      game.gameState.onDamageTaken = () => hits++;
      // Top speed with two speed buffs: about 780 px/s, the fastest the
      // street normally gets.
      game.gameState
        ..distanceMeters = 2000.0
        ..energyDrinkTimer = 99.0
        ..caffeineSurgeTimer = 99.0;
      game.update(1 / 60);
      expect(game.currentSpeed, greaterThan(700.0));

      final player = game.player;
      final size = ObstacleComponent.defaultSizeForType(ObstacleType.scooter);
      final hazard = ObstacleComponent(
        type: ObstacleType.scooter,
        position: Vector2(player.position.x + player.size.x + 4, CourierGame.groundY - size.y),
        size: size,
      );
      game.activeObstacles.add(hazard);
      game.world.add(hazard);
      game.update(0);
      await game.ready();
      game.update(0);

      // One 100 ms frame carries the scooter about 78 px: from just in front
      // of the courier to behind their torso. In a single step it could pass
      // without the two ever overlapping.
      game.update(0.1);
      for (var i = 0; i < 3 && hits == 0; i++) {
        game.update(1 / 60);
      }
      expect(hits, equals(1));
    });

    test('a leap is the same height at 20 frames a second as at 60', () async {
      final at60 = await _leapPeak(1 / 60);
      final at20 = await _leapPeak(1 / 20);
      final at120 = await _leapPeak(1 / 120);
      expect(at60, greaterThan(80.0), reason: 'a held leap gets well off the ground');
      // Without sub-steps the 20 fps arc is integrated in 50 ms lumps and
      // comes out a different height, which changes what it can clear.
      expect(at20, closeTo(at60, at60 * 0.08));
      expect(at120, closeTo(at60, at60 * 0.08));
    });
  });
}
