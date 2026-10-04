import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/cyclist_companion_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/hud_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CyclistCompanionComponent Tests (Issue #56)', () {
    test('initializes with expected default size and position', () {
      final cyclist = CyclistCompanionComponent(
        position: Vector2(250.0, 406.0),
        relativeSpeed: 15.0,
      );

      expect(cyclist.position.x, equals(250.0));
      expect(cyclist.position.y, equals(406.0));
      expect(cyclist.size.x, equals(76.0));
      expect(cyclist.size.y, equals(54.0));
      expect(cyclist.relativeSpeed, equals(15.0));
      expect(cyclist.isPlayerDrafting, isFalse);
      expect(cyclist.playerDraftDuration, equals(0.0));
      expect(cyclist.hasTriggeredSlingshot, isFalse);
    });

    test('update advances wheel rotation angle and relative movement', () {
      final cyclist = CyclistCompanionComponent(
        position: Vector2(200.0, 406.0),
        relativeSpeed: 20.0,
      );

      cyclist.update(0.1);
      expect(cyclist.wheelAngle, closeTo(1.4, 0.01));
      expect(cyclist.position.x, closeTo(202.0, 0.01));
    });

    test('isPlayerInDraftZone accurately detects when runner is in slipstream wake', () {
      final cyclist = CyclistCompanionComponent(
        position: Vector2(300.0, 406.0), // groundY = 460, size.y = 54
      );

      // Cyclist rear wheel is near position.x + 14.
      // Slipstream wake extends from (position.x - 80) to (position.x + 15)
      // i.e., 220 to 315 horizontally.
      // Vertical wake: position.y - 10 (396) to position.y + size.y + 12 (472).

      // 1. Player directly inside the wake
      final playerPosInside = Vector2(240.0, 460.0 - 48.0); // bottom Y = 460, center X = 256
      final playerSize = Vector2(32.0, 48.0);
      expect(cyclist.isPlayerInDraftZone(playerPosInside, playerSize), isTrue);

      // 2. Player ahead of the cyclist
      final playerPosAhead = Vector2(340.0, 460.0 - 48.0); // center X = 356
      expect(cyclist.isPlayerInDraftZone(playerPosAhead, playerSize), isFalse);

      // 3. Player too far behind
      final playerPosTooFar = Vector2(180.0, 460.0 - 48.0); // center X = 196 < 220
      expect(cyclist.isPlayerInDraftZone(playerPosTooFar, playerSize), isFalse);

      // 4. Player high in the air above the wake
      final playerPosHigh = Vector2(250.0, 300.0); // bottom Y = 348 < 396
      expect(cyclist.isPlayerInDraftZone(playerPosHigh, playerSize), isFalse);
    });

    test('renders procedural courier cyclist and slipstream wind without errors', () {
      final cyclist = CyclistCompanionComponent(
        position: Vector2(100.0, 406.0),
      );
      cyclist.isPlayerDrafting = true;
      cyclist.playerDraftDuration = 1.5;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => cyclist.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('shouldRecycle triggers when cyclist scrolls beyond left boundary', () {
      final cyclist = CyclistCompanionComponent(
        position: Vector2(100.0, 406.0),
      );
      expect(cyclist.shouldRecycle, isFalse);

      cyclist.position.x = -260.0;
      expect(cyclist.shouldRecycle, isTrue);
    });
  });

  group('GameState Drafting Mechanics Tests (Issue #56)', () {
    test('initializes with zero drafting stats', () {
      final gameState = GameState();
      expect(gameState.isDrafting, isFalse);
      expect(gameState.bikeDraftSlingshotsInRun, equals(0));
      expect(gameState.totalDraftDurationInRun, equals(0.0));
    });

    test('setDrafting updates state and notifies listeners', () {
      final gameState = GameState();
      var notifyCount = 0;
      gameState.addListener(() {
        notifyCount++;
      });

      gameState.setDrafting(true);
      expect(gameState.isDrafting, isTrue);
      expect(notifyCount, equals(1));

      // Same value should not trigger unnecessary notification
      gameState.setDrafting(true);
      expect(notifyCount, equals(1));

      gameState.setDrafting(false);
      expect(gameState.isDrafting, isFalse);
      expect(notifyCount, equals(2));
    });

    test('recordDraftSlingshot awards base tips multiplied by stunt combo and increments streak', () {
      final gameState = GameState();
      gameState.startRun();

      // Pre-set stunt streak
      gameState.recordStunt(clearance: 10.0); // stuntMultiplier = 1.2

      DraftSlingshotEvent? eventReceived;
      gameState.onBikeDraftSlingshot = (event) {
        eventReceived = event;
      };

      final event = gameState.recordDraftSlingshot();
      expect(event, isNotNull);
      expect(eventReceived, equals(event));
      expect(event!.baseTips, equals(30));
      expect(event.multiplier, equals(1.5));
      expect(event.totalTips, equals(45));
      expect(gameState.bikeDraftSlingshotsInRun, equals(1));
      expect(gameState.stuntStreak, equals(2)); // Incremented stunt streak
    });

    test('startRun resets drafting run counters', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.recordDraftSlingshot();
      gameState.totalDraftDurationInRun = 5.2;
      gameState.setDrafting(true);

      expect(gameState.bikeDraftSlingshotsInRun, equals(1));
      expect(gameState.totalDraftDurationInRun, equals(5.2));
      expect(gameState.isDrafting, isTrue);

      gameState.startRun();
      expect(gameState.bikeDraftSlingshotsInRun, equals(0));
      expect(gameState.totalDraftDurationInRun, equals(0.0));
      expect(gameState.isDrafting, isFalse);
    });
  });

  group('CourierPlayer Drafting & Slingshot Tests (Issue #56)', () {
    test('jumping while drafting triggers slingshot launch impulse and callback', () {
      var didTriggerSlingshot = false;
      final player = CourierPlayer(
        groundY: 460.0,
        onDraftSlingshot: () {
          didTriggerSlingshot = true;
        },
      );

      player.isDrafting = true;
      expect(player.isDrafting, isTrue);

      final jumpResult = player.jump();
      expect(jumpResult, isTrue);
      expect(didTriggerSlingshot, isTrue);
      expect(player.isDrafting, isFalse);
      expect(player.simulator.verticalVelocity, equals(360.0)); // High-velocity catapult!
    });

    test('normal jump without drafting does not trigger slingshot callback', () {
      var didTriggerSlingshot = false;
      final player = CourierPlayer(
        groundY: 460.0,
        onDraftSlingshot: () {
          didTriggerSlingshot = true;
        },
      );

      player.isDrafting = false;
      final jumpResult = player.jump();
      expect(jumpResult, isTrue);
      expect(didTriggerSlingshot, isFalse);
      expect(player.simulator.verticalVelocity, equals(240.0)); // Standard jump
    });
  });

  group('WorldChunkManager Cyclist Spawning Tests (Issue #56)', () {
    test('CyclistData model stores expected coordinates and speed', () {
      const data = CyclistData(x: 400.0, y: 406.0, relativeSpeed: 10.0);
      expect(data.x, equals(400.0));
      expect(data.y, equals(406.0));
      expect(data.width, equals(76.0));
      expect(data.height, equals(54.0));
      expect(data.relativeSpeed, equals(10.0));
    });

    test('does not spawn cyclists before 100 meters', () {
      final manager = WorldChunkManager();
      // Chunk 0 is at 0m
      final chunk0 = manager.generateChunk(startX: 0.0, speed: 200.0, distanceMeters: 0.0);
      expect(chunk0.cyclists, isEmpty);
    });

    test('can generate chunk with cyclists beyond 100 meters', () {
      var spawnedCyclist = false;
      for (var i = 0; i < 20; i++) {
        final manager = WorldChunkManager();
        final chunk = manager.generateChunk(startX: 1000.0, speed: 250.0, distanceMeters: 150.0);
        if (chunk.cyclists.isNotEmpty) {
          spawnedCyclist = true;
          final cy = chunk.cyclists.first;
          expect(cy.width, equals(76.0));
          expect(cy.height, equals(54.0));
          expect(cy.y, equals(460.0 - 54.0));
          break;
        }
      }
      expect(spawnedCyclist, isTrue);
    });
  });

  group('CourierGame Drafting & Slingshot Integration Tests (Issue #56)', () {
    test('entering cyclist slipstream draft zone boosts speed and updates state', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // Position courier at ground baseline
      game.player.position = Vector2(240.0, 460.0 - game.player.size.y);
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      // Add a cyclist companion ahead of courier so courier is in the slipstream
      // Cyclist at x = 290 -> slipstream is 210 to 305. Courier center is 240 + 16 = 256
      final cyclist = CyclistCompanionComponent(
        position: Vector2(290.0, 460.0 - 54.0),
      );
      game.activeCyclists.add(cyclist);
      game.world.add(cyclist);

      // Verify baseline speed
      expect(game.player.isDrafting, isFalse);

      // Run game updates
      game.update(0.05);

      // Should now be drafting!
      expect(game.player.isDrafting, isTrue);
      expect(game.gameState.isDrafting, isTrue);
      expect(cyclist.isPlayerDrafting, isTrue);

      // Next tick calculates speed with drafting boost active
      game.update(0.05);
      expect(game.gameState.totalDraftDurationInRun, closeTo(0.1, 0.001));

      // Speed multiplier should include 1.2x drafting boost
      expect(game.currentSpeed, closeTo(240.0, 1.0)); // 200 * 1.2 = 240 + tiny distance speed ramp
    });

    test('jumping while drafting in CourierGame triggers slingshot boost and awards tips', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      game.player.position = Vector2(240.0, 460.0 - game.player.size.y);
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      final cyclist = CyclistCompanionComponent(
        position: Vector2(290.0, 460.0 - 54.0),
      );
      game.activeCyclists.add(cyclist);
      game.world.add(cyclist);

      game.update(0.05);
      expect(game.player.isDrafting, isTrue);

      // Tap / jump while drafting
      game.player.jump();

      // Slingshot recorded
      expect(game.gameState.bikeDraftSlingshotsInRun, equals(1));
      expect(game.gameState.tips, greaterThan(0));

      // Visual floating text added
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('SLINGSHOT BOOST!')), isTrue);
    });

    test('recycles offscreen cyclists and resets on restartRun', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final cyclist = CyclistCompanionComponent(
        position: Vector2(-300.0, 460.0 - 54.0),
      );
      game.activeCyclists.add(cyclist);
      game.world.add(cyclist);

      game.update(0.1);
      expect(game.activeCyclists, isEmpty);

      final freshCyclist = CyclistCompanionComponent(
        position: Vector2(300.0, 460.0 - 54.0),
      );
      game.activeCyclists.add(freshCyclist);
      game.world.add(freshCyclist);
      expect(game.activeCyclists.length, equals(1));

      game.restartRun();
      expect(game.activeCyclists, isEmpty);
      expect(game.gameState.bikeDraftSlingshotsInRun, equals(0));
      expect(game.gameState.isDrafting, isFalse);
    });
  });

  group('HUDOverlay Drafting UI Tests (Issue #56)', () {
    testWidgets('HUDOverlay displays drafting_stream_badge when gameState.isDrafting is true', (tester) async {
      final gameState = GameState();
      gameState.startRun();
      gameState.setDrafting(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      expect(find.byKey(const Key('drafting_stream_badge')), findsOneWidget);
      expect(find.text('DRAFTING 1.2X (+SLINGSHOT READY)'), findsOneWidget);
    });

    testWidgets('HUDOverlay hides drafting_stream_badge when gameState.isDrafting is false', (tester) async {
      final gameState = GameState();
      gameState.startRun();
      gameState.setDrafting(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      expect(find.byKey(const Key('drafting_stream_badge')), findsNothing);
    });
  });

  group('GameOverModal Drafting UI Tests (Issue #56)', () {
    testWidgets('displays game_over_draft_badge with singular text when bikeDraftSlingshotsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1400,
              tips: 420,
              isNewRecord: false,
              careerTips: 2100,
              bikeDraftSlingshotsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_draft_badge')), findsOneWidget);
      expect(find.text('1 BIKE SLINGSHOT CATAPULT'), findsOneWidget);
    });

    testWidgets('displays game_over_draft_badge with plural text when bikeDraftSlingshotsCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 2200,
              tips: 920,
              isNewRecord: true,
              careerTips: 3800,
              bikeDraftSlingshotsCompleted: 4,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_draft_badge')), findsOneWidget);
      expect(find.text('4 BIKE SLINGSHOT CATAPULTS'), findsOneWidget);
    });

    testWidgets('hides game_over_draft_badge when bikeDraftSlingshotsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 80,
              isNewRecord: false,
              careerTips: 400,
              bikeDraftSlingshotsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_draft_badge')), findsNothing);
    });
  });
}
