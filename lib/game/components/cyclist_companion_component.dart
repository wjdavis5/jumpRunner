import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Interactive urban delivery cyclist riding alongside the courier.
///
/// Runners tucking in directly behind the cyclist companion enter an aerodynamic
/// slipstream draft zone, gaining a +20% ground speed boost and enabling a
/// high-velocity slingshot catapult jump forward (+35% impulse & combo bonus tips).
class CyclistCompanionComponent extends PositionComponent {
  CyclistCompanionComponent({
    required Vector2 position,
    Vector2? size,
    this.groundY = 460.0,
    this.relativeSpeed = 0.0,
  }) : super(
          position: position,
          size: size ?? Vector2(76.0, 54.0),
        );

  final double groundY;

  /// Speed relative to ground scroll (positive = cyclist pedals faster than baseline).
  final double relativeSpeed;

  /// Rotation angle of bicycle wheels and pedal crank.
  double wheelAngle = 0.0;
  double _wakeTimer = 0.0;

  /// Total duration player has continuously drafted in this cyclist's slipstream.
  double playerDraftDuration = 0.0;
  bool isPlayerDrafting = false;

  /// Whether a slingshot catapult jump has been launched from this cyclist's wake.
  bool hasTriggeredSlingshot = false;

  /// Whether the cyclist has scrolled off the left edge of the screen.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Slipstream wake dimensions behind rear wheel
  static const double draftZoneLength = 80.0;
  static const double draftZoneHeight = 50.0;

  @override
  void update(double dt) {
    super.update(dt);

    // Dynamic wheel rotation and pedaling cadence
    wheelAngle += dt * 14.0;
    _wakeTimer += dt * 8.0;

    // Relative forward movement
    if (relativeSpeed != 0.0) {
      position.x += relativeSpeed * dt;
    }
  }

  /// Determines whether the courier player is positioned inside the slipstream draft wake.
  bool isPlayerInDraftZone(Vector2 playerPos, Vector2 playerSize) {
    final playerCenterX = playerPos.x + (playerSize.x / 2);
    final playerBottomY = playerPos.y + playerSize.y;

    // Wake zone extends behind the rear of the bicycle (left of position.x)
    final wakeRight = position.x + 15.0;
    final wakeLeft = position.x - draftZoneLength;
    final wakeTop = position.y - 10.0;
    final wakeBottom = position.y + size.y + 12.0;

    final inHorizontalWake = playerCenterX >= wakeLeft && playerCenterX <= wakeRight;
    final inVerticalWake = playerBottomY >= wakeTop && playerBottomY <= wakeBottom;

    return inHorizontalWake && inVerticalWake;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Aerodynamic Slipstream Wind Streamlines (flowing behind bike)
    _renderSlipstreamWake(canvas, w, h);

    // 2. Bicycle Wheels & Hubs
    const wheelRadius = 11.0;
    final rearWheelCenter = Offset(14.0, h - wheelRadius);
    final frontWheelCenter = Offset(w - 14.0, h - wheelRadius);

    _drawWheel(canvas, rearWheelCenter, wheelRadius, wheelAngle);
    _drawWheel(canvas, frontWheelCenter, wheelRadius, wheelAngle);

    // 3. Bicycle Diamond Frame (Neon Cyan courier palette)
    final framePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bottomBracket = Offset(36.0, h - wheelRadius + 2.0);
    final seatCluster = Offset(26.0, h - 30.0);
    final headTube = Offset(w - 22.0, h - 34.0);

    // Rear triangle (chain stay, seat stay)
    canvas.drawLine(rearWheelCenter, bottomBracket, framePaint);
    canvas.drawLine(rearWheelCenter, seatCluster, framePaint);
    // Main triangle (seat tube, down tube, top tube)
    canvas.drawLine(bottomBracket, seatCluster, framePaint);
    canvas.drawLine(bottomBracket, headTube, framePaint);
    canvas.drawLine(seatCluster, headTube, framePaint);
    // Front fork
    canvas.drawLine(headTube, frontWheelCenter, framePaint);

    // Handlebars & Stem
    final barPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final barPath = Path()
      ..moveTo(headTube.dx, headTube.dy)
      ..lineTo(headTube.dx + 4.0, headTube.dy - 6.0)
      ..lineTo(headTube.dx + 9.0, headTube.dy - 4.0);
    canvas.drawPath(barPath, barPaint);

    // Saddle & Seatpost
    final saddlePaint = Paint()..color = const Color(0xFF1C2833);
    canvas.drawLine(
      seatCluster,
      Offset(seatCluster.dx - 2.0, seatCluster.dy - 6.0),
      framePaint..strokeWidth = 2.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(seatCluster.dx - 7.0, seatCluster.dy - 9.0, 14.0, 3.5),
        const Radius.circular(1.5),
      ),
      saddlePaint,
    );

    // Rear Delivery Cargo Rack & Thermal Bag
    final bagPaint = Paint()..color = const Color(0xFFE67E22);
    final bagTrimPaint = Paint()
      ..color = const Color(0xFFF39C12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rackRect = Rect.fromLTWH(seatCluster.dx - 18.0, seatCluster.dy - 12.0, 16.0, 14.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rackRect, const Radius.circular(2.5)),
      bagPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rackRect, const Radius.circular(2.5)),
      bagTrimPaint,
    );
    // Reflective safety stripe on delivery bag
    final stripePaint = Paint()..color = Colors.white70;
    canvas.drawRect(
      Rect.fromLTWH(rackRect.left, rackRect.top + 5.0, rackRect.width, 2.5),
      stripePaint,
    );

    // Flashing Red Tail Beacon
    final beaconPulse = (math.sin(_wakeTimer * 2.0) + 1.0) / 2.0;
    final beaconGlowPaint = Paint()
      ..color = const Color(0xFFFF2222).withValues(alpha: 0.3 + (0.5 * beaconPulse));
    final beaconCorePaint = Paint()..color = const Color(0xFFFF3333);
    final beaconPos = Offset(rackRect.left - 2.0, rackRect.center.dy);
    canvas.drawCircle(beaconPos, 3.5 + (1.5 * beaconPulse), beaconGlowPaint);
    canvas.drawCircle(beaconPos, 1.8, beaconCorePaint);

    // 4. Animated Cyclist Rider (Legs pedaling around bottom bracket)
    _drawRider(canvas, seatCluster, bottomBracket, headTube, wheelAngle * 0.7);
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, double angle) {
    final tirePaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final rimPaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final spokePaint = Paint()
      ..color = const Color(0xFFCFD8DC).withValues(alpha: 0.65)
      ..strokeWidth = 1.0;
    final hubPaint = Paint()..color = const Color(0xFF00E5FF);

    canvas.drawCircle(center, radius, tirePaint);
    canvas.drawCircle(center, radius - 1.5, rimPaint);
    canvas.drawCircle(center, 1.8, hubPaint);

    // 4 spinning spokes
    for (int i = 0; i < 4; i++) {
      final spokeAngle = angle + (i * (math.pi / 2.0));
      final x2 = center.dx + math.cos(spokeAngle) * (radius - 1.5);
      final y2 = center.dy + math.sin(spokeAngle) * (radius - 1.5);
      canvas.drawLine(center, Offset(x2, y2), spokePaint);
    }
  }

  void _drawRider(Canvas canvas, Offset hip, Offset bb, Offset bars, double pedalAngle) {
    // Crank arms and pedals (180 deg offset)
    const crankLength = 6.5;
    final pedal1 = Offset(
      bb.dx + math.cos(pedalAngle) * crankLength,
      bb.dy + math.sin(pedalAngle) * crankLength,
    );
    final pedal2 = Offset(
      bb.dx + math.cos(pedalAngle + math.pi) * crankLength,
      bb.dy + math.sin(pedalAngle + math.pi) * crankLength,
    );

    final crankPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 1.5;
    canvas.drawLine(bb, pedal1, crankPaint);
    canvas.drawLine(bb, pedal2, crankPaint);

    // Rider Legs (Pedaling two-segment kinematics)
    final legPaint1 = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final legPaint2 = Paint()
      ..color = const Color(0xFF1A252F)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Right leg (foreground)
    _drawLegSegment(canvas, hip, pedal1, legPaint1);
    // Left leg (background)
    _drawLegSegment(canvas, hip, pedal2, legPaint2);

    // Rider Torso (Leaning aerodynamically forward)
    final shoulder = Offset(hip.dx + 16.0, hip.dy - 12.0);
    final jerseyPaint = Paint()
      ..color = const Color(0xFF1ABC9C) // Teal courier jersey
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hip, shoulder, jerseyPaint);

    // Messenger Satchel Cross-Strap
    final strapPaint = Paint()
      ..color = const Color(0xFFF1C40F)
      ..strokeWidth = 1.8;
    canvas.drawLine(
      Offset(shoulder.dx - 4.0, shoulder.dy - 2.0),
      Offset(hip.dx + 4.0, hip.dy + 4.0),
      strapPaint,
    );

    // Rider Arms to Drop Bars
    final armPaint = Paint()
      ..color = const Color(0xFF16A085)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final elbow = Offset(shoulder.dx + 6.0, shoulder.dy + 7.0);
    final hand = Offset(bars.dx + 5.0, bars.dy - 5.0);
    canvas.drawLine(shoulder, elbow, armPaint);
    canvas.drawLine(elbow, hand, armPaint);

    // Rider Head & Aerodynamic Helmet
    final headPos = Offset(shoulder.dx + 4.0, shoulder.dy - 6.0);
    final helmetPaint = Paint()..color = const Color(0xFFFFD700); // Gold aero helmet
    final visorPaint = Paint()..color = const Color(0xFF1C2833);

    canvas.drawOval(
      Rect.fromCenter(center: headPos, width: 9.0, height: 7.0),
      helmetPaint,
    );
    // Sleek visor
    canvas.drawLine(
      Offset(headPos.dx + 1.0, headPos.dy),
      Offset(headPos.dx + 5.0, headPos.dy + 2.0),
      visorPaint..strokeWidth = 2.0,
    );
  }

  void _drawLegSegment(Canvas canvas, Offset hip, Offset pedal, Paint paint) {
    // Two-segment inverse kinematics knee approximation
    final mid = Offset((hip.dx + pedal.dx) / 2 + 5.0, (hip.dy + pedal.dy) / 2 - 2.0);
    canvas.drawLine(hip, mid, paint);
    canvas.drawLine(mid, pedal, paint);
  }

  void _renderSlipstreamWake(Canvas canvas, double w, double h) {
    // Dynamic aerodynamic tailwind wake lines & particles streaming behind rear wheel
    final wakeColor = isPlayerDrafting
        ? const Color(0xFF00E5FF) // Active cyan drafting glow
        : const Color(0x66B0BEC5); // Passive wind streamlines

    for (int i = 0; i < 4; i++) {
      final yOffset = h - 28.0 + (i * 7.0);
      final streamPhase = (_wakeTimer + (i * 1.5)) % 4.0;
      final startX = -10.0 - (streamPhase * 16.0);
      final length = 35.0 + (math.sin(_wakeTimer + i) * 12.0);

      final streamPaint = Paint()
        ..color = wakeColor.withValues(
          alpha: isPlayerDrafting ? (0.4 + (0.3 * math.sin(_wakeTimer + i))) : 0.22,
        )
        ..strokeWidth = isPlayerDrafting ? 2.0 : 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(startX, yOffset)
        ..quadraticBezierTo(
          startX - (length / 2),
          yOffset + math.sin(_wakeTimer * 2.0 + i) * 3.0,
          startX - length,
          yOffset,
        );
      canvas.drawPath(path, streamPaint);
    }

    if (isPlayerDrafting) {
      // High-visibility "DRAFTING" speed aura
      final auraPaint = Paint()
        ..color = const Color(0x2200E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawRect(
        const Rect.fromLTWH(-draftZoneLength, 5.0, draftZoneLength + 20.0, draftZoneHeight),
        auraPaint,
      );
    }
  }
}
