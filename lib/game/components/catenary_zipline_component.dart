import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Aerial high-voltage catenary power line zipline running between rooftops and elevated transit girders.
///
/// Couriers can leap up into the overhead wire, gripping the suspension line with insulated gloves
/// to execute a high-speed aerial zipline slide across wide street canyons and dismount with an
/// upward launch fling (+220 px/s loft) into rooftop landings or grind rails.
class CatenaryZiplineComponent extends PositionComponent {
  CatenaryZiplineComponent({
    required Vector2 position,
    this.spanWidth = 240.0,
    this.cableDrop = 24.0,
    this.sag = 10.0,
    this.groundY = 460.0,
    this.onZiplineDismount,
  }) : super(
          position: position,
          size: Vector2(spanWidth, cableDrop + sag + 36.0),
        );

  final double spanWidth;
  final double cableDrop;
  final double sag;
  final double groundY;
  final VoidCallback? onZiplineDismount;

  bool isCourierAttached = false;
  bool hasDismounted = false;
  double _glowTimer = 0.0;

  /// Start X coordinate in world space.
  double get startX => position.x;

  /// End X coordinate in world space.
  double get endX => position.x + spanWidth;

  /// Start Y coordinate of the lower contact cable in world space.
  double get startY => position.y + 18.0;

  /// End Y coordinate of the lower contact cable in world space.
  double get endY => position.y + 18.0 + cableDrop;

  /// Computes the exact world Y of the contact trolley wire at [worldX].
  double cableYAt(double worldX) {
    if (spanWidth <= 0.0) return startY;
    final t = ((worldX - position.x) / spanWidth).clamp(0.0, 1.0);
    final linearY = startY + t * cableDrop;
    final sagY = 4.0 * sag * t * (1.0 - t);
    return linearY + sagY;
  }

  /// Computes the exact world Y of the upper suspension messenger cable at [worldX].
  double messengerYAt(double worldX) {
    if (spanWidth <= 0.0) return position.y;
    final t = ((worldX - position.x) / spanWidth).clamp(0.0, 1.0);
    final linearY = position.y + t * cableDrop;
    final sagY = 4.0 * (sag + 4.0) * t * (1.0 - t);
    return linearY + sagY;
  }

  /// World space coordinate at the midpoint of the contact cable.
  Vector2 get midpointWorldPosition => Vector2(
        position.x + (spanWidth * 0.5),
        cableYAt(position.x + (spanWidth * 0.5)),
      );

  /// Whether the zipline fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + spanWidth < -180.0;

  // Visual styling paints
  static final Paint _messengerPaint = Paint()
    ..color = const Color(0xFF607D8B) // Braided steel suspension cable
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke;

  static final Paint _trolleyGlowPaint = Paint()
    ..color = const Color(0x6600E5FF) // Electric blue corona discharge aura
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _trolleyCopperPaint = Paint()
    ..color = const Color(0xFFD35400) // Burnished overhead copper contact wire
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _trolleyHighlightPaint = Paint()
    ..color = const Color(0xFFFFCC80) // High-voltage copper reflection
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _dropperPaint = Paint()
    ..color = const Color(0xFF90A4AE) // Vertical hanger dropper wire
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _bracketPaint = Paint()
    ..color = const Color(0xFF37474F) // Industrial steel support bracket
    ..style = PaintingStyle.fill;

  static final Paint _insulatorCeramicPaint = Paint()
    ..color = const Color(0xFF8D6E63) // Terracotta/ceramic spool rib
    ..style = PaintingStyle.fill;

  static final Paint _insulatorHighlightPaint = Paint()
    ..color = const Color(0xFFBCAAA4)
    ..style = PaintingStyle.fill;

  static final Paint _arcFlashPaint = Paint()
    ..color = const Color(0xAA00E5FF)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _glowTimer += dt;
  }

  /// Evaluates whether an airborne courier can latch onto the overhead catenary power line.
  bool canGrabWire(Vector2 playerPosition, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasDismounted || isCourierAttached) return false;
    if (simulator.isGrounded) return false;

    final playerCenterX = playerPosition.x + (playerSize.x * 0.5);

    // Horizontal contact span: from start bracket to near the end bracket
    final inHorizontalRange =
        playerCenterX >= position.x - 4.0 && playerCenterX <= position.x + spanWidth - 20.0;
    if (!inHorizontalRange) return false;

    // Contact wire world Y at player's X
    final wireY = cableYAt(playerCenterX);
    final handY = playerPosition.y + 10.0;

    // Vertical grab window around courier hands
    final inVerticalRange = (handY - wireY).abs() <= 34.0;
    return inVerticalRange;
  }

  /// Checks if the courier's center position has reached the trailing dismount edge.
  bool isPastForwardEdge(double courierCenterX) {
    return courierCenterX >= position.x + spanWidth - 14.0;
  }

  /// Attaches courier to the catenary power line.
  void attachCourier() {
    isCourierAttached = true;
  }

  /// Releases the courier from the wire, catapulting with forward and upward momentum.
  Vector2 releaseCourier() {
    isCourierAttached = false;
    hasDismounted = true;
    onZiplineDismount?.call();
    return Vector2(180.0, 220.0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulse = 0.5 + 0.5 * math.sin(_glowTimer * 10.0);
    _trolleyGlowPaint.color = Color.fromRGBO(0, 229, 255, 0.25 + 0.25 * pulse);

    // 1. Draw Anchor Stanchion Brackets & Ceramic Insulators at start and end
    _renderAnchorFixture(canvas, 0.0, 0.0);
    _renderAnchorFixture(canvas, spanWidth, cableDrop);

    // 2. Draw Upper Suspension Messenger Cable
    final messengerPath = Path();
    messengerPath.moveTo(0.0, 0.0);
    const steps = 24;
    final stepX = spanWidth / steps;
    for (var i = 1; i <= steps; i++) {
      final lx = i * stepX;
      final t = lx / spanWidth;
      final ly = t * cableDrop + 4.0 * (sag + 4.0) * t * (1.0 - t);
      messengerPath.lineTo(lx, ly);
    }
    canvas.drawPath(messengerPath, _messengerPaint);

    // 3. Draw Lower Energized Trolley Contact Wire with Corona Glow
    final trolleyPath = Path();
    trolleyPath.moveTo(0.0, 18.0);
    for (var i = 1; i <= steps; i++) {
      final lx = i * stepX;
      final t = lx / spanWidth;
      final ly = 18.0 + t * cableDrop + 4.0 * sag * t * (1.0 - t);
      trolleyPath.lineTo(lx, ly);
    }

    // Glowing electrical corona aura
    canvas.drawPath(trolleyPath, _trolleyGlowPaint);
    // Heavy copper contact conductor
    canvas.drawPath(trolleyPath, _trolleyCopperPaint);
    // Specular highlight line
    canvas.drawPath(trolleyPath, _trolleyHighlightPaint);

    // 4. Draw Vertical Hanger Dropper Wires between messenger and trolley
    const dropperSpacing = 28.0;
    for (var dx = dropperSpacing; dx < spanWidth - 10.0; dx += dropperSpacing) {
      final t = dx / spanWidth;
      final my = t * cableDrop + 4.0 * (sag + 4.0) * t * (1.0 - t);
      final ty = 18.0 + t * cableDrop + 4.0 * sag * t * (1.0 - t);
      canvas.drawLine(Offset(dx, my), Offset(dx, ty), _dropperPaint);
    }

    // 5. Electric Arc Flash at Wire End or Active Attachment
    if (isCourierAttached) {
      final arcRadius = 8.0 + 4.0 * pulse;
      canvas.drawCircle(Offset(spanWidth * 0.5, 18.0 + (cableDrop * 0.5) + sag), arcRadius, _arcFlashPaint);
    }
  }

  void _renderAnchorFixture(Canvas canvas, double x, double y) {
    // Steel wall mount / girder clamp plate
    canvas.drawRect(Rect.fromLTWH(x - 5.0, y - 6.0, 10.0, 32.0), _bracketPaint);

    // Ceramic ribbed spool insulator stack
    for (var i = 0; i < 3; i++) {
      final iy = y + (i * 6.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, iy), width: 12.0, height: 4.5),
          const Radius.circular(2.0),
        ),
        _insulatorCeramicPaint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, iy), width: 10.0, height: 1.5),
        _insulatorHighlightPaint,
      );
    }
  }
}
