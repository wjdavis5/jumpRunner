import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Industrial rooftop air conditioning condenser unit featuring twin high-speed rotating
/// turbine fans that blast continuous upward thermal draft updrafts.
///
/// Leaping into the condenser draft column catapults the courier upward with vertical momentum
/// and deploys aerodynamic hover glide mode across skyscraper rooftops.
class AcCondenserComponent extends PositionComponent {
  AcCondenserComponent({
    required Vector2 position,
    double width = 72.0,
    double height = 48.0,
    this.updraftImpulse = 380.0,
    this.onUpdraft,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double updraftImpulse;
  final VoidCallback? onUpdraft;

  bool hasLifted = false;
  double _fanAngle = 0.0;
  double _mistTimer = 0.0;

  /// Top rim Y baseline of the condenser fan shroud in world coordinates.
  double get fanTopWorldY => position.y + 6.0;

  /// World space coordinate at the center of the thermal draft updraft column.
  Vector2 get updraftWorldPosition => Vector2(position.x + (size.x / 2), position.y - 12.0);

  /// Center point of the condenser housing in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the condenser unit has scrolled offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _housingPaint = Paint()
    ..color = const Color(0xFF607D8B) // Galvanized sheet metal
    ..style = PaintingStyle.fill;

  static final Paint _housingBorderPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _copperFinPaint = Paint()
    ..color = const Color(0xFFD87D4A) // Radiator copper coil fin
    ..strokeWidth = 1.5;

  static final Paint _cowlPaint = Paint()
    ..color = const Color(0xFF263238) // Deep fan bay cowl
    ..style = PaintingStyle.fill;

  static final Paint _fanBladePaint = Paint()
    ..color = const Color(0xFFCFD8DC) // Aluminum fan blade
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  static final Paint _fanHubPaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.fill;

  static final Paint _gratePaint = Paint()
    ..color = const Color(0xFF455A64) // Wire protective screen
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _damperPaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    _fanAngle += dt * 14.0;
    _mistTimer += dt * 3.5;
  }

  /// Evaluates whether an airborne courier descends into the condenser exhaust draft
  /// to trigger high-altitude thermal vortex lift and aerodynamic hover glide.
  bool checkUpdraft(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasLifted) return false;

    // Must be actively airborne to catch the thermal updraft
    if (simulator.isGrounded) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    // Horizontal overlap with condenser draft footprint
    final inHorizontal = playerRight >= position.x + 4.0 && playerLeft <= position.x + size.x - 4.0;

    // Foot penetrates into the thermal draft zone above the spinning fan blades
    final inVertical = footY >= position.y - 45.0 && footY <= position.y + 14.0;

    if (inHorizontal && inVertical) {
      hasLifted = true;

      // Impart upward thermal draft boost and activate gliding
      simulator.launch(updraftImpulse);
      simulator.isGliding = true;

      onUpdraft?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Vibration Isolation Mounting Footpads
    const footWidth = 10.0;
    const footHeight = 4.0;
    canvas.drawRect(Rect.fromLTWH(4.0, h - footHeight, footWidth, footHeight), _damperPaint);
    canvas.drawRect(Rect.fromLTWH(w - 14.0, h - footHeight, footWidth, footHeight), _damperPaint);

    // 2. Galvanized Steel Enclosure Housing
    final cabinetRect = Rect.fromLTWH(2.0, 6.0, w - 4.0, h - 10.0);
    final cabinetRRect = RRect.fromRectAndRadius(cabinetRect, const Radius.circular(2.5));
    canvas.drawRRect(cabinetRRect, _housingPaint);
    canvas.drawRRect(cabinetRRect, _housingBorderPaint);

    // 3. Side Radiator Copper Heat Exchanger Fins
    const finTopY = 16.0;
    final finBottomY = h - 8.0;
    for (var fx = 8.0; fx <= w - 8.0; fx += 5.5) {
      canvas.drawLine(Offset(fx, finTopY), Offset(fx, finBottomY), _copperFinPaint);
    }

    // 4. Twin Rotating Exhaust Turbines (Left and Right Fans)
    final fanRadius = (w - 16.0) / 4.0;
    final leftCenter = Offset(6.0 + fanRadius, 10.0);
    final rightCenter = Offset(w - 6.0 - fanRadius, 10.0);

    _renderFanCowl(canvas, leftCenter, fanRadius, _fanAngle);
    _renderFanCowl(canvas, rightCenter, fanRadius, -_fanAngle);

    // 5. Ambient Animated Chilled Vapor Waves Rising Above Cowls
    final mistPhase = (math.sin(_mistTimer) + 1.0) / 2.0;
    final vaporPaint = Paint()
      ..color = const Color(0xFFB2EBF2).withValues(alpha: 0.25 + (mistPhase * 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final mistY = -4.0 - (mistPhase * 10.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(leftCenter.dx, mistY), radius: fanRadius * 0.8),
      math.pi * 0.1,
      math.pi * 0.8,
      false,
      vaporPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(rightCenter.dx, mistY), radius: fanRadius * 0.8),
      math.pi * 0.1,
      math.pi * 0.8,
      false,
      vaporPaint,
    );
  }

  void _renderFanCowl(Canvas canvas, Offset center, double radius, double angle) {
    // Recessed circular well
    canvas.drawCircle(center, radius, _cowlPaint);

    // Spinning 4-blade propeller
    for (var i = 0; i < 4; i++) {
      final bladeAngle = angle + (i * math.pi / 2.0);
      final tipX = center.dx + math.cos(bladeAngle) * (radius - 1.5);
      final tipY = center.dy + math.sin(bladeAngle) * (radius - 1.5);
      canvas.drawLine(center, Offset(tipX, tipY), _fanBladePaint);
    }

    // Center electric motor hub
    canvas.drawCircle(center, 2.8, _fanHubPaint);

    // Protective wire grate circle and cross
    canvas.drawCircle(center, radius, _gratePaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), _gratePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), _gratePaint);
  }
}
