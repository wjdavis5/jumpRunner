import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class _RainDrop {
  _RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.alpha,
  });

  double x;
  double y;
  double length;
  double speed;
  double alpha;
}

/// Dynamic atmospheric rain system rendering diagonal falling precipitation streaks across the viewport.
class RainComponent extends PositionComponent {
  RainComponent({
    Vector2? size,
    this.maxDrops = 80,
    math.Random? random,
  })  : _rng = random ?? math.Random(),
        super(
          size: size ?? Vector2(960, 540),
          priority: 5,
        ) {
    _initDrops();
  }

  final int maxDrops;
  final math.Random _rng;
  final List<_RainDrop> _drops = [];

  /// Current rain intensity from 0.0 (completely dry) to 1.0 (heavy downpour).
  double rainIntensity = 0.0;

  /// Current game horizontal scroll speed used to slant raindrops proportionally.
  double horizontalScrollSpeed = 200.0;

  /// Ground surface level where raindrops hit.
  double groundY = 460.0;

  /// Number of raindrops currently maintained in the pool.
  int get dropCount => _drops.length;

  void _initDrops() {
    _drops.clear();
    final w = size.x;
    final h = size.y;
    for (var i = 0; i < maxDrops; i++) {
      _drops.add(
        _RainDrop(
          x: _rng.nextDouble() * (w + 120.0) - 40.0,
          y: _rng.nextDouble() * h,
          length: 12.0 + _rng.nextDouble() * 10.0,
          speed: 480.0 + _rng.nextDouble() * 220.0,
          alpha: 0.35 + _rng.nextDouble() * 0.45,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (rainIntensity <= 0.01) return;

    final w = size.x;
    final slantSpeed = horizontalScrollSpeed * 0.45;

    for (final drop in _drops) {
      drop.y += drop.speed * dt;
      drop.x -= slantSpeed * dt;

      // Reset drop when crossing sidewalk baseline or scrolling off-screen left
      if (drop.y >= groundY || drop.x < -30.0) {
        drop.y = -drop.length - _rng.nextDouble() * 25.0;
        drop.x = _rng.nextDouble() * (w + 140.0) - 20.0;
        drop.length = 12.0 + _rng.nextDouble() * 10.0;
        drop.speed = 480.0 + _rng.nextDouble() * 220.0;
        drop.alpha = 0.35 + _rng.nextDouble() * 0.45;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (rainIntensity <= 0.01) return;

    final w = size.x;

    // 1. Soft atmospheric mist haze wash during heavier precipitation
    if (rainIntensity > 0.15) {
      final mistPaint = Paint()
        ..color = const Color(0xFF4A6572).withValues(
          alpha: (0.12 * rainIntensity).clamp(0.0, 1.0),
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, w, groundY), mistPaint);
    }

    // 2. Active diagonal rain streak rendering
    final activeCount = (maxDrops * rainIntensity).round().clamp(0, _drops.length);
    final slantOffset = (horizontalScrollSpeed / 450.0) * 10.0 + 4.0;

    final rainPaint = Paint()
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < activeCount; i++) {
      final drop = _drops[i];
      final dropAlpha = (drop.alpha * rainIntensity).clamp(0.0, 1.0);
      rainPaint.color = const Color(0xFFCFE8FF).withValues(alpha: dropAlpha);

      canvas.drawLine(
        Offset(drop.x, drop.y),
        Offset(drop.x - slantOffset, drop.y + drop.length),
        rainPaint,
      );
    }
  }
}
