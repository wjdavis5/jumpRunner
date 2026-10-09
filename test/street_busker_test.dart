import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/street_busker_component.dart';
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

  group('StreetBuskerComponent Unit Tests (Issue #109)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final busker = StreetBuskerComponent(
        position: Vector2(300.0, 392.0),
        width: 84.0,
        height: 68.0,
        groundY: 460.0,
      );

      expect(busker.size.x, equals(84.0));
      expect(busker.size.y, equals(68.0));
      expect(busker.hasEncountered, isFalse);
      expect(busker.caseWorldY, equals(460.0 - 16.0)); // 444.0
      expect(busker.saxBellApexWorld, equals(Vector2(300.0 + (84.0 * 0.68), 460.0 - 48.0)));
      expect(busker.centerWorldPosition, equals(Vector2(342.0, 426.0)));
      expect(busker.shouldRecycle, isFalse);
    });

    test('checkInteraction ignores grounded courier even if within bounds', () {
      final busker = StreetBuskerComponent(
        position: Vector2(300.0, 392.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final triggered = busker.checkInteraction(
        Vector2(320.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isFalse);
      expect(busker.hasEncountered, isFalse);
    });

    test('checkInteraction ignores airborne courier horizontally outside busker bounds', () {
      final busker = StreetBuskerComponent(
        position: Vector2(300.0, 392.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 430.0;

      // Far left
      final farLeft = busker.checkInteraction(
        Vector2(200.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = busker.checkInteraction(
        Vector2(450.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(busker.hasEncountered, isFalse);
    });

    test('checkInteraction ignores airborne courier outside vertical interaction window', () {
      final busker = StreetBuskerComponent(
        position: Vector2(300.0, 392.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Way above busker
      sim.currentY = 360.0;
      final tooHigh = busker.checkInteraction(
        Vector2(320.0, 320.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Way below interaction window
      sim.currentY = 480.0;
      final tooLow = busker.checkInteraction(
        Vector2(320.0, 440.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(busker.hasEncountered, isFalse);
    });

    test('checkInteraction triggers encounter, launches avatar, and triggers solo reaction', () {
      var encounterReported = false;
      final busker = StreetBuskerComponent(
        position: Vector2(300.0, 392.0),
        groundY: 460.0,
        onEncounter: () {
          encounterReported = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 430.0;

      final triggered = busker.checkInteraction(
        Vector2(320.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(encounterReported, isTrue);
      expect(busker.hasEncountered, isTrue);
      expect(sim.verticalVelocity, equals(210.0)); // Kinetic parkour vault lift

      // Subsequent check does not re-trigger
      final secondCheck = busker.checkInteraction(
        Vector2(320.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);

      // Update advances groove timer and solo reaction timer
      busker.update(0.1);
      expect(busker.hasEncountered, isTrue);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final busker = StreetBuskerComponent(
        position: Vector2(-280.0, 392.0),
        width: 84.0,
      );
      expect(busker.shouldRecycle, isTrue);

      busker.position.x = 0.0;
      expect(busker.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state and during solo reaction flourish', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final busker = StreetBuskerComponent(
        position: Vector2(100.0, 392.0),
      );

      // Idle render
      expect(() => busker.render(canvas), returnsNormally);

      // Encountered state with solo flourish
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 430.0;
      busker.checkInteraction(Vector2(120.0, 390.0), Vector2(32.0, 40.0), sim);
      busker.update(0.1);
      expect(() => busker.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.musicalNoteFountain Tests (Issue #109)', () {
    test('creates requested number of living particles with buoyant upward velocity and jazz colors', () {
      final fountain = ParticleEffectComponent.musicalNoteFountain(
        position: Vector2(250.0, 412.0),
        count: 28,
      );

      expect(fountain.particles.length, equals(28));
      expect(fountain.isFinished, isFalse);

      for (final p in fountain.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(-42.0)); // Buoyant upward drift
        expect(p.drag, equals(1.1));
      }

      // Step until all particles expire
      fountain.update(1.2);
      expect(fountain.isFinished, isTrue);
    });
  });

  group('GameState Street Busker & Urban Groove Logic Tests (Issue #109)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordStreetBuskerEncounter awards tips, advances streak, and activates urban groove buff', () {
      state.startRun();
      expect(state.buskersEncounteredInRun, equals(0));
      expect(state.isUrbanGrooveActive, isFalse);
      expect(state.urbanGrooveTimer, equals(0.0));

      StreetBuskerEvent? capturedEvent;
      state.onStreetBuskerEncounter = (e) => capturedEvent = e;

      final event = state.recordStreetBuskerEncounter(baseTips: 35);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.buskersEncounteredInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 35 * 1.2x (stuntStreak 1) = 42
      expect(state.tips, equals(42));
      expect(state.isUrbanGrooveActive, isTrue);
      expect(state.urbanGrooveTimer, equals(4.0));
      expect(event!.urbanGrooveDuration, equals(4.0));
    });

    test('updateUrbanGrooveTimer counts down and expires urban groove buff', () {
      state.startRun();
      state.recordStreetBuskerEncounter();
      expect(state.isUrbanGrooveActive, isTrue);

      state.updateUrbanGrooveTimer(2.0);
      expect(state.urbanGrooveTimer, equals(2.0));
      expect(state.isUrbanGrooveActive, isTrue);

      state.updateUrbanGrooveTimer(2.5);
      expect(state.urbanGrooveTimer, equals(0.0));
      expect(state.isUrbanGrooveActive, isFalse);
    });

    test('active urban groove applies +1.5x score multiplier to subsequent near-miss stunts', () {
      state.startRun();
      state.recordStunt();
      final tipsNoBuff = state.tips; // base 5 * 1.2 = 6

      // Reset and trigger urban groove
      state.startRun();
      state.recordStreetBuskerEncounter();
      final tipsAfterBusker = state.tips;

      state.recordStunt();
      final stuntGainWithGroove = state.tips - tipsAfterBusker;
      // Stunt with streak 2 (1.5x): base 5 * 1.5 = 7.5 -> 8.
      // With urban groove (+1.5x): 8 * 1.5 = 12!
      expect(stuntGainWithGroove, greaterThan(tipsNoBuff));
      expect(stuntGainWithGroove, equals(12));
    });

    test('startRun resets buskersEncounteredInRun and urbanGrooveTimer', () {
      state.startRun();
      state.recordStreetBuskerEncounter();
      expect(state.buskersEncounteredInRun, equals(1));
      expect(state.urbanGrooveTimer, equals(4.0));

      state.startRun();
      expect(state.buskersEncounteredInRun, equals(0));
      expect(state.urbanGrooveTimer, equals(0.0));
      expect(state.isUrbanGrooveActive, isFalse);
    });

    test('recordStreetBuskerEncounter returns null when game is not running', () {
      final event = state.recordStreetBuskerEncounter();
      expect(event, isNull);
      expect(state.buskersEncounteredInRun, equals(0));
    });
  });

  group('CourierGame Integration with StreetBuskerComponent (Issue #109)', () {
    test('CourierGame spawns and clears activeStreetBuskers across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final busker = StreetBuskerComponent(
        position: Vector2(300.0, 392.0),
        groundY: 460.0,
      );
      game.activeStreetBuskers.add(busker);
      game.world.add(busker);

      expect(game.activeStreetBuskers.contains(busker), isTrue);
      expect(game.world.children.contains(busker), isTrue);

      game.restartRun();
      expect(game.activeStreetBuskers.contains(busker), isFalse);
      expect(game.world.children.contains(busker), isFalse);
    });

    test('CourierGame scrolls activeStreetBuskers horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final busker = StreetBuskerComponent(
        position: Vector2(450.0, 392.0),
        groundY: 460.0,
      );
      game.activeStreetBuskers.add(busker);
      game.world.add(busker);

      final initialX = busker.position.x;
      game.update(0.1);

      expect(busker.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkInteraction on update and triggers busker encounter', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final busker = StreetBuskerComponent(
        position: Vector2(game.player.position.x + 10.0, 392.0),
        groundY: 460.0,
      );
      game.activeStreetBuskers.add(busker);
      game.world.add(busker);

      // Make player airborne in interaction window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 430.0;

      game.update(0.05);

      expect(busker.hasEncountered, isTrue);
      expect(game.gameState.buskersEncounteredInRun, equals(1));
      expect(game.gameState.isUrbanGrooveActive, isTrue);

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('URBAN GROOVE!')), isTrue);

      // Particles spawned
      final fountainFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(fountainFx.isNotEmpty, isTrue);
    });

    test('CourierGame recycles off-screen street buskers during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenBusker = StreetBuskerComponent(
        position: Vector2(-280.0, 392.0),
      );
      game.activeStreetBuskers.add(offscreenBusker);
      game.world.add(offscreenBusker);

      game.update(0.05);
      expect(game.activeStreetBuskers.contains(offscreenBusker), isFalse);
    });
  });

  group('HUDOverlay Urban Groove Badge UI Tests (Issue #109)', () {
    testWidgets('renders urban_groove_badge when isUrbanGrooveActive is true', (tester) async {
      final state = GameState();
      state.startRun();
      state.recordStreetBuskerEncounter();

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

      final badge = find.byKey(const Key('urban_groove_badge'));
      expect(badge, findsOneWidget);
      expect(find.textContaining('URBAN GROOVE'), findsOneWidget);
    });

    testWidgets('hides urban_groove_badge when isUrbanGrooveActive is false', (tester) async {
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

      final badge = find.byKey(const Key('urban_groove_badge'));
      expect(badge, findsNothing);
    });
  });

  group('GameOverModal Busker Badge UI Tests (Issue #109)', () {
    testWidgets('renders game_over_busker_badge with singular text when 1 encounter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              buskersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_busker_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 STREET BUSKER JAZZ ENCOUNTER'), findsOneWidget);
    });

    testWidgets('renders game_over_busker_badge with plural text when 2 encounters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              buskersCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_busker_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('2 STREET BUSKER JAZZ ENCOUNTERS'), findsOneWidget);
    });

    testWidgets('hides game_over_busker_badge when 0 encounters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              buskersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_busker_badge'));
      expect(badge, findsNothing);
    });
  });
}
