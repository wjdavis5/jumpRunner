import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street-level heavy municipal postal drop collection mailbox along city sidewalks.
///
/// Features a rounded-dome blue steel cabinet, 4 curved anchor legs, drop chute handle,
/// collection schedule placard, and vibrating mail chute flap recoil upon hurdle vault.
class PostalMailboxComponent extends PositionComponent {
  PostalMailboxComponent({
    required Vector2 position,
    double width = 42.0,
    double height = 54.0,
    this.groundY = 460.0,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onVault;

  bool hasVaulted = false;
  double _chuteVibration = 0.0;
  double _chuteTimer = 0.0;

  /// Top surface baseline Y of the rounded mailbox dome in world coordinates.
  double get vaultTopWorldY => groundY - size.y;

  /// World space coordinate at the drop chute opening for particle alignment.
  Vector2 get chuteWorldPosition => Vector2(position.x + (size.x / 2), position.y + 12.0);

  /// Center point of the mailbox in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the mailbox has scrolled offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _boxBodyPaint = Paint()
    ..color = const Color(0xFF0D47A1) // Municipal postal deep blue
    ..style = PaintingStyle.fill;

  static final Paint _boxHighlightPaint = Paint()
    ..color = const Color(0xFF1976D2)
    ..style = PaintingStyle.fill;

  static final Paint _legPaint = Paint()
    ..color = const Color(0xFF263238)
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _footPadPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  static final Paint _chuteHandlePaint = Paint()
    ..color = const Color(0xFFCFD8DC) // Chrome pull handle
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _placardPaint = Paint()
    ..color = const Color(0xFFECEFF1)
    ..style = PaintingStyle.fill;

  static final Paint _placardLinePaint = Paint()
    ..color = const Color(0xFF78909C)
    ..strokeWidth = 1.0;

  static final Paint _chevronRedPaint = Paint()
    ..color = const Color(0xFFD32F2F)
    ..style = PaintingStyle.fill;

  static final Paint _chevronWhitePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    if (hasVaulted && _chuteVibration > 0.0) {
      _chuteTimer += dt;
      _chuteVibration -= dt * 3.5;
      if (_chuteVibration < 0.0) _chuteVibration = 0.0;
    }
  }

  /// Evaluates whether an airborne courier vaults cleanly over the rounded mailbox dome.
  bool checkVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted) return false;

    // Must be actively airborne to hurdle-vault over the mailbox
    if (simulator.isGrounded) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    // Horizontal overlap with mailbox footprint
    final inHorizontal = playerRight >= position.x + 4.0 && playerLeft <= position.x + size.x - 4.0;

    // Foot clears top dome of mailbox
    final clearsTop = footY <= vaultTopWorldY + 12.0 && footY >= vaultTopWorldY - 50.0;

    if (inHorizontal && clearsTop) {
      hasVaulted = true;
      _chuteVibration = 1.0;
      onVault?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    final chuteDeflection = math.sin(_chuteTimer * 24.0) * (_chuteVibration * 4.5);

    // 1. Curved Steel Anchor Legs (4 Corner Feet)
    const legTopY = 46.0;
    final baselineY = h;

    // Left and Right legs
    canvas.drawLine(const Offset(6.0, legTopY), Offset(3.0, baselineY), _legPaint);
    canvas.drawLine(Offset(w - 6.0, legTopY), Offset(w - 3.0, baselineY), _legPaint);
    canvas.drawRect(Rect.fromLTWH(1.0, baselineY - 3.0, 6.0, 3.0), _footPadPaint);
    canvas.drawRect(Rect.fromLTWH(w - 7.0, baselineY - 3.0, 6.0, 3.0), _footPadPaint);

    // 2. Main Steel Cabinet Body
    const bodyTopY = 12.0;
    const bodyHeight = 35.0;
    final bodyRect = Rect.fromLTWH(3.0, bodyTopY, w - 6.0, bodyHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3.0)),
      _boxBodyPaint,
    );

    // Front panel bevel highlight
    final frontRect = Rect.fromLTWH(6.0, bodyTopY + 2.0, w - 12.0, bodyHeight - 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frontRect, const Radius.circular(2.0)),
      _boxHighlightPaint,
    );

    // 3. Rounded Dome Top Cap
    final domePath = Path()
      ..moveTo(3.0, bodyTopY)
      ..cubicTo(
        3.0,
        0.0,
        w - 3.0,
        0.0,
        w - 3.0,
        bodyTopY,
      )
      ..close();
    canvas.drawPath(domePath, _boxBodyPaint);

    // 4. Drop Chute Faceplate & Pull Handle with Vibration Deflection
    canvas.save();
    canvas.translate(0.0, chuteDeflection);

    final chuteRect = Rect.fromLTWH(8.0, 6.0, w - 16.0, 10.0);
    final chutePaint = Paint()
      ..color = const Color(0xFF0A387E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(chuteRect, const Radius.circular(2.0)), chutePaint);

    // Chrome Pull Handle
    canvas.drawLine(
      const Offset(12.0, 11.0),
      Offset(w - 12.0, 11.0),
      _chuteHandlePaint,
    );

    canvas.restore();

    // 5. White Collection Pickup Schedule Placard
    final placardRect = Rect.fromLTWH(9.0, 20.0, w - 18.0, 15.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(placardRect, const Radius.circular(1.5)),
      _placardPaint,
    );

    // Placard schedule text simulated lines
    canvas.drawLine(const Offset(12.0, 23.0), Offset(w - 12.0, 23.0), _placardLinePaint);
    canvas.drawLine(const Offset(12.0, 26.5), Offset(w - 12.0, 26.5), _placardLinePaint);
    canvas.drawLine(const Offset(12.0, 30.0), Offset(w - 16.0, 30.0), _placardLinePaint);

    // 6. Express Airmail Red & White Chevron Band at Base
    const chevronY = bodyTopY + bodyHeight - 5.0;
    const chevronHeight = 4.0;
    final chevronRect = Rect.fromLTWH(3.0, chevronY, w - 6.0, chevronHeight);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(chevronRect, const Radius.circular(1.0)));
    canvas.drawRect(chevronRect, _chevronRedPaint);

    for (var cx = -chevronHeight; cx < w + chevronHeight; cx += 8.0) {
      final path = Path()
        ..moveTo(cx, chevronY)
        ..lineTo(cx + 4.0, chevronY)
        ..lineTo(cx + 4.0 - chevronHeight, chevronY + chevronHeight)
        ..lineTo(cx - chevronHeight, chevronY + chevronHeight)
        ..close();
      canvas.drawPath(path, _chevronWhitePaint);
    }
    canvas.restore();
  }
}
