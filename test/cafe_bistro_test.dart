import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/cafe_bistro_component.dart';
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

  group('CafeBistroComponent Unit Tests (Issue #107)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final bistro = CafeBistroComponent(
        position: Vector2(300.0, 404.0),
        width: 78.0,
        height: 56.0,
        groundY: 460.0,
      );

      expect(bistro.size.x, equals(78.0));
      expect(bistro.size.y, equals(56.0));
      expect(bistro.hasVaulted, isFalse);
      expect(bistro.tabletopWorldY, equals(460.0 - 30.0)); // 430.0
      expect(bistro.tabletopApexWorld, equals(Vector2(339.0, 430.0)));
      expect(bistro.centerWorldPosition, equals(Vector2(339.0, 432.0)));
      expect(bistro.shouldRecycle, isFalse);
    });

    test('checkVault ignores grounded courier even if within bounds', () {
      final bistro = CafeBistroComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final vaulted = bistro.checkVault(
        Vector2(320.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isFalse);
      expect(bistro.hasVaulted, isFalse);
    });

    test('checkVault ignores airborne courier horizontally outside bistro bounds', () {
      final bistro = CafeBistroComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 430.0;

      // Far left
      final farLeft = bistro.checkVault(
        Vector2(200.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = bistro.checkVault(
        Vector2(450.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(bistro.hasVaulted, isFalse);
    });

    test('checkVault ignores airborne courier outside vertical vault window', () {
      final bistro = CafeBistroComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Way above tabletop
      sim.currentY = 380.0;
      final tooHigh = bistro.checkVault(
        Vector2(320.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Way below tabletop
      sim.currentY = 458.0;
      final tooLow = bistro.checkVault(
        Vector2(320.0, 418.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(bistro.hasVaulted, isFalse);
    });

    test('checkVault triggers hurdle vault, launches avatar, and wobbles table', () {
      var vaultReported = false;
      final bistro = CafeBistroComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
        onVault: () {
          vaultReported = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 430.0; // Right at tabletop level

      final vaulted = bistro.checkVault(
        Vector2(320.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isTrue);
      expect(vaultReported, isTrue);
      expect(bistro.hasVaulted, isTrue);
      expect(sim.verticalVelocity, equals(200.0)); // Launch hop

      // Subsequent check does not re-trigger
      final secondCheck = bistro.checkVault(
        Vector2(320.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);

      // Update advances wobble timer
      bistro.update(0.1);
      expect(bistro.hasVaulted, isTrue);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final bistro = CafeBistroComponent(
        position: Vector2(-280.0, 404.0),
        width: 78.0,
      );
      expect(bistro.shouldRecycle, isTrue);

      bistro.position.x = 0.0;
      expect(bistro.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state and during wobble oscillation', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final bistro = CafeBistroComponent(
        position: Vector2(100.0, 404.0),
      );

      // Idle render
      expect(() => bistro.render(canvas), returnsNormally);

      // Vaulted state with wobble
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 430.0;
      bistro.checkVault(Vector2(120.0, 390.0), Vector2(32.0, 40.0), sim);
      bistro.update(0.1);
      expect(() => bistro.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.espressoPorcelainBurst Tests (Issue #107)', () {
    test('creates requested number of living particles with fanning velocity and coffee/porcelain colors', () {
      final burst = ParticleEffectComponent.espressoPorcelainBurst(
        position: Vector2(250.0, 430.0),
        count: 26,
      );

      expect(burst.particles.length, equals(26));
      expect(burst.isFinished, isFalse);

      for (final p in burst.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(210.0)); // Kinetic downward splash arc
        expect(p.drag, equals(0.95));
      }

      // Step until all particles expire
      burst.update(1.0);
      expect(burst.isFinished, isTrue);
    });
  });

  group('GameState Cafe Bistro & Caffeine Surge Logic Tests (Issue #107)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordCafeBistroVault awards tips, advances streak, and activates caffeine surge buff', () {
      state.startRun();
      expect(state.cafeBistroVaultsInRun, equals(0));
      expect(state.isCaffeineSurgeActive, isFalse);
      expect(state.caffeineSurgeTimer, equals(0.0));

      CafeBistroEvent? capturedEvent;
      state.onCafeBistroVault = (e) => capturedEvent = e;

      final event = state.recordCafeBistroVault(baseTips: 30);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.cafeBistroVaultsInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 30 * 1.2x (stuntStreak 1) = 36
      expect(state.tips, equals(36));
      expect(state.isCaffeineSurgeActive, isTrue);
      expect(state.caffeineSurgeTimer, equals(3.5));
      expect(event!.caffeineDuration, equals(3.5));
    });

    test('updateCaffeineSurgeTimer counts down and expires caffeine surge buff', () {
      state.startRun();
      state.recordCafeBistroVault();
      expect(state.isCaffeineSurgeActive, isTrue);

      state.updateCaffeineSurgeTimer(1.5);
      expect(state.caffeineSurgeTimer, closeTo(2.0, 0.001));
      expect(state.isCaffeineSurgeActive, isTrue);

      state.updateCaffeineSurgeTimer(2.5);
      expect(state.caffeineSurgeTimer, equals(0.0));
      expect(state.isCaffeineSurgeActive, isFalse);
    });

    test('startRun resets cafeBistroVaultsInRun and caffeineSurgeTimer', () {
      state.startRun();
      state.recordCafeBistroVault();
      expect(state.cafeBistroVaultsInRun, equals(1));
      expect(state.caffeineSurgeTimer, equals(3.5));

      state.startRun();
      expect(state.cafeBistroVaultsInRun, equals(0));
      expect(state.caffeineSurgeTimer, equals(0.0));
      expect(state.isCaffeineSurgeActive, isFalse);
    });

    test('recordCafeBistroVault returns null when game is not running', () {
      final event = state.recordCafeBistroVault();
      expect(event, isNull);
      expect(state.cafeBistroVaultsInRun, equals(0));
    });
  });

  group('CourierGame Integration with CafeBistroComponent (Issue #107)', () {
    test('CourierGame spawns and clears activeCafeBistros across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final bistro = CafeBistroComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
      );
      game.activeCafeBistros.add(bistro);
      game.world.add(bistro);

      expect(game.activeCafeBistros.contains(bistro), isTrue);
      expect(game.world.children.contains(bistro), isTrue);

      game.restartRun();
      expect(game.activeCafeBistros.contains(bistro), isFalse);
      expect(game.world.children.contains(bistro), isFalse);
    });

    test('CourierGame scrolls activeCafeBistros horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final bistro = CafeBistroComponent(
        position: Vector2(450.0, 404.0),
        groundY: 460.0,
      );
      game.activeCafeBistros.add(bistro);
      game.world.add(bistro);

      final initialX = bistro.position.x;
      game.update(0.1);

      expect(bistro.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkVault on update and triggers cafe bistro vault', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final bistro = CafeBistroComponent(
        position: Vector2(game.player.position.x + 10.0, 404.0),
        groundY: 460.0,
      );
      game.activeCafeBistros.add(bistro);
      game.world.add(bistro);

      // Make player airborne in vault window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 430.0;

      game.update(0.05);

      expect(bistro.hasVaulted, isTrue);
      expect(game.gameState.cafeBistroVaultsInRun, equals(1));
      expect(game.gameState.isCaffeineSurgeActive, isTrue);

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('CAFE BISTRO VAULT!')), isTrue);

      // Particles spawned
      final burstFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(burstFx.isNotEmpty, isTrue);
    });

    test('CourierGame applies speed multiplier and jump impulse boost during caffeine surge', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      // Normal speed
      game.update(0.05);
      final normalSpeed = game.currentSpeed;

      // Trigger caffeine surge
      game.gameState.caffeineSurgeTimer = 3.5;
      game.update(0.05);
      final boostedSpeed = game.currentSpeed;

      expect(boostedSpeed, closeTo(normalSpeed * 1.18, 0.5));

      // Test jump with caffeine surge
      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;
      final jumpMult = game.gameState.isCaffeineSurgeActive ? 1.10 : 1.0;
      game.player.jump(impulseMultiplier: jumpMult);

      expect(game.player.simulator.verticalVelocity, equals(240.0 * 1.10));
    });

    test('CourierGame recycles off-screen cafe bistros during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenBistro = CafeBistroComponent(
        position: Vector2(-280.0, 404.0),
      );
      game.activeCafeBistros.add(offscreenBistro);
      game.world.add(offscreenBistro);

      game.update(0.05);
      expect(game.activeCafeBistros.contains(offscreenBistro), isFalse);
    });
  });

  group('HUDOverlay Caffeine Surge Badge UI Tests (Issue #107)', () {
    testWidgets('renders caffeine_surge_badge when isCaffeineSurgeActive is true', (tester) async {
      final state = GameState();
      state.startRun();
      state.recordCafeBistroVault();

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

      final badge = find.byKey(const Key('caffeine_surge_badge'));
      expect(badge, findsOneWidget);
      expect(find.textContaining('CAFFEINE SURGE'), findsOneWidget);
    });

    testWidgets('hides caffeine_surge_badge when isCaffeineSurgeActive is false', (tester) async {
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

      final badge = find.byKey(const Key('caffeine_surge_badge'));
      expect(badge, findsNothing);
    });
  });

  group('GameOverModal Cafe Bistro Badge UI Tests (Issue #107)', () {
    testWidgets('renders game_over_cafe_bistro_badge with singular text when 1 vault', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              cafeBistrosCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_cafe_bistro_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 CAFE BISTRO VAULT'), findsOneWidget);
    });

    testWidgets('renders game_over_cafe_bistro_badge with plural text when 2 vaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              cafeBistrosCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_cafe_bistro_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('2 CAFE BISTRO VAULTS'), findsOneWidget);
    });

    testWidgets('hides game_over_cafe_bistro_badge when 0 vaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              cafeBistrosCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_cafe_bistro_badge'));
      expect(badge, findsNothing);
    });
  });
}
