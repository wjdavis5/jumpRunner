// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';

/// A mounted game on an empty street at [meters] into a shift, optionally
/// with both speed buffs running.
Future<CourierGame> _emptyStreet(double meters, {bool boosted = false}) async {
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
  game.gameState.distanceMeters = meters;
  if (boosted) {
    game.gameState
      ..energyDrinkTimer = 99.0
      ..caffeineSurgeTimer = 99.0;
  }
  game.update(0);
  await Future<void>.delayed(Duration.zero);
  game.update(1 / 60);
  return game;
}

/// Sends one roosting flock down the street at the courier. Jump is pressed
/// when the gap between them closes to [pressAt] px (null: never) and held
/// for [hold] seconds. Returns whether the courier was hit.
Future<bool> _isHit(double meters, double? pressAt, double hold, {bool boosted = false}) async {
  final game = await _emptyStreet(meters, boosted: boosted);
  var hits = 0;
  game.gameState.onDamageTaken = () => hits++;
  final player = game.player;
  final size = ObstacleComponent.defaultSizeForType(ObstacleType.pigeonFlock);
  final flock = ObstacleComponent(
    type: ObstacleType.pigeonFlock,
    position: Vector2(player.position.x + 900, CourierGame.groundY - size.y),
    size: size,
  );
  game.activeObstacles.add(flock);
  game.world.add(flock);
  game.update(0);
  await game.ready();

  var pressed = false;
  var released = false;
  var heldFor = 0.0;
  for (var f = 0; f < 60 * 8 && flock.position.x + flock.size.x > player.position.x - 80; f++) {
    final gap = flock.position.x - (player.position.x + player.size.x);
    if (!pressed && pressAt != null && gap <= pressAt) {
      player.pressJump();
      pressed = true;
    }
    if (pressed && !released) {
      heldFor += 1 / 60;
      if (heldFor >= hold) {
        player.releaseJump();
        released = true;
      }
    }
    game.update(1 / 60);
    if (flock.isRemoved) break;
  }
  return hits > 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Where in a shift, and whether both speed buffs are running: 200 px/s up
  // to about 780.
  const stages = <(String, double, bool)>[
    ('the start of a shift', 0.0, false),
    ('500 m', 500.0, false),
    ('1,000 m', 1000.0, false),
    ('1,500 m', 1500.0, false),
    ('top speed', 2000.0, false),
    ('top speed with two speed buffs', 2000.0, true),
  ];

  // A roosting flock took off when the courier came within 180 px, at any
  // speed. That is 0.9 s of warning at the start of a shift and a third of
  // a second at top speed, by which time the birds were at head height. So
  // early on the way through was to keep running, and from about 1,500 m
  // the same flock hit a courier who kept running and could not be hopped
  // at all: of the two test players, both were hit by half the flocks they
  // met. The take-off is now a fixed time ahead of the courier, whatever
  // the speed.
  group('A pigeon flock takes off a set time ahead of the courier', () {
    test('at the start of a shift that is a little earlier than it was', () {
      final flock = ObstacleComponent(type: ObstacleType.pigeonFlock)..streetSpeed = 200.0;
      expect(flock.pigeonStartleRange, closeTo(240.0, 0.001));
      expect(flock.pigeonStartleRange, greaterThanOrEqualTo(ObstacleComponent.pigeonStartleDistance));
    });

    test('at speed it is further out, never nearer', () {
      final flock = ObstacleComponent(type: ObstacleType.pigeonFlock);
      for (final speed in [0.0, 100.0, 200.0, 375.0, 550.0, 780.0]) {
        flock.streetSpeed = speed;
        expect(flock.pigeonStartleRange, greaterThanOrEqualTo(180.0));
        final timed = speed * ObstacleComponent.pigeonStartleSeconds;
        expect(flock.pigeonStartleRange, closeTo(timed < 180.0 ? 180.0 : timed, 0.001));
      }
    });

    test('the game tells every hazard how fast the street is going', () async {
      final game = await _emptyStreet(2000.0);
      final flock = ObstacleComponent(
        type: ObstacleType.pigeonFlock,
        position: Vector2(900.0, CourierGame.groundY - 28.0),
      );
      game.activeObstacles.add(flock);
      game.world.add(flock);
      game.update(1 / 60);
      expect(game.currentSpeed, greaterThan(500.0));
      expect(flock.streetSpeed, equals(game.currentSpeed));
    });
  });

  group('What gets a courier past a flock is the same at every speed', () {
    for (final stage in stages) {
      test('just keep running, at ${stage.$1}', () async {
        expect(await _isHit(stage.$2, null, 0, boosted: stage.$3), isFalse);
      });
    }

    for (final stage in stages) {
      test('or hop, whenever: at ${stage.$1}', () async {
        var safe = 0;
        var tried = 0;
        for (var gap = 40.0; gap <= 400.0; gap += 40.0) {
          tried++;
          if (!await _isHit(stage.$2, gap, 0.04, boosted: stage.$3)) safe++;
        }
        expect(safe, equals(tried), reason: '$safe of $tried hops got past');
      });
    }

    test('a full leap into the birds is still a hit somewhere: they are a hazard', () async {
      var hits = 0;
      for (final stage in stages) {
        for (var gap = 40.0; gap <= 400.0; gap += 40.0) {
          if (await _isHit(stage.$2, gap, 0.30, boosted: stage.$3)) hits++;
        }
      }
      expect(hits, greaterThan(10));
    });
  });
}
