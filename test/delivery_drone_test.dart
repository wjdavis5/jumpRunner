// The drone-removal test mounts the game by hand (no flame_test dependency),
// which needs Flame's internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/delivery_drone_component.dart';
import 'package:jump_runner/game/components/pickup_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/hud_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PickupComponent - Drone Type', () {
    test('initializes and returns null spritePath for procedural rendering', () {
      final pickup = PickupComponent(
        type: PickupType.drone,
        position: Vector2(100, 200),
      );

      expect(pickup.type, equals(PickupType.drone));
      expect(PickupComponent.spritePathForType(PickupType.drone), isNull);
    });

    test('renders procedural cyber drone transport crate on canvas without throwing', () {
      final pickup = PickupComponent(
        type: PickupType.drone,
        position: Vector2(100, 200),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => pickup.render(canvas), returnsNormally);
    });
  });

  group('GameState Drone Power-Up State (Issue #32)', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState();
      gameState.startRun();
    });

    test('initializes with inactive drone and zero timer', () {
      expect(gameState.isDroneActive, isFalse);
      expect(gameState.droneTimer, equals(0.0));
    });

    test('activateDrone starts 8-second buff and stacks up to 16-second cap', () {
      gameState.activateDrone();
      expect(gameState.isDroneActive, isTrue);
      expect(gameState.droneTimer, equals(8.0));

      // Stack second pickup
      gameState.activateDrone(8.0);
      expect(gameState.droneTimer, equals(16.0));

      // Attempt to exceed cap
      gameState.activateDrone(5.0);
      expect(gameState.droneTimer, equals(16.0));
    });

    test('updateDroneTimer counts down and deactivates at zero', () {
      gameState.activateDrone(5.0);
      expect(gameState.isDroneActive, isTrue);

      gameState.updateDroneTimer(2.0);
      expect(gameState.droneTimer, closeTo(3.0, 0.001));
      expect(gameState.isDroneActive, isTrue);

      gameState.updateDroneTimer(3.5);
      expect(gameState.droneTimer, equals(0.0));
      expect(gameState.isDroneActive, isFalse);
    });

    test('startRun resets active drone buff', () {
      gameState.activateDrone(8.0);
      expect(gameState.isDroneActive, isTrue);

      gameState.startRun();
      expect(gameState.isDroneActive, isFalse);
      expect(gameState.droneTimer, equals(0.0));
    });
  });

  group('DeliveryDroneComponent Mechanics', () {
    test('renders drone chassis, rotors, and active tractor beam on canvas', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.gameState.activateDrone();

      final drone = DeliveryDroneComponent(
        game: game,
        position: Vector2(200, 200),
      );

      final targetPickup = PickupComponent(
        type: PickupType.coin,
        position: Vector2(240, 280),
      );
      drone.activeTarget = targetPickup;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => drone.render(canvas), returnsNormally);
    });

    test('follows courier player position with floating damping', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.gameState.activateDrone();

      final drone = DeliveryDroneComponent(
        game: game,
        position: Vector2(0, 0),
      );
      game.world.add(drone);

      // Player is at x=120
      game.player.position = Vector2(120, 396);

      drone.update(0.1);

      // Drone should have moved towards player
      expect(drone.position.x, greaterThan(0));
      expect(drone.position.y, greaterThan(0));
    });

    test('acquires closest pickup within scan radius and pulls it via tractor beam', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.gameState.activateDrone();

      final drone = DeliveryDroneComponent(
        game: game,
        position: Vector2(200, 300),
      );
      game.world.add(drone);

      final coin = PickupComponent(
        type: PickupType.coin,
        position: Vector2(260, 320),
      );
      game.world.add(coin);
      game.activePickups.add(coin);

      final initialDist = (coin.position - drone.position).length;

      // Update drone
      drone.update(0.05);

      expect(drone.activeTarget, equals(coin));
      final newDist = (coin.position - drone.position).length;
      expect(newDist, lessThan(initialDist));
    });

    test('collects pickup and invokes onCollected when reeled within proximity', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      game.gameState.activateDrone();

      final drone = DeliveryDroneComponent(
        game: game,
        position: Vector2(200, 300),
      );
      game.world.add(drone);

      bool collected = false;
      final coin = PickupComponent(
        type: PickupType.coin,
        position: Vector2(205, 305), // within collection threshold
        onCollected: (_) => collected = true,
      );
      game.world.add(coin);
      game.activePickups.add(coin);

      drone.update(0.02);

      expect(collected, isTrue);
      expect(coin.isCollected, isTrue);
      expect(drone.activeTarget, isNull);
    });

    test('swoops up and departs when drone buff expires', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
      // Drone buff is inactive (0s)
      expect(game.gameState.isDroneActive, isFalse);

      final drone = DeliveryDroneComponent(
        game: game,
        position: Vector2(200, 200),
      );
      game.world.add(drone);

      final initialY = drone.position.y;
      final initialX = drone.position.x;

      drone.update(0.1);

      expect(drone.isDeparting, isTrue);
      expect(drone.position.y, lessThan(initialY));
      expect(drone.position.x, greaterThan(initialX));
    });

    test('leaves the world once the buff has lapsed and the swoop is done', () async {
      final game = CourierGame();
      game.onGameResize(Vector2(960, 540));
      await game.load();
      game.mount();
      game.update(0);
      await game.ready();
      game.gameState.startRun();
      // An empty street, so no drone cargo can refresh the buff mid-swoop.
      game.nextChunkX = 1e12;
      for (final p in game.activePickups.toList()) {
        p.removeFromParent();
      }
      game.activePickups.clear();

      final drone = DeliveryDroneComponent(
        game: game,
        position: Vector2(200, 200),
      );
      game.world.add(drone);
      game.update(0); // Mount the drone into the tree.
      expect(game.world.children.contains(drone), isTrue);

      // Buff inactive: the drone swoops off the top of the screen and must
      // take itself out of the world (world_housekeeping exempts its
      // lifetime, so this is the guard for the removal path). Frames go
      // through the game so Flame processes the removal.
      for (var i = 0; i < 120 && game.world.children.contains(drone); i++) {
        game.update(0.1);
      }

      expect(game.world.children.contains(drone), isFalse,
          reason: 'a departed drone must not linger in the world');
      expect(drone.isMounted, isFalse);
    });
  });

  group('CourierGame & HUD Integration (Issue #32)', () {
    test('collecting drone pickup activates drone assist buff', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      expect(game.gameState.isDroneActive, isFalse);

      // Collect drone pickup directly
      game.player.position = Vector2(100, 396);
      final droneBox = PickupComponent(
        type: PickupType.drone,
        position: Vector2(100, 396),
        onCollected: (type) {
          game.gameState.activateDrone();
        },
      );
      game.world.add(droneBox);

      // Trigger collision
      droneBox.onCollisionStart({}, game.player);

      expect(droneBox.isCollected, isTrue);
      expect(game.gameState.isDroneActive, isTrue);
    });

    test('spawns DeliveryDroneComponent when drone becomes active', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      expect(game.deliveryDrone, isNull);

      game.gameState.activateDrone();
      game.update(0.01);

      expect(game.deliveryDrone, isNotNull);
      expect(game.world.children.whereType<DeliveryDroneComponent>().length, equals(1));
    });

    test('restartRun cleans up active delivery drone', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      game.gameState.activateDrone();
      game.update(0.01);
      expect(game.deliveryDrone, isNotNull);

      game.restartRun();

      expect(game.deliveryDrone, isNull);
      expect(game.world.children.whereType<DeliveryDroneComponent>(), isEmpty);
    });

    testWidgets('HUDOverlay renders drone assist badge when drone is active', (tester) async {
      final gameState = GameState();
      gameState.startRun();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: gameState,
              builder: (context, _) => HUDOverlay(
                gameState: gameState,
                onPause: () {},
              ),
            ),
          ),
        ),
      );

      // Inactive initially
      expect(find.byKey(const Key('drone_assist_badge')), findsNothing);

      // Activate drone
      gameState.activateDrone(6.5);
      await tester.pump();

      expect(find.byKey(const Key('drone_assist_badge')), findsOneWidget);
      expect(find.textContaining('DRONE HARVEST 6.5s'), findsOneWidget);
    });
  });
}
