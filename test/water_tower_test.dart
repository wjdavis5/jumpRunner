import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/water_tower_component.dart';
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaterTowerComponent Unit Tests (Issue #103)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        width: 86.0,
        height: 110.0,
        groundY: 460.0,
      );

      expect(tower.size.x, equals(86.0));
      expect(tower.size.y, equals(110.0));
      expect(tower.hasTriggered, isFalse);
      expect(tower.isBreached, isFalse);
      expect(tower.catwalkWorldY, equals(460.0 - 110.0 + 60.0)); // 410.0
      expect(tower.apexWorldPosition, equals(Vector2(343.0, 356.0)));
      expect(tower.breachWorldPosition, equals(Vector2(343.0, 415.0)));
      expect(tower.centerWorldPosition, equals(Vector2(343.0, 405.0)));
      expect(tower.shouldRecycle, isFalse);
    });

    test('checkTraverse ignores grounded courier even if positioned within tower bounds', () {
      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final traversed = tower.checkTraverse(
        Vector2(320.0, 400.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(traversed, isFalse);
      expect(tower.hasTriggered, isFalse);
    });

    test('checkTraverse ignores airborne courier when horizontally outside tower bounds', () {
      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 380.0;

      // Far left
      final farLeft = tower.checkTraverse(
        Vector2(200.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = tower.checkTraverse(
        Vector2(450.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(tower.hasTriggered, isFalse);
    });

    test('checkTraverse ignores airborne courier outside vertical interaction windows', () {
      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Way above tower apex
      sim.currentY = 280.0;
      final tooHigh = tower.checkTraverse(
        Vector2(320.0, 240.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // In breach region but traveling rapidly upward (verticalVelocity > 60.0)
      sim.currentY = 435.0;
      sim.verticalVelocity = 200.0;
      final upwardThroughTrestle = tower.checkTraverse(
        Vector2(320.0, 395.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(upwardThroughTrestle, isFalse);
      expect(tower.hasTriggered, isFalse);
    });

    test('checkTraverse triggers catwalk apex launch (+300 px/s loft) and wobble', () {
      bool? breachReported;
      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        groundY: 460.0,
        onTraverse: ({required bool isBreach}) {
          breachReported = isBreach;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 380.0; // In catwalk window (catwalkWorldY is 410.0)

      final traversed = tower.checkTraverse(
        Vector2(320.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(traversed, isTrue);
      expect(tower.hasTriggered, isTrue);
      expect(tower.isBreached, isFalse);
      expect(breachReported, isFalse);
      expect(sim.verticalVelocity, equals(300.0)); // Upward loft

      // Second check does not re-trigger
      final secondCheck = tower.checkTraverse(
        Vector2(320.0, 340.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);

      // Update steps wobble
      tower.update(0.1);
      expect(tower.hasTriggered, isTrue);
    });

    test('checkTraverse triggers timber stave breach cascade (+180 px/s) on downward impact', () {
      bool? breachReported;
      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        groundY: 460.0,
        onTraverse: ({required bool isBreach}) {
          breachReported = isBreach;
        },
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 435.0; // In breach window (> catwalkTop + 18)
      sim.verticalVelocity = -80.0; // Descending downward velocity <= 60.0

      final traversed = tower.checkTraverse(
        Vector2(320.0, 395.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(traversed, isTrue);
      expect(tower.hasTriggered, isTrue);
      expect(tower.isBreached, isTrue);
      expect(breachReported, isTrue);
      expect(sim.verticalVelocity, equals(180.0));
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final tower = WaterTowerComponent(
        position: Vector2(-280.0, 350.0),
        width: 86.0,
      );
      expect(tower.shouldRecycle, isTrue);

      tower.position.x = 0.0;
      expect(tower.shouldRecycle, isFalse);
    });

    test('render paints without exception during idle, catwalk launch wobble, and breached cascade', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final tower = WaterTowerComponent(
        position: Vector2(100.0, 350.0),
      );

      // Idle render
      expect(() => tower.render(canvas), returnsNormally);

      // Breached state with wobble
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 435.0;
      sim.verticalVelocity = -80.0;
      tower.checkTraverse(Vector2(120.0, 395.0), Vector2(32.0, 40.0), sim);
      tower.update(0.1);
      expect(tower.isBreached, isTrue);
      expect(() => tower.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.waterTowerDeluge Tests (Issue #103)', () {
    test('creates requested number of living particles with cascade velocity and water/cedar colors', () {
      final deluge = ParticleEffectComponent.waterTowerDeluge(
        position: Vector2(250.0, 400.0),
        count: 26,
      );

      expect(deluge.particles.length, equals(26));
      expect(deluge.isFinished, isFalse);

      for (final p in deluge.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(240.0)); // Rushing heavy water cascade gravity
      }

      // Step until all particles expire
      deluge.update(1.2);
      expect(deluge.isFinished, isTrue);
    });
  });

  group('GameState Water Tower Logic Tests (Issue #103)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordWaterTowerTraverse catwalk awards base tips and advances stunt streak', () {
      state.startRun();
      expect(state.waterTowersTraversedInRun, equals(0));

      WaterTowerEvent? capturedEvent;
      state.onWaterTowerTraversed = (e) => capturedEvent = e;

      final event = state.recordWaterTowerTraverse(isBreachCascade: false);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.waterTowersTraversedInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 35 * 1.2x (stuntStreak 1) = 42
      expect(state.tips, equals(42));
      expect(event!.baseTips, equals(35));
      expect(event.isBreachCascade, isFalse);
    });

    test('recordWaterTowerTraverse breach cascade awards increased base tips (\$45)', () {
      state.startRun();
      final event = state.recordWaterTowerTraverse(isBreachCascade: true);
      expect(event, isNotNull);
      expect(event!.baseTips, equals(45));
      expect(event.isBreachCascade, isTrue);
      // Base 45 * 1.2x (stuntStreak 1) = 54
      expect(state.tips, equals(54));
      expect(state.waterTowersTraversedInRun, equals(1));
    });

    test('recordWaterTowerTraverse returns null when run is not running', () {
      final event = state.recordWaterTowerTraverse();
      expect(event, isNull);
      expect(state.waterTowersTraversedInRun, equals(0));
    });

    test('startRun resets waterTowersTraversedInRun', () {
      state.startRun();
      state.recordWaterTowerTraverse();
      expect(state.waterTowersTraversedInRun, equals(1));

      state.startRun();
      expect(state.waterTowersTraversedInRun, equals(0));
    });
  });

  group('CourierGame Integration with WaterTowerComponent (Issue #103)', () {
    test('CourierGame spawns and clears activeWaterTowers across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final tower = WaterTowerComponent(
        position: Vector2(300.0, 350.0),
        groundY: 460.0,
      );
      game.activeWaterTowers.add(tower);
      game.world.add(tower);

      expect(game.activeWaterTowers.contains(tower), isTrue);
      expect(game.world.children.contains(tower), isTrue);

      game.restartRun();
      expect(game.activeWaterTowers.contains(tower), isFalse);
      expect(game.world.children.contains(tower), isFalse);
    });

    test('CourierGame scrolls activeWaterTowers horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final tower = WaterTowerComponent(
        position: Vector2(500.0, 350.0),
        groundY: 460.0,
      );
      game.activeWaterTowers.add(tower);
      game.world.add(tower);

      final initialX = tower.position.x;
      game.update(0.1);

      expect(tower.position.x, lessThan(initialX));
    });

    test('CourierGame evaluates checkTraverse on update for catwalk launch', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final tower = WaterTowerComponent(
        position: Vector2(game.player.position.x + 10.0, 350.0),
        groundY: 460.0,
      );
      game.activeWaterTowers.add(tower);
      game.world.add(tower);

      // Make player airborne in catwalk window
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 380.0;

      game.update(0.05);

      expect(tower.hasTriggered, isTrue);
      expect(tower.isBreached, isFalse);
      expect(game.gameState.waterTowersTraversedInRun, equals(1));
      expect(game.player.isGliding, isTrue);

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('CATWALK LAUNCH!')), isTrue);

      // Deluge particles spawned
      final delugeFx = game.world.children.whereType<ParticleEffectComponent>();
      expect(delugeFx.isNotEmpty, isTrue);
    });

    test('CourierGame evaluates checkTraverse on update for stave breach stomp', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final tower = WaterTowerComponent(
        position: Vector2(game.player.position.x + 10.0, 350.0),
        groundY: 460.0,
      );
      game.activeWaterTowers.add(tower);
      game.world.add(tower);

      // Make player airborne in breach window with downward velocity
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 435.0;
      game.player.simulator.verticalVelocity = -80.0;

      game.update(0.05);

      expect(tower.hasTriggered, isTrue);
      expect(tower.isBreached, isTrue);
      expect(game.gameState.waterTowersTraversedInRun, equals(1));

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('WATER TOWER BREACH!')), isTrue);
    });

    test('CourierGame recycles off-screen water towers', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final tower = WaterTowerComponent(
        position: Vector2(-280.0, 350.0),
        groundY: 460.0,
      );
      game.activeWaterTowers.add(tower);
      game.world.add(tower);

      game.update(0.05);

      expect(game.activeWaterTowers.contains(tower), isFalse);
    });
  });

  group('GameOverModal Water Tower Badge Tests (Issue #103)', () {
    testWidgets('renders game_over_water_tower_badge with singular text when 1 traverse', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 500,
              tips: 120,
              isNewRecord: false,
              careerTips: 800,
              waterTowersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_water_tower_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 WATER TOWER TRAVERSE'), findsOneWidget);
    });

    testWidgets('renders game_over_water_tower_badge with plural text when 3 traverses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 850,
              tips: 340,
              isNewRecord: false,
              careerTips: 1200,
              waterTowersCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_water_tower_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('3 WATER TOWER TRAVERSES'), findsOneWidget);
    });

    testWidgets('hides game_over_water_tower_badge when 0 traverses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 80,
              isNewRecord: false,
              careerTips: 500,
              waterTowersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_water_tower_badge'));
      expect(badge, findsNothing);
    });
  });
}
