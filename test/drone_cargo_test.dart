import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/drone_cargo_component.dart';
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

  group('DroneCargoComponent Unit Tests (Issue #77)', () {
    test('initializes with default dimensions, altitude, and active cargo', () {
      final drone = DroneCargoComponent(
        position: Vector2(300.0, 250.0),
        width: 48.0,
        height: 42.0,
        groundY: 460.0,
        relativeSpeed: -20.0,
      );

      expect(drone.position.x, equals(300.0));
      expect(drone.position.y, equals(250.0));
      expect(drone.size.x, equals(48.0));
      expect(drone.size.y, equals(42.0));
      expect(drone.baseAltitudeY, equals(250.0));
      expect(drone.groundY, equals(460.0));
      expect(drone.relativeSpeed, equals(-20.0));
      expect(drone.hasCargo, isTrue);
      expect(drone.hasBeenIntercepted, isFalse);
      expect(drone.shouldRecycle, isFalse);
      expect(drone.crateWorldRect, equals(const Rect.fromLTWH(312.0, 272.0, 24.0, 20.0)));
      expect(drone.crateCenterWorld, equals(Vector2(324.0, 282.0)));
    });

    test('shouldRecycle triggers when drone scrolls offscreen or flies out vertically', () {
      final offscreenLeft = DroneCargoComponent(
        position: Vector2(-200.0, 250.0),
      );
      expect(offscreenLeft.shouldRecycle, isTrue);

      final ascendedSky = DroneCargoComponent(
        position: Vector2(300.0, -130.0),
      );
      expect(ascendedSky.shouldRecycle, isTrue);

      final onscreen = DroneCargoComponent(
        position: Vector2(300.0, 250.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update bobs altitude sinusoidally and updates rotor/blink timers', () {
      final drone = DroneCargoComponent(
        position: Vector2(300.0, 250.0),
        relativeSpeed: 0.0,
      );

      drone.update(0.1);
      expect(drone.position.y, isNot(equals(250.0))); // Bobbed away from base altitude
      expect(drone.hasCargo, isTrue);
      expect(drone.hasBeenIntercepted, isFalse);
    });

    test('update accelerates drone up and away once intercepted', () {
      final drone = DroneCargoComponent(
        position: Vector2(300.0, 250.0),
        relativeSpeed: 0.0,
      );
      drone.hasBeenIntercepted = true;
      drone.hasCargo = false;

      final startY = drone.position.y;
      final startX = drone.position.x;
      drone.update(0.2);

      expect(drone.position.y, lessThan(startY)); // Ascending
      expect(drone.position.x, greaterThan(startX)); // Accelerating forward
    });

    test('checkIntercept returns false if player is grounded', () {
      final drone = DroneCargoComponent(
        position: Vector2(200.0, 250.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(205.0, 260.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(drone.checkIntercept(playerPos, playerSize, simulator), isFalse);
      expect(drone.hasCargo, isTrue);
      expect(drone.hasBeenIntercepted, isFalse);
    });

    test('checkIntercept returns false if player does not overlap crate', () {
      final drone = DroneCargoComponent(
        position: Vector2(500.0, 250.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 350.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 350.0); // Far to the left
      final playerSize = Vector2(40.0, 48.0);

      expect(drone.checkIntercept(playerPos, playerSize, simulator), isFalse);
      expect(drone.hasCargo, isTrue);
      expect(drone.hasBeenIntercepted, isFalse);
    });

    test('checkIntercept triggers successfully when airborne player overlaps crate hitbox', () {
      var intercepted = false;
      final drone = DroneCargoComponent(
        position: Vector2(200.0, 250.0),
        onIntercept: () => intercepted = true,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 270.0;
      simulator.isGrounded = false;

      // Crate world rect: x in [212..236], y in [272..292], inflated by 14: [198..250], [258..306]
      final playerPos = Vector2(210.0, 265.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(drone.checkIntercept(playerPos, playerSize, simulator), isTrue);
      expect(drone.hasCargo, isFalse);
      expect(drone.hasBeenIntercepted, isTrue);
      expect(intercepted, isTrue);

      // Cannot intercept again
      expect(drone.checkIntercept(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints without exception in both cargo and departed states', () {
      final drone = DroneCargoComponent(
        position: Vector2(200.0, 250.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // With cargo
      expect(() => drone.render(canvas), returnsNormally);

      // Intercepted / departed without cargo
      drone.hasCargo = false;
      drone.hasBeenIntercepted = true;
      expect(() => drone.render(canvas), returnsNormally);
    });
  });

  group('GameState Drone Catch Mechanics (Issue #77)', () {
    late GameState state;

    setUp(() {
      state = GameState();
      state.startRun();
    });

    test('recordDroneCatch returns null if game is not running', () {
      state.status = GameStatus.gameOver;
      final event = state.recordDroneCatch();
      expect(event, isNull);
    });

    test('recordDroneCatch awards base tips (\$35) and increments droneCatchesInRun', () {
      DroneCatchEvent? receivedEvent;
      state.onDroneCatch = (e) => receivedEvent = e;

      final initialTips = state.tips;
      final event = state.recordDroneCatch();

      expect(event, isNotNull);
      expect(receivedEvent, equals(event));
      expect(state.droneCatchesInRun, equals(1));
      expect(event!.baseTips, equals(35));
      expect(event.multiplier, equals(1.2));
      expect(event.totalTips, equals(42));
      expect(state.tips, equals(initialTips + 42));
      expect(event.stuntStreak, equals(1));
    });

    test('recordDroneCatch scales with stunt combo multiplier', () {
      state.stuntStreak = 3;
      state.stuntStreakTimer = 2.0;

      final event = state.recordDroneCatch();

      expect(event, isNotNull);
      expect(event!.multiplier, equals(2.5));
      expect(event.totalTips, equals((35 * 2.5).round()));
      expect(event.stuntStreak, equals(4));
    });

    test('recordDroneCatch scales with DailyModifier.skateCommute', () {
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      final event = state.recordDroneCatch();
      expect(event, isNotNull);
      expect(event!.totalTips, equals(84)); // (35 * 1.2) * 2
    });

    test('recordDroneCatch scales with energy boost (2x)', () {
      state.activateEnergyDrink(5.0);

      final event = state.recordDroneCatch();
      expect(event, isNotNull);
      expect(event!.totalTips, equals(84)); // (35 * 1.2) * 2
    });

    test('recordDroneCatch restores lost package HP when damaged', () {
      state.packages = 2; // Lost 1 package
      var packageRestoredFired = false;
      state.onPackageRestored = () => packageRestoredFired = true;

      final event = state.recordDroneCatch();

      expect(event, isNotNull);
      expect(event!.restoredPackage, isTrue);
      expect(state.packages, equals(3)); // Restored back to maxPackages (3)
      expect(packageRestoredFired, isTrue);
    });

    test('recordDroneCatch does not restore package when already at max HP', () {
      state.packages = state.maxPackages;
      var packageRestoredFired = false;
      state.onPackageRestored = () => packageRestoredFired = true;

      final event = state.recordDroneCatch();

      expect(event, isNotNull);
      expect(event!.restoredPackage, isFalse);
      expect(state.packages, equals(state.maxPackages));
      expect(packageRestoredFired, isFalse);
    });

    test('startRun resets droneCatchesInRun to 0', () {
      state.recordDroneCatch();
      expect(state.droneCatchesInRun, equals(1));

      state.startRun();
      expect(state.droneCatchesInRun, equals(0));
    });
  });

  group('ParticleEffectComponent Drone Cargo Effects (Issue #77)', () {
    test('creates droneCargo particle effect with expected burst characteristics', () {
      final fx = ParticleEffectComponent.droneCargo(
        position: Vector2(250.0, 200.0),
        count: 20,
      );

      expect(fx.particles.length, equals(20));
      for (final p in fx.particles) {
        expect(p.isAlive, isTrue);
      }
      expect(fx.isFinished, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => fx.render(canvas), returnsNormally);

      fx.update(1.0);
      expect(fx.isFinished, isTrue);
    });
  });

  group('WorldChunkManager Drone Cargo Spawning (Issue #77)', () {
    test('ChunkData includes droneCargos collection', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        droneCargos: [
          DroneCargoData(x: 300.0, y: 250.0, width: 48.0, height: 42.0),
        ],
      );

      expect(chunk.droneCargos.length, equals(1));
      expect(chunk.droneCargos.first.x, equals(300.0));
      expect(chunk.droneCargos.first.y, equals(250.0));
      expect(chunk.droneCargos.first.width, equals(48.0));
      expect(chunk.droneCargos.first.height, equals(42.0));
    });

    test('generateChunk does not spawn drone cargos prior to 140m milestone', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var droneCount = 0;

      for (var i = 0; i < 10; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 50.0, // Before 140m
        );
        droneCount += chunk.droneCargos.length;
      }

      expect(droneCount, equals(0));
    });

    test('generateChunk can spawn drone cargos after 140m with valid aerial altitude', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var droneFound = false;

      for (var i = 0; i < 30; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 250.0, // Past 140m
        );
        if (chunk.droneCargos.isNotEmpty) {
          droneFound = true;
          final d = chunk.droneCargos.first;
          expect(d.y, equals(460.0 - 210.0));
          expect(d.width, equals(48.0));
          expect(d.height, equals(42.0));
          break;
        }
      }

      expect(droneFound, isTrue);
    });
  });

  group('GameOverModal Drone Cargo Catch Badge (Issue #77)', () {
    testWidgets('renders game_over_drone_catch_badge when droneCatchesCompleted > 0', (tester) async {
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
              droneCatchesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_drone_catch_badge')), findsOneWidget);
      expect(find.text('1 DRONE CARGO CATCH'), findsOneWidget);
    });

    testWidgets('formats plural text when multiple drone catches occurred', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 200,
              isNewRecord: false,
              careerTips: 1500,
              completedContracts: 2,
              contractBonusTips: 50,
              droneCatchesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_drone_catch_badge')), findsOneWidget);
      expect(find.text('3 DRONE CARGO CATCHES'), findsOneWidget);
    });

    testWidgets('omits game_over_drone_catch_badge when droneCatchesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 250,
              tips: 50,
              isNewRecord: false,
              careerTips: 500,
              completedContracts: 0,
              contractBonusTips: 0,
              droneCatchesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_drone_catch_badge')), findsNothing);
    });
  });

  group('CourierGame Drone Cargo Integration Tests (Issue #77)', () {
    test('CourierGame spawns and clears activeDroneCargos across run lifecycle', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final drone = DroneCargoComponent(
        position: Vector2(300.0, 250.0),
      );
      game.activeDroneCargos.add(drone);
      game.world.add(drone);

      expect(game.activeDroneCargos.length, equals(1));
      expect(game.world.children.whereType<DroneCargoComponent>().length, equals(1));

      // Restart run cleans up active drones
      game.restartRun();

      expect(game.activeDroneCargos, isEmpty);
      expect(game.world.children.whereType<DroneCargoComponent>(), isEmpty);
    });

    test('CourierGame update evaluates checkIntercept and triggers drone catch event', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.gameState.packages = 2; // Damaged

      final drone = DroneCargoComponent(
        position: Vector2(100.0, 250.0),
      );
      game.activeDroneCargos.add(drone);
      game.world.add(drone);

      // Set player airborne overlapping drone crate
      game.player.position = Vector2(105.0, 260.0);
      game.player.simulator.currentY = 260.0;
      game.player.simulator.isGrounded = false;

      DroneCatchEvent? caughtEvent;
      game.gameState.onDroneCatch = (e) => caughtEvent = e;

      game.update(0.016);

      expect(drone.hasCargo, isFalse);
      expect(drone.hasBeenIntercepted, isTrue);
      expect(caughtEvent, isNotNull);
      expect(caughtEvent!.restoredPackage, isTrue);
      expect(game.gameState.packages, equals(3));
      expect(game.gameState.droneCatchesInRun, equals(1));
    });
  });
}
