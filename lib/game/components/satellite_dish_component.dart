import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Rooftop parabolic satellite communications dish acting as a directional bounce launcher.
///
/// Features a concave reflective aluminum bowl, cantilevered feed horn arm with
/// an active pulsing cyan microwave telemetry beacon, and elastic spring recoil upon courier landing.
class SatelliteDishComponent extends PositionComponent {
  SatelliteDishComponent({
    required Vector2 position,
    double width = 56.0,
    double height = 50.0,
    this.launchImpulse = 540.0,
    this.onLaunch,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double launchImpulse;
  final VoidCallback? onLaunch;

  bool hasLaunched = false;
  double _compression = 0.0;
  double _beaconTimer = 0.0;
  double _pulsePhase = 0.0;

  /// Top baseline rim Y of the parabolic dish bowl in world coordinates.
  double get dishRimWorldY => position.y + 14.0;

  /// World space coordinate at the feed horn microwave transmitter beacon.
  Vector2 get feedHornWorldPosition => Vector2(position.x + (size.x * 0.72), position.y + 4.0);

  /// Center point of the satellite dish in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the satellite dish has scrolled offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _mountPaint = Paint()
    ..color = const Color(0xFF37474F) // Heavy steel gimbal
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _dishOuterPaint = Paint()
    ..color = const Color(0xFFCFD8DC) // Reflective metallic aluminum
    ..style = PaintingStyle.fill;

  static final Paint _dishInnerPaint = Paint()
    ..color = const Color(0xFF90A4AE) // Concave interior shade
    ..style = PaintingStyle.fill;

  static final Paint _dishRimPaint = Paint()
    ..color = const Color(0xFF546E7A)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _feedArmPaint = Paint()
    ..color = const Color(0xFF455A64)
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _beaconPaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    _beaconTimer += dt;
    _pulsePhase = (math.sin(_beaconTimer * 8.0) + 1.0) / 2.0;

    if (_compression > 0.0) {
      _compression -= dt * 4.5;
      if (_compression < 0.0) _compression = 0.0;
    }
  }

  /// Evaluates whether an airborne courier descends into the parabolic dish bowl
  /// to initiate a high-altitude celestial trajectory launch.
  bool checkLaunch(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasLaunched) return false;

    // Must be actively airborne to engage parabolic leap pad
    if (simulator.isGrounded) return false;

    // Ignore if courier is already rocketing upward at high velocity
    if (simulator.verticalVelocity > 60.0) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    // Horizontal contact with the parabolic bowl
    final inHorizontal = playerRight >= position.x + 6.0 && playerLeft <= position.x + size.x - 6.0;

    // Foot descends into or touches top rim of the concave dish
    final inVertical = footY >= dishRimWorldY - 14.0 && footY <= dishRimWorldY + 22.0;

    if (inHorizontal && inVertical) {
      hasLaunched = true;
      _compression = 1.0;

      // Celestial high-gain parabolic trajectory launch
      simulator.launch(launchImpulse);

      onLaunch?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final compressionOffset = math.sin(_compression * math.pi) * 5.5;

    // 1. Azimuth-Elevation Base & Mounting Pedestal
    final baseCenterX = w * 0.42;
    const basePlateY = 48.0;

    // Roof anchor bolts & footer plate
    final basePlatePaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(baseCenterX - 14.0, basePlateY - 4.0, 28.0, 4.0),
        const Radius.circular(1.5),
      ),
      basePlatePaint,
    );

    // Tripod / A-frame pedestal struts
    canvas.drawLine(Offset(baseCenterX - 10.0, basePlateY), Offset(baseCenterX, 30.0), _mountPaint);
    canvas.drawLine(Offset(baseCenterX + 10.0, basePlateY), Offset(baseCenterX, 30.0), _mountPaint);
    canvas.drawCircle(Offset(baseCenterX, 30.0), 3.0, basePlatePaint);

    // Elevation arm pivot
    canvas.drawLine(
      Offset(baseCenterX, 30.0),
      Offset(baseCenterX + 4.0, 22.0 + compressionOffset),
      _mountPaint,
    );

    // 2. Parabolic Concave Antenna Dish Bowl
    canvas.save();
    canvas.translate(0.0, compressionOffset);

    final dishCenter = Offset(w * 0.44, 20.0);
    const dishRadiusX = 22.0;
    const dishRadiusY = 14.0;

    // Outer metallic reflective backplate
    final dishPath = Path()
      ..moveTo(dishCenter.dx - dishRadiusX, dishCenter.dy)
      ..quadraticBezierTo(
        dishCenter.dx,
        dishCenter.dy + dishRadiusY + 8.0,
        dishCenter.dx + dishRadiusX,
        dishCenter.dy,
      )
      ..quadraticBezierTo(
        dishCenter.dx,
        dishCenter.dy + dishRadiusY - 2.0,
        dishCenter.dx - dishRadiusX,
        dishCenter.dy,
      )
      ..close();
    canvas.drawPath(dishPath, _dishOuterPaint);
    canvas.drawPath(dishPath, _dishRimPaint);

    // Inner parabolic receiver surface
    final innerPath = Path()
      ..moveTo(dishCenter.dx - dishRadiusX + 2.0, dishCenter.dy)
      ..quadraticBezierTo(
        dishCenter.dx,
        dishCenter.dy + dishRadiusY + 5.0,
        dishCenter.dx + dishRadiusX - 2.0,
        dishCenter.dy,
      )
      ..quadraticBezierTo(
        dishCenter.dx,
        dishCenter.dy + dishRadiusY - 4.0,
        dishCenter.dx - dishRadiusX + 2.0,
        dishCenter.dy,
      )
      ..close();
    canvas.drawPath(innerPath, _dishInnerPaint);

    // 3. Feed Horn Cantilever Arm and Microwave Sub-Reflector
    final feedBase = Offset(dishCenter.dx, dishCenter.dy + 8.0);
    final feedEnd = Offset(w * 0.72, 4.0);

    canvas.drawLine(feedBase, feedEnd, _feedArmPaint);

    // Sub-reflector cap
    final subReflectorPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(feedEnd, 3.5, subReflectorPaint);

    // 4. Cyan Microwave Telemetry Beacon Eye
    final beaconRadius = 2.0 + (_pulsePhase * 1.5);
    canvas.drawCircle(feedEnd, beaconRadius, _beaconPaint);

    // Radiating microwave transmission wave rings
    final wavePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25 + (_pulsePhase * 0.35))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(feedEnd, 6.0 + (_pulsePhase * 5.0), wavePaint);

    canvas.restore();
  }
}
