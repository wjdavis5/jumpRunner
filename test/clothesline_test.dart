import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/clothesline_component.dart';
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

  group('ClotheslineComponent Unit Tests (Issue #112)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final clothesline = ClotheslineComponent(
        position: Vector2(300.0, 232.0),
        width: 96.0,
        height: 48.0,
        roofY: 280.0,
      );

      expect(clothesline.size.x, equals(96.0));
      expect(clothesline.size.y, equals(48.0));
      expect(clothesline.hasHurdled, isFalse);
      expect(clothesline.ropeSagWorldY, equals(232.0 + 14.0)); // 246.0
      expect(clothesline.centerApexWorld, equals(Vector2(300.0 + 48.0, 232.0 + 16.0)));
      expect(clothesline.centerWorldPosition, equals(Vector2(348.0, 256.0)));
      expect(clothesline.shouldRecycle, isFalse);
    });

    test('checkHurdle ignores courier outside horizontal bounds', () {
      final clothesline = ClotheslineComponent(
        position: Vector2(300.0, 232.0),
        roofY: 280.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 280.0);
      sim.isGrounded = false;
      sim.currentY = 260.0;

      // Far left
      final farLeft = clothesline.checkHurdle(
        Vector2(100.0, 220.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = clothesline.checkHurdle(
        Vector2(500.0, 220.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(clothesline.hasHurdled, isFalse);
    });

    test('checkHurdle ignores courier outside vertical window', () {
      final clothesline = ClotheslineComponent(
        position: Vector2(300.0, 232.0),
        roofY: 280.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 280.0);
      sim.isGrounded = false;

      // Too high above clothesline window (windowTop is 232 - 12 = 220)
      sim.currentY = 200.0;
      final tooHigh = clothesline.checkHurdle(
        Vector2(320.0, 160.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Below rooftop baseline (windowBottom is 280 + 6 = 286)
      sim.currentY = 300.0;
      final tooLow = clothesline.checkHurdle(
        Vector2(320.0, 260.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(clothesline.hasHurdled, isFalse);
    });

    test('checkHurdle triggers for courier within interaction window and provides rebound loft launch', () {
      var hurdleReported = false;
      final clothesline = ClotheslineComponent(
        position: Vector2(300.0, 232.0),
        roofY: 280.0,
        onHurdle: () {
          hurdleReported = true;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 280.0);
      sim.isGrounded = false;
      sim.currentY = 260.0;

      final triggered = clothesline.checkHurdle(
        Vector2(320.0, 220.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(hurdleReported, isTrue);
      expect(clothesline.hasHurdled, isTrue);
      expect(sim.verticalVelocity, equals(220.0)); // Elastic rope vault rebound lift

      // Subsequent check does not re-trigger
      expect(clothesline.checkHurdle(Vector2(320.0, 220.0), Vector2(32.0, 40.0), sim), isFalse);
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final clothesline = ClotheslineComponent(
        position: Vector2(-280.0, 232.0),
        width: 96.0,
      );
      expect(clothesline.shouldRecycle, isTrue);

      clothesline.position.x = 0.0;
      expect(clothesline.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state and during rebound oscillation', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final clothesline = ClotheslineComponent(
        position: Vector2(100.0, 232.0),
      );

      // Idle render
      expect(() => clothesline.render(canvas), returnsNormally);

      // Trigger hurdle and update for rebound oscillation
      final sim = JumpPhysicsSimulator(groundY: 280.0);
      sim.isGrounded = false;
      sim.currentY = 250.0;
      clothesline.checkHurdle(Vector2(120.0, 220.0), Vector2(32.0, 40.0), sim);
      clothesline.update(0.1);

      expect(() => clothesline.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.clotheslineLinenScatter Tests (Issue #112)', () {
    test('creates requested number of living particles with buoyant gravity and linen colors', () {
      final scatter = ParticleEffectComponent.clotheslineLinenScatter(
        position: Vector2(250.0, 240.0),
        count: 26,
      );

      expect(scatter.particles.length, equals(26));
      expect(scatter.isFinished, isFalse);

      for (final p in scatter.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(140.0)); // Buoyant cotton flutter
        expect(p.drag, equals(0.94));
      }

      // Step until all particles expire
      scatter.update(1.2);
      expect(scatter.isFinished, isTrue);
    });
  });

  group('GameState Clothesline Hurdle Logic Tests (Issue #112)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordClotheslineHurdle awards tips, advances streak, and tracks clotheslinesInRun', () {
      state.startRun();
      expect(state.clotheslinesHurdledInRun, equals(0));

      ClotheslineEvent? capturedEvent;
      state.onClotheslineHurdle = (e) => capturedEvent = e;

      final event = state.recordClotheslineHurdle(baseTips: 30);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.clotheslinesHurdledInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 30 * 1.2x (stuntStreak 1) = 36
      expect(state.tips, equals(36));
      expect(event!.clotheslinesInRun, equals(1));
    });

    test('startRun resets clotheslinesHurdledInRun', () {
      state.startRun();
      state.recordClotheslineHurdle();
      expect(state.clotheslinesHurdledInRun, equals(1));

      state.startRun();
      expect(state.clotheslinesHurdledInRun, equals(0));
    });

    test('recordClotheslineHurdle returns null when game is not running', () {
      final event = state.recordClotheslineHurdle();
      expect(event, isNull);
      expect(state.clotheslinesHurdledInRun, equals(0));
    });
  });

  group('CourierGame Integration with ClotheslineComponent (Issue #112)', () {
    test('CourierGame spawns and clears activeClotheslines across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final clothesline = ClotheslineComponent(
        position: Vector2(300.0, 232.0),
        roofY: 280.0,
      );
      game.activeClotheslines.add(clothesline);
      game.world.add(clothesline);

      expect(game.activeClotheslines.contains(clothesline), isTrue);
      expect(game.world.children.contains(clothesline), isTrue);

      game.restartRun();
      expect(game.activeClotheslines.contains(clothesline), isFalse);
      expect(game.world.children.contains(clothesline), isFalse);
    });

    test('CourierGame scrolls activeClotheslines horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final clothesline = ClotheslineComponent(
        position: Vector2(450.0, 232.0),
        roofY: 280.0,
      );
      game.activeClotheslines.add(clothesline);
      game.world.add(clothesline);

      final initialX = clothesline.position.x;
      game.update(0.1);

      expect(clothesline.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkHurdle on update and triggers clothesline hurdle', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final clothesline = ClotheslineComponent(
        position: Vector2(game.player.position.x + 10.0, 390.0),
        roofY: 460.0,
      );
      game.activeClotheslines.add(clothesline);
      game.world.add(clothesline);

      // Make player airborne in interaction window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 430.0;

      game.update(0.05);

      expect(clothesline.hasHurdled, isTrue);
      expect(game.gameState.clotheslinesHurdledInRun, equals(1));

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('CLOTHESLINE REBOUND!')), isTrue);

      // Particles spawned
      final scatterFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(scatterFx.isNotEmpty, isTrue);
    });

    test('CourierGame recycles off-screen clotheslines during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenClothesline = ClotheslineComponent(
        position: Vector2(-280.0, 232.0),
      );
      game.activeClotheslines.add(offscreenClothesline);
      game.world.add(offscreenClothesline);

      game.update(0.05);
      expect(game.activeClotheslines.contains(offscreenClothesline), isFalse);
    });
  });

  group('GameOverModal Clothesline Badge UI Tests (Issue #112)', () {
    testWidgets('renders game_over_clothesline_badge with singular text when 1 rebound', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              clotheslinesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_clothesline_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 ROOFTOP CLOTHESLINE REBOUND'), findsOneWidget);
    });

    testWidgets('renders game_over_clothesline_badge with plural text when 2 rebounds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              clotheslinesCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_clothesline_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('2 ROOFTOP CLOTHESLINE REBOUNDS'), findsOneWidget);
    });

    testWidgets('hides game_over_clothesline_badge when 0 rebounds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              clotheslinesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_clothesline_badge'));
      expect(badge, findsNothing);
    });
  });
}
