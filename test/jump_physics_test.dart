import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';

void main() {
  group('JumpPhysicsSimulator (U3)', () {
    test('Short tap jump (80ms hold) reaches peak height between 65px and 75px (AE1)', () {
      final peakHeight = JumpPhysicsSimulator.simulateJumpPeak(holdDuration: 0.080);
      expect(
        peakHeight,
        greaterThanOrEqualTo(65.0),
        reason: 'Peak height $peakHeight should be >= 65px',
      );
      expect(
        peakHeight,
        lessThanOrEqualTo(75.0),
        reason: 'Peak height $peakHeight should be <= 75px',
      );
    });

    test('Full hold leap (250ms hold) reaches peak height between 175px and 185px (AE1)', () {
      final peakHeight = JumpPhysicsSimulator.simulateJumpPeak(holdDuration: 0.250);
      expect(
        peakHeight,
        greaterThanOrEqualTo(175.0),
        reason: 'Peak height $peakHeight should be >= 175px',
      );
      expect(
        peakHeight,
        lessThanOrEqualTo(185.0),
        reason: 'Peak height $peakHeight should be <= 185px',
      );
    });

    test('Holding beyond maxHoldTime caps at maximum leap height', () {
      final peak250 = JumpPhysicsSimulator.simulateJumpPeak(holdDuration: 0.250);
      final peak500 = JumpPhysicsSimulator.simulateJumpPeak(holdDuration: 0.500);

      expect(peak500, closeTo(peak250, 1.0));
    });

    test('Ground collision reset: Avatar lands at baseline Y with zero velocity', () {
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      expect(sim.currentY, equals(460.0));
      expect(sim.isGrounded, isTrue);

      sim.startJump();
      expect(sim.isGrounded, isFalse);

      // Simulate until landing
      double elapsed = 0.0;
      while (elapsed < 2.0) {
        sim.update(1.0 / 60.0);
        elapsed += 1.0 / 60.0;
        if (sim.isGrounded && elapsed > 0.1) break;
      }

      expect(sim.isGrounded, isTrue);
      expect(sim.currentY, equals(460.0));
      expect(sim.verticalVelocity, equals(0.0));
      expect(sim.heightAboveGround, equals(0.0));
    });

    test('Mid-air tap rejection: Tapping in mid-air does not trigger a second impulse', () {
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      expect(sim.startJump(), isTrue);
      expect(sim.isGrounded, isFalse);

      // Advance into the air
      sim.update(1.0 / 60.0);
      final velocityBefore = sim.verticalVelocity;

      // Second jump tap while airborne must be rejected
      final secondJumpResult = sim.startJump();
      expect(secondJumpResult, isFalse);
      expect(sim.verticalVelocity, equals(velocityBefore));
    });
  });
}
