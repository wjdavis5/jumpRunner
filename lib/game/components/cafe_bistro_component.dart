import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Sidewalk outdoor dining patio cafe bistro fixture featuring a Parisian round bistro table
/// with an ornate wrought-iron pedestal base, red-and-white checkered tablecloth with draped hem,
/// miniature porcelain espresso cup on saucer, and flanking woven rattan patio chairs.
///
/// Hurdle vaulting across the bistro table triggers a kinetic burst of shattered porcelain shards
/// and foaming espresso droplets, activating an energetic Caffeine Surge (+18% speed boost).
class CafeBistroComponent extends PositionComponent {
  CafeBistroComponent({
    required Vector2 position,
    double width = 78.0,
    double height = 56.0,
    this.groundY = 460.0,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onVault;

  bool hasVaulted = false;
  double _wobbleTimer = 0.0;

  /// Top surface baseline Y of the bistro tabletop in world coordinates.
  double get tabletopWorldY => groundY - 30.0;

  /// World space coordinate at the bistro tabletop apex for particle bursts.
  Vector2 get tabletopApexWorld => Vector2(position.x + (size.x / 2), tabletopWorldY);

  /// Center point of the cafe bistro fixture in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the fixture has scrolled past the active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _ironBasePaint = Paint()
    ..color = const Color(0xFF212121) // Wrought-iron black
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _ironFillPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _tabletopWoodPaint = Paint()
    ..color = const Color(0xFF5D4037)
    ..style = PaintingStyle.fill;

  static final Paint _checkeredRedPaint = Paint()
    ..color = const Color(0xFFD32F2F) // Classic Parisian bistro checkered red
    ..style = PaintingStyle.fill;

  static final Paint _checkeredWhitePaint = Paint()
    ..color = const Color(0xFFFAFAFA) // Crisp white cloth
    ..style = PaintingStyle.fill;

  static final Paint _clothTrimPaint = Paint()
    ..color = const Color(0xFFB71C1C)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _chairRattanPaint = Paint()
    ..color = const Color(0xFFD7CCC8) // Woven bistro chair rattan
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _chairLegPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  static final Paint _porcelainPaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill;

  static final Paint _espressoPaint = Paint()
    ..color = const Color(0xFF3E2723)
    ..style = PaintingStyle.fill;

  static final Paint _cremaPaint = Paint()
    ..color = const Color(0xFFFFE082)
    ..style = PaintingStyle.fill;

  static final Paint _handlePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  @override
  void update(double dt) {
    super.update(dt);

    if (_wobbleTimer > 0) {
      _wobbleTimer = math.max(0.0, _wobbleTimer - dt);
    }
  }

  /// Evaluates whether an airborne courier vaults across the bistro table.
  bool checkVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted) return false;

    // Must be actively airborne to hurdle vault
    if (simulator.isGrounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Hurdle vault window around tabletop level
    final vaultTop = tabletopWorldY - 14.0;
    final vaultBottom = tabletopWorldY + 18.0;
    final inVaultWindow = (footY >= vaultTop) && (footY <= vaultBottom);

    if (inVaultWindow) {
      hasVaulted = true;
      _wobbleTimer = 0.40;
      simulator.launch(200.0); // Crisp parkour vault launch
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

    canvas.save();
    if (_wobbleTimer > 0) {
      final wobbleAngle = math.sin(_wobbleTimer * 28.0) * (_wobbleTimer / 0.40) * 0.05;
      canvas.translate(w / 2, h);
      canvas.rotate(wobbleAngle);
      canvas.translate(-w / 2, -h);
    }

    // 1. Flanking Parisian woven chairs
    _renderChairs(canvas, w, h);

    // 2. Wrought-iron pedestal table base & center column
    _renderTableBase(canvas, w, h);

    // 3. Red-and-white checkered tablecloth and drape
    _renderTablecloth(canvas, w, h);

    // 4. Miniature porcelain espresso cup with saucer
    _renderEspressoCup(canvas, w, h);

    canvas.restore();
  }

  void _renderChairs(Canvas canvas, double w, double h) {
    // Left chair
    const leftSeatX = 4.0;
    const seatW = 14.0;
    const seatY = 36.0;

    // Legs
    canvas.drawLine(const Offset(leftSeatX + 2.0, seatY), Offset(leftSeatX, h), _chairLegPaint);
    canvas.drawLine(const Offset(leftSeatX + seatW - 2.0, seatY), Offset(leftSeatX + seatW, h), _chairLegPaint);

    // Rattan woven seat
    canvas.drawLine(const Offset(leftSeatX, seatY), const Offset(leftSeatX + seatW, seatY), _chairRattanPaint);

    // Curved chair backrest
    final leftBack = Path()
      ..moveTo(leftSeatX + 1.0, seatY)
      ..quadraticBezierTo(leftSeatX - 2.0, 20.0, leftSeatX + 6.0, 18.0)
      ..quadraticBezierTo(leftSeatX + 12.0, 20.0, leftSeatX + 9.0, seatY);
    canvas.drawPath(leftBack, _chairRattanPaint);

    // Right chair
    final rightSeatX = w - 18.0;

    // Legs
    canvas.drawLine(Offset(rightSeatX + 2.0, seatY), Offset(rightSeatX, h), _chairLegPaint);
    canvas.drawLine(Offset(rightSeatX + seatW - 2.0, seatY), Offset(rightSeatX + seatW, h), _chairLegPaint);

    // Rattan seat
    canvas.drawLine(Offset(rightSeatX, seatY), Offset(rightSeatX + seatW, seatY), _chairRattanPaint);

    // Curved backrest
    final rightBack = Path()
      ..moveTo(rightSeatX + seatW - 1.0, seatY)
      ..quadraticBezierTo(rightSeatX + seatW + 2.0, 20.0, rightSeatX + seatW - 6.0, 18.0)
      ..quadraticBezierTo(rightSeatX + 2.0, 20.0, rightSeatX + 5.0, seatY);
    canvas.drawPath(rightBack, _chairRattanPaint);
  }

  void _renderTableBase(Canvas canvas, double w, double h) {
    final centerX = w / 2;

    // Center iron column pole
    canvas.drawLine(Offset(centerX, 28.0), Offset(centerX, h - 5.0), _ironBasePaint);

    // Wrought-iron tripod base feet
    final leftFoot = Path()
      ..moveTo(centerX, h - 5.0)
      ..quadraticBezierTo(centerX - 8.0, h - 4.0, centerX - 15.0, h);
    canvas.drawPath(leftFoot, _ironBasePaint);

    final rightFoot = Path()
      ..moveTo(centerX, h - 5.0)
      ..quadraticBezierTo(centerX + 8.0, h - 4.0, centerX + 15.0, h);
    canvas.drawPath(rightFoot, _ironBasePaint);

    // Center foot ball
    canvas.drawCircle(Offset(centerX, h - 1.5), 2.2, _ironFillPaint);
  }

  void _renderTablecloth(Canvas canvas, double w, double h) {
    final centerX = w / 2;
    const tableW = 38.0;
    const tableTopY = 24.0;
    const drapeH = 9.0;

    final tableLeft = centerX - (tableW / 2);

    // Wooden tabletop substrate
    final topRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tableLeft, tableTopY, tableW, 4.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(topRect, _tabletopWoodPaint);

    // Checkered tablecloth drape
    const squareSize = 4.2;
    const cols = 9;
    const rows = 3;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final sx = tableLeft + (c * squareSize);
        final sy = tableTopY + (r * (drapeH / rows));
        final isRed = (r + c) % 2 == 0;
        final paint = isRed ? _checkeredRedPaint : _checkeredWhitePaint;

        canvas.drawRect(
          Rect.fromLTWH(sx, sy, squareSize, drapeH / rows),
          paint,
        );
      }
    }

    // Scalloped bottom tassel hem
    for (var i = 0; i < cols; i++) {
      final hx = tableLeft + (i * squareSize) + (squareSize / 2);
      canvas.drawCircle(Offset(hx, tableTopY + drapeH), 1.2, _checkeredWhitePaint);
    }

    // Cloth edge outline
    canvas.drawLine(
      Offset(tableLeft, tableTopY + drapeH),
      Offset(tableLeft + tableW, tableTopY + drapeH),
      _clothTrimPaint,
    );
  }

  void _renderEspressoCup(Canvas canvas, double w, double h) {
    final cupX = (w / 2) - 1.0;
    const cupY = 22.0;

    // Small white porcelain saucer
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cupX, cupY + 2.0), width: 9.0, height: 2.2),
      _porcelainPaint,
    );

    // Miniature espresso cup bowl
    final cupRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cupX - 3.0, cupY - 3.5, 6.0, 5.0),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(cupRect, _porcelainPaint);

    // Espresso liquid & crema layer
    canvas.drawOval(
      Rect.fromLTWH(cupX - 2.2, cupY - 3.5, 4.4, 1.8),
      _espressoPaint,
    );
    canvas.drawCircle(Offset(cupX + 0.5, cupY - 2.6), 0.8, _cremaPaint);

    // Curved porcelain handle
    canvas.drawArc(
      Rect.fromLTWH(cupX + 2.8, cupY - 2.8, 2.4, 3.2),
      -math.pi / 2,
      math.pi,
      false,
      _handlePaint,
    );
  }
}
