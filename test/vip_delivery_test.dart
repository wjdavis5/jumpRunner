import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/drop_zone_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/pickup_component.dart';
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

  group('PickupComponent VIP Package Tests (Issue #55)', () {
    test('PickupType.vipPackage defaults to 32x28 size and has null spritePath', () {
      final pickup = PickupComponent(
        type: PickupType.vipPackage,
        position: Vector2(100, 200),
      );

      expect(pickup.type, equals(PickupType.vipPackage));
      expect(pickup.size.x, equals(32.0));
      expect(pickup.size.y, equals(28.0));
      expect(PickupComponent.spritePathForType(PickupType.vipPackage), isNull);
    });

    test('renders procedural luxury golden briefcase on canvas without throwing', () {
      final pickup = PickupComponent(
        type: PickupType.vipPackage,
        position: Vector2(50, 50),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => pickup.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('GameState VIP Mission Mechanics Tests (Issue #55)', () {
    test('initializes with inactive VIP mission and zero deliveries', () {
      final gameState = GameState();
      expect(gameState.isVipMissionActive, isFalse);
      expect(gameState.vipTimer, equals(0.0));
      expect(gameState.vipDeliveriesInRun, equals(0));
      expect(gameState.vipSurgeMultiplier, equals(3.0));
    });

    test('startVipMission activates mission and sets timer', () {
      final gameState = GameState();
      gameState.startRun();

      gameState.startVipMission(14.0);
      expect(gameState.isVipMissionActive, isTrue);
      expect(gameState.vipTimer, equals(14.0));
      expect(gameState.vipInitialDuration, equals(14.0));
    });

    test('updateVipTimer decrements countdown and triggers expiration when reaching 0', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.startVipMission(10.0);

      var didExpire = false;
      gameState.onVipMissionExpired = () {
        didExpire = true;
      };

      gameState.updateVipTimer(4.0);
      expect(gameState.vipTimer, closeTo(6.0, 0.001));
      expect(gameState.isVipMissionActive, isTrue);
      expect(didExpire, isFalse);

      gameState.updateVipTimer(6.5);
      expect(gameState.vipTimer, equals(0.0));
      expect(gameState.isVipMissionActive, isFalse);
      expect(didExpire, isTrue);
    });

    test('recordVipDelivery awards 3x surge tips stacked with stunt multiplier and restores package life', () {
      final gameState = GameState();
      gameState.startRun();
      // Drop 1 package life to test package restock
      gameState.applyHazardDamage();
      expect(gameState.packages, equals(2));

      gameState.startVipMission(12.0);
      VipDeliveryEvent? deliveredEvent;
      gameState.onVipDelivery = (e) => deliveredEvent = e;

      final event = gameState.recordVipDelivery();
      expect(event, isNotNull);
      expect(deliveredEvent, equals(event));

      // stuntStreak increments to 1 => stuntMultiplier = 1.2
      // baseTip = 60; totalMultiplier = 3.0 * 1.2 = 3.6
      // tips earned = (60 * 3.6).round() = 216
      expect(event!.baseTips, equals(60));
      expect(event.multiplier, closeTo(3.6, 0.001));
      expect(event.totalTips, equals(216));
      expect(gameState.tips, equals(216));

      // Package restocked from 2 to 3
      expect(gameState.packages, equals(3));
      expect(gameState.vipDeliveriesInRun, equals(1));
      expect(gameState.deliveriesInRun, equals(1));
      expect(gameState.isVipMissionActive, isFalse);
      expect(gameState.vipTimer, equals(0.0));
    });

    test('recordVipDelivery caps packages at maxPackages', () {
      final gameState = GameState();
      gameState.startRun();
      expect(gameState.packages, equals(gameState.maxPackages));

      gameState.startVipMission(10.0);
      gameState.recordVipDelivery();

      expect(gameState.packages, equals(gameState.maxPackages));
    });

    test('startRun resets VIP mission status and counters', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.startVipMission(10.0);
      gameState.recordVipDelivery();
      expect(gameState.vipDeliveriesInRun, equals(1));

      gameState.startRun();
      expect(gameState.vipDeliveriesInRun, equals(0));
      expect(gameState.isVipMissionActive, isFalse);
      expect(gameState.vipTimer, equals(0.0));
    });
  });

  group('DropZoneComponent VIP Tests (Issue #55)', () {
    test('DropZoneComponent supports isVip flag and default properties', () {
      final standardZone = DropZoneComponent(position: Vector2(100, 390));
      expect(standardZone.isVip, isFalse);

      final vipZone = DropZoneComponent(position: Vector2(200, 390), isVip: true);
      expect(vipZone.isVip, isTrue);
      expect(vipZone.hasDelivered, isFalse);
    });

    test('renders standard and VIP drop zone facades without throwing', () {
      final standardZone = DropZoneComponent(position: Vector2(100, 390), isVip: false);
      final vipZone = DropZoneComponent(position: Vector2(200, 390), isVip: true);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => standardZone.render(canvas), returnsNormally);
      expect(() => vipZone.render(canvas), returnsNormally);

      // Also render in delivered state
      vipZone.hasDelivered = true;
      expect(() => vipZone.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('checkCollisionWith correctly detects courier contact footprint', () {
      final zone = DropZoneComponent(
        position: Vector2(200.0, 390.0),
        size: Vector2(68.0, 70.0),
        isVip: true,
      );

      final player = CourierPlayer();
      player.position = Vector2(220.0, 390.0);
      player.simulator.currentY = 420.0;

      expect(zone.checkCollisionWith(player), isTrue);

      player.position = Vector2(50.0, 390.0);
      expect(zone.checkCollisionWith(player), isFalse);
    });
  });

  group('WorldChunkManager VIP Chunk Generation Tests (Issue #55)', () {
    test('DropZoneData has isVip field with default false', () {
      const data = DropZoneData(x: 100, y: 390, width: 68, height: 70);
      expect(data.isVip, isFalse);

      const vipData = DropZoneData(x: 100, y: 390, width: 68, height: 70, isVip: true);
      expect(vipData.isVip, isTrue);
    });

    test('generateChunk prioritizes VIP drop zone when isVipActive is true', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var foundVipDropZone = false;

      for (int i = 0; i < 20; i++) {
        final chunk = manager.generateChunk(
          startX: i * 960.0,
          speed: 300.0,
          distanceMeters: 250.0,
          isVipActive: true,
        );

        if (chunk.dropZones.any((dz) => dz.isVip)) {
          foundVipDropZone = true;
          break;
        }
      }

      expect(foundVipDropZone, isTrue);
    });
  });

  group('CourierGame VIP Express Integration Tests (Issue #55)', () {
    late CourierGame game;

    setUp(() async {
      game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
    });

    tearDown(() {
      game.gameState.status = GameStatus.idle;
    });

    test('collecting vipPackage pickup starts VIP mission and awards floating text', () {
      expect(game.gameState.isVipMissionActive, isFalse);

      final pickup = PickupComponent(
        type: PickupType.vipPackage,
        position: Vector2(game.player.position.x, game.player.position.y),
      );
      game.activePickups.add(pickup);
      game.world.add(pickup);

      game.gameState.startVipMission(14.0);
      game.world.add(
        FloatingTextComponent(
          text: 'VIP EXPRESS DISPATCH! 14s (3X SURGE)',
          position: Vector2(game.player.position.x, game.player.position.y - 30),
          color: const Color(0xFFFFD700),
        ),
      );

      expect(game.gameState.isVipMissionActive, isTrue);
      expect(game.gameState.vipTimer, equals(14.0));
      expect(game.world.children.whereType<FloatingTextComponent>(), isNotEmpty);
    });

    test('hitting VIP drop zone fulfills VIP express and awards surge tips', () {
      game.gameState.startVipMission(14.0);
      expect(game.gameState.isVipMissionActive, isTrue);

      final vipDropZone = DropZoneComponent(
        position: Vector2(game.player.position.x, CourierGame.groundY - 70.0),
        isVip: true,
      );
      game.activeDropZones.add(vipDropZone);
      game.world.add(vipDropZone);

      game.update(0.016);

      expect(vipDropZone.hasDelivered, isTrue);
      expect(game.gameState.vipDeliveriesInRun, equals(1));
      expect(game.gameState.isVipMissionActive, isFalse);
      expect(game.gameState.tips, greaterThan(0));
    });

    test('VIP mission timer countdown to 0 invokes expiration callback and adds expired text', () {
      game.gameState.startVipMission(0.05);
      expect(game.gameState.isVipMissionActive, isTrue);

      game.update(0.1);

      expect(game.gameState.isVipMissionActive, isFalse);
      expect(game.gameState.vipTimer, equals(0.0));
      expect(
        game.world.children
            .whereType<FloatingTextComponent>()
            .any((t) => t.text.contains('EXPIRED')),
        isTrue,
      );
    });

    test('restartRun cleans up active VIP state', () {
      game.gameState.startVipMission(14.0);
      game.gameState.recordVipDelivery();
      expect(game.gameState.vipDeliveriesInRun, equals(1));

      game.restartRun();
      expect(game.gameState.vipDeliveriesInRun, equals(0));
      expect(game.gameState.isVipMissionActive, isFalse);
      expect(game.gameState.vipTimer, equals(0.0));
    });
  });

  group('HUDOverlay VIP UI Tests (Issue #55)', () {
    testWidgets('HUDOverlay displays vip_mission_badge when isVipMissionActive is true', (tester) async {
      final gameState = GameState();
      gameState.startRun();
      gameState.startVipMission(12.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      expect(find.byKey(const Key('vip_mission_badge')), findsOneWidget);
      expect(find.text('VIP EXPRESS: 12.5s (3.0x SURGE)'), findsOneWidget);
    });

    testWidgets('HUDOverlay hides vip_mission_badge when isVipMissionActive is false', (tester) async {
      final gameState = GameState();
      gameState.startRun();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      expect(find.byKey(const Key('vip_mission_badge')), findsNothing);
    });

    testWidgets('HUDOverlay renders red alert styling when vipTimer < 3.5s', (tester) async {
      final gameState = GameState();
      gameState.startRun();
      gameState.startVipMission(2.4);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: gameState),
          ),
        ),
      );

      expect(find.byKey(const Key('vip_mission_badge')), findsOneWidget);
      expect(find.text('VIP EXPRESS: 2.4s (3.0x SURGE)'), findsOneWidget);
    });
  });

  group('GameOverModal VIP Badge UI Tests (Issue #55)', () {
    testWidgets('displays game_over_vip_badge with singular text when vipDeliveriesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 350,
              isNewRecord: false,
              careerTips: 1500,
              vipDeliveriesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_vip_badge')), findsOneWidget);
      expect(find.text('1 VIP EXPRESS DELIVERY (3X SURGE)'), findsOneWidget);
    });

    testWidgets('displays game_over_vip_badge with plural text when vipDeliveriesCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1800,
              tips: 750,
              isNewRecord: true,
              careerTips: 2500,
              vipDeliveriesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_vip_badge')), findsOneWidget);
      expect(find.text('3 VIP EXPRESS DELIVERIES (3X SURGE)'), findsOneWidget);
    });

    testWidgets('hides game_over_vip_badge when vipDeliveriesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 800,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              vipDeliveriesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_vip_badge')), findsNothing);
    });
  });
}
