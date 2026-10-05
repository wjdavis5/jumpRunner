// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/lightning_flash_component.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/components/rain_component.dart';
import 'package:jump_runner/game/courier_game.dart';

const double _dt = 1.0 / 60.0;
const double _groundY = CourierGame.groundY;

/// A mounted game with a bare street: no chunks spawn, nothing is on it.
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
  for (final c in game.world.children.toList()) {
    if (c is CourierPlayer ||
        c is ParallaxCityComponent ||
        c is RainComponent ||
        c is LightningFlashComponent) {
      continue;
    }
    c.removeFromParent();
  }
  game.update(0);
  await game.ready();
  game.update(_dt);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The generator keeps hazards at least calculateMinClearance apart. These
  // put the awkward pairs exactly that close together in the real game and
  // try a grid of one- and two-press jump plans. If the minimum gap or the
  // jump physics is retuned into something unbeatable, this is where it shows.
  group('The tightest hazard pairs can be cleared', () {
    late CourierGame game;
    int damage = 0;

    setUp(() async {
      game = await _emptyStreet();
      game.gameState.onDamageTaken = () => damage++;
    });

    Future<bool> survives({
      required double meters,
      required ObstacleType first,
      required ObstacleType second,
      required int press1,
      required int hold1,
      int? press2,
      int hold2 = 1,
      bool buffed = false,
    }) async {
      for (final o in game.activeObstacles.toList()) {
        o.removeFromParent();
      }
      game.activeObstacles.clear();
      final player = game.player;
      player.position = Vector2(120.0, _groundY - player.size.y);
      player.simulator
        ..currentY = _groundY
        ..verticalVelocity = 0.0
        ..isGrounded = true
        ..isGliding = false;
      player.state = CourierState.running;
      player.resetForRun();
      // Buffed: an energy drink and a caffeine surge kick in after the pair
      // was laid out for the plain speed, so the courier arrives 42% faster
      // than the gap was sized for.
      game.gameState
        ..distanceMeters = meters
        ..packages = 3
        ..energyDrinkTimer = buffed ? 99.0 : 0.0
        ..caffeineSurgeTimer = buffed ? 99.0 : 0.0;
      final jumpBoost = buffed ? 1.10 : 1.0; // what the surge adds to a jump
      game.isRunning = true;
      game.nextChunkX = 1e12;
      damage = 0;

      final speed = game.chunkManager.calculateSpeed(meters);
      final gap = game.chunkManager.calculateMinClearance(speed);
      final sizeA = ObstacleComponent.defaultSizeForType(first);
      final sizeB = ObstacleComponent.defaultSizeForType(second);
      final ax = player.position.x + player.size.x + speed * 0.9;
      final a = ObstacleComponent(type: first, position: Vector2(ax, _groundY - sizeA.y), size: sizeA);
      final b = ObstacleComponent(
        type: second,
        position: Vector2(ax + sizeA.x + gap, _groundY - sizeB.y),
        size: sizeB,
      );
      game.activeObstacles..add(a)..add(b);
      game.world..add(a)..add(b);
      game.update(0);
      await Future<void>.delayed(Duration.zero);
      game.update(0);

      int? release1;
      int? release2;
      for (var f = 0; f < 420; f++) {
        if (f == press1) {
          player.pressJump(impulseMultiplier: jumpBoost);
          release1 = f + hold1;
        }
        if (press2 != null && f == press2) {
          player.pressJump(impulseMultiplier: jumpBoost);
          release2 = f + hold2;
        }
        if (release1 != null && f == release1) player.releaseJump();
        if (release2 != null && f == release2) player.releaseJump();
        game.update(_dt);
        if (damage > 0) return false;
        if (b.position.x + b.size.x < 100.0) return true;
      }
      return false;
    }

    /// Share of a coarse grid of jump plans that gets past both hazards.
    Future<double> survivalRate(
      double meters,
      ObstacleType first,
      ObstacleType second, {
      bool buffed = false,
    }) async {
      int wins = 0;
      int trials = 0;
      for (var press1 = 0; press1 <= 60; press1 += 6) {
        for (final hold1 in const [1, 15]) {
          for (int? press2 in <int?>[null, for (var f = press1 + 6; f <= press1 + 96; f += 6) f]) {
            for (final hold2 in press2 == null ? const [1] : const [1, 15]) {
              trials++;
              if (await survives(
                meters: meters,
                first: first,
                second: second,
                press1: press1,
                hold1: hold1,
                press2: press2,
                hold2: hold2,
                buffed: buffed,
              )) {
                wins++;
              }
            }
          }
        }
      }
      return wins / trials;
    }

    // 0 m is the 200 px/s starting speed; 2,000 m is the 550 px/s ceiling.
    for (final meters in const [0.0, 2000.0]) {
      test('two vans in a row at ${meters == 0 ? 'starting' : 'top'} speed', () async {
        expect(await survivalRate(meters, ObstacleType.van, ObstacleType.van), greaterThan(0.05));
      });

      test('an oncoming skater, then a van, at ${meters == 0 ? 'starting' : 'top'} speed', () async {
        expect(
          await survivalRate(meters, ObstacleType.skateMessenger, ObstacleType.van),
          greaterThan(0.05),
        );
      });
    }

    // Speed buffs stack (energy drink x1.2, caffeine surge x1.18) and a pair
    // already on the street keeps the spacing it was given. Measured at up to
    // three stacked buffs (896 px/s): 26-33% of plans still get through,
    // mostly because one long leap now carries over both hazards.
    test('two vans in a row at top speed with two speed buffs running', () async {
      expect(
        await survivalRate(2000.0, ObstacleType.van, ObstacleType.van, buffed: true),
        greaterThan(0.05),
      );
      expect(game.currentSpeed, greaterThan(750.0), reason: 'the buffs did apply');
    });
  });
}
