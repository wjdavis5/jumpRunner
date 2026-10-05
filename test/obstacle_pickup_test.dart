import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/components/pickup_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ObstacleComponent & PickupComponent (U4)', () {
    test('ObstacleComponent attaches hitbox and removes when exiting left past -200', () async {
      final obstacle = ObstacleComponent(
        type: ObstacleType.scooter,
        position: Vector2(500, 420),
        size: Vector2(40, 40),
      );
      await obstacle.onLoad();

      final hitboxes = obstacle.children.whereType<RectangleHitbox>();
      expect(hitboxes.length, equals(1));

      // Active when on-screen
      obstacle.update(0.1);
      expect(obstacle.shouldRecycle, isFalse);

      // Moved past -200px threshold
      obstacle.position.x = -205.0;
      obstacle.update(0.1);
      expect(obstacle.shouldRecycle, isTrue);
    });

    test('Obstacle collision with CourierPlayer triggers damage', () async {
      final player = CourierPlayer(groundY: 460.0);
      await player.onLoad();

      final obstacle = ObstacleComponent(
        type: ObstacleType.hydrant,
        position: Vector2(120, 420),
        size: Vector2(30, 40),
      );
      await obstacle.onLoad();

      expect(player.isInvulnerable, isFalse);

      obstacle.onCollisionStart({Vector2.zero()}, player);
      expect(player.isInvulnerable, isTrue);
      expect(player.state, equals(CourierState.hurt));
    });

    test('PickupComponent bobs vertically with sine wave', () async {
      final pickup = PickupComponent(
        type: PickupType.coin,
        position: Vector2(300, 400),
        size: Vector2(24, 24),
      );
      await pickup.onLoad();

      final initialY = pickup.position.y;
      expect(initialY, equals(400.0));

      // Update time step
      pickup.update(0.2);
      expect(pickup.position.y, isNot(equals(initialY)));
    });

    test('Pickup collision with CourierPlayer triggers collection callback and recycling', () async {
      final player = CourierPlayer(groundY: 460.0);
      await player.onLoad();

      PickupType? collectedType;
      final pickup = PickupComponent(
        type: PickupType.coin,
        position: Vector2(120, 420),
        size: Vector2(24, 24),
        onCollected: (type) => collectedType = type,
      );
      await pickup.onLoad();

      pickup.onCollisionStart({Vector2.zero()}, player);
      expect(collectedType, equals(PickupType.coin));
      expect(pickup.isCollected, isTrue);
    });

    test('Pickup removes when exiting left past -200', () async {
      final pickup = PickupComponent(
        type: PickupType.energyDrink,
        position: Vector2(-205, 400),
        size: Vector2(24, 24),
      );
      await pickup.onLoad();

      pickup.update(0.1);
      expect(pickup.shouldRecycle, isTrue);
    });

    test('Magnetized pickup keeps its pulled position instead of bob-snapping', () async {
      final pickup = PickupComponent(
        type: PickupType.coin,
        position: Vector2(300, 400),
        size: Vector2(24, 24),
      );
      await pickup.onLoad();

      // Simulate the magnet pulling the coin upward to (300, 340).
      pickup.isMagnetized = true;
      pickup.position = Vector2(300, 340);
      pickup.update(0.016);

      // The magnet owns the position: no sine-wave snap back to the anchor.
      expect(pickup.position.y, equals(340.0));
    });

    test('Non-magnetized pickup resumes bobbing from its current anchor', () async {
      final pickup = PickupComponent(
        type: PickupType.coin,
        position: Vector2(300, 400),
        size: Vector2(24, 24),
      );
      await pickup.onLoad();

      // Magnet drags the coin, then releases it (boost expired / out of range).
      pickup.isMagnetized = true;
      pickup.position = Vector2(300, 340);
      pickup.update(0.016);
      pickup.isMagnetized = false;

      pickup.update(0.05);
      // Bobbing resumes around the released position, not the spawn anchor.
      expect(pickup.position.y, inInclusiveRange(330.0, 350.0));
    });

    test('Hazard sprite paths match curated Kenney assets', () {
      expect(ObstacleComponent.spritePathForType(ObstacleType.scooter), equals('hazards/scooter.png'));
      expect(ObstacleComponent.spritePathForType(ObstacleType.dog), equals('hazards/dog.png'));
      expect(ObstacleComponent.spritePathForType(ObstacleType.hydrant), equals('hazards/hydrant.png'));
      expect(ObstacleComponent.spritePathForType(ObstacleType.van), equals('hazards/van.png'));
    });

    test('Pickup sprite paths match curated Kenney assets', () {
      expect(PickupComponent.spritePathForType(PickupType.coin), equals('pickups/coin.png'));
      expect(PickupComponent.spritePathForType(PickupType.coin5), equals('pickups/coin.png'));
      expect(PickupComponent.spritePathForType(PickupType.energyDrink), equals('pickups/energy_drink.png'));
      expect(PickupComponent.spritePathForType(PickupType.packageRestore), equals('pickups/package_box.png'));
    });
  });
}
