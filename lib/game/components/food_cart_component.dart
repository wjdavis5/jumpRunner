import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street food vendor cart featuring chrome steam trays, condiment squeeze bottles,
/// wheeled chassis, and a striped canvas sun umbrella that functions as an elastic bounce cushion.
///
/// Landing on the umbrella canopy launches the courier upward with an elastic spring impulse
/// (+400 px/s) while triggering chili & cumin spice cloud particle puffs.
class FoodCartComponent extends PositionComponent {
  FoodCartComponent({
    required Vector2 position,
    double width = 88.0,
    double height = 78.0,
    this.groundY = 460.0,
    this.bounceImpulse = 400.0,
    this.onBounce,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final double bounceImpulse;
  final VoidCallback? onBounce;

  bool hasBounced = false;
  double _bounceAnimTimer = 0.0;
  double _steamTimer = 0.0;

  /// World coordinate at the apex of the umbrella canopy for particle burst alignment.
  Vector2 get umbrellaApexWorld => Vector2(position.x + (size.x / 2), position.y + 4.0);

  /// Top surface baseline Y of the umbrella cushion in world coordinates.
  double get umbrellaTopWorldY => position.y + 8.0;

  /// Whether the food cart has scrolled past active view and should be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    _steamTimer += dt * 4.0;
    if (_bounceAnimTimer > 0) {
      _bounceAnimTimer = math.max(0.0, _bounceAnimTimer - dt);
    }
  }

  /// Evaluates whether the downward-descending courier impacts the umbrella cushion canopy.
  bool checkBounce(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    // If the courier is grounded or traveling rapidly upward, do not trigger a bounce
    if (simulator.isGrounded || simulator.verticalVelocity > 100.0) {
      // Reset hasBounced when courier moves clear of the cushion
      if (hasBounced && (simulator.currentY < umbrellaTopWorldY - 30.0 || simulator.currentY > umbrellaTopWorldY + 30.0)) {
        hasBounced = false;
      }
      return false;
    }

    if (hasBounced) return false;

    final footX = playerPos.x + (playerSize.x / 2);
    final footY = simulator.currentY;

    final canopyCenterX = position.x + (size.x / 2);
    const canopyHalfWidth = 38.0; // 76px total umbrella canopy width

    final inHorizontalSpan = footX >= canopyCenterX - canopyHalfWidth &&
        footX <= canopyCenterX + canopyHalfWidth;
    final inVerticalWindow = footY >= umbrellaTopWorldY - 14.0 &&
        footY <= umbrellaTopWorldY + 22.0;

    if (inHorizontalSpan && inVerticalWindow) {
      hasBounced = true;
      _bounceAnimTimer = 0.45;
      simulator.launch(bounceImpulse);
      onBounce?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Lower Street Food Cart Body & Wheels
    _renderCartBody(canvas, w, h);

    // 2. Umbrella Support Pole
    _renderUmbrellaPole(canvas, w, h);

    // 3. Striped Canvas Umbrella Canopy with Spring Bounce Damping
    _renderUmbrellaCanopy(canvas, w, h);
  }

  void _renderCartBody(Canvas canvas, double w, double h) {
    const cartX = 18.0;
    const cartWidth = 54.0;
    const cartHeight = 32.0;
    final cartY = h - cartHeight - 8.0;

    // Cart Metallic Chassis Box
    final chassisRect = Rect.fromLTWH(cartX, cartY, cartWidth, cartHeight);
    final chassisPaint = Paint()..color = const Color(0xFFBDC3C7);
    canvas.drawRRect(RRect.fromRectAndRadius(chassisRect, const Radius.circular(3.0)), chassisPaint);

    // Top Chrome Counter Rim
    final counterPaint = Paint()..color = const Color(0xFF95A5A6);
    canvas.drawRect(Rect.fromLTWH(cartX - 2.0, cartY, cartWidth + 4.0, 3.0), counterPaint);

    // Decorative Red & Yellow Retro Vendor Stripe
    final stripePaintRed = Paint()..color = const Color(0xFFE74C3C);
    canvas.drawRect(Rect.fromLTWH(cartX, cartY + 12.0, cartWidth, 6.0), stripePaintRed);
    final stripePaintYellow = Paint()..color = const Color(0xFFF1C40F);
    canvas.drawRect(Rect.fromLTWH(cartX, cartY + 18.0, cartWidth, 3.0), stripePaintYellow);

    // Condiment Squeeze Bottles on side ledge (Red ketchup & yellow mustard)
    final ketchupPaint = Paint()..color = const Color(0xFFE74C3C);
    canvas.drawRect(Rect.fromLTWH(cartX + 4.0, cartY - 7.0, 4.0, 7.0), ketchupPaint);
    canvas.drawLine(Offset(cartX + 6.0, cartY - 7.0), Offset(cartX + 6.0, cartY - 10.0), ketchupPaint..strokeWidth = 1.5);

    final mustardPaint = Paint()..color = const Color(0xFFF1C40F);
    canvas.drawRect(Rect.fromLTWH(cartX + 10.0, cartY - 6.0, 4.0, 6.0), mustardPaint);
    canvas.drawLine(Offset(cartX + 12.0, cartY - 6.0), Offset(cartX + 12.0, cartY - 9.0), mustardPaint..strokeWidth = 1.5);

    // Steamer Food Tray Pans with Warm Rising Steam Curls
    final panPaint = Paint()..color = const Color(0xFF7F8C8D);
    canvas.drawRect(Rect.fromLTWH(cartX + 22.0, cartY - 4.0, 26.0, 4.0), panPaint);

    final steamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final steamOffset1 = math.sin(_steamTimer) * 2.0;
    final steamOffset2 = math.cos(_steamTimer * 1.2) * 2.0;
    canvas.drawLine(Offset(cartX + 28.0, cartY - 5.0), Offset(cartX + 28.0 + steamOffset1, cartY - 12.0), steamPaint);
    canvas.drawLine(Offset(cartX + 40.0, cartY - 5.0), Offset(cartX + 40.0 + steamOffset2, cartY - 13.0), steamPaint);

    // Chrome Steering Push Handle
    final handlePaint = Paint()
      ..color = const Color(0xFF7F8C8D)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cartX, cartY + 6.0), Offset(cartX - 7.0, cartY + 4.0), handlePaint);
    canvas.drawLine(Offset(cartX - 7.0, cartY + 4.0), Offset(cartX - 7.0, cartY + 14.0), handlePaint);

    // Large Front & Rear Wheels with Spoked Hubs
    _renderWheel(canvas, cartX + 11.0, h - 7.0, 7.0);
    _renderWheel(canvas, cartX + cartWidth - 11.0, h - 7.0, 7.0);
  }

  void _renderWheel(Canvas canvas, double cx, double cy, double radius) {
    // Tire
    final tirePaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), radius, tirePaint);

    // Hub
    final hubPaint = Paint()..color = const Color(0xFFBDC3C7);
    canvas.drawCircle(Offset(cx, cy), 2.2, hubPaint);

    // Spokes
    final spokePaint = Paint()
      ..color = const Color(0xFF95A5A6)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - radius + 1.0, cy), Offset(cx + radius - 1.0, cy), spokePaint);
    canvas.drawLine(Offset(cx, cy - radius + 1.0), Offset(cx, cy + radius - 1.0), spokePaint);
  }

  void _renderUmbrellaPole(Canvas canvas, double w, double h) {
    final poleX = w / 2;
    final polePaint = Paint()
      ..color = const Color(0xFF7F8C8D)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(poleX, 8.0), Offset(poleX, h - 40.0), polePaint);
  }

  void _renderUmbrellaCanopy(Canvas canvas, double w, double h) {
    final centerX = w / 2;
    const canopyWidth = 76.0;
    const canopyHeight = 24.0;
    const baseY = 28.0;

    // Calculate spring compression scale during bounce rebound
    double scaleY = 1.0;
    if (_bounceAnimTimer > 0) {
      final progress = 1.0 - (_bounceAnimTimer / 0.45);
      // Damped sine wave compression and snapback
      final compression = math.sin(progress * math.pi * 3.0) * math.exp(-progress * 3.5);
      scaleY = (1.0 - compression * 0.35).clamp(0.65, 1.35);
    }

    canvas.save();
    // Anchor scaling at the umbrella base
    canvas.translate(centerX, baseY);
    canvas.scale(1.0, scaleY);
    canvas.translate(-centerX, -baseY);

    // 1. Curved Canopy Dome Clipped Path
    final canopyPath = Path()
      ..moveTo(centerX - (canopyWidth / 2), baseY)
      ..quadraticBezierTo(centerX, baseY - canopyHeight * 1.5, centerX + (canopyWidth / 2), baseY)
      ..close();

    // 2. Multi-Color Alternating Canopy Stripes (Vibrant Red & Cream White)
    final stripeColors = [
      const Color(0xFFE74C3C),
      const Color(0xFFFDFEFE),
      const Color(0xFFE74C3C),
      const Color(0xFFFDFEFE),
      const Color(0xFFE74C3C),
      const Color(0xFFFDFEFE),
      const Color(0xFFE74C3C),
    ];

    canvas.save();
    canvas.clipPath(canopyPath);

    final stripeWidth = canopyWidth / stripeColors.length;
    for (var i = 0; i < stripeColors.length; i++) {
      final stripeX = centerX - (canopyWidth / 2) + (i * stripeWidth);
      final paint = Paint()..color = stripeColors[i];
      canvas.drawRect(Rect.fromLTWH(stripeX, baseY - canopyHeight * 1.6, stripeWidth + 0.5, canopyHeight * 1.8), paint);
    }

    canvas.restore();

    // 3. Scalloped Fringe Valance along bottom edge
    final valancePaint = Paint()
      ..color = const Color(0xFFE74C3C)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < stripeColors.length; i++) {
      final valanceX = centerX - (canopyWidth / 2) + (i * stripeWidth) + (stripeWidth / 2);
      canvas.drawCircle(Offset(valanceX, baseY), stripeWidth / 2, valancePaint);
    }

    // 4. Gold Top Finial Cap
    final finialPaint = Paint()..color = const Color(0xFFF1C40F);
    canvas.drawCircle(Offset(centerX, baseY - canopyHeight - 2.0), 3.0, finialPaint);

    canvas.restore();
  }
}
