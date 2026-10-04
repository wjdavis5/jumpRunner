import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/puddle_component.dart';
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

  group('PuddleComponent Unit Tests (Issue #70)', () {
    test('initializes with default dimensions, position, and un-splashed state', () {
      final puddle = PuddleComponent(
        position: Vector2(240.0, 446.0),
        size: Vector2(74.0, 14.0),
        groundY: 460.0,
      );

      expect(puddle.position.x, equals(240.0));
      expect(puddle.position.y, equals(446.0));
      expect(puddle.size.x, equals(74.0));
      expect(puddle.size.y, equals(14.0));
      expect(puddle.groundY, equals(460.0));
      expect(puddle.surfaceY, equals(446.0));
      expect(puddle.centerWorld.x, equals(240.0 + 37.0));
      expect(puddle.centerWorld.y, equals(446.0 + 7.0));
      expect(puddle.hasSplashed, isFalse);
      expect(puddle.hasSkimmed, isFalse);
      expect(puddle.isRaining, isFalse);
      expect(puddle.shouldRecycle, isFalse);
    });

    test('shouldRecycle triggers when puddle has scrolled completely offscreen', () {
      final puddle = PuddleComponent(
        position: Vector2(-220.0, 446.0),
      );

      expect(puddle.shouldRecycle, isTrue);
    });

    test('checkSplash triggers when courier foot lands in puddle while grounded', () {
      final puddle = PuddleComponent(
        position: Vector2(200.0, 446.0),
        size: Vector2(80.0, 14.0),
        groundY: 460.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 446.0;
      simulator.isGrounded = true;

      // Courier foot inside puddle horizontal bounds
      final playerPos = Vector2(210.0, 410.0);
      final playerSize = Vector2(32.0, 48.0); // foot at x = 226

      expect(puddle.checkSplash(playerPos, playerSize, simulator), isTrue);
    });

    test('checkSplash returns false when courier is airborne over puddle', () {
      final puddle = PuddleComponent(
        position: Vector2(200.0, 446.0),
        size: Vector2(80.0, 14.0),
        groundY: 460.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 380.0; // High in jump arc
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 350.0);
      final playerSize = Vector2(32.0, 48.0);

      expect(puddle.checkSplash(playerPos, playerSize, simulator), isFalse);
    });

    test('checkSkim triggers when courier has cleanly cleared over puddle without splashing', () {
      final puddle = PuddleComponent(
        position: Vector2(200.0, 446.0),
        size: Vector2(80.0, 14.0),
        groundY: 460.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);

      // Foot before puddle
      expect(puddle.checkSkim(Vector2(100.0, 400.0), Vector2(32.0, 48.0), simulator), isFalse);

      // Foot past right edge (200 + 80 = 280)
      final pastPos = Vector2(270.0, 400.0); // foot at 270 + 16 = 286 > 280
      expect(puddle.checkSkim(pastPos, Vector2(32.0, 48.0), simulator), isTrue);

      // If already splashed, skim cannot trigger
      puddle.hasSplashed = true;
      expect(puddle.checkSkim(pastPos, Vector2(32.0, 48.0), simulator), isFalse);
    });

    test('renders procedural asphalt rim, water reflection, and rain plinks without error', () {
      final puddle = PuddleComponent(
        position: Vector2(100.0, 446.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      puddle.render(canvas);

      puddle.isRaining = true;
      puddle.update(0.1);
      puddle.render(canvas);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('ParticleEffectComponent Water Spray Tests (Issue #70)', () {
    test('waterSpray factory creates fanning water droplet particles', () {
      final spray = ParticleEffectComponent.waterSpray(
        position: Vector2(200.0, 450.0),
        count: 14,
      );

      expect(spray.particles.length, equals(14));
      for (final p in spray.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(280.0));
      }
    });

    test('waterSpray particles update and expire over lifecycle', () {
      final spray = ParticleEffectComponent.waterSpray(
        position: Vector2(200.0, 450.0),
        count: 6,
      );

      expect(spray.isFinished, isFalse);
      spray.update(0.65);
      expect(spray.isFinished, isTrue);
    });
  });

  group('GameState Puddle Skim Economy & Combo Tests (Issue #70)', () {
    test('recordPuddleSkim increments counter and advances stunt streak', () {
      final state = GameState();
      state.startRun();

      expect(state.puddleSkimsInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordPuddleSkim(baseTips: 20);
      expect(event, isNotNull);
      expect(event!.baseTips, equals(20));
      expect(event.multiplier, equals(1.2)); // Streak 1 -> 1.2x
      expect(event.totalTips, equals(24)); // 20 * 1.2 = 24
      expect(event.stuntStreak, equals(1));

      expect(state.puddleSkimsInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(state.tips, equals(24));
    });

    test('recordPuddleSkim scales with combo multipliers', () {
      final state = GameState();
      state.startRun();
      state.stuntStreak = 3; // Streak 3 gives 2.0x, incrementing to 4 gives 2.5x

      final event = state.recordPuddleSkim(baseTips: 20);
      expect(event, isNotNull);
      expect(event!.multiplier, equals(2.5));
      expect(event.totalTips, equals(50)); // 20 * 2.5 = 50
    });

    test('recordPuddleSkim doubles tips when energy boost is active', () {
      final state = GameState();
      state.startRun();
      state.activateEnergyDrink(8.0);

      // Streak 1 (1.2x): 20 * 1.2 = 24; energy boost doubles to 48
      final event = state.recordPuddleSkim(baseTips: 20);
      expect(event, isNotNull);
      expect(event!.totalTips, equals(48));
    });

    test('recordPuddleSkim doubles tips with Skate Commute daily shift modifier', () {
      final state = GameState();
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 1000,
          completionBonusTips: 100,
        ),
      );

      // Streak 1 (1.2x): 20 * 1.2 = 24; skate commute doubles to 48
      final event = state.recordPuddleSkim(baseTips: 20);
      expect(event, isNotNull);
      expect(event!.totalTips, equals(48));
    });

    test('recordPuddleSkim invokes onPuddleSkim callback', () {
      final state = GameState();
      state.startRun();

      PuddleSkimEvent? received;
      state.onPuddleSkim = (e) => received = e;

      state.recordPuddleSkim(baseTips: 20);
      expect(received, isNotNull);
      expect(received!.baseTips, equals(20));
    });

    test('startRun resets puddleSkimsInRun', () {
      final state = GameState();
      state.startRun();
      state.recordPuddleSkim();
      expect(state.puddleSkimsInRun, equals(1));

      state.startRun();
      expect(state.puddleSkimsInRun, equals(0));
    });
  });

  group('WorldChunkManager Puddle Spawning Tests (Issue #70)', () {
    test('PuddleData stores coordinates and dimensions', () {
      const data = PuddleData(
        x: 350.0,
        y: 446.0,
        width: 74.0,
        height: 14.0,
      );

      expect(data.x, equals(350.0));
      expect(data.y, equals(446.0));
      expect(data.width, equals(74.0));
      expect(data.height, equals(14.0));
    });

    test('ChunkData includes puddles list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        puddles: [
          PuddleData(x: 200.0, y: 446.0),
        ],
      );

      expect(chunk.puddles.length, equals(1));
      expect(chunk.puddles.first.x, equals(200.0));
    });

    test('WorldChunkManager procedurally generates puddles at distance >= 50m', () {
      final manager = WorldChunkManager();
      var foundPuddle = false;

      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 400.0 + (i * 960.0),
          groundY: 460.0,
          speed: 240.0,
          distanceMeters: 80.0,
        );
        if (chunk.puddles.isNotEmpty) {
          foundPuddle = true;
          final p = chunk.puddles.first;
          expect(p.width, equals(74.0));
          expect(p.height, equals(14.0));
          break;
        }
      }

      expect(foundPuddle, isTrue);
    });
  });

  group('CourierGame Puddle Integration Tests (Issue #70)', () {
    test('stepping in puddle triggers splash and increments wet hazards counter', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final puddle = PuddleComponent(
        position: Vector2(200.0, 446.0),
        groundY: 460.0,
      );
      game.activePuddles.add(puddle);
      game.world.add(puddle);

      expect(puddle.hasSplashed, isFalse);

      // Position courier grounded directly in puddle
      game.player.position.x = 220.0;
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      game.update(0.05);

      expect(puddle.hasSplashed, isTrue);
    });

    test('leaping cleanly over puddle triggers PUDDLE SKIM and awards bonus tips', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final puddle = PuddleComponent(
        position: Vector2(200.0, 446.0),
        groundY: 460.0,
      );
      game.activePuddles.add(puddle);
      game.world.add(puddle);

      expect(puddle.hasSkimmed, isFalse);
      expect(game.gameState.puddleSkimsInRun, equals(0));

      // Courier jumps over puddle
      game.player.position.x = 220.0;
      game.player.simulator.currentY = 360.0;
      game.player.simulator.isGrounded = false;
      game.update(0.05);

      expect(puddle.hasSplashed, isFalse);
      expect(puddle.hasSkimmed, isFalse);

      // Move player past the right edge of puddle
      game.player.position.x = 285.0; // foot at 285 + 16 = 301 > 274
      game.update(0.05);

      expect(puddle.hasSkimmed, isTrue);
      expect(game.gameState.puddleSkimsInRun, equals(1));

      final floatingTexts = game.world.children.whereType<FloatingTextComponent>().toList();
      expect(floatingTexts.any((ft) => ft.text.contains('PUDDLE SKIM!')), isTrue);
    });

    test('restartRun cleans up activePuddles', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final puddle = PuddleComponent(
        position: Vector2(200.0, 446.0),
        groundY: 460.0,
      );
      game.activePuddles.add(puddle);
      game.world.add(puddle);

      expect(game.activePuddles.length, equals(1));

      game.restartRun();

      expect(game.activePuddles.isEmpty, isTrue);
      expect(game.world.children.whereType<PuddleComponent>().isEmpty, isTrue);
    });
  });

  group('GameOverModal Puddle Badge UI Tests (Issue #70)', () {
    testWidgets('GameOverModal displays game_over_puddles_badge with singular text when puddleSkimsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 400,
              tips: 100,
              isNewRecord: false,
              careerTips: 1000,
              puddleSkimsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_puddles_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('1 PUDDLE SKIM'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });

    testWidgets('GameOverModal displays game_over_puddles_badge with plural text when puddleSkimsCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 800,
              tips: 250,
              isNewRecord: true,
              careerTips: 3000,
              puddleSkimsCompleted: 4,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_puddles_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('4 PUDDLE SKIMS'), findsOneWidget);
    });

    testWidgets('GameOverModal hides game_over_puddles_badge when puddleSkimsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 60,
              isNewRecord: false,
              careerTips: 600,
              puddleSkimsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_puddles_badge'));
      expect(badgeFinder, findsNothing);
    });
  });
}
