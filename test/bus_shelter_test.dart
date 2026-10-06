import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/bus_shelter_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
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
  Future<void> startLayer(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusShelterComponent Unit Tests (Issue #120)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final shelter = BusShelterComponent(
        position: Vector2(300.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );

      expect(shelter.size.x, equals(96.0));
      expect(shelter.size.y, equals(54.0));
      expect(shelter.groundY, equals(460.0));
      expect(shelter.hasVaulted, isFalse);
      expect(shelter.roofWorldY, equals(406.0));
      expect(shelter.marqueeApexWorld, equals(Vector2(300.0 + 48.0, 406.0 + 8.0)));
      expect(shelter.centerWorldPosition, equals(Vector2(300.0 + 48.0, 406.0 + 27.0)));
      expect(shelter.shouldRecycle, isFalse);
    });

    test('checkShelterVault ignores courier outside horizontal bounds', () {
      final shelter = BusShelterComponent(
        position: Vector2(300.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 410.0;

      // Far left
      final farLeft = shelter.checkShelterVault(
        Vector2(100.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = shelter.checkShelterVault(
        Vector2(500.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(shelter.hasVaulted, isFalse);
    });

    test('checkShelterVault ignores courier outside vertical window', () {
      final shelter = BusShelterComponent(
        position: Vector2(300.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Too high above canopy (windowTop is 406 - 24 = 382.0)
      sim.currentY = 350.0;
      final tooHigh = shelter.checkShelterVault(
        Vector2(320.0, 310.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Below sidewalk ground (windowBottom is 460 + 4 = 464.0)
      sim.currentY = 480.0;
      final tooLow = shelter.checkShelterVault(
        Vector2(320.0, 440.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(shelter.hasVaulted, isFalse);
    });

    test('checkShelterVault triggers vault and applies loft hop boost (+210 px/s)', () {
      var callbackFired = false;
      final shelter = BusShelterComponent(
        position: Vector2(300.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
        onShelterVault: () => callbackFired = true,
      );

      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 412.0;
      sim.verticalVelocity = -50.0; // Airborne

      final triggered = shelter.checkShelterVault(
        Vector2(320.0, 372.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(shelter.hasVaulted, isTrue);
      expect(callbackFired, isTrue);
      expect(sim.verticalVelocity, equals(210.0)); // Upward loft rebound velocity

      // Subsequent check returns false (single trigger)
      final secondCheck = shelter.checkShelterVault(
        Vector2(320.0, 372.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);
    });

    test('markVaulted sets hasVaulted flag', () {
      final shelter = BusShelterComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
      );
      expect(shelter.hasVaulted, isFalse);
      shelter.markVaulted();
      expect(shelter.hasVaulted, isTrue);
    });

    test('shouldRecycle triggers when past left offscreen boundary', () {
      final shelter = BusShelterComponent(
        position: Vector2(-150.0, 406.0),
        width: 96.0,
      );
      expect(shelter.shouldRecycle, isFalse);

      shelter.position.x = -280.0; // -280 + 96 = -184 < -180
      expect(shelter.shouldRecycle, isTrue);
    });

    test('update advances ticker animation timer and renders without errors', () {
      final shelter = BusShelterComponent(
        position: Vector2(100.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );

      shelter.update(0.1);
      shelter.update(0.15);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => shelter.render(canvas), returnsNormally);
      recorder.endRecording();
    });
  });

  group('ParticleEffectComponent.transitLedSparks Tests (Issue #120)', () {
    test('creates animated amber, cyan, and white LED particles', () {
      final effect = ParticleEffectComponent.transitLedSparks(
        position: Vector2(250.0, 380.0),
        count: 24,
      );

      expect(effect.isFinished, isFalse);

      effect.update(0.1);
      expect(effect.isFinished, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => effect.render(canvas), returnsNormally);
      recorder.endRecording();

      // Fast forward past particle lifetime (~0.65s max)
      effect.update(0.8);
      expect(effect.isFinished, isTrue);
    });
  });

  group('GameState Transit Bus Shelter Logic Tests (Issue #120)', () {
    test('recordBusShelterVault increases counters, tips, and fires callback', () {
      final gs = GameState();
      gs.startRun();

      BusShelterEvent? capturedEvent;
      gs.onBusShelterVault = (event) {
        capturedEvent = event;
      };

      final initialTips = gs.tips;
      final event = gs.recordBusShelterVault(baseTips: 30);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(30));
      expect(event.multiplier, equals(1.2)); // Streak 1 = 1.2x
      expect(event.totalTips, equals(36));
      expect(gs.busSheltersVaultedInRun, equals(1));
      expect(gs.tips, equals(initialTips + 36));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.totalTips, equals(36));
    });

    test('recordBusShelterVault scales tips with stunt multiplier', () {
      final gs = GameState();
      gs.startRun();
      gs.recordStunt(clearance: 10.0); // streak 1

      final initialTips = gs.tips;
      final event = gs.recordBusShelterVault(baseTips: 30); // streak 2 -> 1.5x

      expect(event, isNotNull);
      expect(event!.multiplier, equals(1.5));
      expect(event.totalTips, equals(45));
      expect(gs.tips, equals(initialTips + 45));
    });

    test('recordBusShelterVault returns null when run is not active', () {
      final gs = GameState();
      // Not started
      final event = gs.recordBusShelterVault();
      expect(event, isNull);
      expect(gs.busSheltersVaultedInRun, equals(0));
    });

    test('startRun resets busSheltersVaultedInRun counter', () {
      final gs = GameState();
      gs.startRun();
      gs.recordBusShelterVault();
      gs.recordBusShelterVault();
      expect(gs.busSheltersVaultedInRun, equals(2));

      gs.startRun();
      expect(gs.busSheltersVaultedInRun, equals(0));
    });
  });

  group('CourierGame Transit Bus Shelter Integration Tests (Issue #120)', () {
    test('CourierGame spawns and clears activeBusShelters across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final shelter = BusShelterComponent(
        position: Vector2(300.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );
      game.activeBusShelters.add(shelter);
      game.world.add(shelter);

      expect(game.activeBusShelters.contains(shelter), isTrue);
      expect(game.world.children.contains(shelter), isTrue);

      game.restartRun();
      expect(game.activeBusShelters.contains(shelter), isFalse);
      expect(game.world.children.contains(shelter), isFalse);
    });

    test('BusShelterComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final shelter = BusShelterComponent(
        position: Vector2(500.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );
      game.activeBusShelters.add(shelter);
      game.world.add(shelter);

      final initialX = shelter.position.x;
      game.update(0.1);
      expect(shelter.position.x, lessThan(initialX));
    });

    test('Courier vaulting across bus shelter canopy triggers event, bark, and particles', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final shelter = BusShelterComponent(
        position: Vector2(game.player.position.x + 10.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );
      game.activeBusShelters.add(shelter);
      game.world.add(shelter);

      // Position player in the air landing onto shelter roof
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 412.0;
      game.player.simulator.verticalVelocity = -50.0;

      final initialVaults = game.gameState.busSheltersVaultedInRun;
      game.update(0.016);

      expect(shelter.hasVaulted, isTrue);
      expect(game.gameState.busSheltersVaultedInRun, equals(initialVaults + 1));
      expect(game.player.simulator.verticalVelocity, equals(210.0)); // Upward loft rebound

      // Verify floating text
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('TRANSIT SHELTER VAULT')), isTrue);

      // Verify particle effect
      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(particles.isNotEmpty, isTrue);
    });

    test('Offscreen bus shelter is recycled', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final shelter = BusShelterComponent(
        position: Vector2(-300.0, 406.0),
        width: 96.0,
        height: 54.0,
        groundY: 460.0,
      );
      game.activeBusShelters.add(shelter);
      game.world.add(shelter);

      expect(game.activeBusShelters.contains(shelter), isTrue);
      game.update(0.1);
      expect(game.activeBusShelters.contains(shelter), isFalse);
    });
  });

  group('GameOverModal Bus Shelter Badge Tests (Issue #120)', () {
    testWidgets('renders single bus shelter vault badge when busSheltersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              busSheltersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_bus_shelter_badge')), findsOneWidget);
      expect(find.text('1 TRANSIT SHELTER VAULT'), findsOneWidget);
    });

    testWidgets('renders plural bus shelter vault badge when busSheltersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 680,
              tips: 340,
              isNewRecord: false,
              careerTips: 1800,
              busSheltersCompleted: 4,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_bus_shelter_badge')), findsOneWidget);
      expect(find.text('4 TRANSIT SHELTER VAULTS'), findsOneWidget);
    });

    testWidgets('omits bus shelter badge when busSheltersCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 40,
              isNewRecord: false,
              careerTips: 500,
              busSheltersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_bus_shelter_badge')), findsNothing);
    });
  });
}
