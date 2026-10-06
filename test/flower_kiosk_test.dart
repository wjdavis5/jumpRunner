import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/flower_kiosk_component.dart';
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

  group('FlowerKioskComponent Unit Tests (Issue #100)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final kiosk = FlowerKioskComponent(
        position: Vector2(300.0, 402.0),
        width: 68.0,
        height: 58.0,
        groundY: 460.0,
      );

      expect(kiosk.size.x, equals(68.0));
      expect(kiosk.size.y, equals(58.0));
      expect(kiosk.hasVaulted, isFalse);
      expect(kiosk.kioskRimWorldY, equals(460.0 - 58.0 + 12.0));
      expect(kiosk.canopyApexWorld, equals(Vector2(334.0, 408.0)));
      expect(kiosk.centerWorldPosition, equals(Vector2(334.0, 431.0)));
      expect(kiosk.shouldRecycle, isFalse);
    });

    test('checkVault ignores grounded courier even if positioned within kiosk bounds', () {
      final kiosk = FlowerKioskComponent(
        position: Vector2(300.0, 402.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final vaulted = kiosk.checkVault(
        Vector2(320.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isFalse);
      expect(kiosk.hasVaulted, isFalse);
    });

    test('checkVault ignores airborne courier when horizontally outside kiosk bounds', () {
      final kiosk = FlowerKioskComponent(
        position: Vector2(300.0, 402.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 410.0;

      // Far left
      final farLeft = kiosk.checkVault(
        Vector2(200.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = kiosk.checkVault(
        Vector2(450.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(kiosk.hasVaulted, isFalse);
    });

    test('checkVault ignores airborne courier when vertically outside vault window', () {
      final kiosk = FlowerKioskComponent(
        position: Vector2(300.0, 402.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Way above kiosk (too high)
      sim.currentY = 320.0;
      final tooHigh = kiosk.checkVault(
        Vector2(320.0, 280.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Way below kiosk top
      sim.currentY = 455.0;
      final tooLow = kiosk.checkVault(
        Vector2(320.0, 415.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(kiosk.hasVaulted, isFalse);
    });

    test('checkVault triggers hurdle vault when airborne within bounds, invokes onVault, and wobbles', () {
      var vaultFired = false;
      final kiosk = FlowerKioskComponent(
        position: Vector2(300.0, 402.0),
        groundY: 460.0,
        onVault: () {
          vaultFired = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 412.0;

      final vaulted = kiosk.checkVault(
        Vector2(320.0, 372.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isTrue);
      expect(vaultFired, isTrue);
      expect(kiosk.hasVaulted, isTrue);

      // Subsequent check does not re-trigger
      final secondCheck = kiosk.checkVault(
        Vector2(320.0, 372.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);

      // Update advances wobble timer
      kiosk.update(0.2);
      expect(kiosk.hasVaulted, isTrue);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final kiosk = FlowerKioskComponent(
        position: Vector2(-220.0, 402.0),
        width: 68.0,
      );
      expect(kiosk.shouldRecycle, isTrue);

      kiosk.position.x = 0.0;
      expect(kiosk.shouldRecycle, isFalse);
    });

    test('render paints without exception during idle state and wobble oscillation', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final kiosk = FlowerKioskComponent(
        position: Vector2(100.0, 402.0),
      );

      // Idle render
      expect(() => kiosk.render(canvas), returnsNormally);

      // Vaulted with wobble oscillation render
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 410.0;
      kiosk.checkVault(Vector2(120.0, 370.0), Vector2(32.0, 40.0), sim);
      kiosk.update(0.1);
      expect(() => kiosk.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.petalBurst Tests (Issue #100)', () {
    test('creates requested number of living particles with upward velocity and botanical colors', () {
      final burst = ParticleEffectComponent.petalBurst(
        position: Vector2(250.0, 400.0),
        count: 24,
      );

      expect(burst.particles.length, equals(24));
      expect(burst.isFinished, isFalse);

      for (final p in burst.particles) {
        expect(p.isAlive, isTrue);
        expect(p.velocity.y, lessThan(0.0)); // Initial upward buoyant explosion
        expect(p.gravity, equals(80.0));
        expect(p.drag, equals(0.88));
      }

      // Step until all particles expire
      burst.update(1.2);
      expect(burst.isFinished, isTrue);
    });
  });

  group('GameState Flower Kiosk Vault & Floral Aroma Logic Tests (Issue #100)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordFlowerKioskVault awards tips, advances streak, and activates 4-second floral aroma', () {
      state.startRun();
      expect(state.flowerKioskVaultsInRun, equals(0));
      expect(state.isFloralAromaActive, isFalse);
      expect(state.floralAromaTimer, equals(0.0));

      FlowerKioskEvent? capturedEvent;
      state.onFlowerKioskVault = (e) => capturedEvent = e;

      final event = state.recordFlowerKioskVault(baseTips: 25);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.flowerKioskVaultsInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(state.tips, equals(30)); // 25 * 1.2x (stuntStreak 1) = 30
      expect(state.isFloralAromaActive, isTrue);
      expect(state.floralAromaTimer, equals(4.0));
      expect(event!.floralAromaDuration, equals(4.0));
    });

    test('updateFloralAromaTimer counts down and expires floral aroma buff', () {
      state.startRun();
      state.recordFlowerKioskVault();
      expect(state.isFloralAromaActive, isTrue);

      state.updateFloralAromaTimer(2.0);
      expect(state.floralAromaTimer, equals(2.0));
      expect(state.isFloralAromaActive, isTrue);

      state.updateFloralAromaTimer(2.5);
      expect(state.floralAromaTimer, equals(0.0));
      expect(state.isFloralAromaActive, isFalse);
    });

    test('active floral aroma applies +1.5x score multiplier to subsequent near-miss stunts', () {
      state.startRun();
      // Record regular stunt without floral aroma
      state.recordStunt();
      final tipsNoAroma = state.tips; // base 5 * 1.2 = 6

      // Reset and trigger floral aroma
      state.startRun();
      state.recordFlowerKioskVault();
      final tipsAfterKiosk = state.tips; // 30

      state.recordStunt();
      final stuntGainWithAroma = state.tips - tipsAfterKiosk;
      // Stunt with streak 2 (1.5x): base 5 * 1.5 = 7.5 -> 8.
      // With floral aroma (+1.5x): 8 * 1.5 = 12!
      expect(stuntGainWithAroma, greaterThan(tipsNoAroma));
      expect(stuntGainWithAroma, equals(12));
    });

    test('startRun resets flowerKioskVaultsInRun and floralAromaTimer', () {
      state.startRun();
      state.recordFlowerKioskVault();
      expect(state.flowerKioskVaultsInRun, equals(1));
      expect(state.floralAromaTimer, equals(4.0));

      state.startRun();
      expect(state.flowerKioskVaultsInRun, equals(0));
      expect(state.floralAromaTimer, equals(0.0));
      expect(state.isFloralAromaActive, isFalse);
    });
  });

  group('CourierGame Integration with FlowerKioskComponent (Issue #100)', () {
    test('CourierGame spawns and clears activeFlowerKiosks across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final kiosk = FlowerKioskComponent(
        position: Vector2(300.0, 402.0),
        groundY: 460.0,
      );
      game.activeFlowerKiosks.add(kiosk);
      game.world.add(kiosk);

      expect(game.activeFlowerKiosks.contains(kiosk), isTrue);
      expect(game.world.children.contains(kiosk), isTrue);

      game.restartRun();
      expect(game.activeFlowerKiosks.contains(kiosk), isFalse);
      expect(game.world.children.contains(kiosk), isFalse);
    });

    test('CourierGame evaluates checkVault on update and triggers flower kiosk vault', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final kiosk = FlowerKioskComponent(
        position: Vector2(game.player.position.x + 10.0, 402.0),
        groundY: 460.0,
      );
      game.activeFlowerKiosks.add(kiosk);
      game.world.add(kiosk);

      // Make player airborne in vault window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 410.0;

      game.update(0.05);

      expect(kiosk.hasVaulted, isTrue);
      expect(game.gameState.flowerKioskVaultsInRun, equals(1));
      expect(game.gameState.isFloralAromaActive, isTrue);
      expect(audioBackend.playedSfx.contains(GameAudioController.sfxCoin), isTrue);

      // Verify floating text and particle burst were added to world
      expect(
        game.world.children.whereType<FloatingTextComponent>().any((t) => t.text.contains('FLOWER KIOSK VAULT')),
        isTrue,
      );
      expect(
        game.world.children.whereType<ParticleEffectComponent>().length,
        greaterThanOrEqualTo(1),
      );
    });

    test('CourierGame recycles off-screen flower kiosks during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenKiosk = FlowerKioskComponent(
        position: Vector2(-250.0, 402.0),
      );
      game.activeFlowerKiosks.add(offscreenKiosk);
      game.world.add(offscreenKiosk);

      game.update(0.05);
      expect(game.activeFlowerKiosks.contains(offscreenKiosk), isFalse);
    });
  });

  group('HUDOverlay Floral Aroma Badge UI Tests (Issue #100)', () {
    testWidgets('renders floral_aroma_badge when isFloralAromaActive is true', (tester) async {
      final state = GameState();
      state.startRun();
      state.recordFlowerKioskVault();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );

      expect(find.byKey(const Key('floral_aroma_badge')), findsOneWidget);
      expect(find.textContaining('FLORAL AROMA'), findsOneWidget);
      expect(find.textContaining('+1.5X STUNTS'), findsOneWidget);
      expect(find.byIcon(Icons.local_florist), findsOneWidget);
    });

    testWidgets('hides floral_aroma_badge when isFloralAromaActive is false', (tester) async {
      final state = GameState();
      state.startRun();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );

      expect(find.byKey(const Key('floral_aroma_badge')), findsNothing);
    });
  });

  group('GameOverModal Flower Kiosk Badge UI Tests (Issue #100)', () {
    testWidgets('displays game_over_flower_kiosk_badge with singular text when flowerKiosksCompleted == 1',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 400,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              completedContracts: 1,
              contractBonusTips: 50,
              deliveriesCompleted: 2,
              grindsCompleted: 1,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              flowerKiosksCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_flower_kiosk_badge')), findsOneWidget);
      expect(find.text('1 FLOWER KIOSK VAULT'), findsOneWidget);
      expect(find.byIcon(Icons.local_florist), findsOneWidget);
    });

    testWidgets('displays game_over_flower_kiosk_badge with plural text when flowerKiosksCompleted > 1',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 800,
              tips: 340,
              isNewRecord: true,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 100,
              deliveriesCompleted: 4,
              grindsCompleted: 2,
              vaultsCompleted: 3,
              glidesCompleted: 1,
              subwayStationsCompleted: 0,
              flowerKiosksCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_flower_kiosk_badge')), findsOneWidget);
      expect(find.text('3 FLOWER KIOSK VAULTS'), findsOneWidget);
    });

    testWidgets('hides game_over_flower_kiosk_badge when flowerKiosksCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 50,
              isNewRecord: false,
              careerTips: 500,
              completedContracts: 0,
              contractBonusTips: 0,
              deliveriesCompleted: 0,
              grindsCompleted: 0,
              vaultsCompleted: 0,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              flowerKiosksCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_flower_kiosk_badge')), findsNothing);
    });
  });
}
