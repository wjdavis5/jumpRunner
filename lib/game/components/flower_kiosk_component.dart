import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street-level sidewalk flower vendor kiosk featuring striped canvas awning,
/// rustic cedar cart chassis, tiered galvanized buckets, and blooming flower arrangements.
///
/// Hurdling or vaulting across the floral kiosk kicks up swirling petal bursts
/// and activates a 4-second Floral Aroma +1.5x stunt combo multiplier.
class FlowerKioskComponent extends PositionComponent {
  FlowerKioskComponent({
    required Vector2 position,
    double width = 68.0,
    double height = 58.0,
    this.groundY = 460.0,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onVault;

  bool hasVaulted = false;
  double _wobbleTimer = 0.0;

  /// Top surface baseline Y of the kiosk awning/rim in world coordinates.
  double get kioskRimWorldY => groundY - size.y + 12.0;

  /// World coordinate at the apex of the floral canopy for particle burst alignment.
  Vector2 get canopyApexWorld => Vector2(position.x + (size.x / 2), position.y + 6.0);

  /// Center point of the flower kiosk in world coordinates.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the flower kiosk has scrolled past active view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _awningDarkGreenPaint = Paint()
    ..color = const Color(0xFF1B5E20)
    ..style = PaintingStyle.fill;

  static final Paint _awningWhitePaint = Paint()
    ..color = const Color(0xFFF5F5F5)
    ..style = PaintingStyle.fill;

  static final Paint _awningScallopPaint = Paint()
    ..color = const Color(0xFF2E7D32)
    ..style = PaintingStyle.fill;

  static final Paint _frameWoodPaint = Paint()
    ..color = const Color(0xFF6D4C41)
    ..style = PaintingStyle.fill;

  static final Paint _poleMetalPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _bucketPaint = Paint()
    ..color = const Color(0xFF90A4AE)
    ..style = PaintingStyle.fill;

  static final Paint _bucketHighlightPaint = Paint()
    ..color = const Color(0xFFCFD8DC)
    ..style = PaintingStyle.fill;

  static final Paint _stemPaint = Paint()
    ..color = const Color(0xFF43A047)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _tulipRedPaint = Paint()
    ..color = const Color(0xFFE91E63)
    ..style = PaintingStyle.fill;

  static final Paint _rosePinkPaint = Paint()
    ..color = const Color(0xFFFF4081)
    ..style = PaintingStyle.fill;

  static final Paint _sunflowerGoldPaint = Paint()
    ..color = const Color(0xFFFFD54F)
    ..style = PaintingStyle.fill;

  static final Paint _sunflowerCenterPaint = Paint()
    ..color = const Color(0xFF4E342E)
    ..style = PaintingStyle.fill;

  static final Paint _violetPaint = Paint()
    ..color = const Color(0xFFAB47BC)
    ..style = PaintingStyle.fill;

  static final Paint _wheelPaint = Paint()
    ..color = const Color(0xFF2E1C0C)
    ..style = PaintingStyle.fill;

  static final Paint _wheelHubPaint = Paint()
    ..color = const Color(0xFFB0BEC5)
    ..style = PaintingStyle.fill;

  static final Paint _chalkboardPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _chalkTextPaint = Paint()
    ..color = const Color(0xFFECEFF1)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  @override
  void update(double dt) {
    super.update(dt);
    if (_wobbleTimer > 0) {
      _wobbleTimer = math.max(0.0, _wobbleTimer - dt);
    }
  }

  /// Evaluates whether an airborne courier vaults cleanly across the floral kiosk.
  bool checkVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted) return false;

    // Must be actively airborne to hurdle or vault over the flower vendor kiosk
    if (simulator.isGrounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final courierBottom = simulator.currentY;

    final kioskLeft = position.x;
    final kioskRight = position.x + size.x;
    final kioskTop = groundY - size.y;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= kioskLeft + 8.0) && (courierLeft <= kioskRight - 8.0);

    // Vertical hurdle window: courier foot must be in proximity of the top awning or floral rim
    final verticalProximity = (courierBottom >= kioskTop - 14.0) && (courierBottom <= kioskTop + 36.0);

    if (horizontalOverlap && verticalProximity) {
      hasVaulted = true;
      _wobbleTimer = 0.5;
      onVault?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // Apply wobble sway if recently vaulted
    canvas.save();
    if (_wobbleTimer > 0) {
      final wobbleAngle = math.sin(_wobbleTimer * 24.0) * (_wobbleTimer / 0.5) * 0.06;
      canvas.translate(w / 2, h);
      canvas.rotate(wobbleAngle);
      canvas.translate(-w / 2, -h);
    }

    // 1. Wooden florist cart base chassis & wheels
    _renderCartChassis(canvas, w, h);

    // 2. Tiered flower buckets & wooden crates with lush blossoms
    _renderFloralArrangements(canvas, w, h);

    // 3. Slender metal canopy upright support poles
    _renderCanopyPoles(canvas, w, h);

    // 4. Striped green-and-white canvas awning with scalloped fringe
    _renderAwning(canvas, w, h);

    // 5. Sidewalk promotional chalkboard sign
    _renderChalkboardSign(canvas, w, h);

    canvas.restore();
  }

  void _renderCartChassis(Canvas canvas, double w, double h) {
    // Wheels at bottom left and bottom right
    const wheelRadius = 7.0;
    const wheelY = 51.0;
    canvas.drawCircle(const Offset(14.0, wheelY), wheelRadius, _wheelPaint);
    canvas.drawCircle(const Offset(14.0, wheelY), 2.2, _wheelHubPaint);
    canvas.drawCircle(Offset(w - 14.0, wheelY), wheelRadius, _wheelPaint);
    canvas.drawCircle(Offset(w - 14.0, wheelY), 2.2, _wheelHubPaint);

    // Horizontal axle strut
    canvas.drawLine(
      const Offset(14.0, wheelY),
      Offset(w - 14.0, wheelY),
      _poleMetalPaint,
    );

    // Cedar cart body bed
    final cartRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8.0, 32.0, w - 16.0, 16.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(cartRect, _frameWoodPaint);

    // Rustic wooden crate planks
    final plankPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(8.0, 37.0), Offset(w - 8.0, 37.0), plankPaint);
    canvas.drawLine(const Offset(8.0, 42.0), Offset(w - 8.0, 42.0), plankPaint);
  }

  void _renderFloralArrangements(Canvas canvas, double w, double h) {
    // Three tiered galvanized metal buckets with bouquets
    final bucketXs = [16.0, 34.0, 52.0];

    for (var i = 0; i < bucketXs.length; i++) {
      final bx = bucketXs[i];
      // Draw trapezoidal galvanized bucket
      final bucketPath = Path()
        ..moveTo(bx - 6.0, 24.0)
        ..lineTo(bx + 6.0, 24.0)
        ..lineTo(bx + 4.5, 34.0)
        ..lineTo(bx - 4.5, 34.0)
        ..close();
      canvas.drawPath(bucketPath, _bucketPaint);

      // Galvanized metal rim highlight
      canvas.drawLine(
        Offset(bx - 6.0, 24.0),
        Offset(bx + 6.0, 24.0),
        _bucketHighlightPaint..strokeWidth = 1.2,
      );

      // Stems rising from bucket
      canvas.drawLine(Offset(bx - 3.0, 24.0), Offset(bx - 4.0, 18.0), _stemPaint);
      canvas.drawLine(Offset(bx, 24.0), Offset(bx, 15.0), _stemPaint);
      canvas.drawLine(Offset(bx + 3.0, 24.0), Offset(bx + 4.0, 17.0), _stemPaint);

      // Specific flower variety per bucket
      if (i == 0) {
        // Red Tulips & pink rosebuds
        canvas.drawCircle(Offset(bx - 4.0, 17.0), 3.2, _tulipRedPaint);
        canvas.drawCircle(Offset(bx, 14.0), 3.5, _rosePinkPaint);
        canvas.drawCircle(Offset(bx + 4.0, 16.0), 3.0, _tulipRedPaint);
      } else if (i == 1) {
        // Golden Sunflowers
        canvas.drawCircle(Offset(bx - 3.5, 17.0), 3.4, _sunflowerGoldPaint);
        canvas.drawCircle(Offset(bx - 3.5, 17.0), 1.5, _sunflowerCenterPaint);

        canvas.drawCircle(Offset(bx + 1.0, 14.0), 4.2, _sunflowerGoldPaint);
        canvas.drawCircle(Offset(bx + 1.0, 14.0), 1.8, _sunflowerCenterPaint);

        canvas.drawCircle(Offset(bx + 4.5, 17.5), 3.2, _sunflowerGoldPaint);
        canvas.drawCircle(Offset(bx + 4.5, 17.5), 1.4, _sunflowerCenterPaint);
      } else {
        // Violet & blush floral mix
        canvas.drawCircle(Offset(bx - 4.0, 17.0), 3.0, _violetPaint);
        canvas.drawCircle(Offset(bx, 14.5), 3.4, _rosePinkPaint);
        canvas.drawCircle(Offset(bx + 4.0, 16.5), 3.2, _violetPaint);
      }
    }
  }

  void _renderCanopyPoles(Canvas canvas, double w, double h) {
    // Metal support posts from cart to awning
    canvas.drawLine(const Offset(10.0, 10.0), const Offset(10.0, 34.0), _poleMetalPaint);
    canvas.drawLine(Offset(w - 10.0, 10.0), Offset(w - 10.0, 34.0), _poleMetalPaint);
  }

  void _renderAwning(Canvas canvas, double w, double h) {
    // Striped slanted roof awning (y: 2.0 to 11.0)
    const stripeCount = 7;
    final stripeW = w / stripeCount;

    for (var s = 0; s < stripeCount; s++) {
      final paint = (s % 2 == 0) ? _awningDarkGreenPaint : _awningWhitePaint;
      final x1 = s * stripeW;
      final x2 = (s + 1) * stripeW;

      final stripePath = Path()
        ..moveTo(x1, 2.0)
        ..lineTo(x2, 2.0)
        ..lineTo(x2, 10.0)
        ..lineTo(x1, 10.0)
        ..close();
      canvas.drawPath(stripePath, paint);
    }

    // Scalloped decorative valance fringe
    for (var s = 0; s < stripeCount; s++) {
      final centerX = (s + 0.5) * stripeW;
      final scallopPath = Path()
        ..moveTo(s * stripeW, 10.0)
        ..quadraticBezierTo(centerX, 13.5, (s + 1) * stripeW, 10.0)
        ..close();
      canvas.drawPath(scallopPath, _awningScallopPaint);
    }

    // Top ridge cap line
    final ridgePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(0.0, 2.0), Offset(w, 2.0), ridgePaint);
  }

  void _renderChalkboardSign(Canvas canvas, double w, double h) {
    // Small chalkboard sign hanging on the front of the cart
    const signW = 16.0;
    const signH = 10.0;
    final signX = (w - signW) / 2;
    const signY = 35.0;

    final signRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(signX, signY, signW, signH),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(signRect, _chalkboardPaint);

    // Chalk line markings
    canvas.drawLine(
      Offset(signX + 3.0, signY + 3.5),
      Offset(signX + signW - 3.0, signY + 3.5),
      _chalkTextPaint,
    );
    canvas.drawLine(
      Offset(signX + 4.0, signY + 6.5),
      Offset(signX + signW - 4.0, signY + 6.5),
      _chalkTextPaint,
    );
  }
}
