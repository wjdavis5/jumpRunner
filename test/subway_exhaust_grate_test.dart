import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/subway_exhaust_grate_component.dart';
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

  group('SubwayExhaustGrateComponent Unit Tests (Issue #114)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final grate = SubwayExhaustGrateComponent(
        position: Vector2(300.0, 446.0),
        width: 88.0,
        height: 14.0,
        groundY: 460.0,
      );

      expect(grate.size.x, equals(88.0));
      expect(grate.size.y, equals(14.0));
      expect(grate.hasTriggered, isFalse);
      expect(grate.grateWorldY, equals(446.0));
      expect(grate.plumeApexWorld, equals(Vector2(300.0 + 44.0, 460.0 - 32.0)));
      expect(grate.centerWorldPosition, equals(Vector2(300.0 + 44.0, 446.0 + 7.0)));
      expect(grate.shouldRecycle, isFalse);
    });

    test('checkUpdraft ignores courier outside horizontal bounds', () {
      final grate = SubwayExhaustGrateComponent(
        position: Vector2(300.0, 446.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 440.0;

      // Far left
      final farLeft = grate.checkUpdraft(
        Vector2(100.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = grate.checkUpdraft(
        Vector2(500.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(grate.hasTriggered, isFalse);
    });

    test('checkUpdraft ignores courier outside vertical window', () {
      final grate = SubwayExhaustGrateComponent(
        position: Vector2(300.0, 446.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Too high above updraft window (windowTop is 460 - 80 = 380)
      sim.currentY = 360.0;
      final tooHigh = grate.checkUpdraft(
        Vector2(320.0, 320.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Below ground window (windowBottom is 460 + 6 = 466)
      sim.currentY = 480.0;
      final tooLow = grate.checkUpdraft(
        Vector2(320.0, 440.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(grate.hasTriggered, isFalse);
    });

    test('checkUpdraft triggers within window, provides +230 loft boost, and fires callback', () {
      var updraftReported = false;
      final grate = SubwayExhaustGrateComponent(
        position: Vector2(300.0, 446.0),
        groundY: 460.0,
        onUpdraftCatch: () {
          updraftReported = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 440.0;

      final triggered = grate.checkUpdraft(
        Vector2(320.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(updraftReported, isTrue);
      expect(grate.hasTriggered, isTrue);
      expect(sim.verticalVelocity, equals(230.0)); // Updraft lift

      // Subsequent check does not re-trigger
      expect(grate.checkUpdraft(Vector2(320.0, 400.0), Vector2(32.0, 40.0), sim), isFalse);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final grate = SubwayExhaustGrateComponent(
        position: Vector2(-280.0, 446.0),
        width: 88.0,
      );
      expect(grate.shouldRecycle, isTrue);

      grate.position.x = 0.0;
      expect(grate.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state and after steam updates', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final grate = SubwayExhaustGrateComponent(
        position: Vector2(100.0, 446.0),
      );

      // Idle render
      expect(() => grate.render(canvas), returnsNormally);

      // Update steam flutter timer and re-render
      grate.update(0.25);
      expect(() => grate.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.subwayExhaustSteam Tests (Issue #114)', () {
    test('creates requested number of living particles with upward buoyant velocity and steam properties', () {
      final steam = ParticleEffectComponent.subwayExhaustSteam(
        position: Vector2(250.0, 420.0),
        count: 30,
      );

      expect(steam.particles.length, equals(30));
      expect(steam.isFinished, isFalse);

      for (final p in steam.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(-54.0)); // Buoyant upward thermal draft
        expect(p.drag, equals(0.92));
      }

      // Step until all particles expire
      steam.update(1.2);
      expect(steam.isFinished, isTrue);
    });
  });

  group('JumpPhysicsSimulator Thermal Updraft Glide Float Tests (Issue #114)', () {
    test('isThermalUpdraft modifies buoyant glide acceleration and terminal descent velocity', () {
      final normalSim = JumpPhysicsSimulator(groundY: 10000.0);
      normalSim.isGrounded = false;
      normalSim.currentY = 300.0;
      normalSim.verticalVelocity = 0.0;
      normalSim.isGliding = true;
      normalSim.isThermalUpdraft = false;

      final thermalSim = JumpPhysicsSimulator(groundY: 10000.0);
      thermalSim.isGrounded = false;
      thermalSim.currentY = 300.0;
      thermalSim.verticalVelocity = 0.0;
      thermalSim.isGliding = true;
      thermalSim.isThermalUpdraft = true;

      // Update both for 0.5s of glide descent
      normalSim.update(0.5);
      thermalSim.update(0.5);

      // Thermal glide has lower descent speed (more buoyant float)
      expect(thermalSim.verticalVelocity.abs(), lessThan(normalSim.verticalVelocity.abs()));

      // Run longer to reach terminal velocities
      for (var i = 0; i < 50; i++) {
        normalSim.update(0.1);
        thermalSim.update(0.1);
      }

      expect(thermalSim.verticalVelocity, equals(-35.0)); // Thermal updraft float rate
      expect(normalSim.verticalVelocity, equals(-55.0));  // Standard terminal glide rate
    });
  });

  group('GameState Subway Exhaust Grate Updraft Logic Tests (Issue #114)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordSubwayExhaustGrateCatch awards tips, activates thermal timer, and tracks count', () {
      state.startRun();
      expect(state.exhaustGratesCaughtInRun, equals(0));
      expect(state.isThermalUpdraftActive, isFalse);

      SubwayExhaustGrateEvent? capturedEvent;
      state.onSubwayExhaustGrateCatch = (e) => capturedEvent = e;

      final event = state.recordSubwayExhaustGrateCatch(baseTips: 32);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.exhaustGratesCaughtInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 32 * 1.2x (stuntStreak 1) = 38
      expect(state.tips, equals(38));
      expect(event!.exhaustGratesInRun, equals(1));
      expect(state.isThermalUpdraftActive, isTrue);
      expect(state.thermalUpdraftTimer, equals(3.5));
    });

    test('updateThermalUpdraftTimer counts down and expires buff', () {
      state.startRun();
      state.recordSubwayExhaustGrateCatch();
      expect(state.isThermalUpdraftActive, isTrue);

      state.updateThermalUpdraftTimer(2.0);
      expect(state.thermalUpdraftTimer, closeTo(1.5, 0.001));
      expect(state.isThermalUpdraftActive, isTrue);

      state.updateThermalUpdraftTimer(1.6);
      expect(state.thermalUpdraftTimer, equals(0.0));
      expect(state.isThermalUpdraftActive, isFalse);
    });

    test('startRun resets exhaustGratesCaughtInRun and thermalUpdraftTimer', () {
      state.startRun();
      state.recordSubwayExhaustGrateCatch();
      expect(state.exhaustGratesCaughtInRun, equals(1));
      expect(state.isThermalUpdraftActive, isTrue);

      state.startRun();
      expect(state.exhaustGratesCaughtInRun, equals(0));
      expect(state.thermalUpdraftTimer, equals(0.0));
      expect(state.isThermalUpdraftActive, isFalse);
    });

    test('recordSubwayExhaustGrateCatch returns null when game is not running', () {
      final event = state.recordSubwayExhaustGrateCatch();
      expect(event, isNull);
      expect(state.exhaustGratesCaughtInRun, equals(0));
    });
  });

  group('CourierGame Integration with SubwayExhaustGrateComponent (Issue #114)', () {
    test('CourierGame spawns and clears activeSubwayExhaustGrates across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final grate = SubwayExhaustGrateComponent(
        position: Vector2(300.0, 446.0),
        groundY: 460.0,
      );
      game.activeSubwayExhaustGrates.add(grate);
      game.world.add(grate);

      expect(game.activeSubwayExhaustGrates.contains(grate), isTrue);
      expect(game.world.children.contains(grate), isTrue);

      game.restartRun();
      expect(game.activeSubwayExhaustGrates.contains(grate), isFalse);
      expect(game.world.children.contains(grate), isFalse);
    });

    test('CourierGame scrolls activeSubwayExhaustGrates horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final grate = SubwayExhaustGrateComponent(
        position: Vector2(450.0, 446.0),
        groundY: 460.0,
      );
      game.activeSubwayExhaustGrates.add(grate);
      game.world.add(grate);

      final initialX = grate.position.x;
      game.update(0.1);

      expect(grate.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkUpdraft on update and triggers thermal catch', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final grate = SubwayExhaustGrateComponent(
        position: Vector2(game.player.position.x + 10.0, 446.0),
        groundY: 460.0,
      );
      game.activeSubwayExhaustGrates.add(grate);
      game.world.add(grate);

      // Make player in updraft window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 440.0;

      game.update(0.05);

      expect(grate.hasTriggered, isTrue);
      expect(game.gameState.exhaustGratesCaughtInRun, equals(1));
      expect(game.gameState.isThermalUpdraftActive, isTrue);
      expect(game.player.simulator.isThermalUpdraft, isTrue);

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('THERMAL UPDRAFT!')), isTrue);

      // Particles spawned
      final steamFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(steamFx.isNotEmpty, isTrue);
    });

    test('CourierGame recycles off-screen subway exhaust grates during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenGrate = SubwayExhaustGrateComponent(
        position: Vector2(-280.0, 446.0),
      );
      game.activeSubwayExhaustGrates.add(offscreenGrate);
      game.world.add(offscreenGrate);

      game.update(0.05);
      expect(game.activeSubwayExhaustGrates.contains(offscreenGrate), isFalse);
    });
  });

  group('HUDOverlay Thermal Updraft Badge UI Tests (Issue #114)', () {
    testWidgets('renders thermal_updraft_badge when isThermalUpdraftActive is true', (tester) async {
      final state = GameState();
      state.startRun();
      state.recordSubwayExhaustGrateCatch();

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

      final badge = find.byKey(const Key('thermal_updraft_badge'));
      expect(badge, findsOneWidget);
      expect(find.textContaining('THERMAL'), findsOneWidget);
    });

    testWidgets('hides thermal_updraft_badge when isThermalUpdraftActive is false', (tester) async {
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

      final badge = find.byKey(const Key('thermal_updraft_badge'));
      expect(badge, findsNothing);
    });
  });

  group('GameOverModal Subway Grate Badge UI Tests (Issue #114)', () {
    testWidgets('renders game_over_subway_grate_badge with singular text when 1 updraft', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              subwayGratesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_subway_grate_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 SUBWAY EXHAUST UPDRAFT'), findsOneWidget);
    });

    testWidgets('renders game_over_subway_grate_badge with plural text when 3 updrafts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              subwayGratesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_subway_grate_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('3 SUBWAY EXHAUST UPDRAFTS'), findsOneWidget);
    });

    testWidgets('hides game_over_subway_grate_badge when 0 updrafts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              subwayGratesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_subway_grate_badge'));
      expect(badge, findsNothing);
    });
  });
}
