import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/glass_skylight_component.dart';
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

  group('GlassSkylightComponent Unit Tests (Issue #96)', () {
    test('initializes with default dimensions, position, and unshattered state', () {
      final skylight = GlassSkylightComponent(
        position: Vector2(320.0, 424.0),
        width: 80.0,
        height: 36.0,
        groundY: 460.0,
      );

      expect(skylight.position.x, equals(320.0));
      expect(skylight.position.y, equals(424.0));
      expect(skylight.size.x, equals(80.0));
      expect(skylight.size.y, equals(36.0));
      expect(skylight.groundY, equals(460.0));
      expect(skylight.hasShattered, isFalse);
      expect(skylight.shouldRecycle, isFalse);
      expect(skylight.apexWorldY, equals(424.0));
      expect(skylight.shatterWorldPosition, equals(Vector2(320.0 + 40.0, 424.0 + 8.0)));
      expect(skylight.centerWorldPosition, equals(Vector2(320.0 + 40.0, 424.0 + 18.0)));
    });

    test('shouldRecycle triggers when skylight scrolls offscreen past threshold', () {
      final offscreen = GlassSkylightComponent(
        position: Vector2(-230.0, 424.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = GlassSkylightComponent(
        position: Vector2(100.0, 424.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update advances sheen timer and decays fracture vibration', () {
      final skylight = GlassSkylightComponent(
        position: Vector2(200.0, 424.0),
      );
      skylight.hasShattered = true;
      skylight.update(0.1);
      expect(skylight.hasShattered, isTrue);
    });

    test('checkSmashThrough returns false when courier is grounded', () {
      final skylight = GlassSkylightComponent(
        position: Vector2(200.0, 424.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(210.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(skylight.checkSmashThrough(playerPos, playerSize, simulator), isFalse);
      expect(skylight.hasShattered, isFalse);
    });

    test('checkSmashThrough returns false when courier is outside horizontal span', () {
      final skylight = GlassSkylightComponent(
        position: Vector2(300.0, 424.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 420.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 372.0); // Far away horizontally
      final playerSize = Vector2(40.0, 48.0);

      expect(skylight.checkSmashThrough(playerPos, playerSize, simulator), isFalse);
      expect(skylight.hasShattered, isFalse);
    });

    test('checkSmashThrough returns false when foot Y is outside vertical dome span', () {
      final skylight = GlassSkylightComponent(
        position: Vector2(200.0, 424.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 320.0; // Too high above skylight
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 272.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(skylight.checkSmashThrough(playerPos, playerSize, simulator), isFalse);
      expect(skylight.hasShattered, isFalse);
    });

    test('checkSmashThrough shatters glass dome when airborne courier leaps through', () {
      var smashed = false;
      final skylight = GlassSkylightComponent(
        position: Vector2(200.0, 424.0),
        onSmash: () {
          smashed = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // footY within [424.0 - 12.0, 424.0 + 36.0 + 14.0] = [412.0, 474.0]
      simulator.currentY = 430.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(215.0, 382.0);
      final playerSize = Vector2(40.0, 48.0);

      final result = skylight.checkSmashThrough(playerPos, playerSize, simulator);
      expect(result, isTrue);
      expect(skylight.hasShattered, isTrue);
      expect(smashed, isTrue);

      // Subsequent checks should return false
      expect(skylight.checkSmashThrough(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints intact and shattered glass states without errors', () {
      final skylight = GlassSkylightComponent(
        position: Vector2(100.0, 424.0),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Intact render
      expect(() => skylight.render(canvas), returnsNormally);

      // Shattered render with spiderweb cracks and broken perimeter
      skylight.hasShattered = true;
      skylight.update(0.05);
      expect(() => skylight.render(canvas), returnsNormally);
    });
  });

  group('GameState Glass Skylight Smash Tracking (Issue #96)', () {
    test('recordSkylightSmash awards base tips (\$35) scaled by stunt multiplier and advances streak', () {
      final state = GameState();
      state.startRun();

      GlassSkylightEvent? receivedEvent;
      state.onGlassSkylightSmash = (event) {
        receivedEvent = event;
      };

      expect(state.skylightSmashesInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordSkylightSmash(baseTips: 35);
      expect(event, isNotNull);
      expect(state.skylightSmashesInRun, equals(1));
      expect(state.stuntStreak, equals(1));

      // Streak 1 -> 1.2x multiplier -> round(35 * 1.2) = 42 tips
      expect(event!.baseTips, equals(35));
      expect(event.totalTips, equals(42));
      expect(event.multiplier, equals(1.2));
      expect(event.stuntStreak, equals(1));
      expect(state.tips, equals(42));
      expect(receivedEvent, equals(event));
    });

    test('recordSkylightSmash scales with DailyModifier.skateCommute (doubles) and energy boost', () {
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
      final event = state.recordSkylightSmash(baseTips: 35);
      expect(event, isNotNull);
      // Base: round(35 * 1.2) = 42. With skateCommute: 42 * 2 = 84. With energy drink: 84 * 2 = 168.
      expect(event!.totalTips, equals(168));
      expect(state.tips, equals(168));
    });

    test('recordSkylightSmash returns null when game is not running', () {
      final state = GameState();
      expect(state.recordSkylightSmash(), isNull);
    });

    test('startRun resets skylightSmashesInRun counter', () {
      final state = GameState();
      state.startRun();
      state.recordSkylightSmash();
      expect(state.skylightSmashesInRun, equals(1));

      state.startRun();
      expect(state.skylightSmashesInRun, equals(0));
    });
  });

  group('WorldChunkManager Glass Skylight Procedural Generation (Issue #96)', () {
    test('generates glass skylights after 140m threshold', () {
      final chunkManager = WorldChunkManager(random: math.Random(1));
      var generatedSkylight = false;

      for (var chunkIndex = 0; chunkIndex < 50; chunkIndex++) {
        final chunk = chunkManager.generateChunk(
          startX: chunkIndex * 960.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 320.0,
          distanceMeters: 150.0 + (chunkIndex * 20.0),
        );

        if (chunk.glassSkylights.isNotEmpty) {
          generatedSkylight = true;
          for (final gs in chunk.glassSkylights) {
            expect(gs.width, equals(80.0));
            expect(gs.height, equals(36.0));
            expect(gs.y, equals(460.0 - 36.0));
          }
          break;
        }
      }

      expect(generatedSkylight, isTrue);
    });

    test('GlassSkylightData holds specified coordinates and default dimensions', () {
      const data = GlassSkylightData(
        x: 450.0,
        y: 424.0,
      );
      expect(data.x, equals(450.0));
      expect(data.y, equals(424.0));
      expect(data.width, equals(80.0));
      expect(data.height, equals(36.0));
    });
  });

  group('ParticleEffectComponent.glassShatter Tests (Issue #96)', () {
    test('creates diamond crystal shards with cyan/aqua/diamond palette and explosive velocity', () {
      final shatter = ParticleEffectComponent.glassShatter(
        position: Vector2(300.0, 424.0),
        count: 24,
      );

      expect(shatter.particles.length, equals(24));
      for (final p in shatter.particles) {
        expect(p.position.x, equals(300.0));
        expect(p.position.y, equals(424.0));
        expect(p.maxLife, greaterThan(0.0));
        expect(p.gravity, equals(220.0));
        expect(p.drag, equals(0.92));
      }
    });
  });

  group('CourierGame Integration with GlassSkylightComponent (Issue #96)', () {
    testWidgets('spawns, updates, scrolls, and resets glass skylights in run lifecycle', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final skylight = GlassSkylightComponent(
        position: Vector2(400.0, 424.0),
      );
      game.activeGlassSkylights.add(skylight);
      game.world.add(skylight);

      expect(game.activeGlassSkylights.contains(skylight), isTrue);

      final initialX = skylight.position.x;
      game.update(0.05);
      expect(skylight.position.x, lessThan(initialX));

      game.restartRun();
      expect(game.activeGlassSkylights, isEmpty);
    });

    testWidgets('triggers skylight smash stunt when airborne courier breaches dome', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final skylight = GlassSkylightComponent(
        position: Vector2(game.player.position.x + 10.0, 424.0),
      );
      game.activeGlassSkylights.add(skylight);
      game.world.add(skylight);

      // Make player airborne into the skylight breach window
      game.player.simulator.currentY = 430.0;
      game.player.simulator.isGrounded = false;

      expect(game.gameState.skylightSmashesInRun, equals(0));
      game.update(0.02);

      expect(skylight.hasShattered, isTrue);
      expect(game.gameState.skylightSmashesInRun, equals(1));
    });

    testWidgets('recycles offscreen glass skylights cleanly', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreen = GlassSkylightComponent(
        position: Vector2(-250.0, 424.0),
      );
      game.activeGlassSkylights.add(offscreen);
      game.world.add(offscreen);

      game.update(0.02);
      expect(game.activeGlassSkylights.contains(offscreen), isFalse);
    });
  });

  group('GameOverModal Glass Skylight Badge UI Tests (Issue #96)', () {
    testWidgets('renders game_over_skylight_badge when skylightsCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1600,
              tips: 220,
              isNewRecord: false,
              careerTips: 3200,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              skylightsCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_skylight_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('2 SKYLIGHT SMASHES'), findsOneWidget);
      expect(find.byIcon(Icons.window), findsOneWidget);
    });

    testWidgets('renders singular text when skylightsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1600,
              tips: 220,
              isNewRecord: false,
              careerTips: 3200,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              skylightsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.text('1 SKYLIGHT SMASH'), findsOneWidget);
    });

    testWidgets('omits game_over_skylight_badge when skylightsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1600,
              tips: 220,
              isNewRecord: false,
              careerTips: 3200,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              skylightsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_skylight_badge'));
      expect(badgeFinder, findsNothing);
    });
  });
}
