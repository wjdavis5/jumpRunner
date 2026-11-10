import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/wrecking_ball_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

class MockAudioBackend implements AudioPlayerInterface {
  final List<String> playedSfx = [];

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    playedSfx.add(file);
  }

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {}

  @override
  Future<void> stopBgm() async {}

  @override
  Future<void> setBgmVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopAmbience() async {}

  @override
  Future<void> setAmbienceVolume(double volume) async {}

  @override
  Future<bool> startLayer(String file, {double volume = 0.0}) async => true;

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}

  @override
  Future<void> setLayerPlaybackRate(double rate) async {}
}

WreckingBallComponent _ballAt(Vector2 position, {double phase = 0.0}) =>
    WreckingBallComponent(
      position: position,
      width: 300.0,
      height: 380.0,
      groundY: 460.0,
      phase: phase,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WreckingBallComponent Unit Tests (Issue #73)', () {
    test('initializes with default dimensions and a deterministic swing', () {
      final ball = _ballAt(Vector2(200.0, 80.0), phase: 0.0);

      expect(ball.size.x, equals(300.0));
      expect(ball.size.y, equals(380.0));
      expect(ball.groundY, equals(460.0));
      expect(ball.swingTime, equals(0.0));
      expect(ball.swingAngle, equals(0.0), reason: 'phase 0 hangs straight down');
      expect(ball.shouldRecycle, isFalse);

      // The low point mows a grounded courier: the ball's bottom clears
      // the sidewalk by 10 px, and a well-timed hop clears the arc.
      final low = ball.ballCenterWorld;
      expect(low.y, closeTo(460.0 - 36.0, 0.5));
    });

    test('the pendulum sweeps within its amplitude on a fixed period', () {
      final ball = _ballAt(Vector2(200.0, 80.0), phase: 0.0);

      var maxAngle = 0.0;
      for (var i = 0; i < 240; i++) {
        ball.update(1 / 60);
        maxAngle = math.max(maxAngle, ball.swingAngle.abs());
      }
      expect(maxAngle, closeTo(WreckingBallComponent.swingAmplitude, 0.01));
      expect(
        maxAngle,
        lessThanOrEqualTo(WreckingBallComponent.swingAmplitude + 0.001),
      );

      // A fresh ball returns to its start after exactly one period.
      final full = _ballAt(Vector2(200.0, 80.0), phase: 0.0);
      full.update(WreckingBallComponent.swingPeriod);
      expect(full.swingAngle, closeTo(0.0, 0.01));
    });

    test('phase offsets stagger consecutive balls', () {
      final a = _ballAt(Vector2(200.0, 80.0), phase: 0.0);
      final b = _ballAt(Vector2(600.0, 80.0), phase: math.pi);

      a.update(0.6); // Quarter period.
      b.update(0.6);

      // Quarter period with phase 0 is near max deflection; with phase pi it
      // is heading back through center: the angles must differ in sign.
      expect(a.swingAngle, greaterThan(0.0));
      expect(b.swingAngle, lessThan(0.0));
    });

    test('the ball crushes a courier at its low point', () {
      final ball = _ballAt(Vector2(200.0, 80.0), phase: 0.0);
      // Straight down: ball center at (350, 379), radius 26.
      final center = ball.ballCenterWorld;

      final hit = ball.checkBallHit(
        Vector2(center.x - 16.0, center.y + 4.0),
        Vector2(32.0, 40.0),
      );
      expect(hit, isTrue);
    });

    test('a courier on the far side of the swing is safe', () {
      final ball = _ballAt(Vector2(200.0, 80.0), phase: 0.0);
      ball.update(WreckingBallComponent.swingPeriod / 4); // Max deflection.

      final ballCenter = ball.ballCenterWorld;
      // The courier stands under the anchor, where the ball was at t=0.
      final anchorX = ball.position.x + ball.anchorLocal.dx;
      final courierX = anchorX - 16.0;
      final courierY = ballCenter.y - 20.0;

      expect(ball.checkBallHit(Vector2(courierX, courierY), Vector2(32.0, 40.0)),
          isFalse);
    });

    test('a courier clear of the sweep is never touched', () {
      final ball = _ballAt(Vector2(200.0, 80.0), phase: 0.0);

      // High in the air, above the whole arc.
      final high = ball.checkBallHit(
        Vector2(340.0, 100.0),
        Vector2(32.0, 40.0),
      );
      expect(high, isFalse);

      // Far past the sweep on the street.
      final behind = ball.checkBallHit(
        Vector2(20.0, 420.0),
        Vector2(32.0, 40.0),
      );
      expect(behind, isFalse);
    });

    test('recycles once fully past the left edge, and not before', () {
      final ball = _ballAt(Vector2(-100.0, 80.0));
      expect(ball.shouldRecycle, isFalse,
          reason: 'the mast at -100 still reaches into view');

      ball.position = Vector2(-490.0, 80.0);
      expect(ball.shouldRecycle, isTrue);
    });
  });

  group('WorldChunkManager Wrecking Ball Spawning Tests (Issue #73)', () {
    test('no wrecking ball spawns before 140 m', () {
      var anySpawned = false;
      for (var seed = 0; seed < 30 && !anySpawned; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 139.0,
        );
        anySpawned = chunk.wreckingBalls.isNotEmpty;
      }
      expect(anySpawned, isFalse, reason: 'the gate opens at 140 m');
    });

    test('a wrecking ball is possible at 140 m with a valid phase', () {
      var found = false;
      for (var seed = 0; seed < 60 && !found; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 140.0,
        );
        found = chunk.wreckingBalls.isNotEmpty;

        for (final wb in chunk.wreckingBalls) {
          expect(wb.phase, inInclusiveRange(0.0, 2 * math.pi));
          expect(wb.y, equals(80.0), reason: 'the mast stands on the pavement');
        }
      }
      expect(found, isTrue, reason: 'a wrecking ball must be possible at 140 m');
    });

    test('a station chunk never carries a wrecking ball', () {
      var stations = 0;

      for (var seed = 0; seed < 40 && stations < 20; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 3000.0 && stations < 20; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 1440.0,
            speed: manager.calculateSpeed(meters),
            distanceMeters: meters,
          );
          if (chunk.subwayStations.isNotEmpty) {
            stations++;
            expect(chunk.wreckingBalls, isEmpty,
                reason: 'a demolition crane must not stand on a platform');
          }
        }
      }

      expect(stations, greaterThan(0), reason: 'the street must have stations');
    });
  });

  group('CourierGame Wrecking Ball Integration Tests (Issue #73)', () {
    test('CourierGame spawns and clears activeWreckingBalls across lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final ball = _ballAt(Vector2(200.0, 80.0));
      game.activeWreckingBalls.add(ball);
      game.world.add(ball);

      expect(game.activeWreckingBalls.contains(ball), isTrue);
      expect(game.world.children.contains(ball), isTrue);

      game.restartRun();
      expect(game.activeWreckingBalls.contains(ball), isFalse);
      expect(game.world.children.contains(ball), isFalse);
    });

    test('WreckingBallComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final ball = _ballAt(Vector2(500.0, 80.0));
      game.activeWreckingBalls.add(ball);
      game.world.add(ball);

      final initialX = ball.position.x;
      game.update(0.1);
      expect(ball.position.x, lessThan(initialX));
    });

    test('a swing through the courier knocks a package loose', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      // The ball hangs straight down where the courier is about to run.
      final ball = _ballAt(
        Vector2(game.player.position.x - 134.0, 80.0),
        phase: 0.0,
      );
      game.activeWreckingBalls.add(ball);
      game.world.add(ball);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;

      final packagesBefore = game.gameState.packages;
      game.update(0.016);

      expect(game.gameState.packages, equals(packagesBefore - 1));
      expect(game.player.isInvulnerable, isTrue,
          reason: 'the hit grants the standard damage invulnerability');
    });

    test('invulnerability holds through repeated contact with the same swing', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final ball = _ballAt(
        Vector2(game.player.position.x - 134.0, 80.0),
        phase: 0.0,
      );
      game.activeWreckingBalls.add(ball);
      game.world.add(ball);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;

      final packagesBefore = game.gameState.packages;
      game.update(0.016);
      game.update(0.016);
      game.update(0.016);

      expect(game.gameState.packages, equals(packagesBefore - 1),
          reason: 'one swing, one hit: invulnerability gates the rest');
    });

    test('the mast is background: a courier with the ball swung away is untouched', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      // Ball at max deflection away from the courier running under the anchor.
      final ball = _ballAt(
        Vector2(game.player.position.x - 134.0, 80.0),
        phase: 0.0,
      );
      ball.update(WreckingBallComponent.swingPeriod / 4);
      game.activeWreckingBalls.add(ball);
      game.world.add(ball);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;

      final packagesBefore = game.gameState.packages;
      game.update(0.016);

      expect(game.gameState.packages, equals(packagesBefore));
      expect(game.player.isInvulnerable, isFalse);
    });
  });
}
