import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/crosswalk_zone_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CrosswalkZoneComponent Tests (Issue #59)', () {
    test('initializes with default width, groundY, countdown, size, and isHighFived == false', () {
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(250.0, 404.0),
        width: 140.0,
        groundY: 460.0,
        signalCountdown: 8,
      );

      expect(crosswalk.size.x, equals(140.0));
      expect(crosswalk.size.y, equals(56.0));
      expect(crosswalk.groundY, equals(460.0));
      expect(crosswalk.signalCountdown, equals(8));
      expect(crosswalk.isHighFived, isFalse);
      expect(crosswalk.shouldRecycle, isFalse);
    });

    test('handWorldPosition calculates correct world coordinate', () {
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(200.0, 400.0),
        width: 140.0,
      );

      final handPos = crosswalk.handWorldPosition;
      expect(handPos.x, equals(200.0 + 140.0 - 22.0));
      expect(handPos.y, equals(400.0 + 18.0));
    });

    test('checkHighFiveProximity returns false when player is out of range', () {
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(300.0, 400.0),
        width: 140.0,
      );

      // Player far to the left
      expect(
        crosswalk.checkHighFiveProximity(Vector2(100.0, 400.0), Vector2(32.0, 48.0)),
        isFalse,
      );

      // Player far to the right
      expect(
        crosswalk.checkHighFiveProximity(Vector2(600.0, 400.0), Vector2(32.0, 48.0)),
        isFalse,
      );

      // Player too high
      expect(
        crosswalk.checkHighFiveProximity(Vector2(410.0, 200.0), Vector2(32.0, 48.0)),
        isFalse,
      );

      // Player too low
      expect(
        crosswalk.checkHighFiveProximity(Vector2(410.0, 600.0), Vector2(32.0, 48.0)),
        isFalse,
      );

      expect(crosswalk.isHighFived, isFalse);
    });

    test('checkHighFiveProximity triggers onHighFive callback and sets isHighFived', () {
      var didTriggerCallback = false;
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(300.0, 400.0),
        width: 140.0,
        onHighFive: () {
          didTriggerCallback = true;
        },
      );

      // Hand is at (300 + 140 - 22, 400 + 18) = (418, 418)
      // Player bounding box covering (400, 395) with size (32, 48) -> spans x:[400, 432], y:[395, 443]
      final result = crosswalk.checkHighFiveProximity(
        Vector2(400.0, 395.0),
        Vector2(32.0, 48.0),
      );

      expect(result, isTrue);
      expect(crosswalk.isHighFived, isTrue);
      expect(didTriggerCallback, isTrue);

      // Subsequent proximity checks return false without re-triggering callback
      didTriggerCallback = false;
      final secondCheck = crosswalk.checkHighFiveProximity(
        Vector2(400.0, 395.0),
        Vector2(32.0, 48.0),
      );
      expect(secondCheck, isFalse);
      expect(didTriggerCallback, isFalse);
    });

    test('shouldRecycle evaluates scroll bounds correctly', () {
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(50.0, 400.0),
        width: 140.0,
      );
      expect(crosswalk.shouldRecycle, isFalse);

      // Move completely offscreen past -180.0
      crosswalk.position.x = -350.0;
      expect(crosswalk.shouldRecycle, isTrue);
    });

    test('update advances signal timer and clap animation timer', () {
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(300.0, 400.0),
        width: 140.0,
      );

      crosswalk.checkHighFiveProximity(
        Vector2(400.0, 395.0),
        Vector2(32.0, 48.0),
      );
      expect(crosswalk.isHighFived, isTrue);

      crosswalk.update(0.25);
      crosswalk.update(0.35); // timer elapses past 0.5s
      // Should not throw or crash
    });

    test('render executes without error across signal phases and clap animations', () {
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(100.0, 400.0),
        width: 140.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // 1. Walk phase render
      crosswalk.render(canvas);

      // 2. Amber hand phase render
      crosswalk.update(1.8);
      crosswalk.render(canvas);

      // 3. High five clap celebration render
      crosswalk.checkHighFiveProximity(
        Vector2(200.0, 395.0),
        Vector2(32.0, 48.0),
      );
      crosswalk.render(canvas);

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('GameState High-Five Logic Tests (Issue #59)', () {
    test('initializes with highFivesInRun == 0', () {
      final state = GameState();
      expect(state.highFivesInRun, equals(0));
    });

    test('recordHighFive returns null when game is not running', () {
      final state = GameState();
      state.status = GameStatus.idle;

      final event = state.recordHighFive();
      expect(event, isNull);
      expect(state.highFivesInRun, equals(0));
    });

    test('recordHighFive increments counters, awards tips, and fires callback', () {
      final state = GameState();
      state.startRun();

      HighFiveEvent? receivedEvent;
      state.onHighFive = (e) => receivedEvent = e;

      final event = state.recordHighFive(baseTips: 20);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(20));
      expect(event.totalTips, equals(24));
      expect(event.multiplier, equals(1.2));
      expect(event.stuntStreak, equals(1));

      expect(state.highFivesInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(state.stuntStreakTimer, equals(GameState.stuntComboDuration));
      expect(state.tips, equals(24));
      expect(receivedEvent, equals(event));
    });

    test('recordHighFive scales with stunt multiplier, energy boost, and skate commute', () {
      final state = GameState();
      state.startRun();
      state.stuntStreak = 4; // After increment: streak 5 -> multiplier 2.5x
      state.activateEnergyDrink(8.0);

      final event = state.recordHighFive(baseTips: 20);
      expect(event, isNotNull);
      // Base: (20 * 2.5) = 50; energy boost doubles to 100
      expect(event!.totalTips, equals(100));
      expect(state.tips, equals(100));

      // Daily shift skate commute
      final dailyState = GameState();
      dailyState.startRun();
      dailyState.activeDailyShift = const DailyShift(
        dateString: '2026-10-04',
        modifier: DailyModifier.skateCommute,
        targetDistanceMeters: 1000,
        completionBonusTips: 100,
      );

      final dailyEvent = dailyState.recordHighFive(baseTips: 20);
      expect(dailyEvent, isNotNull);
      // Streak 1: (20 * 1.2) = 24; skate commute doubles base to 48
      expect(dailyEvent!.totalTips, equals(48));
    });

    test('startRun resets highFivesInRun', () {
      final state = GameState();
      state.startRun();
      state.recordHighFive();
      expect(state.highFivesInRun, equals(1));

      state.startRun();
      expect(state.highFivesInRun, equals(0));
    });
  });

  group('WorldChunkManager Crosswalk Spawning Tests (Issue #59)', () {
    test('CrosswalkData model stores coordinates and attributes', () {
      const data = CrosswalkData(
        x: 450.0,
        y: 404.0,
        width: 140.0,
        signalCountdown: 7,
      );

      expect(data.x, equals(450.0));
      expect(data.y, equals(404.0));
      expect(data.width, equals(140.0));
      expect(data.signalCountdown, equals(7));
    });

    test('ChunkData includes crosswalks list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        crosswalks: [
          CrosswalkData(x: 200.0, y: 404.0),
        ],
      );

      expect(chunk.crosswalks.length, equals(1));
      expect(chunk.crosswalks.first.x, equals(200.0));
    });

    test('WorldChunkManager procedurally produces crosswalks at distance >= 90m', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var foundCrosswalk = false;

      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 500.0 + (i * 960.0),
          groundY: 460.0,
          speed: 240.0,
          distanceMeters: 150.0,
        );
        if (chunk.crosswalks.isNotEmpty) {
          foundCrosswalk = true;
          final cw = chunk.crosswalks.first;
          expect(cw.width, equals(140.0));
          expect(cw.signalCountdown, greaterThanOrEqualTo(6));
          break;
        }
      }

      expect(foundCrosswalk, isTrue);
    });
  });

  group('CourierGame Crosswalk Integration Tests (Issue #59)', () {
    test('CourierGame updates active crosswalks and detects high-fives', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // Place a crosswalk zone directly in courier path
      // Hand position: (100.0 + 140.0 - 22.0, 404.0 + 18.0) = (218.0, 422.0)
      final crosswalk = CrosswalkZoneComponent(
        position: Vector2(100.0, 404.0),
        width: 140.0,
        groundY: 460.0,
      );
      game.activeCrosswalks.add(crosswalk);
      game.world.add(crosswalk);

      expect(game.activeCrosswalks.length, equals(1));
      expect(game.gameState.highFivesInRun, equals(0));

      // Position player at hand contact region (around x = 200..220, y = 400..420)
      game.player.position.x = 205.0;
      game.player.position.y = 410.0;

      // Update game loop
      game.update(0.05);

      expect(crosswalk.isHighFived, isTrue);
      expect(game.gameState.highFivesInRun, equals(1));
      expect(game.gameState.tips, greaterThan(0));

      // Floating text effect is spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('HIGH FIVE!')), isTrue);
    });

    test('recycles offscreen crosswalks and cleans up on restartRun', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreenCrosswalk = CrosswalkZoneComponent(
        position: Vector2(-360.0, 404.0),
        width: 140.0,
      );
      game.activeCrosswalks.add(offscreenCrosswalk);
      game.world.add(offscreenCrosswalk);

      game.update(0.1);
      expect(game.activeCrosswalks, isEmpty);

      final freshCrosswalk = CrosswalkZoneComponent(
        position: Vector2(300.0, 404.0),
        width: 140.0,
      );
      game.activeCrosswalks.add(freshCrosswalk);
      game.world.add(freshCrosswalk);
      expect(game.activeCrosswalks.length, equals(1));

      game.restartRun();
      expect(game.activeCrosswalks, isEmpty);
      expect(game.gameState.highFivesInRun, equals(0));
    });
  });

  group('GameOverModal High Fives Badge UI Tests (Issue #59)', () {
    testWidgets('displays game_over_high_fives_badge with singular text when highFivesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1400,
              tips: 420,
              isNewRecord: false,
              careerTips: 2100,
              highFivesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_high_fives_badge')), findsOneWidget);
      expect(find.text('1 CROSSWALK HIGH FIVE'), findsOneWidget);
    });

    testWidgets('displays game_over_high_fives_badge with plural text when highFivesCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 2300,
              tips: 950,
              isNewRecord: true,
              careerTips: 3400,
              highFivesCompleted: 4,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_high_fives_badge')), findsOneWidget);
      expect(find.text('4 CROSSWALK HIGH FIVES'), findsOneWidget);
    });

    testWidgets('hides game_over_high_fives_badge when highFivesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 90,
              isNewRecord: false,
              careerTips: 450,
              highFivesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_high_fives_badge')), findsNothing);
    });
  });
}
