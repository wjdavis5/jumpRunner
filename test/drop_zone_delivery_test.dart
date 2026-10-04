import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/drop_zone_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/hud_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DropZoneComponent Unit Tests (Issue #42)', () {
    test('initializes with default dimensions and unfulfilled state', () {
      final dropZone = DropZoneComponent(
        position: Vector2(300.0, 390.0),
        size: Vector2(68.0, 70.0),
      );

      expect(dropZone.hasDelivered, isFalse);
      expect(dropZone.shouldRecycle, isFalse);
      expect(dropZone.position.x, equals(300.0));
      expect(dropZone.position.y, equals(390.0));
      expect(dropZone.size.x, equals(68.0));
      expect(dropZone.size.y, equals(70.0));
    });

    test('checkCollisionWith detects runner contact and respects hasDelivered', () {
      final dropZone = DropZoneComponent(
        position: Vector2(120.0, 390.0),
        size: Vector2(68.0, 70.0),
        groundY: 460.0,
      );

      final player = CourierPlayer(
        initialX: 130.0,
        groundY: 460.0,
      );

      expect(dropZone.checkCollisionWith(player), isTrue);

      // Once delivered, ignores repeated collision
      dropZone.hasDelivered = true;
      expect(dropZone.checkCollisionWith(player), isFalse);

      // Distant player does not trigger collision
      dropZone.hasDelivered = false;
      player.position.x = 800.0;
      expect(dropZone.checkCollisionWith(player), isFalse);
    });

    test('recycles when scrolled off the left edge', () {
      final dropZone = DropZoneComponent(
        position: Vector2(100.0, 390.0),
      );

      expect(dropZone.shouldRecycle, isFalse);
      dropZone.position.x = -200.0;
      expect(dropZone.shouldRecycle, isTrue);
    });

    test('renders on canvas without error for both unfulfilled and completed states', () {
      final dropZone = DropZoneComponent(
        position: Vector2(100.0, 390.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Initial unfulfilled beacon state
      expect(() => dropZone.render(canvas), returnsNormally);

      // Advance pulse animation
      dropZone.update(0.1);
      expect(() => dropZone.render(canvas), returnsNormally);

      // Completed checkmark state
      dropZone.hasDelivered = true;
      expect(() => dropZone.render(canvas), returnsNormally);
    });
  });

  group('GameState Doorstep Delivery & Streak Mechanics', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState();
      gameState.startRun();
    });

    test('awards 5-star rating and base tip when cargo is full (3 packages)', () {
      expect(gameState.packages, equals(3));
      final event = gameState.recordDoorstepDelivery();

      expect(event, isNotNull);
      expect(event!.ratingStars, equals(5));
      expect(event.baseTips, equals(35));
      expect(event.totalTips, equals(35));
      expect(event.streak, equals(1));
      expect(event.multiplier, equals(1.0));
      expect(event.didRestockPackage, isFalse);
      expect(gameState.tips, equals(35));
      expect(gameState.deliveriesInRun, equals(1));
      expect(gameState.deliveryStreak, equals(1));
    });

    test('awards 4-star rating when 1 package has been damaged (2 packages remaining)', () {
      gameState.packages = 2;
      final event = gameState.recordDoorstepDelivery();

      expect(event, isNotNull);
      expect(event!.ratingStars, equals(4));
      expect(event.baseTips, equals(25));
      expect(event.totalTips, equals(25));
    });

    test('awards 3-star rating when 2 packages have been damaged (1 package remaining)', () {
      gameState.packages = 1;
      final event = gameState.recordDoorstepDelivery();

      expect(event, isNotNull);
      expect(event!.ratingStars, equals(3));
      expect(event.baseTips, equals(15));
      expect(event.totalTips, equals(15));
    });

    test('delivery streak scales tips and 3x streak restocks a lost package', () {
      gameState.packages = 2; // Lost 1 package earlier

      // Delivery 1 (streak 1: 1.0x)
      final e1 = gameState.recordDoorstepDelivery()!;
      expect(e1.streak, equals(1));
      expect(e1.multiplier, equals(1.0));
      expect(e1.totalTips, equals(25)); // 25 * 1.0
      expect(gameState.packages, equals(2));

      // Delivery 2 (streak 2: 1.5x)
      final e2 = gameState.recordDoorstepDelivery()!;
      expect(e2.streak, equals(2));
      expect(e2.multiplier, equals(1.5));
      expect(e2.totalTips, equals((25 * 1.5).round())); // 38
      expect(gameState.packages, equals(2));

      // Delivery 3 (streak 3: 2.0x -> Restock perk fires!)
      final e3 = gameState.recordDoorstepDelivery()!;
      expect(e3.streak, equals(3));
      expect(e3.multiplier, equals(2.0));
      expect(e3.totalTips, equals((25 * 2.0).round())); // 50
      expect(e3.didRestockPackage, isTrue);
      expect(gameState.packages, equals(3)); // Successfully restocked!

      // Delivery 4 (streak 4: 2.5x max multiplier)
      final e4 = gameState.recordDoorstepDelivery()!;
      expect(e4.streak, equals(4));
      expect(e4.multiplier, equals(2.5));
      expect(e4.totalTips, equals((35 * 2.5).round())); // Now 5-star cargo: 35 * 2.5 = 88
    });

    test('taking hazard damage resets active delivery streak', () {
      gameState.recordDoorstepDelivery();
      gameState.recordDoorstepDelivery();
      expect(gameState.deliveryStreak, equals(2));

      // Collision with hazard
      gameState.applyHazardDamage();
      expect(gameState.deliveryStreak, equals(0));
      expect(gameState.deliveryMultiplier, equals(1.0));
    });

    test('energy drink buff doubles doorstep delivery earnings', () {
      gameState.activateEnergyDrink();
      final event = gameState.recordDoorstepDelivery()!;
      expect(event.baseTips, equals(35));
      expect(event.totalTips, equals(70)); // 35 * 2
      expect(gameState.tips, equals(70));
    });
  });

  group('LocalStorageService Delivery Persistence', () {
    test('records and accumulates lifetime doorstep deliveries', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.lifetimeDeliveries, equals(0));

      await storage.recordDeliveries(3);
      expect(storage.lifetimeDeliveries, equals(3));

      await storage.recordDeliveries(2);
      expect(storage.lifetimeDeliveries, equals(5));
    });
  });

  group('WorldChunkManager Drop Zone Generation', () {
    test('ChunkData includes dropZones list', () {
      final manager = WorldChunkManager();
      final chunk = manager.generateChunk(startX: 0.0, speed: 200.0, distanceMeters: 0.0);
      expect(chunk.dropZones, isNotNull);
    });

    test('generates drop zones with obstacle clearance beyond 70m', () {
      WorldChunkManager? foundManager;
      ChunkData? dropZoneChunk;

      for (int seed = 0; seed < 100; seed++) {
        final m = WorldChunkManager(random: math.Random(seed));
        final c = m.generateChunk(startX: 500.0, speed: 250.0, distanceMeters: 80.0);
        if (c.dropZones.isNotEmpty) {
          foundManager = m;
          dropZoneChunk = c;
          break;
        }
      }

      expect(foundManager, isNotNull);
      expect(dropZoneChunk, isNotNull);
      expect(dropZoneChunk!.dropZones, isNotEmpty);

      final dropZone = dropZoneChunk.dropZones.first;
      expect(dropZone.y, equals(CourierGame.groundY - 70.0));
      expect(dropZone.width, equals(68.0));
      expect(dropZone.height, equals(70.0));

      // Verifies generous clearance from any obstacle in the chunk
      for (final obs in dropZoneChunk.obstacles) {
        final overlaps = (dropZone.x + dropZone.width >= obs.x - 40.0) &&
            (dropZone.x <= obs.x + obs.width + 40.0);
        expect(overlaps, isFalse);
      }
    });
  });

  group('CourierGame Drop Zone Traversal & Integration', () {
    test('fulfills delivery on contact, awards tips, and cleans up on restart', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      final game = CourierGame(storageService: storage);
      await game.onLoad();
      game.gameState.startRun();

      final dropZone = DropZoneComponent(
        position: Vector2(game.player.position.x - 10.0, 390.0),
        size: Vector2(68.0, 70.0),
        groundY: 460.0,
      );

      game.activeDropZones.add(dropZone);
      game.world.add(dropZone);

      expect(game.gameState.deliveriesInRun, equals(0));
      expect(game.gameState.deliveryStreak, equals(0));

      // Trigger frame to collide with drop zone
      game.update(0.016);

      expect(dropZone.hasDelivered, isTrue);
      expect(game.gameState.deliveriesInRun, equals(1));
      expect(game.gameState.deliveryStreak, equals(1));
      expect(game.gameState.tips, equals(35));
      expect(storage.lifetimeDeliveries, equals(1));

      // Floating text indicator spawned
      expect(game.world.children.whereType<FloatingTextComponent>().any(
        (t) => t.text.contains('★★★★★'),
      ), isTrue);

      // Verify restartRun cleanly detaches drop zones
      expect(game.activeDropZones.contains(dropZone), isTrue);
      game.restartRun();
      expect(game.activeDropZones, isEmpty);
      expect(game.world.children.whereType<DropZoneComponent>(), isEmpty);
    });
  });

  group('HUDOverlay and GameOverModal Widget Tests (Issue #42)', () {
    testWidgets('HUDOverlay displays delivery_streak_badge when streak > 1', (tester) async {
      final gameState = GameState();
      gameState.startRun();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      // No streak badge initially
      expect(find.byKey(const Key('delivery_streak_badge')), findsNothing);

      // Fulfill 2 deliveries to build a streak
      gameState.recordDoorstepDelivery();
      gameState.recordDoorstepDelivery();
      expect(gameState.deliveryStreak, equals(2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      // Streak badge is now visible
      expect(find.byKey(const Key('delivery_streak_badge')), findsOneWidget);
      expect(find.textContaining('DELIVERY STREAK 1.5x (2)'), findsOneWidget);
    });

    testWidgets('GameOverModal displays game_over_deliveries_badge when deliveriesCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 120,
              careerTips: 850,
              deliveriesCompleted: 3,
              isNewRecord: false,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_deliveries_badge')), findsOneWidget);
      expect(find.text('3 DOORSTEP DROPS FULFILLED'), findsOneWidget);
    });
  });
}
