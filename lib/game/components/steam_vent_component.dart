import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// An urban sidewalk steam grate that releases billowing thermal vapor plumes.
///
/// Imparts a vertical aerodynamic updraft to the courier, launching them upward
/// and enabling long-distance backpack gliding across street hazards.
class SteamVentComponent extends PositionComponent with CollisionCallbacks {
  SteamVentComponent({
    Vector2? position,
    Vector2? size,
    this.groundY = 460.0,
    this.updraftHeight = 220.0,
    this.updraftVelocity = 380.0,
  }) {
    this.size = size ?? Vector2(48.0, 16.0);
    if (position != null) {
      this.position = position;
    }
  }

  /// Ground surface Y baseline.
  final double groundY;

  /// Vertical height of the rising thermal steam plume in pixels.
  final double updraftHeight;

  /// Upward vertical impulse / velocity imparted to the courier (px/s).
  final double updraftVelocity;

  /// Whether the courier has already engaged this vent's initial boost.
  bool hasTriggeredBoost = false;

  /// Animation cycle timer for billowing steam particles.
  double animationTime = 0.0;

  /// Whether the steam vent has moved past the recycling boundary off-screen.
  bool get shouldRecycle => position.x < -200.0;

  @override
  void update(double dt) {
    super.update(dt);
    animationTime += dt;
  }

  /// Determines whether the courier's bounding footprint is currently inside
  /// the active thermal updraft column.
  bool isInUpdraft(Vector2 playerPosition, Vector2 playerSize) {
    final playerCenterX = playerPosition.x + (playerSize.x / 2);
    final playerBottomY = playerPosition.y + playerSize.y;

    final inHorizontal = playerCenterX >= position.x - 10.0 &&
        playerCenterX <= position.x + size.x + 10.0;
    final inVertical = playerBottomY <= position.y + 16.0 &&
        playerBottomY >= position.y - updraftHeight;

    return inHorizontal && inVertical;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _renderUpdraftPlume(canvas);
    _renderCastIronGrate(canvas);
  }

  /// Renders billowing, expanding vapor puffs ascending vertically from the grate.
  void _renderUpdraftPlume(Canvas canvas) {
    const puffCount = 6;
    for (var i = 0; i < puffCount; i++) {
      final t = (animationTime * 0.8 + (i / puffCount)) % 1.0;
      final puffY = -t * updraftHeight;
      final radius = 7.0 + (t * 22.0);
      final driftX = (size.x / 2) + math.sin(animationTime * 3.5 + (i * 1.2)) * (4.0 + t * 12.0);
      final alpha = ((1.0 - t) * 0.42).clamp(0.0, 1.0);

      final plumePaint = Paint()
        ..color = const Color(0xFFE0F7FA).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

      canvas.drawCircle(Offset(driftX, puffY), radius, plumePaint);

      // Inner dense vapor core
      if (t < 0.6) {
        final corePaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawCircle(Offset(driftX, puffY), radius * 0.5, corePaint);
      }
    }
  }

  /// Renders the heavy cast-iron sidewalk manhole grate with bolt studs and vent slots.
  void _renderCastIronGrate(Canvas canvas) {
    final rimRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rimRRect = RRect.fromRectAndRadius(rimRect, const Radius.circular(5.0));

    // 1. Dark cast iron base
    final basePaint = Paint()..color = const Color(0xFF2C3E50);
    canvas.drawRRect(rimRRect, basePaint);

    // 2. Metallic beveled rim outline
    final strokePaint = Paint()
      ..color = const Color(0xFF7F8C8D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rimRRect, strokePaint);

    // 3. Hot subsurface boiler glow inside vents
    final glowPaint = Paint()
      ..color = const Color(0xFFFF7043).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawRect(Rect.fromLTWH(6, 4, size.x - 12, size.y - 8), glowPaint);

    // 4. Slotted ventilation grates
    final slotPaint = Paint()..color = const Color(0xFF1A1A1A);
    const slotCount = 5;
    final slotWidth = (size.x - 16) / slotCount;
    for (var i = 0; i < slotCount; i++) {
      final slotX = 8.0 + (i * slotWidth);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(slotX + 1.0, 3.5, slotWidth - 2.5, size.y - 7.0),
          const Radius.circular(1.0),
        ),
        slotPaint,
      );
    }

    // 5. Corner anchor bolt rivets
    final boltPaint = Paint()..color = const Color(0xFFBDC3C7);
    canvas.drawCircle(const Offset(4, 4), 1.5, boltPaint);
    canvas.drawCircle(Offset(size.x - 4, 4), 1.5, boltPaint);
    canvas.drawCircle(Offset(4, size.y - 4), 1.5, boltPaint);
    canvas.drawCircle(Offset(size.x - 4, size.y - 4), 1.5, boltPaint);
  }
}
