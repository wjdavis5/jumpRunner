import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/storm_drain_component.dart';
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

  group('StormDrainComponent Tests (Issue #62)', () {
    test('initializes with default dimensions, impulse, and untriggered state', () {
      final drain = StormDrainComponent(
        position: Vector2(250.0, 442.0),
        groundY: 460.0,
      );

      expect(drain.size.x, equals(56.0));
      expect(drain.size.y, equals(18.0));
      expect(drain.groundY, equals(460.0));
      expect(drain.launchImpulse, equals(450.0));
      expect(drain.hasTriggered, isFalse);
      expect(drain.shouldRecycle, isFalse);
    });

    test('grateTopWorldY and centerWorldPosition calculate coordinates correctly', () {
      final drain = StormDrainComponent(
        position: Vector2(200.0, 442.0),
        width: 56.0,
        height: 18.0,
      );

      expect(drain.grateTopWorldY, equals(442.0));
      expect(drain.centerWorldPosition.x, equals(200.0 + 28.0));
      expect(drain.centerWorldPosition.y, equals(442.0 + 9.0));
    });

    test('checkTrigger returns false when player is out of reach horizontally or vertically', () {
      final drain = StormDrainComponent(
        position: Vector2(200.0, 442.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);

      // Foot X far to the left
      expect(
        drain.checkTrigger(Vector2(100.0, 412.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );

      // Foot X far to the right
      expect(
        drain.checkTrigger(Vector2(400.0, 412.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );

      // Foot Y high above ground
      simulator.currentY = 350.0;
      expect(
        drain.checkTrigger(Vector2(210.0, 302.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );
    });

    test('checkTrigger launches courier, sets hasTriggered, and invokes callback', () {
      var didTrigger = false;
      final drain = StormDrainComponent(
        position: Vector2(200.0, 442.0),
        groundY: 460.0,
        launchImpulse: 460.0,
        onTrigger: () {
          didTrigger = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 458.0;

      // Player centered over drain: drain pos = 200, width = 56, center = 228
      // Player pos x = 212, width = 32 -> footX = 228
      final result = drain.checkTrigger(
        Vector2(212.0, 410.0),
        Vector2(32.0, 48.0),
        simulator,
      );

      expect(result, isTrue);
      expect(drain.hasTriggered, isTrue);
      expect(didTrigger, isTrue);
      expect(simulator.verticalVelocity, equals(460.0));
      expect(simulator.isGrounded, isFalse);

      // Subsequent call does not re-trigger
      didTrigger = false;
      final secondResult = drain.checkTrigger(
        Vector2(212.0, 410.0),
        Vector2(32.0, 48.0),
        simulator,
      );
      expect(secondResult, isFalse);
      expect(didTrigger, isFalse);
    });

    test('shouldRecycle evaluates scroll boundary', () {
      final drain = StormDrainComponent(
        position: Vector2(10.0, 442.0),
      );
      expect(drain.shouldRecycle, isFalse);

      drain.position.x = -250.0;
      expect(drain.shouldRecycle, isTrue);
    });

    test('render executes cleanly without errors during simmering and geyser eruption', () {
      final drain = StormDrainComponent(
        position: Vector2(100.0, 442.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Simmering vapor render
      drain.render(canvas);

      // Trigger geyser eruption and render
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      drain.checkTrigger(Vector2(112.0, 412.0), Vector2(32.0, 48.0), simulator);

      drain.update(0.1);
      drain.render(canvas);

      final pic = recorder.endRecording();
      pic.dispose();
    });
  });

  group('GameState Storm Drain Logic Tests (Issue #62)', () {
    test('drainGeysersInRun initializes to 0', () {
      final state = GameState();
      expect(state.drainGeysersInRun, equals(0));
    });

    test('recordDrainGeyser returns null when status is not running', () {
      final state = GameState();
      state.status = GameStatus.idle;

      final event = state.recordDrainGeyser();
      expect(event, isNull);
      expect(state.drainGeysersInRun, equals(0));
    });

    test('recordDrainGeyser increments counters, advances streak, and fires callback', () {
      final state = GameState();
      state.startRun();

      StormDrainEvent? received;
      state.onStormDrain = (e) => received = e;

      // Base: 30; streak advances 0 -> 1 (multiplier 1.2x); 30 * 1.2 = 36
      final event = state.recordDrainGeyser(baseTips: 30, coinsSpawned: 3);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(30));
      expect(event.multiplier, equals(1.2));
      expect(event.totalTips, equals(36));
      expect(event.stuntStreak, equals(1));
      expect(event.coinsSpawned, equals(3));

      expect(state.drainGeysersInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(state.stuntStreakTimer, equals(GameState.stuntComboDuration));
      expect(state.tips, equals(36));
      expect(received, equals(event));
    });

    test('recordDrainGeyser scales with high combo streak, energy boost, and skate commute', () {
      final state = GameState();
      state.startRun();
      state.stuntStreak = 4; // streak advances to 5 -> multiplier 2.5x
      state.activateEnergyDrink(8.0);

      // (30 * 2.5) = 75; doubled with energy boost to 150
      final event = state.recordDrainGeyser(baseTips: 30);
      expect(event, isNotNull);
      expect(event!.totalTips, equals(150));
      expect(state.tips, equals(150));

      // Daily shift skate commute
      final dailyState = GameState();
      dailyState.startRun();
      dailyState.activeDailyShift = const DailyShift(
        dateString: '2026-10-04',
        modifier: DailyModifier.skateCommute,
        targetDistanceMeters: 1000,
        completionBonusTips: 100,
      );

      // Streak 1 (1.2x) -> 30 * 1.2 = 36; skate commute doubles to 72
      final dailyEvent = dailyState.recordDrainGeyser(baseTips: 30);
      expect(dailyEvent, isNotNull);
      expect(dailyEvent!.totalTips, equals(72));
    });

    test('startRun resets drainGeysersInRun', () {
      final state = GameState();
      state.startRun();
      state.recordDrainGeyser();
      expect(state.drainGeysersInRun, equals(1));

      state.startRun();
      expect(state.drainGeysersInRun, equals(0));
    });
  });

  group('WorldChunkManager Storm Drain Spawning Tests (Issue #62)', () {
    test('StormDrainData model stores attributes', () {
      const data = StormDrainData(
        x: 400.0,
        y: 442.0,
        width: 56.0,
        height: 18.0,
        coinsSpawned: 4,
      );

      expect(data.x, equals(400.0));
      expect(data.y, equals(442.0));
      expect(data.width, equals(56.0));
      expect(data.height, equals(18.0));
      expect(data.coinsSpawned, equals(4));
    });

    test('ChunkData includes stormDrains list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        stormDrains: [
          StormDrainData(x: 220.0, y: 442.0),
        ],
      );

      expect(chunk.stormDrains.length, equals(1));
      expect(chunk.stormDrains.first.x, equals(220.0));
    });

    test('WorldChunkManager procedurally produces storm drains at distance >= 120m', () {
      final manager = WorldChunkManager();
      var foundDrain = false;

      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 500.0 + (i * 960.0),
          groundY: 460.0,
          speed: 240.0,
          distanceMeters: 160.0,
        );
        if (chunk.stormDrains.isNotEmpty) {
          foundDrain = true;
          final sd = chunk.stormDrains.first;
          expect(sd.width, equals(56.0));
          expect(sd.height, equals(18.0));
          expect(sd.coinsSpawned, greaterThanOrEqualTo(3));
          break;
        }
      }

      expect(foundDrain, isTrue);
    });
  });

  group('CourierGame Storm Drain Integration Tests (Issue #62)', () {
    test('stepping on storm drain launches courier, awards tips, and spawns coin geyser', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final drain = StormDrainComponent(
        position: Vector2(200.0, 442.0),
        groundY: 460.0,
        launchImpulse: 450.0,
      );
      game.activeStormDrains.add(drain);
      game.world.add(drain);

      expect(game.activeStormDrains.length, equals(1));
      expect(game.gameState.drainGeysersInRun, equals(0));

      final initialPickupCount = game.activePickups.length;

      // Position courier over storm drain on the ground
      game.player.position.x = 212.0;
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      game.update(0.05);

      expect(drain.hasTriggered, isTrue);
      expect(game.gameState.drainGeysersInRun, equals(1));
      expect(game.gameState.tips, greaterThan(0));
      expect(game.player.simulator.verticalVelocity, equals(450.0));

      // 3 golden coins were spawned in active pickups
      expect(game.activePickups.length, equals(initialPickupCount + 3));

      // Visual floating text added
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('DRAIN GEYSER!')), isTrue);
    });

    test('recycles offscreen storm drains and resets on restartRun', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreenDrain = StormDrainComponent(
        position: Vector2(-300.0, 442.0),
      );
      game.activeStormDrains.add(offscreenDrain);
      game.world.add(offscreenDrain);

      game.update(0.1);
      expect(game.activeStormDrains, isEmpty);

      final freshDrain = StormDrainComponent(
        position: Vector2(300.0, 442.0),
      );
      game.activeStormDrains.add(freshDrain);
      game.world.add(freshDrain);
      expect(game.activeStormDrains.length, equals(1));

      game.restartRun();
      expect(game.activeStormDrains, isEmpty);
      expect(game.gameState.drainGeysersInRun, equals(0));
    });
  });

  group('GameOverModal Storm Drain Badge UI Tests (Issue #62)', () {
    testWidgets('displays game_over_drain_geysers_badge with singular text when drainGeysersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1300,
              tips: 390,
              isNewRecord: false,
              careerTips: 1950,
              drainGeysersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_drain_geysers_badge')), findsOneWidget);
      expect(find.text('1 STORM DRAIN GEYSER'), findsOneWidget);
    });

    testWidgets('displays game_over_drain_geysers_badge with plural text when drainGeysersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 2400,
              tips: 980,
              isNewRecord: true,
              careerTips: 3500,
              drainGeysersCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_drain_geysers_badge')), findsOneWidget);
      expect(find.text('3 STORM DRAIN GEYSERS'), findsOneWidget);
    });

    testWidgets('hides game_over_drain_geysers_badge when drainGeysersCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 550,
              tips: 70,
              isNewRecord: false,
              careerTips: 350,
              drainGeysersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_drain_geysers_badge')), findsNothing);
    });
  });
}
