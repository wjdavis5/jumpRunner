import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Rooftop elevated wooden cedar water tower featuring structural steel lattice trestle legs,
/// cylindrical wooden stave barrel vat with iron tension bands, conical cedar shingled roof,
/// and copper spire finial.
///
/// Traversal options:
/// 1. Catwalk aerial apex launch: leaping off the catwalk platform launches into high aerial glide (+300 px/s).
/// 2. Timber stave breach: high-speed or stomping impact breaches the cedar vat, unleashing a rushing
///    torrent of water (+240 px/s forward momentum boost).
class WaterTowerComponent extends PositionComponent {
  WaterTowerComponent({
    required Vector2 position,
    double width = 86.0,
    double height = 110.0,
    this.groundY = 460.0,
    this.onTraverse,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final void Function({required bool isBreach})? onTraverse;

  bool hasTriggered = false;
  bool isBreached = false;
  double _wobbleTimer = 0.0;
  double _dripTimer = 0.0;

  /// Top surface baseline Y of the elevated catwalk platform in world coordinates.
  double get catwalkWorldY => groundY - size.y + 60.0;

  /// World space coordinate at the water tower apex for launch alignment.
  Vector2 get apexWorldPosition => Vector2(position.x + (size.x / 2), position.y + 6.0);

  /// World space coordinate at the water breach spout for deluge particle bursts.
  Vector2 get breachWorldPosition => Vector2(position.x + (size.x / 2), groundY - 45.0);

  /// Center point of the water tower in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the water tower has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _steelTrestlePaint = Paint()
    ..color = const Color(0xFF263238) // Weathered dark steel
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _steelCrossPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  static final Paint _woodVatPaint = Paint()
    ..color = const Color(0xFF795548) // Weathered cedar timber
    ..style = PaintingStyle.fill;

  static final Paint _woodStavePaint = Paint()
    ..color = const Color(0xFF5D4037)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _ironBandPaint = Paint()
    ..color = const Color(0xFF212121) // Iron tension hoops
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke;

  static final Paint _roofCedarPaint = Paint()
    ..color = const Color(0xFF6D4C41)
    ..style = PaintingStyle.fill;

  static final Paint _roofShinglePaint = Paint()
    ..color = const Color(0xFF4E342E)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _copperSpirePaint = Paint()
    ..color = const Color(0xFF26A69A) // Oxidized verdigris copper
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _copperSpireBallPaint = Paint()
    ..color = const Color(0xFF80CBC4)
    ..style = PaintingStyle.fill;

  static final Paint _catwalkPaint = Paint()
    ..color = const Color(0xFF455A64)
    ..style = PaintingStyle.fill;

  static final Paint _dripPaint = Paint()
    ..color = const Color(0xFF80DEEA).withValues(alpha: 0.8)
    ..style = PaintingStyle.fill;

  static final Paint _waterSpillPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.75)
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  void update(double dt) {
    super.update(dt);

    if (_wobbleTimer > 0) {
      _wobbleTimer = math.max(0.0, _wobbleTimer - dt);
    }

    _dripTimer = (_dripTimer + dt * 2.5) % 1.0;
  }

  /// Evaluates whether an airborne courier interacts with the water tower,
  /// executing either an elevated catwalk aerial launch or a timber stave breach cascade.
  bool checkTraverse(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasTriggered) return false;

    // Must be actively airborne to interact with the water tower
    if (simulator.isGrounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final courierBottom = simulator.currentY;

    final towerLeft = position.x;
    final towerRight = position.x + size.x;
    final towerTop = groundY - size.y;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= towerLeft + 6.0) && (courierLeft <= towerRight - 6.0);
    if (!horizontalOverlap) return false;

    // 1. High Catwalk Traversal Window (near catwalk / roof level)
    final catwalkTop = catwalkWorldY;
    final isCatwalkWindow = (courierBottom >= towerTop - 15.0) && (courierBottom <= catwalkTop + 18.0);

    if (isCatwalkWindow) {
      hasTriggered = true;
      _wobbleTimer = 0.45;
      simulator.launch(300.0); // High-altitude aerial glide loft
      onTraverse?.call(isBreach: false);
      return true;
    }

    // 2. Timber Stave Breach Window (impacting the lower vat or trestle while traveling downward)
    final isBreachWindow = (courierBottom > catwalkTop + 18.0) &&
        (courierBottom <= groundY - 10.0) &&
        (simulator.verticalVelocity <= 60.0);

    if (isBreachWindow) {
      hasTriggered = true;
      isBreached = true;
      _wobbleTimer = 0.65;
      simulator.launch(180.0);
      onTraverse?.call(isBreach: true);
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
      final wobbleAngle = math.sin(_wobbleTimer * 26.0) * (_wobbleTimer / 0.65) * 0.04;
      canvas.translate(w / 2, h);
      canvas.rotate(wobbleAngle);
      canvas.translate(-w / 2, -h);
    }

    // 1. Steel lattice trestle legs & cross-bracing
    _renderTrestleLegs(canvas, w, h);

    // 2. Catwalk observation railing
    _renderCatwalk(canvas, w, h);

    // 3. Wooden cedar barrel vat & iron hoops
    _renderWoodenVat(canvas, w, h);

    // 4. Conical cedar roof & oxidized copper spire
    _renderConicalRoof(canvas, w, h);

    // 5. Overflow pipe spout & ambient dripping water
    _renderOverflowSpout(canvas, w, h);

    canvas.restore();
  }

  void _renderTrestleLegs(Canvas canvas, double w, double h) {
    const legTopY = 62.0;
    final legBottomY = h;

    const leftTopX = 16.0;
    const leftBottomX = 8.0;
    final rightTopX = w - 16.0;
    final rightBottomX = w - 8.0;

    // Main 4 vertical/slanted steel support pillars
    canvas.drawLine(const Offset(leftTopX, legTopY), Offset(leftBottomX, legBottomY), _steelTrestlePaint);
    canvas.drawLine(Offset(rightTopX, legTopY), Offset(rightBottomX, legBottomY), _steelTrestlePaint);

    // Center internal cross-braces
    canvas.drawLine(const Offset(leftTopX, legTopY), Offset(rightBottomX, legBottomY), _steelCrossPaint);
    canvas.drawLine(Offset(rightTopX, legTopY), Offset(leftBottomX, legBottomY), _steelCrossPaint);

    // Horizontal steel tie beams
    const midY1 = legTopY + (110.0 - legTopY) * 0.35;
    const midY2 = legTopY + (110.0 - legTopY) * 0.70;

    const x1Left = leftTopX + (leftBottomX - leftTopX) * 0.35;
    final x1Right = rightTopX + (rightBottomX - rightTopX) * 0.35;
    canvas.drawLine(const Offset(x1Left, midY1), Offset(x1Right, midY1), _steelCrossPaint);

    const x2Left = leftTopX + (leftBottomX - leftTopX) * 0.70;
    final x2Right = rightTopX + (rightBottomX - rightTopX) * 0.70;
    canvas.drawLine(const Offset(x2Left, midY2), Offset(x2Right, midY2), _steelCrossPaint);
  }

  void _renderCatwalk(Canvas canvas, double w, double h) {
    // Horizontal steel walkway platform under the vat
    final catwalkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4.0, 58.0, w - 8.0, 5.0),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(catwalkRect, _catwalkPaint);

    // Catwalk guardrails
    final railingPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(4.0, 51.0), Offset(w - 4.0, 51.0), railingPaint);
    canvas.drawLine(const Offset(10.0, 51.0), const Offset(10.0, 58.0), railingPaint);
    canvas.drawLine(Offset(w - 10.0, 51.0), Offset(w - 10.0, 58.0), railingPaint);
    canvas.drawLine(Offset(w / 2, 51.0), Offset(w / 2, 58.0), railingPaint);
  }

  void _renderWoodenVat(Canvas canvas, double w, double h) {
    const vatX = 14.0;
    final vatW = w - 28.0;
    const vatY = 22.0;
    const vatH = 37.0;

    // Cedar vat background
    final vatRect = Rect.fromLTWH(vatX, vatY, vatW, vatH);
    canvas.drawRect(vatRect, _woodVatPaint);

    // Vertical wooden stave plank lines
    const staveCount = 9;
    final staveW = vatW / staveCount;
    for (var i = 1; i < staveCount; i++) {
      final sx = vatX + i * staveW;
      canvas.drawLine(Offset(sx, vatY), Offset(sx, vatY + vatH), _woodStavePaint);
    }

    // 3 Horizontal dark iron tension bands
    const bandY1 = vatY + vatH * 0.20;
    const bandY2 = vatY + vatH * 0.50;
    const bandY3 = vatY + vatH * 0.80;

    canvas.drawLine(const Offset(vatX - 1.0, bandY1), Offset(vatX + vatW + 1.0, bandY1), _ironBandPaint);
    canvas.drawLine(const Offset(vatX - 1.0, bandY2), Offset(vatX + vatW + 1.0, bandY2), _ironBandPaint);
    canvas.drawLine(const Offset(vatX - 1.0, bandY3), Offset(vatX + vatW + 1.0, bandY3), _ironBandPaint);

    // Side maintenance access ladder
    const ladderX = vatX + 3.0;
    final ladderPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(ladderX, vatY - 4.0), const Offset(ladderX, vatY + vatH), ladderPaint);
    canvas.drawLine(const Offset(ladderX + 4.0, vatY - 4.0), const Offset(ladderX + 4.0, vatY + vatH), ladderPaint);
    for (var ly = vatY; ly <= vatY + vatH; ly += 6.0) {
      canvas.drawLine(Offset(ladderX, ly), Offset(ladderX + 4.0, ly), ladderPaint);
    }

    // If breached, draw fractured timber breach hole with rushing water spray
    if (isBreached) {
      final breachPaint = Paint()
        ..color = const Color(0xFF1B0000)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(vatX + vatW * 0.65, vatY + vatH * 0.70), 6.5, breachPaint);

      // Water rushing out of hole
      canvas.drawLine(
        Offset(vatX + vatW * 0.65, vatY + vatH * 0.70),
        Offset(vatX + vatW * 0.65 + 14.0, vatY + vatH * 0.70 + 12.0),
        _waterSpillPaint,
      );
    }
  }

  void _renderConicalRoof(Canvas canvas, double w, double h) {
    const roofBaseY = 22.0;
    const roofApexY = 7.0;
    final apexX = w / 2;
    const leftX = 12.0;
    final rightX = w - 12.0;

    // Conical roof triangle
    final roofPath = Path()
      ..moveTo(leftX, roofBaseY)
      ..lineTo(apexX, roofApexY)
      ..lineTo(rightX, roofBaseY)
      ..close();
    canvas.drawPath(roofPath, _roofCedarPaint);

    // Shingle lines radiating from apex
    canvas.drawLine(Offset(apexX, roofApexY), const Offset(20.0, roofBaseY), _roofShinglePaint);
    canvas.drawLine(Offset(apexX, roofApexY), const Offset(34.0, roofBaseY), _roofShinglePaint);
    canvas.drawLine(Offset(apexX, roofApexY), Offset(w / 2, roofBaseY), _roofShinglePaint);
    canvas.drawLine(Offset(apexX, roofApexY), Offset(w - 34.0, roofBaseY), _roofShinglePaint);
    canvas.drawLine(Offset(apexX, roofApexY), Offset(w - 20.0, roofBaseY), _roofShinglePaint);

    // Copper spire finial at apex
    canvas.drawLine(Offset(apexX, roofApexY), Offset(apexX, 1.0), _copperSpirePaint);
    canvas.drawCircle(Offset(apexX, 1.5), 2.2, _copperSpireBallPaint);
  }

  void _renderOverflowSpout(Canvas canvas, double w, double h) {
    // Metal drainage spout on right edge of vat
    final spoutX = w - 14.0;
    const spoutY = 32.0;

    final spoutPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(spoutX, spoutY), Offset(spoutX + 5.0, spoutY), spoutPaint);
    canvas.drawLine(Offset(spoutX + 5.0, spoutY), Offset(spoutX + 5.0, spoutY + 4.0), spoutPaint);

    // Periodic animated water drip
    final dripY = spoutY + 4.0 + (_dripTimer * 18.0);
    canvas.drawCircle(Offset(spoutX + 5.0, dripY), 1.5, _dripPaint);
  }
}
