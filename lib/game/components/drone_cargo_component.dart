import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Autonomous high-altitude quadcopter delivery drone carrying a suspended
/// magnetic cargo crate that couriers can intercept mid-jump.
class DroneCargoComponent extends PositionComponent {
  DroneCargoComponent({
    required Vector2 position,
    double width = 48.0,
    double height = 42.0,
    this.groundY = 460.0,
    this.relativeSpeed = 0.0,
    this.onIntercept,
  })  : baseAltitudeY = position.y,
        super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final double baseAltitudeY;
  final double relativeSpeed;
  final VoidCallback? onIntercept;

  bool hasCargo = true;
  bool hasBeenIntercepted = false;

  double _rotorRotation = 0.0;
  double _hoverPhase = 0.0;
  double _blinkTimer = 0.0;
  double _departTimer = 0.0;

  /// Bounding rectangle of the suspended magnetic cargo crate in world coordinates.
  Rect get crateWorldRect => Rect.fromLTWH(
        position.x + 12.0,
        position.y + 22.0,
        24.0,
        20.0,
      );

  /// Center point of the suspended cargo crate for particle bursts and drop effects.
  Vector2 get crateCenterWorld => Vector2(position.x + 24.0, position.y + 32.0);

  /// Whether the drone has moved completely offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0 || position.y < -120.0;

  // Visual styling paints
  static final Paint _fuselagePaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _fuselageHighlightPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  static final Paint _strutPaint = Paint()
    ..color = const Color(0xFF455A64)
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _rotorDiscPaint = Paint()
    ..color = const Color(0xFFB0BEC5).withValues(alpha: 0.35)
    ..style = PaintingStyle.fill;

  static final Paint _bladePaint = Paint()
    ..color = const Color(0xFFCFD8DC)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  static final Paint _cablePaint = Paint()
    ..color = const Color(0xFF1A1A1A)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _cratePaint = Paint()
    ..color = const Color(0xFFE67E22) // Courier Orange cargo crate
    ..style = PaintingStyle.fill;

  static final Paint _crateBorderPaint = Paint()
    ..color = const Color(0xFFD35400)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _latchClampPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.fill;

  static final Paint _latchLedPaint = Paint()
    ..color = const Color(0xFF00E676)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _rotorRotation += dt * 32.0;
    _hoverPhase += dt * 2.8;
    _blinkTimer = (_blinkTimer + dt) % 0.8;

    if (hasBeenIntercepted) {
      _departTimer += dt;
      // High-speed aerial ascent away from the courier
      position.x += (relativeSpeed + 160.0) * dt;
      position.y -= (180.0 + _departTimer * 120.0) * dt;
    } else {
      position.x += relativeSpeed * dt;
      position.y = baseAltitudeY + math.sin(_hoverPhase) * 6.0;
    }
  }

  /// Evaluates whether an airborne courier leaps up and intercepts the suspended cargo crate.
  bool checkIntercept(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (!hasCargo || hasBeenIntercepted) return false;

    // Must be actively airborne to intercept high-altitude cargo
    if (simulator.isGrounded) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final playerTop = playerPos.y;
    final playerBottom = playerPos.y + playerSize.y;

    final crateHitbox = crateWorldRect.inflate(14.0);

    final overlapsHorizontally = playerRight >= crateHitbox.left && playerLeft <= crateHitbox.right;
    final overlapsVertically = playerBottom >= crateHitbox.top && playerTop <= crateHitbox.bottom;

    if (overlapsHorizontally && overlapsVertically) {
      hasBeenIntercepted = true;
      hasCargo = false;
      onIntercept?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final isPortBlink = _blinkTimer < 0.4;

    // 1. Motor Booms (Diagonal Struts from Fuselage)
    const centerX = 24.0;
    const centerY = 12.0;

    // Struts to 4 motor nacelles
    canvas.drawLine(const Offset(centerX, centerY), const Offset(8.0, 4.0), _strutPaint);
    canvas.drawLine(const Offset(centerX, centerY), const Offset(40.0, 4.0), _strutPaint);
    canvas.drawLine(const Offset(centerX, centerY), const Offset(8.0, 18.0), _strutPaint);
    canvas.drawLine(const Offset(centerX, centerY), const Offset(40.0, 18.0), _strutPaint);

    // 2. Spinning Quad-Rotors at Nacelle Corners
    const nacelles = [
      Offset(8.0, 4.0),
      Offset(40.0, 4.0),
      Offset(8.0, 18.0),
      Offset(40.0, 18.0),
    ];

    for (var i = 0; i < nacelles.length; i++) {
      final n = nacelles[i];
      // Rotor motion blur disc
      canvas.drawOval(
        Rect.fromCenter(center: n, width: 15.0, height: 5.0),
        _rotorDiscPaint,
      );

      // Rotating blades
      final bladeAngle = _rotorRotation + (i * (math.pi / 2));
      final bx = math.cos(bladeAngle) * 7.0;
      final by = math.sin(bladeAngle) * 2.2;
      canvas.drawLine(Offset(n.dx - bx, n.dy - by), Offset(n.dx + bx, n.dy + by), _bladePaint);
    }

    // 3. Central Aerodynamic Carbon Fuselage
    const fuselageRect = Rect.fromLTWH(12.0, 6.0, 24.0, 12.0);
    final fuselageRRect = RRect.fromRectAndRadius(fuselageRect, const Radius.circular(5.0));
    canvas.drawRRect(fuselageRRect, _fuselagePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(15.0, 8.0, 18.0, 4.0), const Radius.circular(2.0)),
      _fuselageHighlightPaint,
    );

    // Cyan forward telemetry eye
    final eyePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(34.0, 12.0), 2.0, eyePaint);

    // 4. Port & Starboard Navigation Strobe LEDs
    final portStrobePaint = Paint()
      ..color = isPortBlink ? const Color(0xFFFF1744) : const Color(0xFFB71C1C)
      ..style = PaintingStyle.fill;
    final stbdStrobePaint = Paint()
      ..color = !isPortBlink ? const Color(0xFF00E676) : const Color(0xFF1B5E20)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(6.0, 11.0), 1.6, portStrobePaint);
    canvas.drawCircle(const Offset(42.0, 11.0), 1.6, stbdStrobePaint);

    // 5. Suspended Magnetic Cargo Container Crate
    if (hasCargo) {
      // Suspension cables
      canvas.drawLine(const Offset(18.0, 18.0), const Offset(16.0, 24.0), _cablePaint);
      canvas.drawLine(const Offset(30.0, 18.0), const Offset(32.0, 24.0), _cablePaint);

      // Crate box
      const crateRect = Rect.fromLTWH(12.0, 24.0, 24.0, 17.0);
      final crateRRect = RRect.fromRectAndRadius(crateRect, const Radius.circular(3.0));
      canvas.drawRRect(crateRRect, _cratePaint);
      canvas.drawRRect(crateRRect, _crateBorderPaint);

      // Yellow/Black diagonal hazard tape
      final hazardPaint = Paint()
        ..color = const Color(0xFFF1C40F).withValues(alpha: 0.8)
        ..strokeWidth = 2.0;
      canvas.drawLine(const Offset(14.0, 31.0), const Offset(20.0, 31.0), hazardPaint);
      canvas.drawLine(const Offset(24.0, 31.0), const Offset(30.0, 31.0), hazardPaint);

      // Magnetic latch clamp & green validation LED
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(20.0, 22.0, 8.0, 4.0), const Radius.circular(1.5)),
        _latchClampPaint,
      );
      canvas.drawCircle(const Offset(24.0, 24.0), 1.2, _latchLedPaint);
    }
  }
}
