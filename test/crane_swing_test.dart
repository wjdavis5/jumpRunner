import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/crane_swing_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
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

  group('CraneSwingComponent Unit Tests (Issue #51)', () {
    test('initializes with default and custom crane dimensions and physics parameters', () {
      final defaultCrane = CraneSwingComponent(position: Vector2(300.0, 40.0));
      expect(defaultCrane.size.x, equals(260.0));
      expect(defaultCrane.size.y, equals(320.0));
      expect(defaultCrane.cableLength, equals(175.0));
      expect(defaultCrane.anchorOffset.x, equals(140.0));
      expect(defaultCrane.anchorOffset.y, equals(42.0));
      expect(defaultCrane.isCourierAttached, isFalse);
      expect(defaultCrane.hasLaunched, isFalse);
      expect(defaultCrane.shouldRecycle, isFalse);

      final customCrane = CraneSwingComponent(
        position: Vector2(100.0, 20.0),
        size: Vector2(300.0, 360.0),
        anchorOffset: Vector2(160.0, 50.0),
        cableLength: 190.0,
      );
      expect(customCrane.cableLength, equals(190.0));
      expect(customCrane.anchorOffset.x, equals(160.0));
      expect(customCrane.anchorOffset.y, equals(50.0));
    });

    test('hookPosition calculates correct world coordinates based on swing angle and cable length', () {
      final crane = CraneSwingComponent(
        position: Vector2(200.0, 50.0),
        anchorOffset: Vector2(100.0, 40.0),
        cableLength: 150.0,
      );

      // Resting vertical (swingAngle = 0)
      crane.swingAngle = 0.0;
      expect(crane.hookPosition.x, closeTo(300.0, 0.001));
      expect(crane.hookPosition.y, closeTo(240.0, 0.001));

      // Swung forward at +0.5 rad (~28.6 degrees)
      crane.swingAngle = 0.5;
      final expectedX = 200.0 + 100.0 + (math.sin(0.5) * 150.0);
      final expectedY = 50.0 + 40.0 + (math.cos(0.5) * 150.0);
      expect(crane.hookPosition.x, closeTo(expectedX, 0.01));
      expect(crane.hookPosition.y, closeTo(expectedY, 0.01));
    });

    test('canGrabHook accurately detects proximity to the grab hook ring', () {
      final crane = CraneSwingComponent(
        position: Vector2(100.0, 40.0),
        anchorOffset: Vector2(120.0, 40.0),
        cableLength: 160.0,
      );
      crane.swingAngle = 0.0;
      final hook = crane.hookPosition; // (220.0, 240.0)

      // Courier player positioned with hands at hook
      final closePlayerPos = Vector2(hook.x - 32.0, hook.y - 14.0);
      expect(crane.canGrabHook(closePlayerPos, Vector2(64.0, 64.0)), isTrue);

      // Courier player too far to the left
      final farPlayerPos = Vector2(hook.x - 120.0, hook.y - 14.0);
      expect(crane.canGrabHook(farPlayerPos, Vector2(64.0, 64.0)), isFalse);

      // Rejects grab if already launched
      crane.hasLaunched = true;
      expect(crane.canGrabHook(closePlayerPos, Vector2(64.0, 64.0)), isFalse);
    });

    test('attachCourier and releaseCourier update state and return energetic impulses', () {
      final crane = CraneSwingComponent(position: Vector2(100.0, 50.0));
      expect(crane.isCourierAttached, isFalse);

      crane.attachCourier();
      expect(crane.isCourierAttached, isTrue);
      expect(crane.angularVelocity, greaterThan(2.0));
      expect(crane.swingAngle, lessThan(0.0)); // Leaning back ready to swing forward

      final impulses = crane.releaseCourier();
      expect(crane.isCourierAttached, isFalse);
      expect(crane.hasLaunched, isTrue);
      expect(impulses.x, greaterThanOrEqualTo(120.0));
      expect(impulses.y, greaterThanOrEqualTo(330.0));
    });

    test('update advances beacon timer and pendulum integration', () {
      final crane = CraneSwingComponent(position: Vector2.zero());
      final initialBeacon = crane.beaconOn;

      // Advance past 0.42s beacon blink interval
      crane.update(0.5);
      expect(crane.beaconOn, isNot(equals(initialBeacon)));

      // Pendulum integration while courier attached
      crane.attachCourier();
      final initialAngle = crane.swingAngle;
      crane.update(0.1);
      expect(crane.swingAngle, greaterThan(initialAngle)); // Swinging forward
    });

    test('shouldRecycle returns true once crane has scrolled past screen horizon', () {
      final crane = CraneSwingComponent(
        position: Vector2(100.0, 40.0),
        size: Vector2(260.0, 320.0),
      );
      expect(crane.shouldRecycle, isFalse);

      crane.position.x = -500.0;
      expect(crane.shouldRecycle, isTrue);
    });

    test('procedural canvas rendering of mast truss, guy wires, and cable executes cleanly', () {
      final crane = CraneSwingComponent(position: Vector2.zero());
      crane.update(0.05);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => crane.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('CourierPlayer Crane Swing Mechanics (Issue #51)', () {
    test('attachToCrane transitions to swinging state and renders swinging posture', () {
      final player = CourierPlayer();
      final crane = CraneSwingComponent(position: Vector2(200.0, 50.0));

      expect(player.isSwinging, isFalse);
      player.attachToCrane(crane);

      expect(player.isSwinging, isTrue);
      expect(player.state, equals(CourierState.swinging));
      expect(player.attachedCrane, equals(crane));
      expect(crane.isCourierAttached, isTrue);

      // Invulnerable to hazard damage while swinging
      expect(player.takeDamage(), isFalse);

      // Procedural canvas rendering in swinging state
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => player.render(canvas), returnsNormally);
      recorder.endRecording().dispose();
    });

    test('jump while swinging releases crane hook and launches courier into aerial flight', () {
      double? capturedLaunchAngle;
      final player = CourierPlayer(
        onCraneLaunch: (angle) {
          capturedLaunchAngle = angle;
        },
      );
      final crane = CraneSwingComponent(position: Vector2(200.0, 50.0));
      player.attachToCrane(crane);

      // Initiating jump while swinging triggers launch
      final jumped = player.jump();
      expect(jumped, isTrue);
      expect(player.isSwinging, isFalse);
      expect(player.state, equals(CourierState.jumping));
      expect(player.simulator.isGrounded, isFalse);
      expect(player.simulator.verticalVelocity, greaterThan(300.0));
      expect(capturedLaunchAngle, isNotNull);
    });
  });

  group('GameState Crane Swing Scoring Mechanics (Issue #51)', () {
    test('recordCraneSwing increments counter, applies combo multipliers, and fires event', () {
      final state = GameState();
      state.startRun();
      expect(state.craneSwingsInRun, equals(0));

      CraneSwingEvent? capturedEvent;
      state.onCraneSwing = (event) {
        capturedEvent = event;
      };

      // 1st crane launch at 1.2x combo multiplier (stuntStreak = 1)
      final event1 = state.recordCraneSwing(swingAngle: 0.45);
      expect(state.craneSwingsInRun, equals(1));
      expect(event1, isNotNull);
      expect(event1!.totalTips, equals(42)); // (35 * 1.2).round() = 42
      expect(state.tips, equals(42));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.swingAngle, equals(0.45));
      expect(capturedEvent!.baseTips, equals(35));
      expect(capturedEvent!.totalTips, equals(42));

      // Increase stunt combo
      state.recordStunt(clearance: 15.0);
      final mult = state.stuntMultiplier;
      expect(mult, greaterThan(1.0));

      // 2nd crane launch with active multiplier (stuntStreak = 3 -> 2.0x)
      final event2 = state.recordCraneSwing(swingAngle: 0.60);
      expect(state.craneSwingsInRun, equals(2));
      expect(event2!.totalTips, equals(70)); // (35 * 2.0).round() = 70
      expect(capturedEvent!.totalTips, equals(70));
    });

    test('startRun resets craneSwingsInRun to 0', () {
      final state = GameState();
      state.startRun();
      state.recordCraneSwing(swingAngle: 0.5);
      expect(state.craneSwingsInRun, equals(1));

      state.startRun();
      expect(state.craneSwingsInRun, equals(0));
    });
  });

  group('WorldChunkManager Crane Swing Procedural Generation (Issue #51)', () {
    test('crane swings do not spawn prior to 240 meters', () {
      final manager = WorldChunkManager(random: math.Random(54321));
      for (int i = 0; i < 10; i++) {
        final chunk = manager.generateChunk(
          startX: i * 960.0,
          speed: 260.0,
          distanceMeters: 50.0 + (i * 15.0),
        );
        expect(chunk.craneSwings, isEmpty);
      }
    });

    test('crane swings spawn beyond 240m without conflicting with scaffolding or subway', () {
      WorldChunkManager? manager;
      ChunkData? craneChunk;
      for (int seed = 1; seed < 100; seed++) {
        final m = WorldChunkManager(random: math.Random(seed));
        final chunk = m.generateChunk(
          startX: 1200.0,
          speed: 300.0,
          distanceMeters: 280.0,
        );
        if (chunk.craneSwings.isNotEmpty) {
          manager = m;
          craneChunk = chunk;
          break;
        }
      }

      expect(manager, isNotNull);
      expect(craneChunk, isNotNull);
      expect(craneChunk!.craneSwings.length, equals(1));
      final craneData = craneChunk.craneSwings.first;
      expect(craneData.cableLength, equals(175.0));

      // Mutually exclusive with conflicting terrain features
      expect(craneChunk.scaffoldings, isEmpty);
      expect(craneChunk.grindRails, isEmpty);
      expect(craneChunk.subwayStations, isEmpty);
    });
  });

  group('CourierGame Crane Swing Integration (Issue #51)', () {
    late CourierGame game;

    setUp(() async {
      game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
    });

    tearDown(() {
      game.gameState.status = GameStatus.idle;
    });

    test('player grabs crane hook when jumping within reach and auto-launches at swing apex', () {
      final crane = CraneSwingComponent(
        position: Vector2(game.player.position.x - 120.0, 40.0),
        anchorOffset: Vector2(140.0, 42.0),
        cableLength: 175.0,
      );
      game.activeCranes.add(crane);
      game.world.add(crane);

      // Position courier mid-air within hook grab range
      game.player.position = Vector2(crane.hookPosition.x - 32.0, crane.hookPosition.y - 14.0);
      game.player.simulator.currentY = game.player.position.y + 64.0;
      game.player.simulator.isGrounded = false;
      game.player.simulator.verticalVelocity = 40.0;
      game.update(0.016);

      // Hook should now be grabbed
      expect(crane.isCourierAttached, isTrue);
      expect(game.player.isSwinging, isTrue);

      // Swing forward until apex auto-release triggers
      crane.swingAngle = 0.65;
      game.update(0.016);

      expect(game.player.isSwinging, isFalse);
      expect(game.gameState.craneSwingsInRun, equals(1));
      expect(game.gameState.tips, greaterThanOrEqualTo(35));

      // Floating text should be spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('CRANE SWING!')), isTrue);
    });

    test('step 6 recycling removes off-screen activeCranes', () {
      final crane = CraneSwingComponent(
        position: Vector2(-500.0, 40.0),
        size: Vector2(260.0, 320.0),
      );
      game.activeCranes.add(crane);
      game.world.add(crane);

      expect(crane.shouldRecycle, isTrue);
      expect(game.activeCranes.contains(crane), isTrue);

      game.update(0.016);

      expect(game.activeCranes.contains(crane), isFalse);
      expect(crane.isMounted, isFalse);
    });

    test('restartRun cleans up active cranes and resets counters', () {
      final crane = CraneSwingComponent(
        position: Vector2(game.player.position.x, 40.0),
      );
      game.activeCranes.add(crane);
      game.world.add(crane);

      game.gameState.recordCraneSwing(swingAngle: 0.5);
      expect(game.gameState.craneSwingsInRun, equals(1));

      game.restartRun();

      expect(game.gameState.craneSwingsInRun, equals(0));
      expect(game.activeCranes.contains(crane), isFalse);
    });
  });

  group('GameOverModal Crane Badge UI Tests (Issue #51)', () {
    testWidgets('GameOverModal displays game_over_crane_badge with singular text when craneSwingsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              careerTips: 850,
              isNewRecord: false,
              craneSwingsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_crane_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('1 CRANE SWING'), findsOneWidget);
    });

    testWidgets('GameOverModal displays plural text when craneSwingsCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 290,
              careerTips: 1300,
              isNewRecord: false,
              craneSwingsCompleted: 4,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_crane_badge')), findsOneWidget);
      expect(find.text('4 CRANE SWINGS'), findsOneWidget);
    });

    testWidgets('GameOverModal hides game_over_crane_badge when craneSwingsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 40,
              careerTips: 350,
              isNewRecord: false,
              craneSwingsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_crane_badge')), findsNothing);
    });
  });
}
