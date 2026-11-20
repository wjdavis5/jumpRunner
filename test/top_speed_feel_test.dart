import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/speed_lines_component.dart';

import 'support/bare_street.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeedLinesComponent Unit Tests', () {
    test('calm air draws nothing and spends no work', () {
      final lines = SpeedLinesComponent(
        size: Vector2(960, 540),
        random: math.Random(7),
      );

      expect(lines.intensity, equals(0.0));
      expect(lines.activeStreakCount, equals(0));

      final xsBefore = [for (var i = 0; i < lines.maxStreaks; i++) lines.streakX(i)];
      lines.update(0.5);
      final xsAfter = [for (var i = 0; i < lines.maxStreaks; i++) lines.streakX(i)];
      expect(xsAfter, equals(xsBefore),
          reason: 'calm air leaves every streak parked');
    });

    test('flat-out sprint fills the pool and races ahead of the street', () {
      final lines = SpeedLinesComponent(
        size: Vector2(960, 540),
        groundY: 460.0,
        random: math.Random(7),
      )..intensity = 1.0;

      expect(lines.activeStreakCount, equals(lines.maxStreaks));

      lines.horizontalScrollSpeed = 550.0;
      final xsBefore = [for (var i = 0; i < lines.maxStreaks; i++) lines.streakX(i)];
      lines.update(1 / 60);
      for (var i = 0; i < lines.maxStreaks; i++) {
        final moved = xsBefore[i] - lines.streakX(i);
        expect(moved, greaterThan(550.0 * 1.5 / 60.0),
            reason: 'streaks outrun the street scroll');
      }
    });

    test('streaks recycle off the left edge back onto the right', () {
      // A tiny viewport: one step at sprint intensity blows every streak
      // past the left edge, so all of them must respawn on the right.
      final lines = SpeedLinesComponent(
        size: Vector2(120, 540),
        random: math.Random(7),
      )..intensity = 1.0;

      lines.horizontalScrollSpeed = 550.0;
      lines.update(1.0);

      for (var i = 0; i < lines.maxStreaks; i++) {
        expect(lines.streakX(i), greaterThanOrEqualTo(-8.0),
            reason: 'a recycled streak never lingers off the left edge');
        expect(lines.streakX(i), lessThan(220.0),
            reason: 'a recycled streak respawns just off the right edge');
      }
    });

    test('intensity scales the visible pool', () {
      final lines = SpeedLinesComponent(
        size: Vector2(960, 540),
        random: math.Random(7),
      );

      lines.intensity = 0.4;
      expect(lines.activeStreakCount, equals((26 * 0.4).round()));
      lines.intensity = 0.0;
      expect(lines.activeStreakCount, equals(0));
    });
  });

  group('Run Cycle Speed Coupling Tests', () {
    test('the stride ticks at the base rate when the street is calm', () {
      final player = CourierPlayer(groundY: 460.0);
      expect(player.runCycleRate, equals(1.0));

      // 0.1 s of running: not yet a full 0.12 s stride frame.
      for (var i = 0; i < 6; i++) {
        player.update(1 / 60);
      }
      expect(player.runFrame, equals(0),
          reason: '0.1 s of running keeps the first stride frame');

      // Two more steps cross 0.12 s of stride clock.
      player.update(1 / 60);
      player.update(1 / 60);
      expect(player.runFrame, equals(1),
          reason: '0.13 s of running advances the stride');
    });

    test('a flat-out sprint strides almost twice-and-a-half as fast', () {
      final player = CourierPlayer(groundY: 460.0);
      player.runCycleRate = 2.4;

      // 0.117 s of sim time at rate 2.4 = 0.28 s of stride clock: two ticks.
      for (var i = 0; i < 7; i++) {
        player.update(1 / 60);
      }
      expect(player.runFrame, equals(2),
          reason: 'the sprint stride covers two frames in 0.117 s');
    });

    test('the stride cycles through all four frames and wraps', () {
      final player = CourierPlayer(groundY: 460.0);
      player.runCycleRate = 10.0;
      for (var i = 0; i < 8; i++) {
        player.update(1 / 60);
      }
      expect(player.runFrame, inInclusiveRange(0, 3));
    });
  });

  group('CourierGame Top-Speed Wiring Tests', () {
    test('calm street: no wind, base stride', () async {
      final game = await bareStreetGame(0);
      game.update(1 / 60);

      expect(game.currentSpeed, closeTo(200.0, 0.1));
      expect(game.speedLines.intensity, equals(0.0));
      expect(game.player.runCycleRate, closeTo(1.0, 0.001));
    });

    test('top speed: full wind and the fastest stride', () async {
      final game = await bareStreetGame(2600);
      game.update(1 / 60);

      expect(game.currentSpeed, closeTo(550.0, 1.0));
      expect(game.speedLines.intensity, equals(1.0));
      expect(game.speedLines.activeStreakCount, greaterThan(0));
      expect(game.player.runCycleRate, equals(2.4));
    });

    test('the wind spins up through the middle of the ramp', () async {
      final game = await bareStreetGame(1200);
      game.update(1 / 60);

      // 1,200 m lands the ramp at ~410 px/s: wind just above its threshold.
      expect(game.currentSpeed, closeTo(410.0, 2.0));
      expect(game.speedLines.intensity, greaterThan(0.0));
      expect(game.speedLines.intensity, lessThan(0.3));
    });
  });
}
