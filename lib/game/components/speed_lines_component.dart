import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class _Streak {
  _Streak({
    required this.x,
    required this.y,
    required this.length,
    required this.speedFactor,
    required this.alpha,
  });

  double x;
  double y;
  double length;
  double speedFactor;
  double alpha;
}

/// Rushing-air wind streaks that overlay the viewport when the courier is at
/// the top of the speed ramp: thin horizontal smears streaming leftward
/// faster than the street, so flat-out runs feel like flat-out runs.
///
/// The game feeds [intensity] from the scroll speed (0 below ~380 px/s,
/// 1.0 at the 550 px/s cap) and [horizontalScrollSpeed] each frame; below
/// the threshold nothing is drawn and no streaks move.
class SpeedLinesComponent extends PositionComponent {
  SpeedLinesComponent({
    Vector2? size,
    this.maxStreaks = 26,
    this.groundY = 460.0,
    math.Random? random,
  })  : _rng = random ?? math.Random(),
        super(
          size: size ?? Vector2(960, 540),
          priority: 6,
        ) {
    _initStreaks();
  }

  final int maxStreaks;
  final math.Random _rng;

  /// Ground surface level; streaks stay in the air above it.
  double groundY = 460.0;

  /// Current wind intensity from 0.0 (calm) to 1.0 (flat-out sprint).
  double intensity = 0.0;

  /// Current game horizontal scroll speed the streaks race ahead of.
  double horizontalScrollSpeed = 200.0;

  final List<_Streak> _streaks = [];

  /// How many streaks are currently visible at the present intensity.
  int get activeStreakCount =>
      (maxStreaks * intensity).round().clamp(0, _streaks.length);

  /// The leading edge of streak [index], for tests and HUD tuning.
  double streakX(int index) => _streaks[index].x;

  void _initStreaks() {
    _streaks.clear();
    final w = size.x;
    final h = size.y;
    for (var i = 0; i < maxStreaks; i++) {
      _streaks.add(
        _Streak(
          x: _rng.nextDouble() * w,
          y: _rng.nextDouble() * (h * 0.78),
          length: 46.0 + _rng.nextDouble() * 96.0,
          speedFactor: 1.6 + _rng.nextDouble() * 1.0,
          alpha: 0.14 + _rng.nextDouble() * 0.16,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (intensity <= 0.01) return;

    final w = size.x;
    for (final streak in _streaks) {
      streak.x -= horizontalScrollSpeed * streak.speedFactor * dt;

      // Recycle off the left edge back onto the right, above the sidewalk.
      if (streak.x + streak.length < -8.0) {
        streak.x = w + _rng.nextDouble() * 90.0;
        streak.y = _rng.nextDouble() * (size.y * 0.78);
        streak.length = 46.0 + _rng.nextDouble() * 96.0;
        streak.speedFactor = 1.6 + _rng.nextDouble() * 1.0;
        streak.alpha = 0.14 + _rng.nextDouble() * 0.16;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (intensity <= 0.01) return;

    final streakPaint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final count = activeStreakCount;
    for (var i = 0; i < count; i++) {
      final streak = _streaks[i];
      final streakAlpha = (streak.alpha * intensity).clamp(0.0, 1.0);
      streakPaint.color = const Color(0xFFE3F2FD).withValues(alpha: streakAlpha);
      canvas.drawLine(
        Offset(streak.x, streak.y),
        Offset(streak.x + streak.length, streak.y),
        streakPaint,
      );
    }
  }
}
