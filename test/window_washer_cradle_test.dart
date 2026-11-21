import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/window_washer_cradle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'support/bare_street.dart';

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

const double groundY = 460.0;

WindowWasherCradleComponent _cradleAt(
  Vector2 position, {
  double phase = 0.0,
}) =>
    WindowWasherCradleComponent(
      position: position,
      width: 120.0,
      height: 300.0,
      groundY: groundY,
      phase: phase,
    );

/// The courier's foot center x on screen: the catch window samples there.
double footXOf(CourierGame game) =>
    game.player.position.x + (game.player.size.x / 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowWasherCradleComponent Unit Tests (Issue #83)', () {
    test('initializes with rig geometry and an unridden state', () {
      final cradle = _cradleAt(Vector2(200.0, groundY - 300.0));

      expect(cradle.size.x, equals(120.0));
      expect(cradle.size.y, equals(300.0));
      expect(cradle.groundY, equals(groundY));
      expect(cradle.hasAwardedRide, isFalse);
      expect(cradle.shouldRecycle, isFalse);
      expect(cradle.platformLowY, closeTo(groundY - 92.0, 0.001),
          reason: 'the platform never crowds the sidewalk');
      expect(cradle.platformSpanWorld.width, closeTo(110.0, 0.001));
    });

    test('the platform bobs from the bottom up to its apex and back', () {
      final cradle = _cradleAt(Vector2(200.0, groundY - 300.0), phase: 0.0);

      expect(cradle.surfaceY, closeTo(cradle.platformLowY, 0.001),
          reason: 'a fresh rig hangs at its lowest point');
      expect(cradle.surfaceY, greaterThan(groundY - 92.0 - 1.0),
          reason: 'still well above a walking courier');

      cradle.update(WindowWasherCradleComponent.bobPeriod / 2);
      expect(cradle.surfaceY,
          closeTo(cradle.platformLowY - WindowWasherCradleComponent.bobAmplitude, 0.01),
          reason: 'half a period carries it to the apex');

      cradle.update(WindowWasherCradleComponent.bobPeriod / 2);
      expect(cradle.surfaceY, closeTo(cradle.platformLowY, 0.01),
          reason: 'a full period returns it to the bottom');

      // The bob never leaves its band.
      var lowest = cradle.surfaceY;
      var highest = cradle.surfaceY;
      for (var i = 0; i < 240; i++) {
        cradle.update(1 / 60);
        lowest = math.max(lowest, cradle.surfaceY);
        highest = math.min(highest, cradle.surfaceY);
      }
      expect(highest,
          greaterThanOrEqualTo(cradle.platformLowY - WindowWasherCradleComponent.bobAmplitude - 0.01));
      expect(lowest, lessThanOrEqualTo(cradle.platformLowY + 0.01));
    });

    test('phase offsets stagger neighbouring rigs', () {
      final a = _cradleAt(Vector2(200.0, groundY - 300.0), phase: 0.0);
      final b = _cradleAt(Vector2(600.0, groundY - 300.0), phase: math.pi);

      a.update(0.55); // Quarter period: both platforms sit at mid-travel...
      b.update(0.55);

      // ...but phase 0 is still rising while phase pi is already falling.
      a.update(0.05);
      b.update(0.05);
      expect(a.surfaceY, lessThan(b.surfaceY - 5.0),
          reason: 'a quarter period in, one rig climbs while the other sags');
    });

    test('recycles once fully past the left edge, and not before', () {
      final cradle = _cradleAt(Vector2(-100.0, groundY - 300.0));
      expect(cradle.shouldRecycle, isFalse,
          reason: 'the rig at -100 still reaches into view');

      cradle.position = Vector2(-310.0, groundY - 300.0);
      expect(cradle.shouldRecycle, isTrue);
    });
  });

  group('WorldChunkManager Cradle Spawning Tests (Issue #83)', () {
    test('no cradle spawns before 170 m', () {
      var anyCradle = false;
      for (var seed = 0; seed < 40 && !anyCradle; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 169.0 && !anyCradle; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 0.0,
            chunkWidth: 960.0,
            groundY: groundY,
            speed: 200.0,
            distanceMeters: meters,
          );
          anyCradle = chunk.washerCradles.isNotEmpty;
        }
      }
      expect(anyCradle, isFalse, reason: 'the gate opens at 170 m');
    });

    test('a cradle is possible past the gate, clear of sky watches', () {
      var found = 0;
      for (var seed = 0; seed < 60 && found < 3; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 4000.0; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 1440.0,
            speed: manager.calculateSpeed(meters),
            distanceMeters: meters,
          );
          if (chunk.washerCradles.isEmpty) continue;
          found++;

          // One sky watch at a time: the cradle rules out the others.
          expect(chunk.scaffoldings, isEmpty,
              reason: 'no cradle on a scaffold route');
          expect(chunk.wreckingBalls, isEmpty,
              reason: 'no cradle under a wrecking ball');
          expect(chunk.subwayStations, isEmpty,
              reason: 'no cradle on a platform chunk');

          for (final c in chunk.washerCradles) {
            expect(c.width, equals(120.0));
            expect(c.height, equals(300.0));
            expect(c.phase, inInclusiveRange(0.0, 2 * math.pi));

            // The apex tips float above the platform span.
            final apexCoins = chunk.pickups.where(
              (p) =>
                  p.x >= c.x &&
                  p.x <= c.x + c.width &&
                  p.y < groundY - 100.0,
            );
            expect(apexCoins.length, greaterThanOrEqualTo(2),
                reason: 'the ride is lined with tips at the top');
          }
          break;
        }
      }
      expect(found, greaterThanOrEqualTo(3),
          reason: 'the street must carry cradles');
    });
  });

  group('GameState Cradle Ride Tests (Issue #83)', () {
    test('recording a ride pays streak-scaled tips and counts it', () {
      final state = GameState();
      state.startRun();

      final before = state.tips;
      final event = state.recordCradleRide(apexHeightMeters: 7.9);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(18));
      expect(event.totalTips, equals((18 * state.stuntMultiplier).round()));
      expect(event.apexHeightMeters, closeTo(7.9, 0.001));
      expect(state.cradleRidesInRun, equals(1));
      expect(state.tips, equals(before + event.totalTips));
      expect(state.stuntStreak, equals(1), reason: 'the ride is a stunt');
    });

    test('an energy boost doubles the ride tips', () {
      final state = GameState();
      state.startRun();
      state.energyDrinkTimer = 99.0;

      final event = state.recordCradleRide(apexHeightMeters: 7.9);
      expect(event!.totalTips, equals(((18 * state.stuntMultiplier).round()) * 2));
    });

    test('a ride is only recorded mid-run', () {
      final state = GameState();
      expect(state.recordCradleRide(apexHeightMeters: 7.9), isNull);
      expect(state.cradleRidesInRun, equals(0));
    });
  });

  group('CourierGame Cradle Integration Tests (Issue #83)', () {
    test('CourierGame spawns and clears activeWasherCradles across lifecycle',
        () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final cradle = _cradleAt(Vector2(900.0, groundY - 300.0));
      game.activeWasherCradles.add(cradle);
      game.world.add(cradle);

      expect(game.activeWasherCradles.contains(cradle), isTrue);
      expect(game.world.children.contains(cradle), isTrue);

      game.restartRun();
      expect(game.activeWasherCradles.contains(cradle), isFalse);
      expect(game.world.children.contains(cradle), isFalse);
    });

    test('WindowWasherCradleComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final cradle = _cradleAt(Vector2(900.0, groundY - 300.0));
      game.activeWasherCradles.add(cradle);
      game.world.add(cradle);

      final initialX = cradle.position.x;
      game.update(0.1);
      expect(cradle.position.x, lessThan(initialX));
    });

    test('a courier falling onto the platform lands and rides the bob',
        () async {
      final game = await bareStreetGame(0);

      final fx = footXOf(game);
      final cradle = _cradleAt(Vector2(fx - 60.0, groundY - 300.0));
      game.activeWasherCradles.add(cradle);
      game.world.add(cradle);

      // Drop the courier from just above the platform, falling.
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = cradle.surfaceY - 24.0;
      game.player.simulator.verticalVelocity = -60.0;
      game.player.setTargetSurfaceY(groundY);

      var landed = false;
      for (var i = 0; i < 30 && !landed; i++) {
        game.update(1 / 60);
        landed = game.player.simulator.isGrounded &&
            (game.player.simulator.currentY - cradle.surfaceY).abs() < 1.5;
      }

      expect(landed, isTrue, reason: 'the courier lands on the platform');

      // Riding: the courier tracks the bob while the span is overhead.
      for (var i = 0; i < 5; i++) {
        game.update(1 / 60);
        expect(game.player.simulator.isGrounded, isTrue);
        expect(game.player.simulator.currentY,
            closeTo(cradle.surfaceY, 1.5),
            reason: 'the ride carries the courier with the platform');
      }
    });

    test('riding across the apex pays the timing bonus once', () async {
      final game = await bareStreetGame(0);

      final fx = footXOf(game);
      // The rig's span just covers the courier (its right edge sits 110 px
      // of scroll away) and rises through its apex ~0.30 s in, mid-ride.
      final cradle =
          _cradleAt(Vector2(fx - 5.0, groundY - 300.0), phase: 2.284);
      game.activeWasherCradles.add(cradle);
      game.world.add(cradle);

      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = cradle.surfaceY - 24.0;
      game.player.simulator.verticalVelocity = -60.0;
      game.player.setTargetSurfaceY(groundY);

      String? spoken;
      game.audio.addCourierBarkListener((type, line) => spoken = line);
      final tipsBefore = game.gameState.tips;
      var awarded = false;
      for (var i = 0; i < 40 && !awarded; i++) {
        game.update(1 / 60);
        awarded = game.gameState.cradleRidesInRun > 0;
      }

      expect(awarded, isTrue, reason: 'the ride crossed the bob apex');
      expect(game.gameState.cradleRidesInRun, equals(1));
      expect(cradle.hasAwardedRide, isTrue);
      expect(game.gameState.tips, greaterThan(tipsBefore));
      expect(spoken, equals('Squeaky clean!'),
          reason: 'the courier announces the ride the way every stunt does');
    });

    test('jumping off the platform ends the ride cleanly', () async {
      final game = await bareStreetGame(0);

      final fx = footXOf(game);
      final cradle = _cradleAt(Vector2(fx - 60.0, groundY - 300.0), phase: 0.0);
      game.activeWasherCradles.add(cradle);
      game.world.add(cradle);

      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = cradle.surfaceY - 24.0;
      game.player.simulator.verticalVelocity = -60.0;
      game.player.setTargetSurfaceY(groundY);
      var landed = false;
      for (var i = 0; i < 30 && !landed; i++) {
        game.update(1 / 60);
        landed = game.player.simulator.isGrounded;
      }
      expect(landed, isTrue);

      game.player.simulator.startJump();
      game.update(1 / 60);
      game.update(1 / 60);

      expect(game.player.simulator.isGrounded, isFalse,
          reason: 'the courier leaps off into the air');
      expect(game.gameState.cradleRidesInRun, equals(0),
          reason: 'bailing before the apex earns nothing');
    });

    test('a courier at street level walks under the rig untouched', () async {
      final game = await bareStreetGame(0);

      final fx = footXOf(game);
      final cradle = _cradleAt(Vector2(fx - 60.0, groundY - 300.0), phase: 0.0);
      game.activeWasherCradles.add(cradle);
      game.world.add(cradle);

      expect(cradle.surfaceY, greaterThan(groundY - 100.0),
          reason: 'the platform rides well above a walking courier');

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = groundY;
      game.player.resetTargetSurfaceY();

      game.update(1 / 60);
      game.update(1 / 60);

      expect(game.player.simulator.isGrounded, isTrue);
      expect(game.player.simulator.currentY, closeTo(groundY, 0.5));
      expect(game.gameState.cradleRidesInRun, equals(0));
    });
  });
}
