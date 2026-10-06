import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/newsstand_component.dart';
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

  group('NewsstandComponent Unit Tests (Issue #105)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final newsstand = NewsstandComponent(
        position: Vector2(300.0, 398.0),
        width: 82.0,
        height: 62.0,
        groundY: 460.0,
      );

      expect(newsstand.size.x, equals(82.0));
      expect(newsstand.size.y, equals(62.0));
      expect(newsstand.hasVaulted, isFalse);
      expect(newsstand.counterWorldY, equals(460.0 - 32.0)); // 428.0
      expect(newsstand.counterApexWorld, equals(Vector2(341.0, 428.0)));
      expect(newsstand.centerWorldPosition, equals(Vector2(341.0, 429.0)));
      expect(newsstand.shouldRecycle, isFalse);
    });

    test('checkVault ignores grounded courier even if within bounds', () {
      final newsstand = NewsstandComponent(
        position: Vector2(300.0, 398.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final vaulted = newsstand.checkVault(
        Vector2(320.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isFalse);
      expect(newsstand.hasVaulted, isFalse);
    });

    test('checkVault ignores airborne courier horizontally outside kiosk bounds', () {
      final newsstand = NewsstandComponent(
        position: Vector2(300.0, 398.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 428.0;

      // Far left
      final farLeft = newsstand.checkVault(
        Vector2(200.0, 388.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = newsstand.checkVault(
        Vector2(450.0, 388.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(newsstand.hasVaulted, isFalse);
    });

    test('checkVault ignores airborne courier outside vertical vault window', () {
      final newsstand = NewsstandComponent(
        position: Vector2(300.0, 398.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Way above counter
      sim.currentY = 380.0;
      final tooHigh = newsstand.checkVault(
        Vector2(320.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Way below counter level
      sim.currentY = 458.0;
      final tooLow = newsstand.checkVault(
        Vector2(320.0, 418.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(newsstand.hasVaulted, isFalse);
    });

    test('checkVault triggers hurdle vault, launches avatar, wobbles, and spins postcard rack', () {
      var vaultReported = false;
      final newsstand = NewsstandComponent(
        position: Vector2(300.0, 398.0),
        groundY: 460.0,
        onVault: () {
          vaultReported = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 428.0; // Right at counter level

      final vaulted = newsstand.checkVault(
        Vector2(320.0, 388.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isTrue);
      expect(vaultReported, isTrue);
      expect(newsstand.hasVaulted, isTrue);
      expect(sim.verticalVelocity, equals(200.0)); // Launch hop

      // Subsequent check does not re-trigger
      final secondCheck = newsstand.checkVault(
        Vector2(320.0, 388.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);

      // Update advances wobble and postcard spin
      newsstand.update(0.1);
      expect(newsstand.hasVaulted, isTrue);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final newsstand = NewsstandComponent(
        position: Vector2(-280.0, 398.0),
        width: 82.0,
      );
      expect(newsstand.shouldRecycle, isTrue);

      newsstand.position.x = 0.0;
      expect(newsstand.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state, wobble oscillation, and postcard spin', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final newsstand = NewsstandComponent(
        position: Vector2(100.0, 398.0),
      );

      // Idle render
      expect(() => newsstand.render(canvas), returnsNormally);

      // Vaulted state with wobble & spinning rack
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 428.0;
      newsstand.checkVault(Vector2(120.0, 388.0), Vector2(32.0, 40.0), sim);
      newsstand.update(0.1);
      expect(() => newsstand.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.newsprintScatter Tests (Issue #105)', () {
    test('creates requested number of living particles with fanning velocity and paper colors', () {
      final scatter = ParticleEffectComponent.newsprintScatter(
        position: Vector2(250.0, 400.0),
        count: 24,
      );

      expect(scatter.particles.length, equals(24));
      expect(scatter.isFinished, isFalse);

      for (final p in scatter.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(48.0)); // Gentle floating drift
        expect(p.drag, equals(1.65)); // Aerodynamic paper flutter drag
      }

      // Step until all particles expire
      scatter.update(1.2);
      expect(scatter.isFinished, isTrue);
    });
  });

  group('GameState Newsstand & Notoriety Logic Tests (Issue #105)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordNewsstandVault awards tips, advances streak, and activates notoriety buff', () {
      state.startRun();
      expect(state.newsstandsVaultedInRun, equals(0));
      expect(state.isNotorietyActive, isFalse);
      expect(state.notorietyTimer, equals(0.0));

      NewsstandEvent? capturedEvent;
      state.onNewsstandVault = (e) => capturedEvent = e;

      final event = state.recordNewsstandVault(baseTips: 28);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.newsstandsVaultedInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 28 * 1.2x (stuntStreak 1) = 34
      expect(state.tips, equals(34));
      expect(state.isNotorietyActive, isTrue);
      expect(state.notorietyTimer, equals(4.0));
      expect(event!.notorietyDuration, equals(4.0));
    });

    test('updateNotorietyTimer counts down and expires notoriety buff', () {
      state.startRun();
      state.recordNewsstandVault();
      expect(state.isNotorietyActive, isTrue);

      state.updateNotorietyTimer(2.0);
      expect(state.notorietyTimer, equals(2.0));
      expect(state.isNotorietyActive, isTrue);

      state.updateNotorietyTimer(2.5);
      expect(state.notorietyTimer, equals(0.0));
      expect(state.isNotorietyActive, isFalse);
    });

    test('active notoriety applies +1.5x score multiplier to subsequent near-miss stunts', () {
      state.startRun();
      state.recordStunt();
      final tipsNoBuff = state.tips; // base 5 * 1.2 = 6

      // Reset and trigger notoriety
      state.startRun();
      state.recordNewsstandVault();
      final tipsAfterVault = state.tips;

      state.recordStunt();
      final stuntGainWithNotoriety = state.tips - tipsAfterVault;
      // Stunt with streak 2 (1.5x): base 5 * 1.5 = 7.5 -> 8.
      // With notoriety (+1.5x): 8 * 1.5 = 12!
      expect(stuntGainWithNotoriety, greaterThan(tipsNoBuff));
      expect(stuntGainWithNotoriety, equals(12));
    });

    test('startRun resets newsstandsVaultedInRun and notorietyTimer', () {
      state.startRun();
      state.recordNewsstandVault();
      expect(state.newsstandsVaultedInRun, equals(1));
      expect(state.notorietyTimer, equals(4.0));

      state.startRun();
      expect(state.newsstandsVaultedInRun, equals(0));
      expect(state.notorietyTimer, equals(0.0));
      expect(state.isNotorietyActive, isFalse);
    });

    test('recordNewsstandVault returns null when game is not running', () {
      final event = state.recordNewsstandVault();
      expect(event, isNull);
      expect(state.newsstandsVaultedInRun, equals(0));
    });
  });

  group('CourierGame Integration with NewsstandComponent (Issue #105)', () {
    test('CourierGame spawns and clears activeNewsstands across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final newsstand = NewsstandComponent(
        position: Vector2(300.0, 398.0),
        groundY: 460.0,
      );
      game.activeNewsstands.add(newsstand);
      game.world.add(newsstand);

      expect(game.activeNewsstands.contains(newsstand), isTrue);
      expect(game.world.children.contains(newsstand), isTrue);

      game.restartRun();
      expect(game.activeNewsstands.contains(newsstand), isFalse);
      expect(game.world.children.contains(newsstand), isFalse);
    });

    test('CourierGame scrolls activeNewsstands horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final newsstand = NewsstandComponent(
        position: Vector2(450.0, 398.0),
        groundY: 460.0,
      );
      game.activeNewsstands.add(newsstand);
      game.world.add(newsstand);

      final initialX = newsstand.position.x;
      game.update(0.1);

      expect(newsstand.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkVault on update and triggers newsstand vault', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final newsstand = NewsstandComponent(
        position: Vector2(game.player.position.x + 10.0, 398.0),
        groundY: 460.0,
      );
      game.activeNewsstands.add(newsstand);
      game.world.add(newsstand);

      // Make player airborne in vault window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 428.0;

      game.update(0.05);

      expect(newsstand.hasVaulted, isTrue);
      expect(game.gameState.newsstandsVaultedInRun, equals(1));
      expect(game.gameState.isNotorietyActive, isTrue);

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('EXTRA! EXTRA! VAULT!')), isTrue);

      // Particles spawned
      final scatterFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(scatterFx.isNotEmpty, isTrue);
    });

    test('CourierGame recycles off-screen newsstands during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenStand = NewsstandComponent(
        position: Vector2(-280.0, 398.0),
      );
      game.activeNewsstands.add(offscreenStand);
      game.world.add(offscreenStand);

      game.update(0.05);
      expect(game.activeNewsstands.contains(offscreenStand), isFalse);
    });
  });

  group('HUDOverlay Notoriety Badge UI Tests (Issue #105)', () {
    testWidgets('renders notoriety_badge when isNotorietyActive is true', (tester) async {
      final state = GameState();
      state.startRun();
      state.recordNewsstandVault();

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

      final badge = find.byKey(const Key('notoriety_badge'));
      expect(badge, findsOneWidget);
      expect(find.textContaining('EXTRA! EXTRA!'), findsOneWidget);
    });

    testWidgets('hides notoriety_badge when isNotorietyActive is false', (tester) async {
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

      final badge = find.byKey(const Key('notoriety_badge'));
      expect(badge, findsNothing);
    });
  });

  group('GameOverModal Newsstand Badge UI Tests (Issue #105)', () {
    testWidgets('renders game_over_newsstand_badge with singular text when 1 vault', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              newsstandsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_newsstand_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 NEWSSTAND VAULT'), findsOneWidget);
    });

    testWidgets('renders game_over_newsstand_badge with plural text when 2 vaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              newsstandsCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_newsstand_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('2 NEWSSTAND VAULTS'), findsOneWidget);
    });

    testWidgets('hides game_over_newsstand_badge when 0 vaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              newsstandsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_newsstand_badge'));
      expect(badge, findsNothing);
    });
  });
}
