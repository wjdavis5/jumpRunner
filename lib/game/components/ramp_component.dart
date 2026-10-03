import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'courier_player.dart';

/// Angled delivery & construction ramp that catapults the runner upward
/// into the elevated aerial scaffolding route.
class RampComponent extends PositionComponent {
  RampComponent({
    required Vector2 position,
    Vector2? size,
    this.launchImpulse = 520.0,
  }) : super(
          position: position,
          size: size ?? Vector2(74.0, 36.0),
        );

  /// Vertical launch velocity applied to the player upon contact.
  final double launchImpulse;

  /// Whether this ramp has already triggered its launch impulse.
  bool hasLaunched = false;

  /// Whether this ramp has scrolled offscreen and should be recycled.
  bool get shouldRecycle => position.x + size.x < -120.0;

  static final Paint _rampBasePaint = Paint()..color = const Color(0xFF34495E);
  static final Paint _hazardStripeYellow = Paint()..color = const Color(0xFFF1C40F);
  static final Paint _steelEdgePaint = Paint()
    ..color = const Color(0xFFECF0F1)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _arrowPaint = Paint()
    ..color = const Color(0xFFFF9F43)
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  double _glowTimer = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _glowTimer += dt * 5.0;
  }

  /// Determines whether the courier player has stepped on or collided with this ramp.
  bool checkCollisionWith(CourierPlayer player) {
    if (hasLaunched) return false;
    final footX = player.position.x + (player.size.x / 2);
    final footY = player.simulator.currentY;

    // Contact occurs when courier's footprint steps onto the ramp's incline
    return (footX >= position.x && footX <= position.x + size.x + 8.0) &&
           (footY >= position.y && footY <= position.y + size.y + 12.0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Wedge ramp path: starts low on the left (0, size.y) and rises to high lip on the right (size.x, 0)
    final rampPath = Path()
      ..moveTo(0, size.y)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, size.y)
      ..close();

    // 1. Base dark foundation
    canvas.drawPath(rampPath, _rampBasePaint);

    // 2. Diagonal hazard stripes clipped inside the ramp incline
    canvas.save();
    canvas.clipPath(rampPath);

    const stripeWidth = 14.0;
    for (double sx = -size.y; sx < size.x + size.y; sx += stripeWidth * 2) {
      final stripePath = Path()
        ..moveTo(sx, size.y)
        ..lineTo(sx + stripeWidth, 0)
        ..lineTo(sx + stripeWidth * 2, 0)
        ..lineTo(sx + stripeWidth, size.y)
        ..close();
      canvas.drawPath(stripePath, _hazardStripeYellow);
    }
    canvas.restore();

    // 3. Steel lip highlight on the upper edge
    canvas.drawLine(Offset(0, size.y), Offset(size.x, 0), _steelEdgePaint);

    // 4. Directional Launch Chevron Indicator (>>)
    final glowAlpha = ((1.0 + (0.4 * (_glowTimer % 2.0 - 1.0).abs())) * 128).clamp(80, 255).toInt();
    _arrowPaint.color = Color.fromARGB(glowAlpha, 255, 159, 67);

    final midX = size.x * 0.45;
    final midY = size.y * 0.55;
    final chevron = Path()
      ..moveTo(midX - 8, midY + 4)
      ..lineTo(midX + 2, midY - 6)
      ..lineTo(midX + 12, midY - 6);
    canvas.drawPath(chevron, _arrowPaint);
  }
}
