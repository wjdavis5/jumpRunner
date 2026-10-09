import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/cement_mixer_component.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CementMixerComponent Unit Tests (Issue #126)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final mixer = CementMixerComponent(
        position: Vector2(300.0, 404.0),
        groundY: 460.0,
      );

      expect(mixer.size.x, equals(64.0));
      expect(mixer.size.y, equals(56.0));
      expect(mixer.groundY, equals(460.0));
      expect(mixer.hasHopped, isFalse);
      expect(mixer.drumRotation, equals(0.0));
      expect(mixer.shouldRecycle, isFalse);
      expect(mixer.mixerTopY, equals(404.0));
      expect(mixer.centerWorldPosition, equals(Vector2(332.0, 432.0)));
      expect(mixer.drumCenterWorld, equals(Vector2(332.0, 426.4)));
      expect(mixer.hopApexWorld, equals(Vector2(332.0, 414.08)));
    });

    test('the drum churns forward as time passes', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));

      mixer.update(0.5);
      expect(
        mixer.drumRotation,
        closeTo(CementMixerComponent.drumRotationSpeed * 0.5, 0.001),
      );

      final afterHalf = mixer.drumRotation;
      mixer.update(0.5);
      expect(mixer.drumRotation, closeTo(afterHalf * 2.0, 0.001));
    });

    test('checkMixerHop ignores courier outside horizontal bounds', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 420.0;

      final farLeft = mixer.checkMixerHop(
        Vector2(100.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      final farRight = mixer.checkMixerHop(
        Vector2(380.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(mixer.hasHopped, isFalse);
    });

    test('checkMixerHop ignores courier outside the drum window', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      sim.currentY = 340.0; // Well above the drum hood
      final tooHigh = mixer.checkMixerHop(
        Vector2(310.0, 300.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      sim.currentY = 470.0; // Below the pavement line
      final tooLow = mixer.checkMixerHop(
        Vector2(310.0, 430.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(mixer.hasHopped, isFalse);
    });

    test('a grounded courier is marked but not launched', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final triggered = mixer.checkMixerHop(
        Vector2(310.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(mixer.hasHopped, isTrue);
      expect(sim.verticalVelocity, equals(0.0),
          reason: 'running past under the drum is not a hop');
    });

    test('an airborne courier gets the +230 px/s mortar hop once', () {
      final mixer = CementMixerComponent(position: Vector2(300.0, 404.0));
      var hops = 0;
      final mixerWithCallback = CementMixerComponent(
        position: Vector2(300.0, 404.0),
        onHop: () => hops++,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 420.0;
      sim.verticalVelocity = -40.0; // Coming down onto the drum

      final triggered = mixerWithCallback.checkMixerHop(
        Vector2(310.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(triggered, isTrue);
      expect(sim.verticalVelocity, equals(230.0));
      expect(mixerWithCallback.hasHopped, isTrue);
      expect(hops, equals(1));

      final secondCheck = mixerWithCallback.checkMixerHop(
        Vector2(310.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);
      expect(hops, equals(1), reason: 'one hop per mixer, not one per frame');

      // The untouched fixture stays idle.
      expect(mixer.hasHopped, isFalse);
    });

    test('a fixture scrolled well past the camera recycles', () {
      final mixer = CementMixerComponent(position: Vector2(-300.0, 404.0));
      expect(mixer.shouldRecycle, isTrue);
    });
  });
}
