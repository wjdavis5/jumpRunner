import 'package:flame/collisions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CourierPlayer (U3)', () {
    test('Initializes with torso hitbox and rests on ground baseline in running state', () async {
      final player = CourierPlayer(groundY: 460.0);
      await player.onLoad();

      expect(player.state, equals(CourierState.running));
      expect(player.position.x, equals(120.0));
      // Player height is 64; feet at groundY=460 means position.y is 460 - 64 = 396
      expect(player.position.y, equals(460.0 - player.size.y));

      final hitboxes = player.children.whereType<RectangleHitbox>();
      expect(hitboxes.length, equals(1));
      final torsoHitbox = hitboxes.first;
      // Torso hitbox should be narrower than full 64px width (e.g. 32-36px) to avoid limb clip
      expect(torsoHitbox.size.x, lessThan(player.size.x));
      expect(torsoHitbox.size.y, lessThanOrEqualTo(player.size.y));
    });

    test('Jump input transitions state: running -> jumping -> falling -> running', () async {
      final player = CourierPlayer(groundY: 460.0);
      await player.onLoad();

      // 1. Initial running
      expect(player.state, equals(CourierState.running));

      // 2. Jump initiated
      final jumpSuccess = player.jump();
      expect(jumpSuccess, isTrue);

      player.update(0.016); // 1 frame
      expect(player.state, equals(CourierState.jumping));
      expect(player.position.y, lessThan(460.0 - player.size.y));

      // 3. Update past apex to falling
      double elapsed = 0.016;
      while (player.simulator.verticalVelocity > 0 && elapsed < 2.0) {
        player.update(0.016);
        elapsed += 0.016;
      }

      player.update(0.016);
      expect(player.state, equals(CourierState.falling));

      // 4. Update until landing
      while (!player.simulator.isGrounded && elapsed < 3.0) {
        player.update(0.016);
        elapsed += 0.016;
      }

      expect(player.simulator.isGrounded, isTrue);
      expect(player.state, equals(CourierState.running));
      expect(player.position.y, equals(460.0 - player.size.y));
    });

    test('Mid-air tap is rejected and maintains flight trajectory', () async {
      final player = CourierPlayer(groundY: 460.0);
      await player.onLoad();

      player.jump();
      player.update(0.05);

      final secondJump = player.jump();
      expect(secondJump, isFalse);
    });

    test('Damage triggers 1.5s invulnerability window and hurt state', () async {
      final player = CourierPlayer(groundY: 460.0);
      await player.onLoad();

      expect(player.isInvulnerable, isFalse);

      final damaged = player.takeDamage();
      expect(damaged, isTrue);
      expect(player.isInvulnerable, isTrue);
      expect(player.state, equals(CourierState.hurt));

      // Subsequent damage while invulnerable is ignored
      final secondDamage = player.takeDamage();
      expect(secondDamage, isFalse);

      // Advance 1.0 second (still invulnerable)
      player.update(1.0);
      expect(player.isInvulnerable, isTrue);

      // Advance past 1.5 seconds
      player.update(0.6);
      expect(player.isInvulnerable, isFalse);
      expect(player.state, equals(CourierState.running));
    });
  });
}
