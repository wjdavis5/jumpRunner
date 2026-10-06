import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/fire_hydrant_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/hud_overlay.dart';

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
  Future<void> startLayer(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FireHydrantComponent Unit Tests (Issue #111)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        width: 86.0,
        height: 54.0,
        groundY: 460.0,
      );

      expect(hydrant.size.x, equals(86.0));
      expect(hydrant.size.y, equals(54.0));
      expect(hydrant.hasTriggered, isFalse);
      expect(hydrant.hydrantApexWorldY, equals(460.0 - 38.0)); // 422.0
      expect(hydrant.sprayApexWorld, equals(Vector2(300.0 + 46.0, 460.0 - 26.0)));
      expect(hydrant.centerWorldPosition, equals(Vector2(343.0, 433.0)));
      expect(hydrant.shouldRecycle, isFalse);
    });

    test('checkInteraction ignores courier outside horizontal bounds', () {
      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 440.0;

      // Far left
      final farLeft = hydrant.checkInteraction(
        Vector2(100.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = hydrant.checkInteraction(
        Vector2(500.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(hydrant.hasTriggered, isFalse);
    });

    test('checkInteraction ignores courier outside vertical window', () {
      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Too high above interaction window (windowTop is 460 - 56 = 404)
      sim.currentY = 380.0;
      final tooHigh = hydrant.checkInteraction(
        Vector2(320.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Below ground baseline (windowBottom is 460 + 4 = 464)
      sim.currentY = 480.0;
      final tooLow = hydrant.checkInteraction(
        Vector2(320.0, 440.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(hydrant.hasTriggered, isFalse);
    });

    test('checkInteraction triggers for grounded courier without launch boost', () {
      var sprayTraversed = false;
      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
        onSprayTraverse: () {
          sprayTraversed = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final triggered = hydrant.checkInteraction(
        Vector2(320.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(sprayTraversed, isTrue);
      expect(hydrant.hasTriggered, isTrue);
      expect(sim.verticalVelocity, equals(0.0)); // Grounded courier stays sliding
    });

    test('checkInteraction triggers for airborne courier and provides water-loft launch', () {
      var sprayTraversed = false;
      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
        onSprayTraverse: () {
          sprayTraversed = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 440.0;

      final triggered = hydrant.checkInteraction(
        Vector2(320.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(sprayTraversed, isTrue);
      expect(hydrant.hasTriggered, isTrue);
      expect(sim.verticalVelocity, equals(200.0)); // Water-loft launch hop
    });

    test('checkInteraction does not re-trigger once triggered', () {
      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      expect(hydrant.checkInteraction(Vector2(320.0, 420.0), Vector2(32.0, 40.0), sim), isTrue);
      expect(hydrant.checkInteraction(Vector2(320.0, 420.0), Vector2(32.0, 40.0), sim), isFalse);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final hydrant = FireHydrantComponent(
        position: Vector2(-280.0, 406.0),
        width: 86.0,
      );
      expect(hydrant.shouldRecycle, isTrue);

      hydrant.position.x = 0.0;
      expect(hydrant.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state and after spray pulse update', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final hydrant = FireHydrantComponent(
        position: Vector2(100.0, 406.0),
      );

      expect(() => hydrant.render(canvas), returnsNormally);

      hydrant.update(0.15);
      expect(() => hydrant.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.hydrantWaterPlume Tests (Issue #111)', () {
    test('creates requested number of living particles with upward velocity and cyan/rainbow colors', () {
      final plume = ParticleEffectComponent.hydrantWaterPlume(
        position: Vector2(250.0, 420.0),
        count: 32,
      );

      expect(plume.particles.length, equals(32));
      expect(plume.isFinished, isFalse);

      for (final p in plume.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(220.0)); // Kinetic downward splash arc
        expect(p.drag, equals(0.96));
      }

      // Step until all particles expire
      plume.update(1.2);
      expect(plume.isFinished, isTrue);
    });
  });

  group('JumpPhysicsSimulator Hydroplane Glide Float Tests (Issue #111)', () {
    test('isHydroplaning modifies buoyant glide acceleration and terminal descent velocity', () {
      final normalSim = JumpPhysicsSimulator(groundY: 10000.0);
      normalSim.isGrounded = false;
      normalSim.currentY = 300.0;
      normalSim.verticalVelocity = 0.0;
      normalSim.isGliding = true;
      normalSim.isHydroplaning = false;

      final hydroSim = JumpPhysicsSimulator(groundY: 10000.0);
      hydroSim.isGrounded = false;
      hydroSim.currentY = 300.0;
      hydroSim.verticalVelocity = 0.0;
      hydroSim.isGliding = true;
      hydroSim.isHydroplaning = true;

      // Update both for 0.5s of glide descent
      normalSim.update(0.5);
      hydroSim.update(0.5);

      // Hydroplaning glide has lower descent speed (more buoyant float)
      expect(hydroSim.verticalVelocity.abs(), lessThan(normalSim.verticalVelocity.abs()));

      // Run longer to reach terminal velocities
      for (var i = 0; i < 50; i++) {
        normalSim.update(0.1);
        hydroSim.update(0.1);
      }

      // Normal terminal descent velocity is -55.0, hydroplane is -42.0
      expect(normalSim.verticalVelocity, equals(-55.0));
      expect(hydroSim.verticalVelocity, equals(-42.0));
    });
  });

  group('GameState Fire Hydrant & Hydroplane Logic Tests (Issue #111)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordFireHydrantTraverse awards tips, advances streak, and activates hydroplane buff', () {
      state.startRun();
      expect(state.hydrantsTraversedInRun, equals(0));
      expect(state.isHydroplaneActive, isFalse);
      expect(state.hydroplaneTimer, equals(0.0));

      FireHydrantEvent? capturedEvent;
      state.onFireHydrantTraverse = (e) => capturedEvent = e;

      final event = state.recordFireHydrantTraverse(baseTips: 32);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.hydrantsTraversedInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 32 * 1.2x (stuntStreak 1) = 38
      expect(state.tips, equals(38));
      expect(state.isHydroplaneActive, isTrue);
      expect(state.hydroplaneTimer, equals(3.0));
      expect(event!.hydroplaneDuration, equals(3.0));
    });

    test('updateHydroplaneTimer counts down and expires hydroplane buff', () {
      state.startRun();
      state.recordFireHydrantTraverse();
      expect(state.isHydroplaneActive, isTrue);

      state.updateHydroplaneTimer(1.5);
      expect(state.hydroplaneTimer, equals(1.5));
      expect(state.isHydroplaneActive, isTrue);

      state.updateHydroplaneTimer(1.8);
      expect(state.hydroplaneTimer, equals(0.0));
      expect(state.isHydroplaneActive, isFalse);
    });

    test('startRun resets hydrantsTraversedInRun and hydroplaneTimer', () {
      state.startRun();
      state.recordFireHydrantTraverse();
      expect(state.hydrantsTraversedInRun, equals(1));
      expect(state.hydroplaneTimer, equals(3.0));

      state.startRun();
      expect(state.hydrantsTraversedInRun, equals(0));
      expect(state.hydroplaneTimer, equals(0.0));
      expect(state.isHydroplaneActive, isFalse);
    });

    test('recordFireHydrantTraverse returns null when game is not running', () {
      final event = state.recordFireHydrantTraverse();
      expect(event, isNull);
      expect(state.hydrantsTraversedInRun, equals(0));
    });
  });

  group('CourierGame Integration with FireHydrantComponent (Issue #111)', () {
    test('CourierGame spawns and clears activeFireHydrants across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final hydrant = FireHydrantComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
      );
      game.activeFireHydrants.add(hydrant);
      game.world.add(hydrant);

      expect(game.activeFireHydrants.contains(hydrant), isTrue);
      expect(game.world.children.contains(hydrant), isTrue);

      game.restartRun();
      expect(game.activeFireHydrants.contains(hydrant), isFalse);
      expect(game.world.children.contains(hydrant), isFalse);
    });

    test('CourierGame scrolls activeFireHydrants horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final hydrant = FireHydrantComponent(
        position: Vector2(450.0, 406.0),
        groundY: 460.0,
      );
      game.activeFireHydrants.add(hydrant);
      game.world.add(hydrant);

      final initialX = hydrant.position.x;
      game.update(0.1);

      expect(hydrant.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkInteraction on update and triggers hydrant traverse', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final hydrant = FireHydrantComponent(
        position: Vector2(game.player.position.x + 10.0, 406.0),
        groundY: 460.0,
      );
      game.activeFireHydrants.add(hydrant);
      game.world.add(hydrant);

      // Make player airborne in interaction window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 430.0;

      game.update(0.05);

      expect(hydrant.hasTriggered, isTrue);
      expect(game.gameState.hydrantsTraversedInRun, equals(1));
      expect(game.gameState.isHydroplaneActive, isTrue);
      expect(game.player.simulator.isHydroplaning, isTrue);

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('HYDROPLANE!')), isTrue);

      // Particles spawned
      final plumeFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(plumeFx.isNotEmpty, isTrue);
    });

    test('CourierGame recycles off-screen fire hydrants during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenHydrant = FireHydrantComponent(
        position: Vector2(-280.0, 406.0),
      );
      game.activeFireHydrants.add(offscreenHydrant);
      game.world.add(offscreenHydrant);

      game.update(0.05);
      expect(game.activeFireHydrants.contains(offscreenHydrant), isFalse);
    });
  });

  group('HUDOverlay Hydroplane Badge UI Tests (Issue #111)', () {
    testWidgets('renders hydroplane_badge when isHydroplaneActive is true', (tester) async {
      final state = GameState();
      state.startRun();
      state.recordFireHydrantTraverse();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(
              gameState: state,
              onPause: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('hydroplane_badge'));
      expect(badge, findsOneWidget);
      expect(find.textContaining('HYDROPLANE'), findsOneWidget);
    });

    testWidgets('hides hydroplane_badge when isHydroplaneActive is false', (tester) async {
      final state = GameState();
      state.startRun();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(
              gameState: state,
              onPause: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('hydroplane_badge'));
      expect(badge, findsNothing);
    });
  });

  group('GameOverModal Hydrant Badge UI Tests (Issue #111)', () {
    testWidgets('renders game_over_hydrant_badge with singular text when 1 blast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              hydrantsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_hydrant_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 FIRE HYDRANT SPRAY BLAST'), findsOneWidget);
    });

    testWidgets('renders game_over_hydrant_badge with plural text when 2 blasts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              hydrantsCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_hydrant_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('2 FIRE HYDRANT SPRAY BLASTS'), findsOneWidget);
    });

    testWidgets('hides game_over_hydrant_badge when 0 blasts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              hydrantsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_hydrant_badge'));
      expect(badge, findsNothing);
    });
  });
}
