import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'courier_player.dart';

/// Elevated urban metallic grind rail that enables couriers to slide along rails,
/// surging forward with friction sparks and performing high-flying Rail Ollie combos.
///
/// Features tubular steel geometry, chrome reflective highlight sheen,
/// heavy-duty support stanchions anchored to the street, and safety hazard end brackets.
class GrindRailComponent extends PositionComponent {
  GrindRailComponent({
    required Vector2 position,
    required Vector2 size,
    this.groundY = 460.0,
  }) : super(position: position, size: size);

  final double groundY;

  /// Top surface Y coordinate where the courier's shoes or board grind.
  double get surfaceY => position.y;

  /// Whether this grind rail has scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -120.0;

  // Visual styling paints
  static final Paint _pipePaint = Paint()
    ..color = const Color(0xFFF1C40F) // Safety yellow tubular steel
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _pipeCorePaint = Paint()
    ..color = const Color(0xFFD68910)
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _chromeHighlightPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _stanchionPaint = Paint()
    ..color = const Color(0xFF4A5568) // Industrial dark steel
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke;

  static final Paint _boltedFlangePaint = Paint()..color = const Color(0xFF2D3748);
  static final Paint _neonCapPaint = Paint()..color = const Color(0xFF00E5FF);

  double _pulseTimer = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt * 4.0;
  }

  /// Checks if the courier's bottom footprint intersects the top landing surface of the rail.
  bool isUnderCourierFootprint(double footX, double footY) {
    final horizontalOverlap = footX >= position.x && footX <= position.x + size.x;
    final verticalOverlap = footY >= surfaceY - 14.0 && footY <= surfaceY + 18.0;
    return horizontalOverlap && verticalOverlap;
  }

  /// Returns true if the courier has reached or passed the forward dismount edge of this rail.
  bool isPastForwardEdge(double footX) {
    return footX > position.x + size.x;
  }

  /// Helper to check collision with player.
  bool checkCollisionWith(CourierPlayer player) {
    final footX = player.position.x + (player.size.x / 2);
    final footY = player.simulator.currentY;
    return isUnderCourierFootprint(footX, footY);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    const railThickness = 8.0;
    const railHalfThickness = railThickness / 2;
    const railY = railHalfThickness;

    // 1. Heavy-duty vertical support stanchions anchored to the ground
    final totalLegHeight = (groundY - position.y) - railThickness;
    if (totalLegHeight > 0) {
      const stanchionSpacing = 80.0;
      double legX = 24.0;
      while (legX < size.x - 12.0) {
        // Vertical stanchion column
        canvas.drawLine(
          Offset(legX, railY + railHalfThickness),
          Offset(legX, railY + totalLegHeight),
          _stanchionPaint,
        );

        // Bolted base mounting flange on the street
        final flangeRect = Rect.fromCenter(
          center: Offset(legX, railY + totalLegHeight - 2.0),
          width: 14.0,
          height: 6.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(flangeRect, const Radius.circular(2)),
          _boltedFlangePaint,
        );

        // Sub-rail cross bracket collar
        final collarRect = Rect.fromCenter(
          center: Offset(legX, railY + railHalfThickness + 4.0),
          width: 10.0,
          height: 5.0,
        );
        canvas.drawRect(collarRect, _boltedFlangePaint);

        legX += stanchionSpacing;
      }
    }

    // 2. Tubular Rail Pipe (Core Shadow)
    canvas.drawLine(
      const Offset(4.0, railY + 1.5),
      Offset(size.x - 4.0, railY + 1.5),
      _pipeCorePaint,
    );

    // 3. Tubular Rail Pipe (Main Yellow / Steel Body)
    canvas.drawLine(
      const Offset(4.0, railY),
      Offset(size.x - 4.0, railY),
      _pipePaint,
    );

    // 4. Chrome Sun / Streetlamp Reflective Sheen
    canvas.drawLine(
      const Offset(8.0, railY - 2.0),
      Offset(size.x - 8.0, railY - 2.0),
      _chromeHighlightPaint,
    );

    // 5. Pulsing holographic entry beacon indicator at lead-in lip
    final pulseAlpha = (0.4 + 0.6 * math.sin(_pulseTimer)).clamp(0.0, 1.0);
    final pulsePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: pulseAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawCircle(const Offset(4.0, railY), 4.5, pulsePaint);
    canvas.drawCircle(const Offset(4.0, railY), 2.5, _neonCapPaint);

    // 6. Rail dismount tip bracket at trailing end
    canvas.drawCircle(Offset(size.x - 4.0, railY), 3.5, _boltedFlangePaint);
  }
}
