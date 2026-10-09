import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/cement_mixer_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CementMixerComponent Unit Tests (Issue #126)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final mixer = CementMixerComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
      );

      expect(mixer.size.x, equals(64.0));
      expect(mixer.size.y, equals(56.0));
      expect(mixer.groundY, equals(460.0));
      expect(mixer.hasHopped, isFalse);
      expect(mixer.drumRotation, equals(0.0));
      expect(mixer.shouldRecycle, isFalse);
      expect(mixer.mixerTopY, equals(404.0));
      expect(mixer.centerWorldPosition, equals(Vector2(332.0, 432.0)));
      expect(mixer.drumCenterWorld, equals(Vector2(332.0, 426.4)));
      expect(mixer.hopApexWorld, equals(Vector2(332.0, 414.08)));
    });

    test('the drum churns forward as time passes', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));

      mixer.update(0.5);
      expect(mixer.drumRotation, closeTo(1.2, 0.001)); // 2.4 rad/s half a second

      mixer.update(0.5);
      expect(mixer.drumRotation, closeTo(2.4, 0.001));
    });

    test('checkMixerHop ignores courier outside horizontal bounds', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 420.0;

      final farLeft = mixer.checkMixerHop(
        Vector2(100.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      final farRight = mixer.checkMixerHop(
        Vector2(380.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(mixer.hasHopped, isFalse);
    });

    test('checkMixerHop ignores courier outside the drum window', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      sim.currentY = 340.0; // Well above the drum hood
      final tooHigh = mixer.checkMixerHop(
        Vector2(310.0, 300.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      sim.currentY = 470.0; // Below the pavement line
      final tooLow = mixer.checkMixerHop(
        Vector2(310.0, 430.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(mixer.hasHopped, isFalse);
    });

    test('a grounded courier runs past without triggering the mixer', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final triggered = mixer.checkMixerHop(
        Vector2(310.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isFalse);
      expect(mixer.hasHopped, isFalse,
          reason: 'a run-past must leave the mixer fresh for a real hop');
      expect(sim.verticalVelocity, equals(0.0));

      // The same mixer still hops the courier once they are airborne.
      sim.isGrounded = false;
      sim.currentY = 420.0;
      expect(
        mixer.checkMixerHop(Vector2(310.0, 370.0), Vector2(32.0, 40.0), sim),
        isTrue,
      );
      expect(sim.verticalVelocity, equals(230.0));
    });

    test('an airborne courier gets the +230 px/s mortar hop once', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      var hops = 0;
      final mixerWithCallback = CementMixerComponent(
        position: Vector2(300.0, 404.0),
        onHop: () => hops++,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 420.0;
      sim.verticalVelocity = -40.0; // Coming down onto the drum

      final triggered = mixerWithCallback.checkMixerHop(
        Vector2(310.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(triggered, isTrue);
      expect(sim.verticalVelocity, equals(230.0));
      expect(mixerWithCallback.hasHopped, isTrue);
      expect(hops, equals(1));

      final secondCheck = mixerWithCallback.checkMixerHop(
        Vector2(310.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);
      expect(hops, equals(1), reason: 'one hop per mixer, not one per frame');

      // The untouched fixture stays idle.
      expect(mixer.hasHopped, isFalse);
    });

    test('a fixture scrolled well past the camera recycles', () {
      final mixer = CementMixerComponent(position: Vector2(-300.0, 404.0));
      expect(mixer.shouldRecycle, isTrue);
    });

    test('a mixer still on screen is not recycled', () {
      final mixer = CementMixerComponent(position: Vector2(-100.0, 404.0));
      expect(mixer.shouldRecycle, isFalse,
          reason: 'its right edge is still 36 px inside the screen');
    });

    test('render draws the churning drum, chassis, engine and chute without errors', () {
      final mixer = CementMixerComponent(
        position: Vector2(100.0, 404.0),
        groundY: 460.0,
      );
      mixer.update(0.25); // A part-turn so the ribs are mid-rotation.

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => mixer.render(canvas), returnsNormally);
      recorder.endRecording();
    });
  });

  group('ParticleEffectComponent.cementMixerSplashes Tests (Issue #126)', () {
    test('creates wet aggregate, water and dust particles', () {
      final effect = ParticleEffectComponent.cementMixerSplashes(
        position: Vector2(250.0, 380.0),
        count: 26,
      );

      expect(effect.particles.length, equals(26));
      expect(effect.isFinished, isFalse);
      expect(effect.particles.every((p) => p.gravity == 260.0), isTrue,
          reason: 'cement spatter falls, it does not float');

      effect.update(0.1);
      expect(effect.isFinished, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => effect.render(canvas), returnsNormally);
      recorder.endRecording();

      // The longest-lived spatter is 0.75 s old after the two steps above.
      effect.update(0.8);
      expect(effect.isFinished, isTrue);
    });
  });

  group('GameState Cement Mixer Logic Tests (Issue #126)', () {
    test('recordCementMixerHop increases counters, tips, and fires callback', () {
      final gs = GameState();
      gs.startRun();

      CementMixerEvent? capturedEvent;
      gs.onCementMixerHop = (event) {
        capturedEvent = event;
      };

      final initialTips = gs.tips;
      final event = gs.recordCementMixerHop(baseTips: 34);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(34));
      expect(event.multiplier, equals(1.2)); // Streak 1 = 1.2x
      expect(event.totalTips, equals(41)); // (34 * 1.2).round() = 41
      expect(event.stuntStreak, equals(1));
      expect(gs.cementMixerHopsInRun, equals(1));
      expect(gs.tips, equals(initialTips + 41));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.mixersInRun, equals(1));
    });

    test('recordCementMixerHop scales tips with the stunt multiplier', () {
      final gs = GameState();
      gs.startRun();
      gs.recordStunt(clearance: 10.0); // streak 1

      final initialTips = gs.tips;
      final event = gs.recordCementMixerHop(baseTips: 34); // streak 2 -> 1.5x

      expect(event, isNotNull);
      expect(event!.multiplier, equals(1.5));
      expect(event.totalTips, equals(51)); // (34 * 1.5).round() = 51
      expect(event.stuntStreak, equals(2));
      expect(gs.tips, equals(initialTips + 51));
      expect(gs.cementMixerHopsInRun, equals(1));
    });

    test('recordCementMixerHop returns null when the run is not active', () {
      final gs = GameState();

      final event = gs.recordCementMixerHop();

      expect(event, isNull);
      expect(gs.cementMixerHopsInRun, equals(0));
    });

    test('startRun resets the cement mixer hop counter', () {
      final gs = GameState();
      gs.startRun();
      gs.recordCementMixerHop();
      gs.recordCementMixerHop();
      expect(gs.cementMixerHopsInRun, equals(2));

      gs.startRun();
      expect(gs.cementMixerHopsInRun, equals(0));
    });
  });

  group('WorldChunkManager Cement Mixer Generation Tests (Issue #126)', () {
    test('generateChunk does not spawn cement mixers before the 85m milestone', () {
      final manager = WorldChunkManager(random: math.Random(7));
      var count = 0;

      for (var i = 0; i < 20; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 40.0, // Before 85m
        );
        count += chunk.cementMixers.length;
      }

      expect(count, equals(0));
    });

    test('generateChunk can spawn a cement mixer past 85m, based on the pavement', () {
      final manager = WorldChunkManager(random: math.Random(11));
      var found = false;

      for (var i = 0; i < 200; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 150.0, // Past 85m
        );
        if (chunk.cementMixers.isNotEmpty) {
          found = true;
          final cm = chunk.cementMixers.first;
          expect(cm.y, equals(460.0 - 56.0));
          expect(cm.width, equals(64.0));
          expect(cm.height, equals(56.0));
          expect(cm.x, greaterThanOrEqualTo(75.0));
          expect(cm.x + cm.width, lessThanOrEqualTo(960.0 + 1e-9));
          break;
        }
      }

      expect(found, isTrue);
    });

    test('the spawn gate opens exactly at 85 m', () {
      // 84 m: nothing, over many seeds and chunks.
      for (var seed = 0; seed < 30; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var i = 0; i < 10; i++) {
          manager.reset();
          final chunk = manager.generateChunk(
            startX: 0.0,
            chunkWidth: 960.0,
            groundY: 460.0,
            speed: 200.0,
            distanceMeters: 84.0,
          );
          expect(chunk.cementMixers, isEmpty,
              reason: 'no mixer may spawn before 85 m (seed $seed)');
        }
      }

      // 85 m: the gate is open; at least one mixer appears across the seeds.
      var found = false;
      for (var seed = 0; seed < 30 && !found; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var i = 0; i < 10 && !found; i++) {
          manager.reset();
          final chunk = manager.generateChunk(
            startX: 0.0,
            chunkWidth: 960.0,
            groundY: 460.0,
            speed: 200.0,
            distanceMeters: 85.0,
          );
          found = chunk.cementMixers.isNotEmpty;
        }
      }
      expect(found, isTrue, reason: 'a mixer must be possible at 85 m');
    });

    test('a station chunk never carries a cement mixer', () {
      var stations = 0;

      // The generator shape from subway_station_chunk_test: whole streets
      // out to 3,000 m, where stations actually appear.
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
            expect(chunk.cementMixers, isEmpty,
                reason: 'a cement mixer must not stand on a station platform');
          }
        }
      }

      expect(stations, greaterThan(0), reason: 'the street must have stations');
    });
  });

  group('CourierGame Cement Mixer Integration Tests (Issue #126)', () {
    test('CourierGame spawns and clears activeCementMixers across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final mixer = CementMixerComponent(
        position: Vector2(300.0, 404.0),
        width: 64.0,
        height: 56.0,
        groundY: 460.0,
      );
      game.activeCementMixers.add(mixer);
      game.world.add(mixer);

      expect(game.activeCementMixers.contains(mixer), isTrue);
      expect(game.world.children.contains(mixer), isTrue);

      game.restartRun();
      expect(game.activeCementMixers.contains(mixer), isFalse);
      expect(game.world.children.contains(mixer), isFalse);
    });

    test('CementMixerComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final mixer = CementMixerComponent(
        position: Vector2(500.0, 404.0),
        width: 64.0,
        height: 56.0,
        groundY: 460.0,
      );
      game.activeCementMixers.add(mixer);
      game.world.add(mixer);

      final initialX = mixer.position.x;
      game.update(0.1);
      expect(mixer.position.x, lessThan(initialX));
    });

    test('a courier bounding off the drum hops, earns tips, barks and splatters', () async {
      final backend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: backend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final barkLines = <String>[];
      game.audio.addCourierBarkListener((type, line) => barkLines.add(line));

      final mixer = CementMixerComponent(
        position: Vector2(game.player.position.x + 10.0, 404.0),
        width: 64.0,
        height: 56.0,
        groundY: 460.0,
      );
      game.activeCementMixers.add(mixer);
      game.world.add(mixer);

      // Coming down onto the drum with the feet inside the hop window.
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 400.0;
      game.player.simulator.verticalVelocity = -30.0;

      final initialHops = game.gameState.cementMixerHopsInRun;
      game.update(0.016);

      expect(mixer.hasHopped, isTrue);
      expect(game.gameState.cementMixerHopsInRun, equals(initialHops + 1));
      expect(game.player.simulator.verticalVelocity, equals(230.0));

      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(
        floatingTexts.any((ft) => ft.text.contains('CEMENT MIXER HOP')),
        isTrue,
      );
      expect(backend.playedSfx, contains(GameAudioController.sfxBarkStunt));
      expect(barkLines, contains('Still setting!'));

      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(
        particles.any((p) => p.particles.length == 26),
        isTrue,
        reason: 'the cement splatter effect must be the one spawned',
      );
    });

    test('a grounded run-past awards nothing and leaves the mixer fresh', () async {
      final backend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: backend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final mixer = CementMixerComponent(
        position: Vector2(game.player.position.x + 10.0, 404.0),
        width: 64.0,
        height: 56.0,
        groundY: 460.0,
      );
      game.activeCementMixers.add(mixer);
      game.world.add(mixer);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;

      final initialHops = game.gameState.cementMixerHopsInRun;
      game.update(0.016);

      expect(mixer.hasHopped, isFalse);
      expect(game.gameState.cementMixerHopsInRun, equals(initialHops));
      expect(
        game.world.children
            .whereType<FloatingTextComponent>()
            .any((ft) => ft.text.contains('CEMENT MIXER HOP')),
        isFalse,
      );
      expect(backend.playedSfx, isNot(contains(GameAudioController.sfxBarkStunt)));
    });

    test('an offscreen cement mixer is recycled', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final mixer = CementMixerComponent(
        position: Vector2(-260.0, 404.0), // -260 + 64 = -196 < -180
        width: 64.0,
        height: 56.0,
        groundY: 460.0,
      );
      game.activeCementMixers.add(mixer);
      game.world.add(mixer);

      expect(game.activeCementMixers.contains(mixer), isTrue);
      game.update(0.1);
      expect(game.activeCementMixers.contains(mixer), isFalse);
    });
  });

  group('GameOverModal Cement Mixer Badge Tests (Issue #126)', () {
    testWidgets('renders the singular badge when cementMixersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              cementMixersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_cement_mixer_badge')), findsOneWidget);
      expect(find.text('1 CEMENT MIXER HOP'), findsOneWidget);
    });

    testWidgets('renders the plural badge when cementMixersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 680,
              tips: 340,
              isNewRecord: false,
              careerTips: 1800,
              cementMixersCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_cement_mixer_badge')), findsOneWidget);
      expect(find.text('3 CEMENT MIXER HOPS'), findsOneWidget);
    });

    testWidgets('omits the badge when cementMixersCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 40,
              isNewRecord: false,
              careerTips: 500,
              cementMixersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_cement_mixer_badge')), findsNothing);
    });
  });
}
