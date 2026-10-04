import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Industrial rooftop/elevated galvanized HVAC turbine fan housing that projects
/// a high-velocity forward wind tunnel cone with swirling paper vortices and aerodynamic hover glides.
class HvacWindTunnelComponent extends PositionComponent {
  HvacWindTunnelComponent({
    required Vector2 position,
    this.housingWidth = 54.0,
    this.housingHeight = 54.0,
    this.windLength = 260.0,
    this.thrustBonus = 140.0,
    this.buoyancyMultiplier = 0.30,
    this.groundY = 460.0,
  }) : super(
          position: position,
          size: Vector2(housingWidth + windLength, housingHeight),
        );

  final double housingWidth;
  final double housingHeight;
  final double windLength;
  final double thrustBonus;
  final double buoyancyMultiplier;
  final double groundY;

  /// Whether the courier has already been awarded the stunt bonus for traversing this wind tunnel.
  bool hasAwarded = false;

  double _fanRotation = 0.0;
  double _streamAnim = 0.0;

  /// Center world position of the fan turbine intake.
  Vector2 get fanCenterWorld => Vector2(position.x + housingWidth / 2, position.y + housingHeight / 2);

  /// Bounding rectangle of the forward projected air stream in world coordinates.
  Rect get windStreamWorldRect => Rect.fromLTRB(
        position.x + housingWidth,
        position.y - 12.0,
        position.x + housingWidth + windLength,
        position.y + housingHeight + 12.0,
      );

  /// Whether this wind tunnel and its stream have scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -120.0;

  // Visual styling paints
  static final Paint _casingPaint = Paint()
    ..color = const Color(0xFF546E7A) // Galvanized sheet metal
    ..style = PaintingStyle.fill;

  static final Paint _casingBorderPaint = Paint()
    ..color = const Color(0xFF78909C)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _grillRimPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _grillWirePaint = Paint()
    ..color = const Color(0xFFB0BEC5)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _bladePaint = Paint()
    ..color = const Color(0xFFCFD8DC)
    ..style = PaintingStyle.fill;

  static final Paint _bladeHubPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  static final Paint _ledPaint = Paint()
    ..color = const Color(0xFF00E676) // Glowing green operational LED
    ..style = PaintingStyle.fill;

  /// Checks if the courier's center is currently immersed within the high-velocity wind stream cone.
  bool isInWindStream(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    final playerCenterX = playerPos.x + playerSize.x / 2;
    final playerCenterY = simulator.currentY - playerSize.y / 2;

    return windStreamWorldRect.contains(Offset(playerCenterX, playerCenterY));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fanRotation += dt * 18.0;
    _streamAnim += dt * 5.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Forward Projected Wind Tunnel Airflow Streamlines
    final streamStart = housingWidth;
    final streamEnd = housingWidth + windLength;
    final streamHeight = housingHeight;

    // Outer faint air current envelope
    final conePath = Path()
      ..moveTo(streamStart, 4.0)
      ..lineTo(streamEnd, -8.0)
      ..lineTo(streamEnd, streamHeight + 8.0)
      ..lineTo(streamStart, streamHeight - 4.0)
      ..close();
    final conePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(conePath, conePaint);

    // Racing horizontal aerodynamic streamline vectors
    const lineCount = 5;
    for (var i = 0; i < lineCount; i++) {
      final baseY = 8.0 + (i * 9.0);
      final offsetPhase = (_streamAnim * 120.0 + (i * 65.0)) % windLength;
      final lineStartX = streamStart + offsetPhase;
      final lineLen = 35.0 + math.sin(_streamAnim + i) * 15.0;
      final lineEndX = math.min(streamEnd, lineStartX + lineLen);

      if (lineStartX < streamEnd) {
        final lineAlpha = ((1.0 - ((lineStartX - streamStart) / windLength)) * 140).toInt().clamp(20, 180);
        final linePaint = Paint()
          ..color = (i.isEven ? const Color(0xFF00E5FF) : Colors.white).withAlpha(lineAlpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

        final waveY = baseY + math.sin(_streamAnim * 2.0 + (i * 1.5)) * 3.0;
        canvas.drawLine(Offset(lineStartX, waveY), Offset(lineEndX, waveY), linePaint);
      }
    }

    // Swirling paper newspaper debris scraps within current
    for (var i = 0; i < 3; i++) {
      final scrapPhase = (_streamAnim * 80.0 + (i * 95.0)) % windLength;
      final scrapX = streamStart + scrapPhase;
      final scrapY = 12.0 + (i * 14.0) + math.sin(_streamAnim * 3.0 + i) * 6.0;
      final scrapRot = _streamAnim * 4.0 + (i * 2.0);

      canvas.save();
      canvas.translate(scrapX, scrapY);
      canvas.rotate(scrapRot);

      final scrapPaint = Paint()
        ..color = (i == 1 ? const Color(0xFF8D6E63) : Colors.white).withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawRect(const Rect.fromLTWH(-3, -2, 6, 4), scrapPaint);
      canvas.restore();
    }

    // 2. Industrial Galvanized Turbine Housing Box
    final housingRect = Rect.fromLTWH(0, 0, housingWidth, housingHeight);
    final housingRRect = RRect.fromRectAndRadius(housingRect, const Radius.circular(4.0));
    canvas.drawRRect(housingRRect, _casingPaint);
    canvas.drawRRect(housingRRect, _casingBorderPaint);

    // Bolted corner rivets
    final rivetPaint = Paint()..color = const Color(0xFF37474F);
    for (final ox in [4.0, housingWidth - 4.0]) {
      for (final oy in [4.0, housingHeight - 4.0]) {
        canvas.drawCircle(Offset(ox, oy), 1.5, rivetPaint);
      }
    }

    // 3. Circular Fan Cowling / Safety Grill
    final fanCenter = Offset(housingWidth / 2, housingHeight / 2);
    const fanRadius = 21.0;
    canvas.drawCircle(fanCenter, fanRadius, _grillRimPaint);

    // 4. Rotating Turbine Fan Blades
    canvas.save();
    canvas.translate(fanCenter.dx, fanCenter.dy);
    canvas.rotate(_fanRotation);

    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * (math.pi / 2));
      final bladePath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(5.0, -10.0, 3.0, -fanRadius + 2.0)
        ..lineTo(-3.0, -fanRadius + 2.0)
        ..quadraticBezierTo(-2.0, -10.0, 0, 0)
        ..close();
      canvas.drawPath(bladePath, _bladePaint);
      canvas.restore();
    }

    // Central blade rotor hub
    canvas.drawCircle(Offset.zero, 5.0, _bladeHubPaint);
    canvas.restore();

    // 5. Protective Safety Wire Cage Grill (stationary over rotating blades)
    canvas.drawCircle(fanCenter, fanRadius, _grillWirePaint);
    canvas.drawCircle(fanCenter, fanRadius * 0.55, _grillWirePaint);
    canvas.drawLine(
      Offset(fanCenter.dx - fanRadius, fanCenter.dy),
      Offset(fanCenter.dx + fanRadius, fanCenter.dy),
      _grillWirePaint,
    );
    canvas.drawLine(
      Offset(fanCenter.dx, fanCenter.dy - fanRadius),
      Offset(fanCenter.dx, fanCenter.dy + fanRadius),
      _grillWirePaint,
    );

    // 6. Operational Status Indicator LED
    canvas.drawCircle(const Offset(8.0, 8.0), 2.5, _ledPaint);
  }
}
