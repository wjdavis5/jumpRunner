import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street-level construction cement mixer: a portable diesel-powered rotor
/// mounted on a safety-yellow tubular tripod chassis, with a corrugated
/// churning drum, engine housing and exhaust, cast-iron pouring chute and
/// dual rubber tires.
///
/// An airborne courier bounding onto the churning drum gets a rotational
/// mortar hop (+230 px/s loft) and scatters wet concrete aggregate.
class CementMixerComponent extends PositionComponent {
  CementMixerComponent({
    required Vector2 position,
    double width = 64.0,
    double height = 56.0,
    this.groundY = 460.0,
    this.onHop,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onHop;

  bool hasHopped = false;

  /// Angle of the mixing drum in radians, advanced every frame so the
  /// corrugated ribs read as churning aggregate.
  double drumRotation = 0.0;

  /// Rotational speed of the drum, in radians a second.
  static const double drumRotationSpeed = 2.4;

  /// Top surface baseline Y of the mixer chassis in world coordinates.
  double get mixerTopY => groundY - size.y;

  /// Center of the mixing drum in world coordinates, where the hop reads
  /// from and where splatter particles are anchored.
  Vector2 get drumCenterWorld =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.40));

  /// World space coordinate at the mortar hop apex for launch particles.
  Vector2 get hopApexWorld =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.18));

  /// Center point of the mixer in world coordinates.
  Vector2 get centerWorldPosition =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.5));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    drumRotation =
        (drumRotation + (dt * drumRotationSpeed)) % (2 * math.pi);
  }

  /// Evaluates whether an approaching courier bounds off the churning drum
  /// for a rotational mortar hop.
  ///
  /// Contact marks the mixer spent either way; only an airborne courier is
  /// launched (a grounded courier runs past under the drum).
  bool checkMixerHop(
    Vector2 playerPos,
    Vector2 playerSize,
    JumpPhysicsSimulator simulator,
  ) {
    if (hasHopped) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check: tight contact window with the drum barrel.
    final horizontalOverlap =
        (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from the drum hood down to the pavement.
    final windowTop = mixerTopY - 24.0;
    final windowBottom = groundY + 4.0;
    final inHopWindow = (footY >= windowTop) && (footY <= windowBottom);
    if (!inHopWindow) return false;

    hasHopped = true;
    if (!simulator.isGrounded) {
      simulator.launch(230.0); // Rotational mortar hop off the churning drum.
    }
    onHop?.call();
    return true;
  }

  /// Manually mark the mixer as hopped.
  void markHopped() {
    hasHopped = true;
  }

  // Visual styling paints
  static final Paint _chassisPaint = Paint()
    ..color = const Color(0xFFF9A825) // Safety yellow tubular steel
    ..style = PaintingStyle.fill;

  static final Paint _chassisShadePaint = Paint()
    ..color = const Color(0xFFF57F17)
    ..style = PaintingStyle.fill;

  static final Paint _tirePaint = Paint()
    ..color = const Color(0xFF212121) // Dual rubber tires
    ..style = PaintingStyle.fill;

  static final Paint _hubPaint = Paint()
    ..color = const Color(0xFF9E9E9E)
    ..style = PaintingStyle.fill;

  static final Paint _drumPaint = Paint()
    ..color = const Color(0xFF8D6E63) // Weather-beaten mortar drum
    ..style = PaintingStyle.fill;

  static final Paint _drumRibPaint = Paint()
    ..color = const Color(0xFF5D4037) // Corrugated spiral ribs
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _drumRimPaint = Paint()
    ..color = const Color(0xFFBCAAA4)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _drumMouthPaint = Paint()
    ..color = const Color(0xFF3E2723)
    ..style = PaintingStyle.fill;

  static final Paint _mortarPaint = Paint()
    ..color = const Color(0xFFBDBDBD) // Wet aggregate clinging to the mouth
    ..style = PaintingStyle.fill;

  static final Paint _enginePaint = Paint()
    ..color = const Color(0xFF455A64) // Diesel engine housing
    ..style = PaintingStyle.fill;

  static final Paint _engineVentPaint = Paint()
    ..color = const Color(0xFF263238)
    ..strokeWidth = 1.1
    ..style = PaintingStyle.stroke;

  static final Paint _mufflerPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  static final Paint _chutePaint = Paint()
    ..color = const Color(0xFF616161) // Cast-iron pouring chute
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Tubular tripod chassis legs (splayed to the pavement)
    _renderTripod(canvas, w, h);

    // 2. Churning corrugated mixing drum
    _renderDrum(canvas, w, h);

    // 3. Diesel engine housing with exhaust muffler stack
    _renderEngine(canvas, w, h);

    // 4. Cast-iron pouring chute under the drum mouth
    _renderChute(canvas, w, h);

    // 5. Dual rubber tires on the rear axle
    _renderTires(canvas, w, h);
  }

  void _renderTripod(Canvas canvas, double w, double h) {
    final left = Path()
      ..moveTo(w * 0.18, h * 0.42)
      ..lineTo(w * 0.08, h)
      ..lineTo(w * 0.20, h)
      ..lineTo(w * 0.28, h * 0.46)
      ..close();
    canvas.drawPath(left, _chassisPaint);

    final right = Path()
      ..moveTo(w * 0.72, h * 0.46)
      ..lineTo(w * 0.80, h)
      ..lineTo(w * 0.92, h)
      ..lineTo(w * 0.82, h * 0.42)
      ..close();
    canvas.drawPath(right, _chassisPaint);

    // Cross brace
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.62, w * 0.64, 3.0), _chassisShadePaint);
  }

  void _renderDrum(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final cy = h * 0.40;
    final drumW = w - 22.0;
    const drumH = 26.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(drumRotation);

    // Barrel body
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: drumW, height: drumH),
      _drumPaint,
    );

    // Corrugated spiral ribs read as diagonal bands while the drum turns.
    for (var i = -1; i <= 1; i++) {
      final x = i * (drumW / 3.6);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, 0), width: drumW * 0.62, height: drumH),
        -1.1,
        2.2,
        false,
        _drumRibPaint,
      );
    }

    // Rim shading at both barrel ends
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-drumW * 0.34, 0), width: 8.0, height: drumH),
      _drumRimPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(drumW * 0.34, 0), width: 8.0, height: drumH),
      _drumRimPaint,
    );

    // Drum mouth and clinging wet mortar
    canvas.drawCircle(Offset(-drumW * 0.30, -drumH * 0.34), 4.2, _drumMouthPaint);
    canvas.drawCircle(Offset(-drumW * 0.30 - 1.0, -drumH * 0.34 - 1.0), 2.2, _mortarPaint);
    canvas.restore();

    // Chassis collar that carries the drum
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + drumH * 0.62), width: w * 0.44, height: 4.0),
      _chassisShadePaint,
    );
  }

  void _renderEngine(Canvas canvas, double w, double h) {
    // Engine block behind the drum
    final housing = Rect.fromLTWH(w * 0.56, h * 0.20, w * 0.30, h * 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(housing, const Radius.circular(3.0)),
      _enginePaint,
    );

    // Cooling vents
    for (var i = 0; i < 3; i++) {
      final y = housing.top + 4.0 + (i * 5.0);
      canvas.drawLine(Offset(housing.left + 3.0, y), Offset(housing.right - 3.0, y), _engineVentPaint);
    }

    // Exhaust muffler stack
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.78, h * 0.06, 5.0, h * 0.24),
        const Radius.circular(2.0),
      ),
      _mufflerPaint,
    );
  }

  void _renderChute(Canvas canvas, double w, double h) {
    final chute = Path()
      ..moveTo(w * 0.24, h * 0.58)
      ..lineTo(w * 0.44, h * 0.66)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.20, h * 0.66)
      ..close();
    canvas.drawPath(chute, _chutePaint);
  }

  void _renderTires(Canvas canvas, double w, double h) {
    const tireR = 7.0;
    for (final cx in [w * 0.30, w * 0.66]) {
      canvas.drawCircle(Offset(cx, h - tireR + 1.0), tireR, _tirePaint);
      canvas.drawCircle(Offset(cx, h - tireR + 1.0), 2.4, _hubPaint);
    }
  }
}
