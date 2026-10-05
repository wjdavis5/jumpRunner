import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/grind_rail_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GrindRailComponent Unit Tests', () {
    test('initializes with accurate surface coordinates and recycling boundaries', () {
      final rail = GrindRailComponent(
        position: Vector2(200.0, 380.0),
        size: Vector2(240.0, 8.0),
        groundY: 460.0,
      );

      expect(rail.surfaceY, equals(380.0));
      expect(rail.shouldRecycle, isFalse);

      rail.position.x = -370.0;
      expect(rail.shouldRecycle, isTrue);
    });

    test('isUnderCourierFootprint detects landing contact zone accurately', () {
      final rail = GrindRailComponent(
        position: Vector2(100.0, 380.0),
        size: Vector2(200.0, 8.0),
        groundY: 460.0,
      );

      // Directly centered on rail surface
      expect(rail.isUnderCourierFootprint(200.0, 380.0), isTrue);

      // Slightly above or below rail surface within tolerance (-14 to +18)
      expect(rail.isUnderCourierFootprint(150.0, 370.0), isTrue);
      expect(rail.isUnderCourierFootprint(150.0, 395.0), isTrue);

      // Horizontally outside rail footprint
      expect(rail.isUnderCourierFootprint(90.0, 380.0), isFalse);
      expect(rail.isUnderCourierFootprint(310.0, 380.0), isFalse);

      // Vertically way above or below rail
      expect(rail.isUnderCourierFootprint(200.0, 300.0), isFalse);
      expect(rail.isUnderCourierFootprint(200.0, 440.0), isFalse);
    });

    test('isPastForwardEdge detects when player foot clears trailing rail edge', () {
      final rail = GrindRailComponent(
        position: Vector2(100.0, 380.0),
        size: Vector2(200.0, 8.0),
      );

      expect(rail.isPastForwardEdge(250.0), isFalse);
      expect(rail.isPastForwardEdge(300.0), isFalse);
      expect(rail.isPastForwardEdge(301.0), isTrue);
    });

    test('renders on canvas without error', () {
      final rail = GrindRailComponent(
        position: Vector2(50.0, 380.0),
        size: Vector2(200.0, 8.0),
        groundY: 460.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      rail.render(canvas);
      rail.update(0.1);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('CourierPlayer Grinding State & Rail Ollie Mechanics', () {
    test('startGrinding transitions player to grinding state and locks surface', () {
      final player = CourierPlayer(groundY: 460.0);
      expect(player.state, equals(CourierState.running));
      expect(player.isGrinding, isFalse);

      player.startGrinding(380.0);
      expect(player.state, equals(CourierState.grinding));
      expect(player.isGrinding, isTrue);
      expect(player.simulator.currentSurfaceY, equals(380.0));
      expect(player.simulator.isGrounded, isTrue);
      expect(player.grindDistance, equals(0.0));
    });

    test('jump while grinding triggers Rail Ollie with amplified pop impulse', () {
      bool didOllie = false;
      bool didJump = false;

      final player = CourierPlayer(
        groundY: 460.0,
        onJump: () => didJump = true,
        onRailOllie: () => didOllie = true,
      );

      player.startGrinding(380.0);
      expect(player.isGrinding, isTrue);

      final jumped = player.jump();
      expect(jumped, isTrue);
      expect(didOllie, isTrue);
      expect(didJump, isTrue);
      expect(player.state, equals(CourierState.jumping));
      expect(player.isGrinding, isFalse);
      // Rail Ollie impulse is 340.0 px/s (amplified over normal 240.0 px/s)
      expect(player.simulator.verticalVelocity, equals(340.0));
    });

    test('endGrinding resets state to running and clears grind distance', () {
      final player = CourierPlayer(groundY: 460.0);
      player.startGrinding(380.0);
      player.grindDistance = 25.5;

      player.endGrinding();
      expect(player.state, equals(CourierState.running));
      expect(player.isGrinding, isFalse);
      expect(player.grindDistance, equals(0.0));
    });

    test('player update maintains grinding state while grounded on rail', () {
      final player = CourierPlayer(groundY: 460.0);
      player.startGrinding(380.0);

      player.update(0.016);
      expect(player.state, equals(CourierState.grinding));
      expect(player.simulator.isGrounded, isTrue);
      expect(player.position.y, equals(380.0 - player.size.y));
    });

    test('player renders grinding posture with skateboard without error', () {
      final player = CourierPlayer(groundY: 460.0);
      player.startGrinding(380.0);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      player.render(canvas);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('GameState Rail Ollie & Rail Clear Scoring Tests', () {
    test('recordRailOllie advances streak, scales tips with combo multiplier and energy drink', () {
      final state = GameState();
      state.startRun();

      RailOllieEvent? capturedEvent;
      state.onRailOllie = (event) => capturedEvent = event;

      // First Rail Ollie
      final event1 = state.recordRailOllie(grindDistanceMeters: 12.5);
      expect(event1, isNotNull);
      expect(capturedEvent, equals(event1));
      expect(state.grindsInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(event1!.multiplier, equals(1.2));
      // Base tip 20 * 1.2 = 24
      expect(event1.totalTips, equals(24));
      expect(state.tips, equals(24));

      // Second Rail Ollie with energy boost active
      state.activateEnergyDrink(5.0);
      final event2 = state.recordRailOllie(grindDistanceMeters: 18.0);
      expect(event2, isNotNull);
      expect(state.grindsInRun, equals(2));
      expect(state.stuntStreak, equals(2));
      expect(event2!.multiplier, equals(1.5));
      // Base 20 * 1.5 = 30; with energy drink double = 60
      expect(event2.totalTips, equals(60));
      expect(state.tips, equals(24 + 60));
    });

    test('recordRailClear awards clean dismount bonus tips', () {
      final state = GameState();
      state.startRun();

      RailClearEvent? capturedEvent;
      state.onRailClear = (event) => capturedEvent = event;

      final event = state.recordRailClear(grindDistanceMeters: 20.0);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));
      expect(state.grindsInRun, equals(1));
      expect(event!.bonusTips, equals(10));
      expect(state.tips, equals(10));
    });

    test('hazard damage resets stunt streak and multiplier', () {
      final state = GameState();
      state.startRun();
      state.recordRailOllie(grindDistanceMeters: 10.0);
      state.recordRailOllie(grindDistanceMeters: 10.0);
      expect(state.stuntStreak, equals(2));
      expect(state.stuntMultiplier, equals(1.5));

      state.applyHazardDamage();
      expect(state.stuntStreak, equals(0));
      expect(state.stuntMultiplier, equals(1.0));
    });

    test('startRun resets grindsInRun counter', () {
      final state = GameState();
      state.startRun();
      state.recordRailOllie(grindDistanceMeters: 10.0);
      state.recordRailClear(grindDistanceMeters: 10.0);
      expect(state.grindsInRun, equals(2));

      state.startRun();
      expect(state.grindsInRun, equals(0));
    });
  });

  group('WorldChunkManager Procedural Generation with Grind Rails', () {
    test('generateChunk includes grindRails array in ChunkData', () {
      final manager = WorldChunkManager(random: math.Random(1));
      final chunk = manager.generateChunk(
        startX: 0.0,
        speed: 250.0,
        distanceMeters: 0.0,
      );

      expect(chunk.grindRails, isNotNull);
      expect(chunk.grindRails, isA<List<GrindRailData>>());
    });

    test('generateChunk generates grind rails with floating reward coins past 90m', () {
      final manager = WorldChunkManager(random: math.Random(1));
      bool foundRail = false;

      // Sample multiple chunks beyond 90m to verify procedural spawning
      for (int i = 0; i < 30; i++) {
        final chunk = manager.generateChunk(
          startX: i * 960.0,
          speed: 300.0,
          distanceMeters: 200.0,
        );
        if (chunk.grindRails.isNotEmpty) {
          foundRail = true;
          final rail = chunk.grindRails.first;
          expect(rail.width, greaterThanOrEqualTo(160.0));
          expect(rail.y, lessThan(460.0));

          // Check that coins hover above rail surface
          final railCoins = chunk.pickups.where(
            (p) => p.x >= rail.x - 10.0 && p.x <= rail.x + rail.width + 10.0,
          );
          expect(railCoins, isNotEmpty);
          break;
        }
      }

      expect(foundRail, isTrue);
    });
  });

  group('CourierGame Grind Rail Integration & Traversal Juice', () {
    test('CourierGame mounts grind rail, initiates grinding, and surcharges forward velocity', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // Place a grind rail under the player's initial horizontal footprint (player starts at x=120, width=64)
      final rail = GrindRailComponent(
        position: Vector2(100.0, 390.0),
        size: Vector2(250.0, 8.0),
        groundY: 460.0,
      );
      game.activeGrindRails.add(rail);
      game.world.add(rail);

      // Position player landing on the rail
      game.player.position.y = 390.0 - game.player.size.y;
      game.player.simulator.currentY = 390.0;
      game.player.simulator.isGrounded = true;

      // Update game loop: frame 1 mounts rail, frame 2 evaluates speed surge
      game.update(0.016);
      game.update(0.016);

      // Verify player entered grinding state
      expect(game.player.isGrinding, isTrue);
      expect(game.player.state, equals(CourierState.grinding));

      // Verify forward scroll speed received the +20% grind surge
      final baseSpeed = game.chunkManager.calculateSpeed(game.gameState.distanceMeters);
      expect(game.currentSpeed, closeTo(baseSpeed * 1.20, 0.5));
    });

    test('jumping while grinding triggers Rail Ollie, floating text popup, and combo tips', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final rail = GrindRailComponent(
        position: Vector2(100.0, 390.0),
        size: Vector2(250.0, 8.0),
        groundY: 460.0,
      );
      game.activeGrindRails.add(rail);
      game.world.add(rail);

      game.player.position.y = 390.0 - game.player.size.y;
      game.player.simulator.currentY = 390.0;
      game.player.simulator.isGrounded = true;
      game.update(0.016);
      expect(game.player.isGrinding, isTrue);

      final initialTips = game.gameState.tips;

      // Player initiates jump from the grind rail
      final didJump = game.player.jump();
      expect(didJump, isTrue);
      expect(game.player.isGrinding, isFalse);
      expect(game.player.state, equals(CourierState.jumping));

      // Update game loop to process effect queues
      game.update(0.016);

      // Verified combo tips awarded and stunt streak incremented
      expect(game.gameState.tips, greaterThan(initialTips));
      expect(game.gameState.stuntStreak, equals(1));
      expect(game.gameState.grindsInRun, equals(1));

      // Floating text component for Rail Ollie added
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      final hasOllieText = floatingTexts.any((t) => t.text.contains('RAIL OLLIE!'));
      expect(hasOllieText, isTrue);
    });

    test('reaching rail trailing edge executes clean dismount and awards RAIL CLEAR bonus', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final rail = GrindRailComponent(
        position: Vector2(100.0, 390.0),
        size: Vector2(200.0, 8.0),
        groundY: 460.0,
      );
      game.activeGrindRails.add(rail);
      game.world.add(rail);

      game.player.position.y = 390.0 - game.player.size.y;
      game.player.simulator.currentY = 390.0;
      game.player.simulator.isGrounded = true;
      game.update(0.016);
      expect(game.player.isGrinding, isTrue);

      final initialTips = game.gameState.tips;

      // Move player foot past rail trailing edge (rail ends at x=300; player center placed at x=320)
      game.player.position.x = 320.0 - (game.player.size.x / 2);
      game.update(0.016);

      // Player should have cleanly dismounted
      expect(game.player.isGrinding, isFalse);
      expect(game.gameState.tips, equals(initialTips + 10));

      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      final hasClearText = floatingTexts.any((t) => t.text.contains('RAIL CLEAR!'));
      expect(hasClearText, isTrue);
    });

    test('restartRun cleans up active grind rails and resets grinding state', () async {
      final game = CourierGame();
      await game.onLoad();

      final rail = GrindRailComponent(
        position: Vector2(100.0, 390.0),
        size: Vector2(200.0, 8.0),
      );
      game.activeGrindRails.add(rail);
      game.world.add(rail);
      game.player.startGrinding(390.0);

      game.restartRun();

      expect(game.activeGrindRails, isEmpty);
      expect(game.player.isGrinding, isFalse);
      expect(game.gameState.grindsInRun, equals(0));
    });
  });

  group('GameOverModal Rail Grinds Badge Tests', () {
    testWidgets('renders game_over_grinds_badge when grindsCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 850,
              tips: 140,
              isNewRecord: false,
              careerTips: 1200,
              grindsCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_grinds_badge')), findsOneWidget);
      expect(find.text('3 RAIL GRINDS & STUNTS'), findsOneWidget);
    });

    testWidgets('omits game_over_grinds_badge when grindsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 500,
              tips: 50,
              isNewRecord: false,
              careerTips: 500,
              grindsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_grinds_badge')), findsNothing);
    });
  });
}
