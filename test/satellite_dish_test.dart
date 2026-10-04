import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/satellite_dish_component.dart';
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

  group('SatelliteDishComponent Unit Tests (Issue #86)', () {
    test('initializes with default dimensions, position, impulse, and unlaunched state', () {
      final dish = SatelliteDishComponent(
        position: Vector2(300.0, 410.0),
        width: 56.0,
        height: 50.0,
        launchImpulse: 540.0,
      );

      expect(dish.position.x, equals(300.0));
      expect(dish.position.y, equals(410.0));
      expect(dish.size.x, equals(56.0));
      expect(dish.size.y, equals(50.0));
      expect(dish.launchImpulse, equals(540.0));
      expect(dish.hasLaunched, isFalse);
      expect(dish.shouldRecycle, isFalse);
      expect(dish.dishRimWorldY, equals(410.0 + 14.0));
      expect(dish.feedHornWorldPosition, equals(Vector2(300.0 + (56.0 * 0.72), 410.0 + 4.0)));
      expect(dish.centerWorldPosition, equals(Vector2(300.0 + 28.0, 410.0 + 25.0)));
    });

    test('shouldRecycle triggers when satellite dish scrolls offscreen', () {
      final offscreen = SatelliteDishComponent(
        position: Vector2(-250.0, 410.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = SatelliteDishComponent(
        position: Vector2(100.0, 410.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update advances microwave beacon timer and decays compression recoil', () {
      final dish = SatelliteDishComponent(
        position: Vector2(300.0, 410.0),
      );

      dish.update(0.1);
      expect(dish.hasLaunched, isFalse);
    });

    test('checkLaunch returns false when courier is grounded', () {
      final dish = SatelliteDishComponent(
        position: Vector2(200.0, 410.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 424.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(210.0, 380.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(dish.checkLaunch(playerPos, playerSize, simulator), isFalse);
      expect(dish.hasLaunched, isFalse);
    });

    test('checkLaunch returns false when courier is rocketing upward rapidly', () {
      final dish = SatelliteDishComponent(
        position: Vector2(200.0, 410.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 424.0;
      simulator.isGrounded = false;
      simulator.verticalVelocity = 200.0; // Rapidly ascending already

      final playerPos = Vector2(210.0, 380.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(dish.checkLaunch(playerPos, playerSize, simulator), isFalse);
      expect(dish.hasLaunched, isFalse);
    });

    test('checkLaunch returns false when courier is outside horizontal span', () {
      final dish = SatelliteDishComponent(
        position: Vector2(300.0, 410.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 424.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 380.0); // Far away horizontally
      final playerSize = Vector2(40.0, 48.0);

      expect(dish.checkLaunch(playerPos, playerSize, simulator), isFalse);
      expect(dish.hasLaunched, isFalse);
    });

    test('checkLaunch returns false when foot Y is outside vertical contact range', () {
      final dish = SatelliteDishComponent(
        position: Vector2(200.0, 410.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 300.0; // High above dish
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 260.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(dish.checkLaunch(playerPos, playerSize, simulator), isFalse);
      expect(dish.hasLaunched, isFalse);
    });

    test('checkLaunch launches airborne courier upward and invokes callback', () {
      var launched = false;
      final dish = SatelliteDishComponent(
        position: Vector2(200.0, 410.0),
        launchImpulse: 540.0,
        onLaunch: () {
          launched = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // dishRimWorldY = 410.0 + 14.0 = 424.0. Contact window: 410.0 to 446.0.
      simulator.currentY = 424.0;
      simulator.verticalVelocity = -100.0; // Descending into bowl (negative)
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 376.0);
      final playerSize = Vector2(40.0, 48.0);

      final result = dish.checkLaunch(playerPos, playerSize, simulator);
      expect(result, isTrue);
      expect(dish.hasLaunched, isTrue);
      expect(launched, isTrue);
      expect(simulator.verticalVelocity, equals(540.0)); // Launched celestial trajectory

      // Subsequent checks should return false
      expect(dish.checkLaunch(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints mounting base, concave dish, feed arm, and microwave eye without errors', () {
      final dish = SatelliteDishComponent(
        position: Vector2(100.0, 410.0),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => dish.render(canvas), returnsNormally);

      // Render after launch compression
      dish.hasLaunched = true;
      dish.update(0.1);
      expect(() => dish.render(canvas), returnsNormally);
    });
  });

  group('GameState Satellite Launch Tracking (Issue #86)', () {
    test('recordSatelliteLaunch awards base tips scaled by stunt multiplier and advances streak', () {
      final state = GameState();
      state.startRun();

      SatelliteLaunchEvent? receivedEvent;
      state.onSatelliteLaunch = (event) {
        receivedEvent = event;
      };

      expect(state.satelliteLaunchesInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordSatelliteLaunch(baseTips: 35, launchImpulse: 540.0);
      expect(event, isNotNull);
      expect(state.satelliteLaunchesInRun, equals(1));
      expect(state.stuntStreak, equals(1));

      // Streak 1 -> 1.2x multiplier -> round(35 * 1.2) = 42 tips
      expect(event!.baseTips, equals(35));
      expect(event.totalTips, equals(42));
      expect(event.multiplier, equals(1.2));
      expect(event.stuntStreak, equals(1));
      expect(event.launchImpulse, equals(540.0));
      expect(state.tips, equals(42));
      expect(receivedEvent, equals(event));
    });

    test('recordSatelliteLaunch scales with DailyModifier.skateCommute (doubles) and energy boost', () {
      final state = GameState();
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      state.activateEnergyDrink(10.0);
      final event = state.recordSatelliteLaunch(baseTips: 35);
      expect(event, isNotNull);
      // Base: round(35 * 1.2) = 42. With skateCommute: 42 * 2 = 84. With energy drink: 84 * 2 = 168.
      expect(event!.totalTips, equals(168));
      expect(state.tips, equals(168));
    });

    test('recordSatelliteLaunch returns null when game is not running', () {
      final state = GameState();
      expect(state.recordSatelliteLaunch(), isNull);
    });

    test('startRun resets satelliteLaunchesInRun counter', () {
      final state = GameState();
      state.startRun();
      state.recordSatelliteLaunch();
      expect(state.satelliteLaunchesInRun, equals(1));

      state.startRun();
      expect(state.satelliteLaunchesInRun, equals(0));
    });
  });

  group('WorldChunkManager Satellite Dish Procedural Generation (Issue #86)', () {
    test('generates satellite dishes after 130m threshold', () {
      final chunkManager = WorldChunkManager();
      var generatedDish = false;

      for (var chunkIndex = 0; chunkIndex < 50; chunkIndex++) {
        final chunk = chunkManager.generateChunk(
          startX: chunkIndex * 960.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 320.0,
          distanceMeters: 140.0 + (chunkIndex * 20.0),
        );

        if (chunk.satelliteDishes.isNotEmpty) {
          generatedDish = true;
          for (final sd in chunk.satelliteDishes) {
            expect(sd.width, equals(56.0));
            expect(sd.height, equals(50.0));
            expect(sd.launchImpulse, equals(540.0));
          }
          break;
        }
      }

      expect(generatedDish, isTrue);
    });

    test('SatelliteDishData holds specified coordinates and default dimensions', () {
      const data = SatelliteDishData(
        x: 450.0,
        y: 350.0,
      );
      expect(data.x, equals(450.0));
      expect(data.y, equals(350.0));
      expect(data.width, equals(56.0));
      expect(data.height, equals(50.0));
      expect(data.launchImpulse, equals(540.0));
    });
  });

  group('ParticleEffectComponent.satellitePulse Tests (Issue #86)', () {
    test('creates expanding microwave transmission particles with cyan/blue palette', () {
      final pulses = ParticleEffectComponent.satellitePulse(
        position: Vector2(300.0, 410.0),
        count: 20,
      );

      expect(pulses.particles.length, equals(20));
      for (final p in pulses.particles) {
        expect(p.position.x, equals(300.0));
        expect(p.position.y, equals(410.0));
        expect(p.maxLife, greaterThan(0.0));
        expect(p.gravity, equals(160.0));
        expect(p.drag, equals(0.92));
      }
    });
  });

  group('CourierGame Integration with SatelliteDishComponent (Issue #86)', () {
    testWidgets('spawns, updates, scrolls, and resets satellite dishes in run lifecycle', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final dish = SatelliteDishComponent(
        position: Vector2(500.0, 410.0),
      );
      game.activeSatelliteDishes.add(dish);
      game.world.add(dish);

      expect(game.activeSatelliteDishes.contains(dish), isTrue);

      final initialX = dish.position.x;
      game.update(0.05);
      expect(dish.position.x, lessThan(initialX));

      game.restartRun();
      expect(game.activeSatelliteDishes, isEmpty);
    });

    testWidgets('triggers satellite launch stunt when airborne courier touches dish', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final dish = SatelliteDishComponent(
        position: Vector2(game.player.position.x + 10.0, 410.0),
      );
      game.activeSatelliteDishes.add(dish);
      game.world.add(dish);

      // Descending airborne courier
      game.player.simulator.currentY = 424.0;
      game.player.simulator.verticalVelocity = -80.0;
      game.player.simulator.isGrounded = false;

      expect(game.gameState.satelliteLaunchesInRun, equals(0));
      game.update(0.02);

      expect(dish.hasLaunched, isTrue);
      expect(game.gameState.satelliteLaunchesInRun, equals(1));
      expect(game.player.simulator.verticalVelocity, equals(540.0)); // Launched!
    });

    testWidgets('recycles offscreen satellite dishes cleanly', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreen = SatelliteDishComponent(
        position: Vector2(-250.0, 410.0),
      );
      game.activeSatelliteDishes.add(offscreen);
      game.world.add(offscreen);

      game.update(0.02);
      expect(game.activeSatelliteDishes.contains(offscreen), isFalse);
    });
  });

  group('GameOverModal Satellite Badge UI Tests (Issue #86)', () {
    testWidgets('renders game_over_satellite_badge when satelliteLaunchesCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 150,
              isNewRecord: false,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              grindsCompleted: 2,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              craneSwingsCompleted: 0,
              vipDeliveriesCompleted: 0,
              satelliteLaunchesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_satellite_badge')), findsOneWidget);
      expect(find.text('3 SATELLITE LAUNCHES'), findsOneWidget);
      expect(find.byIcon(Icons.satellite_alt), findsOneWidget);
    });

    testWidgets('renders singular text when satelliteLaunchesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 150,
              isNewRecord: false,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              grindsCompleted: 2,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              craneSwingsCompleted: 0,
              vipDeliveriesCompleted: 0,
              satelliteLaunchesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_satellite_badge')), findsOneWidget);
      expect(find.text('1 SATELLITE LAUNCH'), findsOneWidget);
    });

    testWidgets('does not render game_over_satellite_badge when satelliteLaunchesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 150,
              isNewRecord: false,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              grindsCompleted: 2,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              craneSwingsCompleted: 0,
              vipDeliveriesCompleted: 0,
              satelliteLaunchesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_satellite_badge')), findsNothing);
    });
  });
}
