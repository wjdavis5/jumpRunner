import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street corner open fire hydrant fixture blasting a high-pressure foaming water spray arc
/// across the sidewalk and asphalt, featuring an open brass side nozzle, shimmering rainbow mist
/// prism reflections, and ground puddle ripples.
///
/// Hurdling or hydroplane-dashing through the spray stream triggers a refreshing water plume burst
/// and activates the Hydroplane Glide buff (+25% glide duration and reduced gravity float).
class FireHydrantComponent extends PositionComponent {
  FireHydrantComponent({
    required Vector2 position,
    double width = 86.0,
    double height = 54.0,
    this.groundY = 460.0,
    this.onSprayTraverse,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onSprayTraverse;

  bool hasTriggered = false;
  double _sprayTimer = 0.0;

  /// Top surface baseline Y of the hydrant bonnet in world coordinates.
  double get hydrantApexWorldY => groundY - 38.0;

  /// World space coordinate at the water spray arc apex for particle bursts.
  Vector2 get sprayApexWorld => Vector2(position.x + 46.0, groundY - 26.0);

  /// Center point of the fire hydrant fixture in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _hydrantRedPaint = Paint()
    ..color = const Color(0xFFE53935) // High-visibility city hydrant red
    ..style = PaintingStyle.fill;

  static final Paint _hydrantDarkPaint = Paint()
    ..color = const Color(0xFFB71C1C) // Shadowed cast-iron base flange
    ..style = PaintingStyle.fill;

  static final Paint _metalCapPaint = Paint()
    ..color = const Color(0xFFCFD8DC) // Chrome silver bonnet cap & nut
    ..style = PaintingStyle.fill;

  static final Paint _brassNozzlePaint = Paint()
    ..color = const Color(0xFFFFD54F) // Unbolted brass side nozzle
    ..style = PaintingStyle.fill;

  static final Paint _waterStreamPaint = Paint()
    ..color = const Color(0x9900E5FF) // Translucent high-pressure electric cyan
    ..style = PaintingStyle.fill;

  static final Paint _waterCorePaint = Paint()
    ..color = const Color(0xCC80D8FF) // Lighter pressurized water core
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round;

  static final Paint _foamCrestPaint = Paint()
    ..color = const Color(0xFFFFFFFF) // White foaming froth crest
    ..style = PaintingStyle.fill;

  static final Paint _puddlePaint = Paint()
    ..color = const Color(0x7700B0FF) // Ground puddle sheen
    ..style = PaintingStyle.fill;

  static final Paint _rainbowRed = Paint()
    ..color = const Color(0x44FF1744)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _rainbowGold = Paint()
    ..color = const Color(0x44FFEA00)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _rainbowCyan = Paint()
    ..color = const Color(0x4400E5FF)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _rainbowViolet = Paint()
    ..color = const Color(0x44D500F9)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  @override
  void update(double dt) {
    super.update(dt);
    _sprayTimer += dt;
  }

  /// Evaluates whether a courier vaults over or hydroplanes through the water spray arc.
  bool checkInteraction(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasTriggered) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from above hydrant apex down to ground baseline
    final windowTop = groundY - 56.0;
    final windowBottom = groundY + 4.0;
    final inInteractionWindow = (footY >= windowTop) && (footY <= windowBottom);

    if (inInteractionWindow) {
      hasTriggered = true;
      if (!simulator.isGrounded) {
        simulator.launch(200.0); // Refreshing water-loft hop
      }
      onSprayTraverse?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Street Puddle Ripple on Asphalt
    _renderGroundPuddle(canvas, w, h);

    // 2. High-Pressure Parabolic Water Spray Arc & Rainbow Prism
    _renderWaterSprayArc(canvas, w, h);

    // 3. Cast-Iron City Fire Hydrant Body
    _renderHydrantBody(canvas, w, h);
  }

  void _renderGroundPuddle(Canvas canvas, double w, double h) {
    final ripple = math.sin(_sprayTimer * 6.0) * 1.5;

    // Ground puddle sheen
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.64, h - 2.0), width: 44.0 + ripple, height: 6.0),
      _puddlePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.68, h - 2.0), width: 28.0 - ripple, height: 3.8),
      _foamCrestPaint..color = const Color(0x66FFFFFF),
    );
    _foamCrestPaint.color = const Color(0xFFFFFFFF);
  }

  void _renderHydrantBody(Canvas canvas, double w, double h) {
    const hydLeft = 4.0;
    const hydW = 20.0;
    const hydH = 36.0;
    final hydTop = h - hydH;

    // Base flange
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(hydLeft - 2.0, h - 6.0, hydW + 4.0, 6.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(baseRect, _hydrantDarkPaint);

    // Main barrel column
    final barrelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(hydLeft, hydTop + 8.0, hydW, hydH - 12.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(barrelRect, _hydrantRedPaint);

    // Rounded bonnet dome
    final bonnetPath = Path()
      ..moveTo(hydLeft - 1.0, hydTop + 8.0)
      ..quadraticBezierTo(hydLeft + (hydW / 2), hydTop, hydLeft + hydW + 1.0, hydTop + 8.0)
      ..close();
    canvas.drawPath(bonnetPath, _hydrantRedPaint);

    // Top pentagonal operating nut
    canvas.drawRect(
      Rect.fromLTWH(hydLeft + (hydW / 2) - 2.5, hydTop - 2.5, 5.0, 3.5),
      _metalCapPaint,
    );

    // Left cap nozzle (closed)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hydLeft - 3.5, hydTop + 14.0, 4.0, 6.5),
        const Radius.circular(1.0),
      ),
      _metalCapPaint,
    );

    // Right nozzle (open & gushing)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hydLeft + hydW - 1.0, hydTop + 13.0, 5.0, 8.0),
        const Radius.circular(1.0),
      ),
      _brassNozzlePaint,
    );
    // Dark open nozzle orifice
    canvas.drawOval(
      Rect.fromLTWH(hydLeft + hydW + 2.5, hydTop + 14.0, 2.0, 6.0),
      _hydrantDarkPaint,
    );
  }

  void _renderWaterSprayArc(Canvas canvas, double w, double h) {
    const startX = 26.0;
    final startY = h - 18.0;
    final endX = w - 4.0;
    final endY = h - 2.0;

    final pulse = math.sin(_sprayTimer * 12.0) * 2.0;
    final wave1 = math.sin(_sprayTimer * 16.0) * 1.5;

    // Parabolic water spray path
    final sprayPath = Path()
      ..moveTo(startX, startY)
      ..quadraticBezierTo(startX + 22.0, startY - 20.0 + pulse, endX, endY)
      ..lineTo(endX - 12.0, endY)
      ..quadraticBezierTo(startX + 18.0, startY - 12.0 + pulse, startX, startY + 4.0)
      ..close();

    canvas.drawPath(sprayPath, _waterStreamPaint);

    // Pressurized water core stream line
    final corePath = Path()
      ..moveTo(startX + 2.0, startY)
      ..quadraticBezierTo(startX + 22.0, startY - 16.0 + wave1, endX - 6.0, endY - 1.0);
    canvas.drawPath(corePath, _waterCorePaint);

    // Shimmering rainbow mist refraction lines
    final rainbowPath = Path()
      ..moveTo(startX + 6.0, startY - 2.0)
      ..quadraticBezierTo(startX + 24.0, startY - 22.0 + pulse, endX - 4.0, endY - 6.0);

    canvas.save();
    canvas.translate(0, -2.5);
    canvas.drawPath(rainbowPath, _rainbowRed);
    canvas.translate(0, 1.2);
    canvas.drawPath(rainbowPath, _rainbowGold);
    canvas.translate(0, 1.2);
    canvas.drawPath(rainbowPath, _rainbowCyan);
    canvas.translate(0, 1.2);
    canvas.drawPath(rainbowPath, _rainbowViolet);
    canvas.restore();

    // Foaming froth bubbles along spray arc
    for (var i = 1; i <= 6; i++) {
      final t = i / 7.0;
      final bx = startX + (endX - startX) * t;
      final by = (startY * (1 - t) * (1 - t)) +
          ((startY - 20.0 + pulse) * 2 * (1 - t) * t) +
          (endY * t * t);
      canvas.drawCircle(Offset(bx + (math.sin(i + _sprayTimer * 8.0) * 2.0), by - 1.0), 1.2, _foamCrestPaint);
    }
  }
}
