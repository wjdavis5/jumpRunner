import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';

const double _dt = 1 / 60;

/// A leap that has been held for [seconds].
JumpPhysicsSimulator _leapAfter(double seconds) {
  final sim = JumpPhysicsSimulator()..startJump();
  for (var t = 0.0; t < seconds - 1e-9; t += _dt) {
    sim.update(_dt);
  }
  return sim;
}

/// Runs [sim] until it lands and returns the greatest height it reached.
double _peak(JumpPhysicsSimulator sim) {
  var peak = sim.heightAboveGround;
  for (var i = 0; i < 600 && !sim.isGrounded; i++) {
    sim.update(_dt);
    if (sim.heightAboveGround > peak) peak = sim.heightAboveGround;
  }
  return peak;
}

void main() {
  // Fourteen street pieces launch the courier: an awning, a storm drain, a
  // satellite dish, a newsstand, a thermal. Most launch at 200 to 240 px/s.
  // A held leap climbs at up to 435. A launch set the speed to its own and
  // ended the hold, so a leap that brushed one of them on the way up was cut
  // down to a hop: the courier leapt a van, touched a newsstand and came
  // down on the van. A player with good timing lost one leap in five to it.
  group('Help from the street never costs height', () {
    test('a launch leaves alone a held leap that is climbing higher', () {
      final untouched = _peak(_leapAfter(0.1));
      expect(untouched, greaterThan(160.0));

      for (final moment in const [0.0, 0.05, 0.1, 0.2, 0.3, 0.4]) {
        for (final impulse in const [200.0, 230.0, 240.0]) {
          final sim = _leapAfter(moment);
          final speedBefore = sim.verticalVelocity;
          final holdingBefore = sim.isHolding;
          sim.launch(impulse);
          expect(sim.verticalVelocity, equals(speedBefore), reason: 'launch of $impulse at $moment s');
          expect(sim.isHolding, equals(holdingBefore));
          expect(_peak(sim), closeTo(untouched, 0.5), reason: 'launch of $impulse at $moment s');
        }
      }
    });

    test('the old launch would have halved that leap', () {
      // What a launch did: its speed, no hold.
      final cut = _leapAfter(0.1)
        ..isHolding = false
        ..verticalVelocity = 230.0;
      expect(_peak(cut), lessThan(_peak(_leapAfter(0.1)) * 0.5));
    });

    test('a launch still lifts a courier who is falling', () {
      final sim = _leapAfter(1.0);
      expect(sim.verticalVelocity, lessThan(0));
      final from = sim.heightAboveGround;
      sim.launch(230.0);
      expect(sim.verticalVelocity, equals(230.0));
      expect(_peak(sim), greaterThan(from + 20.0));
    });

    test('and one who is near the top of a jump with little climb left', () {
      final sim = _leapAfter(0.6);
      expect(sim.verticalVelocity, inExclusiveRange(0.0, 150.0));
      sim.launch(230.0);
      expect(sim.verticalVelocity, equals(230.0));
    });

    test('a launch stronger than the jump takes over', () {
      final sim = _leapAfter(0.05);
      sim.launch(700.0);
      expect(sim.verticalVelocity, equals(700.0));
      expect(sim.isHolding, isFalse);
    });

    test('from the ground a launch is what it always was', () {
      final sim = JumpPhysicsSimulator()..launch(230.0);
      expect(sim.isGrounded, isFalse);
      expect(sim.verticalVelocity, equals(230.0));
      expect(_peak(sim), closeTo(230.0 * 230.0 / (2 * 980.0), 3.0));
    });

    test('a release downward is not a launch and goes through', () {
      final sim = _leapAfter(0.1)..launch(-80.0);
      expect(sim.verticalVelocity, equals(-80.0));
    });

    test('an updraft does not end the hold of a leap passing through it', () {
      final untouched = _peak(_leapAfter(0.05));
      final sim = _leapAfter(0.05)..applyUpdraft(200.0);
      expect(sim.isHolding, isTrue);
      expect(_peak(sim), closeTo(untouched, 0.5));
    });

    test('an updraft still lifts a courier who is falling', () {
      final sim = _leapAfter(1.0)..applyUpdraft(200.0);
      expect(sim.verticalVelocity, equals(200.0));
    });
  });

  group('What is left of a jump', () {
    test('matches where the jump actually tops out, held or tapped', () {
      for (final moment in const [0.0, 0.1, 0.2, 0.3, 0.5]) {
        final sim = _leapAfter(moment);
        final predicted = sim.heightAboveGround + sim.riseRemaining;
        expect(predicted, closeTo(_peak(_leapAfter(moment)), 8.0), reason: 'held, at $moment s');
      }
      final tap = JumpPhysicsSimulator()
        ..startJump()
        ..stopJump();
      final predicted = tap.heightAboveGround + tap.riseRemaining;
      final tapAgain = JumpPhysicsSimulator()
        ..startJump()
        ..stopJump();
      expect(predicted, closeTo(_peak(tapAgain), 8.0));
    });

    test('is nothing on the ground or on the way down', () {
      expect(JumpPhysicsSimulator().riseRemaining, equals(0.0));
      expect(_leapAfter(1.0).riseRemaining, equals(0.0));
    });
  });
}
