import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'courier_player.dart';

/// Interactive residential porch stoop and parcel drop-off zone.
///
/// Runners passing through active drop zones deliver customer parcels,
/// earning instant cash tips, 5-star ratings, and advancing their delivery streak.
class DropZoneComponent extends PositionComponent {
  DropZoneComponent({
    required Vector2 position,
    Vector2? size,
    this.groundY = 460.0,
    this.isVip = false,
  }) : super(
          position: position,
          size: size ?? Vector2(68.0, 70.0),
        );

  final double groundY;
  final bool isVip;

  /// Whether this drop zone has already completed its delivery for this pass.
  bool hasDelivered = false;

  /// Whether this prop has scrolled off the left edge of the screen.
  bool get shouldRecycle => position.x + size.x < -120.0;

  double _pulseTimer = 0.0;

  static final Paint _stoopStonePaint = Paint()..color = const Color(0xFF4A4E54);
  static final Paint _stoopStepPaint = Paint()..color = const Color(0xFF5D636B);
  static final Paint _doorPaint = Paint()..color = const Color(0xFF6C3428);
  static final Paint _doorTrimPaint = Paint()
    ..color = const Color(0xFF8B4513)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _matPaint = Paint()..color = const Color(0xFF1ABC9C);
  static final Paint _beaconGlowPaint = Paint()
    ..color = const Color(0x3300E5FF)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt * 3.5;
  }

  /// Determines whether the courier has entered the drop-off zone footprint.
  bool checkCollisionWith(CourierPlayer player) {
    if (hasDelivered) return false;

    final playerLeft = player.position.x;
    final playerRight = player.position.x + player.size.x;
    final playerBottom = player.simulator.currentY;

    final zoneLeft = position.x;
    final zoneRight = position.x + size.x;
    final zoneTop = position.y;
    final zoneBottom = position.y + size.y;

    // Contact occurs when courier runs past the porch stoop at street level
    final overlapsHorizontally = (playerRight >= zoneLeft + 10.0 && playerLeft <= zoneRight - 10.0);
    final overlapsVertically = (playerBottom >= zoneTop && playerBottom <= zoneBottom + 16.0);

    return overlapsHorizontally && overlapsVertically;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    if (isVip) {
      // 1. VIP Luxury Penthouse / Hotel Lobby Entrance
      final doorRect = Rect.fromLTWH(w * 0.22, 0, w * 0.56, h * 0.65);
      final vipDoorPaint = Paint()..color = const Color(0xFF1A1A1D);
      final vipDoorTrimPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(doorRect, vipDoorPaint);
      canvas.drawRect(doorRect, vipDoorTrimPaint);

      // Gold Double Handles
      final goldHandlePaint = Paint()..color = const Color(0xFFFFD700);
      canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.28, 2.5, 12), goldHandlePaint);
      canvas.drawRect(Rect.fromLTWH(w * 0.51, h * 0.28, 2.5, 12), goldHandlePaint);

      // Dark Polished Marble Steps
      final stepHeight = (h * 0.35) / 3;
      final marbleDark = Paint()..color = const Color(0xFF2C3E50);
      final marbleLight = Paint()..color = const Color(0xFF34495E);
      for (int i = 0; i < 3; i++) {
        final stepWidth = w * (0.6 + (i * 0.2));
        final stepX = (w - stepWidth) / 2;
        final stepY = h * 0.65 + (i * stepHeight);
        final stepRect = Rect.fromLTWH(stepX, stepY, stepWidth, stepHeight);
        canvas.drawRect(stepRect, i.isEven ? marbleDark : marbleLight);
      }

      // Plush Red Carpet Cascading Down Steps
      final carpetPaint = Paint()..color = const Color(0xFFC0392B);
      final carpetTrimPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final carpetRect = Rect.fromLTWH(w * 0.30, h * 0.65, w * 0.40, h * 0.35);
      canvas.drawRect(carpetRect, carpetPaint);
      canvas.drawRect(carpetRect, carpetTrimPaint);

      // Gold Stanchions & Velvet Ropes on Left & Right
      final stanchionPaint = Paint()..color = const Color(0xFFFFD700);
      canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.60, 3, h * 0.40), stanchionPaint);
      canvas.drawCircle(Offset(w * 0.12 + 1.5, h * 0.60), 3.5, stanchionPaint);
      canvas.drawRect(Rect.fromLTWH(w * 0.85, h * 0.60, 3, h * 0.40), stanchionPaint);
      canvas.drawCircle(Offset(w * 0.85 + 1.5, h * 0.60), 3.5, stanchionPaint);

      final ropePaint = Paint()
        ..color = const Color(0xFF922B21)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final ropePath = Path()
        ..moveTo(w * 0.12 + 1.5, h * 0.62)
        ..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.85 + 1.5, h * 0.62);
      canvas.drawPath(ropePath, ropePaint);
    } else {
      // 1. Standard Brownstone Stoop Architectural Facade & Door
      final doorRect = Rect.fromLTWH(w * 0.25, 0, w * 0.5, h * 0.65);
      canvas.drawRect(doorRect, _doorPaint);
      canvas.drawRect(doorRect, _doorTrimPaint);

      // Brass door handle
      final handlePaint = Paint()..color = const Color(0xFFF1C40F);
      canvas.drawCircle(Offset(w * 0.65, h * 0.35), 2.5, handlePaint);

      // Stoop Steps (3 ascending tiers)
      final stepHeight = (h * 0.35) / 3;
      for (int i = 0; i < 3; i++) {
        final stepWidth = w * (0.6 + (i * 0.2));
        final stepX = (w - stepWidth) / 2;
        final stepY = h * 0.65 + (i * stepHeight);
        final stepRect = Rect.fromLTWH(stepX, stepY, stepWidth, stepHeight);
        canvas.drawRect(stepRect, i.isEven ? _stoopStonePaint : _stoopStepPaint);
      }

      // Woven Parcel Delivery Mat
      final matRect = Rect.fromLTWH(w * 0.15, h - 5.0, w * 0.7, 5.0);
      canvas.drawRect(matRect, _matPaint);
    }

    // 2. Holographic Destination Beacon & Floating Chevrons
    final pulse = (math.sin(_pulseTimer) + 1.0) / 2.0; // 0.0 .. 1.0
    final beaconColor = hasDelivered
        ? const Color(0x332ECC71)
        : (isVip ? const Color(0xFFFFD700) : const Color(0xFF00E5FF));

    // Vertical holographic light column
    _beaconGlowPaint.color =
        beaconColor.withValues(alpha: hasDelivered ? 0.1 : (0.15 + (0.15 * pulse)));
    final beamRect = Rect.fromLTWH(w * 0.18, -35.0, w * 0.64, h + 35.0);
    canvas.drawRect(beamRect, _beaconGlowPaint);

    // Animated downward chevron indicator
    if (!hasDelivered) {
      final chevronY = -10.0 + (pulse * 12.0);
      final chevronPaint = Paint()
        ..color = (isVip ? const Color(0xFFFFD700) : const Color(0xFFF1C40F))
            .withValues(alpha: 0.7 + (0.3 * pulse))
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(w * 0.35, chevronY)
        ..lineTo(w * 0.5, chevronY + 8.0)
        ..lineTo(w * 0.65, chevronY);
      canvas.drawPath(path, chevronPaint);

      // Holographic "DROP" or "VIP DROP" text indicator
      final label = isVip ? 'VIP DROP' : 'DROP';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: (isVip ? const Color(0xFFFFD700) : const Color(0xFF00E5FF))
                .withValues(alpha: 0.85 + (0.15 * pulse)),
            fontSize: isVip ? 9.5 : 10.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((w - textPainter.width) / 2, chevronY - 14.0));
    } else {
      // Completed checkmark
      final checkPaint = Paint()
        ..color = const Color(0xFF2ECC71)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final checkPath = Path()
        ..moveTo(w * 0.35, -5.0)
        ..lineTo(w * 0.48, 4.0)
        ..lineTo(w * 0.68, -12.0);
      canvas.drawPath(checkPath, checkPaint);
    }
  }
}
