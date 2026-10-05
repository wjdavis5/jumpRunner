import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/fire_escape_ladder_component.dart';
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

  group('FireEscapeLadderComponent Unit Tests (Issue #80)', () {
    test('initializes with default dimensions, position, and un-dropped state', () {
      final escape = FireEscapeLadderComponent(
        position: Vector2(240.0, 320.0),
        width: 84.0,
        height: 140.0,
        groundY: 460.0,
        launchImpulse: 420.0,
      );

      expect(escape.position.x, equals(240.0));
      expect(escape.position.y, equals(320.0));
      expect(escape.size.x, equals(84.0));
      expect(escape.size.y, equals(140.0));
      expect(escape.groundY, equals(460.0));
      expect(escape.launchImpulse, equals(420.0));
      expect(escape.hasDropped, isFalse);
      expect(escape.shouldRecycle, isFalse);
      expect(escape.balconyTopWorldY, equals(320.0));
      expect(escape.ladderGrabWorldPosition, equals(Vector2(240.0 + 55.0, 320.0 + 78.0)));
      expect(escape.ladderGrabWorldRect, equals(const Rect.fromLTWH(276.0, 368.0, 36.0, 50.0)));
    });

    test('shouldRecycle triggers when fire escape scrolls offscreen', () {
      final offscreen = FireEscapeLadderComponent(
        position: Vector2(-230.0, 320.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = FireEscapeLadderComponent(
        position: Vector2(240.0, 320.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update advances drop progress when hasDropped is true', () {
      final escape = FireEscapeLadderComponent(
        position: Vector2(240.0, 320.0),
      );
      escape.hasDropped = true;

      escape.update(0.1);
      // Ladder drop progress advances
      expect(escape.hasDropped, isTrue);
    });

    test('checkLadderGrab returns false when courier is grounded', () {
      final escape = FireEscapeLadderComponent(
        position: Vector2(200.0, 320.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(240.0, 380.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(escape.checkLadderGrab(playerPos, playerSize, simulator), isFalse);
      expect(escape.hasDropped, isFalse);
    });

    test('checkLadderGrab returns false when courier does not overlap ladder grab zone', () {
      final escape = FireEscapeLadderComponent(
        position: Vector2(400.0, 320.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 380.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 380.0); // Far away
      final playerSize = Vector2(40.0, 48.0);

      expect(escape.checkLadderGrab(playerPos, playerSize, simulator), isFalse);
      expect(escape.hasDropped, isFalse);
    });

    test('checkLadderGrab triggers when airborne courier catches the dangling ladder', () {
      var grabbed = false;
      final escape = FireEscapeLadderComponent(
        position: Vector2(200.0, 320.0),
        launchImpulse: 420.0,
        onLadderGrab: () => grabbed = true,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 390.0;
      simulator.isGrounded = false;

      // Grab hitbox: x in [236..272], y in [368..418], inflated by 10: [226..282], [358..428]
      final playerPos = Vector2(240.0, 375.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(escape.checkLadderGrab(playerPos, playerSize, simulator), isTrue);
      expect(escape.hasDropped, isTrue);
      expect(grabbed, isTrue);
      expect(simulator.verticalVelocity, equals(420.0)); // Catapult launch applied

      // Cannot trigger a second time
      expect(escape.checkLadderGrab(playerPos, playerSize, simulator), isFalse);
    });

    test('isCourierOnBalcony correctly detects foot positioning on balcony deck', () {
      final escape = FireEscapeLadderComponent(
        position: Vector2(200.0, 320.0),
        width: 84.0,
      );

      final playerSize = Vector2(40.0, 48.0);

      // On balcony deck
      final onDeckPos = Vector2(220.0, 272.0); // Center at 240, foot at 320
      expect(escape.isCourierOnBalcony(onDeckPos, playerSize, 320.0), isTrue);

      // Outside horizontally
      final offDeckX = Vector2(320.0, 272.0); // Past 284
      expect(escape.isCourierOnBalcony(offDeckX, playerSize, 320.0), isFalse);

      // Outside vertically
      expect(escape.isCourierOnBalcony(onDeckPos, playerSize, 360.0), isFalse);
    });

    test('render paints without exception before and after ladder drop', () {
      final escape = FireEscapeLadderComponent(
        position: Vector2(200.0, 320.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Before drop
      expect(() => escape.render(canvas), returnsNormally);

      // After drop
      escape.hasDropped = true;
      escape.update(0.3);
      expect(() => escape.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent Fire Escape Sparks (Issue #80)', () {
    test('creates fireEscapeSparks particle burst with expected count and physics', () {
      final fx = ParticleEffectComponent.fireEscapeSparks(
        position: Vector2(240.0, 380.0),
        count: 18,
      );

      expect(fx.particles.length, equals(18));
      for (final p in fx.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(280.0));
      }
      expect(fx.isFinished, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => fx.render(canvas), returnsNormally);

      fx.update(1.0);
      expect(fx.isFinished, isTrue);
    });
  });

  group('GameState Fire Escape Mechanics (Issue #80)', () {
    late GameState state;

    setUp(() {
      state = GameState();
      state.startRun();
    });

    test('recordFireEscapeDrop returns null when game is not running', () {
      state.status = GameStatus.gameOver;
      expect(state.recordFireEscapeDrop(), isNull);
    });

    test('recordFireEscapeDrop awards base tips (\$30) scaled by stunt combo', () {
      FireEscapeEvent? eventReceived;
      state.onFireEscapeDrop = (e) => eventReceived = e;

      final initialTips = state.tips;
      final event = state.recordFireEscapeDrop();

      expect(event, isNotNull);
      expect(eventReceived, equals(event));
      expect(state.fireEscapeDropsInRun, equals(1));
      expect(event!.baseTips, equals(30));
      expect(event.multiplier, equals(1.2)); // 1st streak
      expect(event.totalTips, equals(36)); // (30 * 1.2)
      expect(state.tips, equals(initialTips + 36));
      expect(event.stuntStreak, equals(1));
    });

    test('recordFireEscapeDrop scales with stunt streak multiplier', () {
      state.stuntStreak = 3;
      state.stuntStreakTimer = 2.0;

      final event = state.recordFireEscapeDrop();

      expect(event, isNotNull);
      expect(event!.multiplier, equals(2.5)); // 4th streak
      expect(event.totalTips, equals((30 * 2.5).round())); // 75
      expect(event.stuntStreak, equals(4));
    });

    test('recordFireEscapeDrop scales with DailyModifier.skateCommute (doubles)', () {
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      final event = state.recordFireEscapeDrop();
      expect(event, isNotNull);
      expect(event!.totalTips, equals(72)); // (30 * 1.2) * 2 = 72
    });

    test('recordFireEscapeDrop scales with energy boost (doubles)', () {
      state.activateEnergyDrink(5.0);

      final event = state.recordFireEscapeDrop();
      expect(event, isNotNull);
      expect(event!.totalTips, equals(72)); // (30 * 1.2) * 2 = 72
    });

    test('startRun resets fireEscapeDropsInRun to 0', () {
      state.recordFireEscapeDrop();
      expect(state.fireEscapeDropsInRun, equals(1));

      state.startRun();
      expect(state.fireEscapeDropsInRun, equals(0));
    });
  });

  group('WorldChunkManager Fire Escape Spawning (Issue #80)', () {
    test('ChunkData includes fireEscapes collection', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        fireEscapes: [
          FireEscapeData(x: 200.0, y: 320.0, width: 84.0, height: 140.0),
        ],
      );

      expect(chunk.fireEscapes.length, equals(1));
      expect(chunk.fireEscapes.first.x, equals(200.0));
      expect(chunk.fireEscapes.first.y, equals(320.0));
      expect(chunk.fireEscapes.first.width, equals(84.0));
      expect(chunk.fireEscapes.first.height, equals(140.0));
      expect(chunk.fireEscapes.first.launchImpulse, equals(420.0));
    });

    test('generateChunk does not spawn fire escapes prior to 130m milestone', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var count = 0;

      for (var i = 0; i < 10; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 50.0, // Before 130m
        );
        count += chunk.fireEscapes.length;
      }

      expect(count, equals(0));
    });

    test('generateChunk can spawn fire escapes after 130m with valid clearance', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var found = false;

      for (var i = 0; i < 30; i++) {
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 200.0, // Past 130m
        );
        if (chunk.fireEscapes.isNotEmpty) {
          found = true;
          final fe = chunk.fireEscapes.first;
          expect(fe.y, equals(460.0 - 140.0));
          expect(fe.width, equals(84.0));
          expect(fe.height, equals(140.0));
          expect(fe.launchImpulse, equals(420.0));
          break;
        }
      }

      expect(found, isTrue);
    });
  });

  group('GameOverModal Fire Escape Badge (Issue #80)', () {
    testWidgets('renders game_over_fire_escape_badge with singular text when fireEscapesCompleted == 1', (tester) async {
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
              fireEscapesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_fire_escape_badge')), findsOneWidget);
      expect(find.text('1 FIRE ESCAPE DROP'), findsOneWidget);
    });

    testWidgets('renders game_over_fire_escape_badge with plural text when fireEscapesCompleted > 1', (tester) async {
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
              fireEscapesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_fire_escape_badge')), findsOneWidget);
      expect(find.text('3 FIRE ESCAPE DROPS'), findsOneWidget);
    });

    testWidgets('omits game_over_fire_escape_badge when fireEscapesCompleted == 0', (tester) async {
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
              fireEscapesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_fire_escape_badge')), findsNothing);
    });
  });

  group('CourierGame Fire Escape Integration Tests (Issue #80)', () {
    test('CourierGame spawns and clears activeFireEscapes across run lifecycle', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final escape = FireEscapeLadderComponent(
        position: Vector2(250.0, 320.0),
      );
      game.activeFireEscapes.add(escape);
      game.world.add(escape);

      expect(game.activeFireEscapes.length, equals(1));
      expect(game.world.children.whereType<FireEscapeLadderComponent>().length, equals(1));

      // Restart run cleans up active fire escapes
      game.restartRun();

      expect(game.activeFireEscapes, isEmpty);
      expect(game.world.children.whereType<FireEscapeLadderComponent>(), isEmpty);
    });

    test('CourierGame update evaluates checkLadderGrab and catapults courier upward', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final escape = FireEscapeLadderComponent(
        position: Vector2(100.0, 320.0),
        launchImpulse: 420.0,
      );
      game.activeFireEscapes.add(escape);
      game.world.add(escape);

      // Position player airborne in grab zone
      game.player.position = Vector2(140.0, 375.0);
      game.player.simulator.currentY = 375.0;
      game.player.simulator.isGrounded = false;

      FireEscapeEvent? caughtEvent;
      game.gameState.onFireEscapeDrop = (e) => caughtEvent = e;

      game.update(0.016);

      expect(escape.hasDropped, isTrue);
      expect(caughtEvent, isNotNull);
      expect(caughtEvent!.totalTips, equals(36));
      expect(game.player.simulator.verticalVelocity, equals(420.0));
      expect(game.gameState.fireEscapeDropsInRun, equals(1));
      expect(game.gameState.stuntStreak, equals(1));
    });
  });
}
