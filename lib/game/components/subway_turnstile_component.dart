import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Interactive street-level subway entrance turnstile kiosk with brushed stainless steel
/// chassis, magnetic MetroCard swipe reader console, pulsing LED transit indicator,
/// and rotating tripod mechanical barrier arms.
class SubwayTurnstileComponent extends PositionComponent {
  SubwayTurnstileComponent({
    required Vector2 position,
    double width = 58.0,
    double height = 52.0,
    this.groundY = 460.0,
    this.onSwipe,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onSwipe;
  final VoidCallback? onVault;

  bool hasSwiped = false;
  bool hasVaulted = false;

  double _armRotation = 0.0;
  double _targetArmRotation = 0.0;
  double _swipeFlashTimer = 0.0;
  double _pulseTimer = 0.0;

  /// Top surface baseline Y of the turnstile barrier in world coordinates.
  double get barrierTopWorldY => position.y + 12.0;

  /// World coordinates of the magnetic card validator reader for particle alignment.
  Vector2 get cardReaderWorldPosition => Vector2(position.x + 20.0, position.y + 8.0);

  /// Center world coordinate of the rotating tripod rotor hub.
  Vector2 get rotorHubWorldPosition => Vector2(position.x + 36.0, position.y + 26.0);

  /// Whether the turnstile has scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _steelBasePaint = Paint()
    ..color = const Color(0xFF546E7A)
    ..style = PaintingStyle.fill;

  static final Paint _steelBodyPaint = Paint()
    ..color = const Color(0xFF78909C)
    ..style = PaintingStyle.fill;

  static final Paint _steelHighlightPaint = Paint()
    ..color = const Color(0xFFCFD8DC)
    ..style = PaintingStyle.fill;

  static final Paint _steelBorderPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _readerBezelPaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.fill;

  static final Paint _slotPaint = Paint()
    ..color = const Color(0xFFFFD54F) // MetroCard yellow stripe slot
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _rotorHubPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _armPaint = Paint()
    ..color = const Color(0xFFECEFF1)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _armCapPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt * 3.5;

    if (_swipeFlashTimer > 0) {
      _swipeFlashTimer = math.max(0.0, _swipeFlashTimer - dt);
    }

    if (_armRotation < _targetArmRotation) {
      _armRotation = math.min(_targetArmRotation, _armRotation + dt * 14.0);
    }
  }

  /// Evaluates whether the courier sprints through at sidewalk level, swiping the transit pass.
  bool checkSwipe(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasSwiped || hasVaulted) return false;

    final courierFootX = playerPos.x + (playerSize.x / 2);
    final courierFootY = simulator.currentY;

    // Must be at sidewalk level (not leaping high above)
    final isGroundedOrLow = simulator.isGrounded || (courierFootY >= groundY - 26.0);
    final inHorizontalRange = courierFootX >= position.x - 12.0 &&
        courierFootX <= position.x + size.x + 8.0;

    if (isGroundedOrLow && inHorizontalRange) {
      hasSwiped = true;
      _swipeFlashTimer = 0.65;
      _targetArmRotation += (2 * math.pi) / 3; // 120 degree tripod notch advance
      onSwipe?.call();
      return true;
    }

    return false;
  }

  /// Evaluates whether the courier cleanly hurdle-vaults over the turnstile barrier.
  bool checkVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted || hasSwiped) return false;

    final courierFootX = playerPos.x + (playerSize.x / 2);
    final courierFootY = simulator.currentY;

    // Airborne above turnstile hurdle
    final isAirborneOverTurnstile = !simulator.isGrounded &&
        courierFootY < barrierTopWorldY + 12.0 &&
        courierFootY >= barrierTopWorldY - 40.0;
    final inHorizontalRange = courierFootX >= position.x &&
        courierFootX <= position.x + size.x;

    if (isAirborneOverTurnstile && inHorizontalRange) {
      hasVaulted = true;
      _swipeFlashTimer = 0.65;
      _targetArmRotation += (2 * math.pi) / 3;
      onVault?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final h = size.y;

    // 1. Bolted Concrete Ground Mounting Flange
    final baseRect = Rect.fromLTWH(4.0, h - 8.0, 34.0, 8.0);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(2.0)), _steelBasePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(2.0)), _steelBorderPaint);

    final boltPaint = Paint()..color = const Color(0xFF263238);
    canvas.drawCircle(Offset(8.0, h - 4.0), 1.5, boltPaint);
    canvas.drawCircle(Offset(34.0, h - 4.0), 1.5, boltPaint);

    // 2. Stainless Steel Pedestal Pillar Housing
    final pillarRect = Rect.fromLTWH(8.0, 10.0, 26.0, h - 18.0);
    canvas.drawRRect(RRect.fromRectAndRadius(pillarRect, const Radius.circular(3.0)), _steelBodyPaint);
    // Vertical specular brushed sheen stripe
    canvas.drawRect(Rect.fromLTWH(14.0, 10.0, 8.0, h - 18.0), _steelHighlightPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(pillarRect, const Radius.circular(3.0)), _steelBorderPaint);

    // 3. Angled Reader Console Head
    final readerPath = Path()
      ..moveTo(4.0, 12.0)
      ..lineTo(14.0, 2.0)
      ..lineTo(36.0, 2.0)
      ..lineTo(38.0, 12.0)
      ..close();
    canvas.drawPath(readerPath, _steelBodyPaint);
    canvas.drawPath(readerPath, _steelBorderPaint);

    // Dark screen bezel
    const screenRect = Rect.fromLTWH(12.0, 4.0, 20.0, 7.0);
    canvas.drawRect(screenRect, _readerBezelPaint);

    // MetroCard yellow swipe slot
    canvas.drawLine(const Offset(14.0, 9.0), const Offset(28.0, 9.0), _slotPaint);

    // 4. LED Transit Validation Indicator
    final isFlashing = _swipeFlashTimer > 0;
    final Color ledColor;
    if (isFlashing) {
      ledColor = const Color(0xFF00E676); // Emerald validated green
    } else {
      final pulse = (0.5 + 0.5 * math.sin(_pulseTimer)).clamp(0.2, 1.0);
      ledColor = Color.lerp(const Color(0xFF00B0FF), const Color(0xFF00E5FF), pulse)!;
    }

    final ledPaint = Paint()
      ..color = ledColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(24.0, 6.0), 2.2, ledPaint);

    if (isFlashing) {
      // Glow halo
      final glowPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(const Offset(24.0, 6.0), 5.0, glowPaint);
    }

    // 5. Tripod Mechanical Barrier Arms
    const rotorCenter = Offset(34.0, 26.0);

    canvas.save();
    canvas.translate(rotorCenter.dx, rotorCenter.dy);
    canvas.rotate(_armRotation);

    // 3 arms at 120-degree intervals (2 * pi / 3 = ~2.094 rad)
    const armLength = 25.0;
    for (var i = 0; i < 3; i++) {
      final angle = i * (2 * math.pi / 3);
      final armEndX = math.cos(angle) * armLength;
      final armEndY = math.sin(angle) * armLength;

      // Drop shadow for tubular steel arm
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(0, 2.0), Offset(armEndX, armEndY + 2.0), shadowPaint);

      // Stainless steel tubular arm
      canvas.drawLine(Offset.zero, Offset(armEndX, armEndY), _armPaint);

      // Rubber end safety cap
      canvas.drawCircle(Offset(armEndX, armEndY), 2.8, _armCapPaint);
    }

    // Central rotor hub
    canvas.drawCircle(Offset.zero, 6.0, _rotorHubPaint);
    canvas.drawCircle(Offset.zero, 2.5, _steelHighlightPaint);
    canvas.restore();

    // 6. Directional Green Entry Arrow on front pillar face
    final arrowPaint = Paint()
      ..color = isFlashing ? const Color(0xFF00E676) : const Color(0xFF4CAF50).withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final arrowPath = Path()
      ..moveTo(17.0, 24.0)
      ..lineTo(21.0, 20.0)
      ..lineTo(25.0, 24.0)
      ..moveTo(21.0, 20.0)
      ..lineTo(21.0, 32.0);
    canvas.drawPath(arrowPath, arrowPaint);
  }
}
