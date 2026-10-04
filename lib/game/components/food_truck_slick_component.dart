import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Gourmet street food truck with retro awning, sizzling exhaust flue,
/// and an extended golden-amber culinary oil/grease slick on the asphalt
/// that initiates a high-speed frictionless drift slide maneuver.
class FoodTruckSlickComponent extends PositionComponent {
  FoodTruckSlickComponent({
    required Vector2 position,
    double width = 120.0,
    double height = 88.0,
    this.groundY = 460.0,
    this.onDrift,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onDrift;

  bool hasDrifted = false;
  double _sizzleTimer = 0.0;
  double _steamPhase = 0.0;

  /// Top surface baseline Y of the grease slick on the asphalt in world coordinates.
  double get slickSurfaceWorldY => groundY - 8.0;

  /// Center world coordinate of the grease slick puddle for particle bursts.
  Vector2 get slickCenterWorldPosition => Vector2(position.x + 76.0, groundY - 4.0);

  /// Hitbox rectangle of the slick puddle on the road surface.
  Rect get slickWorldRect => Rect.fromLTWH(
        position.x + 38.0,
        groundY - 14.0,
        78.0,
        14.0,
      );

  /// Whether the food truck has scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _vanBodyPaint = Paint()
    ..color = const Color(0xFFC0392B) // Gourmet Food Truck Crimson
    ..style = PaintingStyle.fill;

  static final Paint _vanTrimPaint = Paint()
    ..color = const Color(0xFF962D22)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _windowPaint = Paint()
    ..color = const Color(0xFFF39C12) // Warm interior service glow
    ..style = PaintingStyle.fill;

  static final Paint _counterPaint = Paint()
    ..color = const Color(0xFFBDC3C7) // Brushed aluminum service counter
    ..style = PaintingStyle.fill;

  static final Paint _wheelPaint = Paint()
    ..color = const Color(0xFF2C3E50)
    ..style = PaintingStyle.fill;

  static final Paint _hubcapPaint = Paint()
    ..color = const Color(0xFF7F8C8D)
    ..style = PaintingStyle.fill;

  static final Paint _exhaustPaint = Paint()
    ..color = const Color(0xFF7F8C8D)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  static final Paint _awningRedPaint = Paint()..color = const Color(0xFFE74C3C);
  static final Paint _awningWhitePaint = Paint()..color = const Color(0xFFECF0F1);

  static final Paint _slickAsphaltRimPaint = Paint()
    ..color = const Color(0xFF1E272C) // Dark asphalt perimeter
    ..style = PaintingStyle.fill;

  static final Paint _slickOilPaint = Paint()
    ..color = const Color(0xFFFFA000).withValues(alpha: 0.65) // Golden culinary grease
    ..style = PaintingStyle.fill;

  static final Paint _slickSheenPaint = Paint()
    ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.4) // Iridescent sheen
    ..style = PaintingStyle.fill;

  static final Paint _bubblePaint = Paint()
    ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.85) // Sizzle bubble
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _steamPhase += dt * 3.2;
    if (_sizzleTimer > 0) {
      _sizzleTimer = math.max(0.0, _sizzleTimer - dt);
    }
  }

  /// Evaluates whether the grounded courier runs or slides into the culinary grease slick.
  bool checkDrift(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasDrifted) return false;

    // Must be grounded to drift slide on street grease
    if (!simulator.isGrounded) return false;

    final footX = playerPos.x + (playerSize.x / 2);
    final footY = simulator.currentY;

    final inHorizontalRange = footX >= slickWorldRect.left && footX <= slickWorldRect.right;
    final inVerticalRange = footY >= groundY - 18.0 && footY <= groundY + 8.0;

    if (inHorizontalRange && inVerticalRange) {
      hasDrifted = true;
      _sizzleTimer = 0.55;
      onDrift?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final truckGroundY = groundY - position.y;

    // 1. Extended Golden-Amber Oil/Grease Slick on Asphalt
    const slickLocalX = 38.0;
    const slickWidth = 78.0;
    const slickHeight = 10.0;
    final slickY = truckGroundY - 8.0;

    // Dark asphalt wet edge
    final rimRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(slickLocalX - 4.0, 0, slickWidth + 8.0, slickHeight + 4.0),
      const Radius.circular(5.0),
    );
    canvas.save();
    canvas.translate(0, slickY - 2.0);
    canvas.drawRRect(rimRRect, _slickAsphaltRimPaint);

    // Golden oil body
    final oilRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(slickLocalX, 2.0, slickWidth, slickHeight),
      const Radius.circular(4.0),
    );
    canvas.drawRRect(oilRRect, _slickOilPaint);

    // Iridescent slick sheen highlight
    final sheenRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(slickLocalX + 8.0, 3.5, slickWidth - 16.0, 4.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(sheenRRect, _slickSheenPaint);

    // Sizzling grease bubbles
    final bubbleOffset1 = (math.sin(_steamPhase) * 6.0) + 16.0;
    final bubbleOffset2 = (math.cos(_steamPhase * 1.4) * 8.0) + 45.0;
    canvas.drawCircle(Offset(slickLocalX + bubbleOffset1, 6.0), 1.5, _bubblePaint);
    canvas.drawCircle(Offset(slickLocalX + bubbleOffset2, 5.0), 1.8, _bubblePaint);
    canvas.restore();

    // 2. Food Truck Body & Cab (Left side)
    const truckWidth = 52.0;
    const truckHeight = 46.0;
    final truckTopY = truckGroundY - truckHeight - 6.0;

    // Van chassis
    final vanRect = Rect.fromLTWH(0.0, truckTopY, truckWidth, truckHeight);
    final vanRRect = RRect.fromRectAndRadius(vanRect, const Radius.circular(6.0));
    canvas.drawRRect(vanRRect, _vanBodyPaint);
    canvas.drawRRect(vanRRect, _vanTrimPaint);

    // Service window & glowing interior
    const windowRect = Rect.fromLTWH(8.0, 0.0, 26.0, 16.0);
    canvas.save();
    canvas.translate(0, truckTopY + 10.0);
    canvas.drawRect(windowRect, _windowPaint);

    // Brushed aluminum service counter
    canvas.drawRect(const Rect.fromLTWH(6.0, 16.0, 30.0, 3.0), _counterPaint);
    canvas.restore();

    // Striped Awning over serving counter
    const awningY = 0.0;
    canvas.save();
    canvas.translate(4.0, truckTopY + 6.0);
    for (var ax = 0.0; ax < 34.0; ax += 8.0) {
      final isRed = ((ax ~/ 8) % 2) == 0;
      final paint = isRed ? _awningRedPaint : _awningWhitePaint;
      canvas.drawRect(Rect.fromLTWH(ax, awningY, 8.0, 5.0), paint);
    }
    canvas.restore();

    // Roof exhaust flue pipe
    canvas.drawLine(
      Offset(12.0, truckTopY),
      Offset(12.0, truckTopY - 12.0),
      _exhaustPaint,
    );
    // Exhaust pipe cap
    canvas.drawLine(
      Offset(8.0, truckTopY - 12.0),
      Offset(16.0, truckTopY - 12.0),
      _exhaustPaint,
    );

    // Animated steam vapor puff from exhaust flue
    final steamPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.45 + math.sin(_steamPhase) * 0.15)
      ..style = PaintingStyle.fill;
    final steamY = (truckTopY - 18.0) - (math.sin(_steamPhase).abs() * 4.0);
    canvas.drawCircle(Offset(12.0, steamY), 3.5, steamPaint);

    // 3. Truck Wheels & Hubcaps
    final wheelY = truckGroundY - 6.0;
    // Front wheel
    canvas.drawCircle(Offset(12.0, wheelY), 7.0, _wheelPaint);
    canvas.drawCircle(Offset(12.0, wheelY), 3.0, _hubcapPaint);
    // Rear wheel
    canvas.drawCircle(Offset(40.0, wheelY), 7.0, _wheelPaint);
    canvas.drawCircle(Offset(40.0, wheelY), 3.0, _hubcapPaint);
  }
}
