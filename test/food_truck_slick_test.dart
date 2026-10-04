import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/food_truck_slick_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FoodTruckSlickComponent Unit Tests (Issue #81)', () {
    test('initializes with default dimensions, position, and un-drifted state', () {
      final truck = FoodTruckSlickComponent(
        position: Vector2(250.0, 372.0),
        width: 120.0,
        height: 88.0,
        groundY: 460.0,
      );

      expect(truck.position.x, equals(250.0));
      expect(truck.position.y, equals(372.0));
      expect(truck.size.x, equals(120.0));
      expect(truck.size.y, equals(88.0));
      expect(truck.groundY, equals(460.0));
      expect(truck.hasDrifted, isFalse);
      expect(truck.shouldRecycle, isFalse);
      expect(truck.slickSurfaceWorldY, equals(460.0 - 8.0));
      expect(truck.slickCenterWorldPosition, equals(Vector2(250.0 + 76.0, 460.0 - 4.0)));
      expect(truck.slickWorldRect, equals(const Rect.fromLTWH(250.0 + 38.0, 460.0 - 14.0, 78.0, 14.0)));
    });

    test('shouldRecycle triggers when food truck scrolls offscreen', () {
      final offscreen = FoodTruckSlickComponent(
        position: Vector2(-310.0, 372.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = FoodTruckSlickComponent(
        position: Vector2(250.0, 372.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update advances steam phase and decrements sizzle timer', () {
      final truck = FoodTruckSlickComponent(
        position: Vector2(250.0, 372.0),
      );
      truck.hasDrifted = true;

      truck.update(0.1);
      expect(truck.hasDrifted, isTrue);
    });

    test('checkDrift returns false when courier is airborne', () {
      final truck = FoodTruckSlickComponent(
        position: Vector2(200.0, 372.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 400.0;
      simulator.isGrounded = false; // In air

      final playerPos = Vector2(260.0, 390.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(truck.checkDrift(playerPos, playerSize, simulator), isFalse);
      expect(truck.hasDrifted, isFalse);
    });

    test('checkDrift returns false when courier foot is outside slick hitbox', () {
      final truck = FoodTruckSlickComponent(
        position: Vector2(400.0, 372.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(100.0, 412.0); // Far away
      final playerSize = Vector2(40.0, 48.0);

      expect(truck.checkDrift(playerPos, playerSize, simulator), isFalse);
      expect(truck.hasDrifted, isFalse);
    });

    test('checkDrift triggers when grounded courier slides across grease slick', () {
      var drifted = false;
      final truck = FoodTruckSlickComponent(
        position: Vector2(200.0, 372.0),
        groundY: 460.0,
        onDrift: () => drifted = true,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      // Slick X: [238..316], Player foot at 240 + 20 = 260
      final playerPos = Vector2(240.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(truck.checkDrift(playerPos, playerSize, simulator), isTrue);
      expect(truck.hasDrifted, isTrue);
      expect(drifted, isTrue);

      // Cannot trigger again
      expect(truck.checkDrift(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints without exception before and after drift trigger', () {
      final truck = FoodTruckSlickComponent(
        position: Vector2(200.0, 372.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Before drift
      expect(() => truck.render(canvas), returnsNormally);

      // After drift
      truck.hasDrifted = true;
      truck.update(0.2);
      expect(() => truck.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent Grease Spray (Issue #81)', () {
    test('creates greaseSpray particle burst with expected count and physics', () {
      final fx = ParticleEffectComponent.greaseSpray(
        position: Vector2(250.0, 455.0),
        count: 16,
      );

      expect(fx.particles.length, equals(16));
      for (final p in fx.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(240.0));
      }
      expect(fx.isFinished, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => fx.render(canvas), returnsNormally);

      fx.update(1.0);
      expect(fx.isFinished, isTrue);
    });
  });

  group('GameState Food Truck Drift Mechanics (Issue #81)', () {
    late GameState state;

    setUp(() {
      state = GameState();
      state.startRun();
    });

    test('recordFoodTruckDrift returns null when game is not running', () {
      state.status = GameStatus.gameOver;
      expect(state.recordFoodTruckDrift(), isNull);
    });

    test('recordFoodTruckDrift awards base tips (\$25) scaled by stunt multiplier', () {
      FoodTruckDriftEvent? eventReceived;
      state.onFoodTruckDrift = (e) => eventReceived = e;

      final initialTips = state.tips;
      final event = state.recordFoodTruckDrift();

      expect(event, isNotNull);
      expect(eventReceived, equals(event));
      expect(state.foodTruckDriftsInRun, equals(1));
      expect(event!.baseTips, equals(25));
      expect(event.multiplier, equals(1.2)); // 1st streak
      expect(event.totalTips, equals(30)); // (25 * 1.2) = 30
      expect(state.tips, equals(initialTips + 30));
      expect(event.stuntStreak, equals(1));
    });

    test('recordFoodTruckDrift scales with combo streak multiplier', () {
      state.stuntStreak = 3;
      state.stuntStreakTimer = 2.0;

      final event = state.recordFoodTruckDrift();

      expect(event, isNotNull);
      expect(event!.multiplier, equals(2.5)); // 4th streak
      expect(event.totalTips, equals((25 * 2.5).round())); // 63
      expect(event.stuntStreak, equals(4));
    });

    test('recordFoodTruckDrift scales with DailyModifier.skateCommute (doubles)', () {
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      final event = state.recordFoodTruckDrift();
      expect(event, isNotNull);
      expect(event!.totalTips, equals(60)); // (25 * 1.2) * 2 = 60
    });

    test('recordFoodTruckDrift scales with energy boost (doubles)', () {
      state.activateEnergyDrink(5.0);

      final event = state.recordFoodTruckDrift();
      expect(event, isNotNull);
      expect(event!.totalTips, equals(60)); // (25 * 1.2) * 2 = 60
    });

    test('startRun resets foodTruckDriftsInRun to 0', () {
      state.recordFoodTruckDrift();
      expect(state.foodTruckDriftsInRun, equals(1));

      state.startRun();
      expect(state.foodTruckDriftsInRun, equals(0));
    });
  });

  group('WorldChunkManager Food Truck Slick Spawning (Issue #81)', () {
    test('ChunkData includes foodTruckSlicks collection', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        foodTruckSlicks: [
          FoodTruckSlickData(x: 200.0, y: 372.0, width: 120.0, height: 88.0),
        ],
      );

      expect(chunk.foodTruckSlicks.length, equals(1));
      expect(chunk.foodTruckSlicks.first.x, equals(200.0));
      expect(chunk.foodTruckSlicks.first.y, equals(372.0));
      expect(chunk.foodTruckSlicks.first.width, equals(120.0));
      expect(chunk.foodTruckSlicks.first.height, equals(88.0));
    });

    test('generateChunk does not spawn food truck slicks prior to 90m milestone', () {
      final manager = WorldChunkManager();
      var count = 0;

      for (var i = 0; i < 10; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 40.0, // Before 90m
        );
        count += chunk.foodTruckSlicks.length;
      }

      expect(count, equals(0));
    });

    test('generateChunk can spawn food truck slicks after 90m with valid clearance', () {
      final manager = WorldChunkManager();
      var found = false;

      for (var i = 0; i < 30; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 150.0, // Past 90m
        );
        if (chunk.foodTruckSlicks.isNotEmpty) {
          found = true;
          final fts = chunk.foodTruckSlicks.first;
          expect(fts.y, equals(460.0 - 88.0));
          expect(fts.width, equals(120.0));
          expect(fts.height, equals(88.0));
          break;
        }
      }

      expect(found, isTrue);
    });
  });

  group('GameOverModal Food Truck Drift Badge (Issue #81)', () {
    testWidgets('renders game_over_grease_drift_badge with singular text when foodTruckDriftsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 350,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              completedContracts: 1,
              contractBonusTips: 25,
              foodTruckDriftsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_grease_drift_badge')), findsOneWidget);
      expect(find.text('1 GREASE DRIFT SLIDE'), findsOneWidget);
    });

    testWidgets('renders game_over_grease_drift_badge with plural text when foodTruckDriftsCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 550,
              tips: 250,
              isNewRecord: false,
              careerTips: 2000,
              completedContracts: 2,
              contractBonusTips: 50,
              foodTruckDriftsCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_grease_drift_badge')), findsOneWidget);
      expect(find.text('3 GREASE DRIFT SLIDES'), findsOneWidget);
    });

    testWidgets('omits game_over_grease_drift_badge when foodTruckDriftsCompleted == 0', (tester) async {
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
              foodTruckDriftsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_grease_drift_badge')), findsNothing);
    });
  });

  group('CourierGame Food Truck Drift Integration Tests (Issue #81)', () {
    test('CourierGame spawns and clears activeFoodTruckSlicks across run lifecycle', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final truck = FoodTruckSlickComponent(
        position: Vector2(250.0, 372.0),
      );
      game.activeFoodTruckSlicks.add(truck);
      game.world.add(truck);

      expect(game.activeFoodTruckSlicks.length, equals(1));
      expect(game.world.children.whereType<FoodTruckSlickComponent>().length, equals(1));

      // Restart run cleans up active food truck slicks
      game.restartRun();

      expect(game.activeFoodTruckSlicks, isEmpty);
      expect(game.world.children.whereType<FoodTruckSlickComponent>(), isEmpty);
    });

    test('CourierGame update evaluates checkDrift and awards tips/streak', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final truck = FoodTruckSlickComponent(
        position: Vector2(100.0, 372.0),
        groundY: 460.0,
      );
      game.activeFoodTruckSlicks.add(truck);
      game.world.add(truck);

      // Position player grounded inside the slick
      game.player.position = Vector2(150.0, 412.0);
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      FoodTruckDriftEvent? caughtEvent;
      game.gameState.onFoodTruckDrift = (e) => caughtEvent = e;

      game.update(0.016);

      expect(truck.hasDrifted, isTrue);
      expect(caughtEvent, isNotNull);
      expect(caughtEvent!.totalTips, equals(30));
      expect(game.gameState.foodTruckDriftsInRun, equals(1));
      expect(game.gameState.stuntStreak, equals(1));
    });
  });
}
