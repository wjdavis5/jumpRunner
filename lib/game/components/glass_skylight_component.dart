import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Elevated rooftop architectural glass skylight atrium dome featuring reinforced
/// steel glazing bars, translucent cyan tempered glass panes, and specular reflection glints.
///
/// Airborne couriers plunging or hurdle-leaping through the skylight smash the glass
/// in an explosive shower of glittering diamond crystal shards, executing an instant
/// high-velocity parkour breach and awarding bonus tips and stunt multipliers.
class GlassSkylightComponent extends PositionComponent {
  GlassSkylightComponent({
    required Vector2 position,
    double width = 80.0,
    double height = 36.0,
    this.groundY,
    this.onSmash,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double? groundY;
  final VoidCallback? onSmash;

  bool hasShattered = false;
  double _sheenTimer = 0.0;
  double _fractureVibration = 0.0;

  /// Top apex ridge of the pitched skylight glazing in world coordinates.
  double get apexWorldY => position.y;

  /// World space coordinate at the center apex where crystal shards burst upon smash-through.
  Vector2 get shatterWorldPosition => Vector2(position.x + (size.x / 2), position.y + 8.0);

  /// Center point of the skylight assembly in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the skylight component has scrolled offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _curbPaint = Paint()
    ..color = const Color(0xFF263238) // Dark structural curbing
    ..style = PaintingStyle.fill;

  static final Paint _curbHighlightPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  static final Paint _ironFramePaint = Paint()
    ..color = const Color(0xFF212121) // Heavy structural mullion frame
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke;

  static final Paint _mullionPaint = Paint()
    ..color = const Color(0xFF455A64) // Glazing bars
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke;

  static final Paint _ridgePaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _glassFillPaint = Paint()
    ..color = const Color(0x8880DEEA) // Translucent cyan/aqua tempered glass
    ..style = PaintingStyle.fill;

  static final Paint _glassHighlightPaint = Paint()
    ..color = const Color(0x66B2EBF2)
    ..style = PaintingStyle.fill;

  static final Paint _glintPaint = Paint()
    ..color = const Color(0xCCFFFFFF) // Specular sunlight glint sheen
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _spiderwebPaint = Paint()
    ..color = const Color(0xEEFFFFFF) // Post-impact fractured glass cracks
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _brokenGlassPerimeterPaint = Paint()
    ..color = const Color(0x994DD0E1) // Remaining jagged perimeter shards
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _sheenTimer += dt * 2.2;
    if (_fractureVibration > 0) {
      _fractureVibration = math.max(0.0, _fractureVibration - dt * 4.0);
    }
  }

  /// Evaluates whether an airborne courier descends or vaults through the skylight dome,
  /// shattering the glass and triggering high-velocity breach physics.
  bool checkSmashThrough(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasShattered) return false;

    // Must be actively airborne to smash through the elevated glass dome
    if (simulator.isGrounded) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    // Horizontal overlap with skylight frame
    final inHorizontal = playerRight >= position.x + 6.0 && playerLeft <= position.x + size.x - 6.0;

    // Foot penetrates into the glass dome ridge and internal volume
    final inVertical = footY >= position.y - 12.0 && footY <= position.y + size.y + 14.0;

    if (inHorizontal && inVertical) {
      hasShattered = true;
      _fractureVibration = 1.0;

      onSmash?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    const curbH = 8.0;
    final domeH = h - curbH;

    // 1. Concrete / Iron Roof Curb Foundation
    final curbRect = Rect.fromLTWH(0.0, domeH, w, curbH);
    canvas.drawRect(curbRect, _curbPaint);
    canvas.drawRect(Rect.fromLTWH(2.0, domeH, w - 4.0, 2.0), _curbHighlightPaint);

    final apexX = w / 2.0;
    const apexY = 2.0;
    final baseLeft = Offset(4.0, domeH);
    final baseRight = Offset(w - 4.0, domeH);
    final apex = Offset(apexX, apexY);

    if (!hasShattered) {
      // 2. Intact Architectural Glass Panels (Pitched Gable Roof)
      final leftPanePath = Path()
        ..moveTo(baseLeft.dx, baseLeft.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(apexX, domeH)
        ..close();

      final rightPanePath = Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(baseRight.dx, baseRight.dy)
        ..lineTo(apexX, domeH)
        ..close();

      canvas.drawPath(leftPanePath, _glassFillPaint);
      canvas.drawPath(rightPanePath, _glassHighlightPaint);

      // Specular Sunlight Sheen Reflection Lines
      final sheenOffset = ((math.sin(_sheenTimer) + 1.0) / 2.0) * (w * 0.4);
      final glintStart = Offset(8.0 + sheenOffset, domeH - 4.0);
      final glintEnd = Offset(18.0 + sheenOffset, apexY + 8.0);
      canvas.drawLine(glintStart, glintEnd, _glintPaint);
      canvas.drawLine(
        Offset(glintStart.dx + 6.0, glintStart.dy),
        Offset(glintEnd.dx + 6.0, glintEnd.dy),
        _glintPaint,
      );

      // Structural Iron Glazing Bars (Mullions)
      canvas.drawLine(baseLeft, apex, _ironFramePaint);
      canvas.drawLine(baseRight, apex, _ironFramePaint);
      canvas.drawLine(Offset(apexX, domeH), apex, _mullionPaint);

      // Intermediate mullion struts
      canvas.drawLine(Offset(baseLeft.dx + 16.0, domeH), Offset(apexX - 10.0, apexY + 8.0), _mullionPaint);
      canvas.drawLine(Offset(baseRight.dx - 16.0, domeH), Offset(apexX + 10.0, apexY + 8.0), _mullionPaint);

      // Ridge Cap Beam
      canvas.drawLine(Offset(apexX - 8.0, apexY), Offset(apexX + 8.0, apexY), _ridgePaint);
    } else {
      // 3. Shattered Post-Breach State: Blown-out center cavity with perimeter shards and spiderweb cracks
      // Jagged perimeter glass remnants
      final leftRemnant = Path()
        ..moveTo(baseLeft.dx, baseLeft.dy)
        ..lineTo(baseLeft.dx + 12.0, baseLeft.dy)
        ..lineTo(baseLeft.dx + 8.0, baseLeft.dy - 10.0)
        ..lineTo(baseLeft.dx + 16.0, baseLeft.dy - 6.0)
        ..lineTo(apexX - 14.0, apexY + 12.0)
        ..lineTo(apexX - 22.0, apexY + 16.0)
        ..close();

      final rightRemnant = Path()
        ..moveTo(baseRight.dx, baseRight.dy)
        ..lineTo(baseRight.dx - 12.0, baseRight.dy)
        ..lineTo(baseRight.dx - 8.0, baseRight.dy - 12.0)
        ..lineTo(baseRight.dx - 18.0, baseRight.dy - 8.0)
        ..lineTo(apexX + 16.0, apexY + 14.0)
        ..lineTo(apexX + 22.0, apexY + 18.0)
        ..close();

      canvas.drawPath(leftRemnant, _brokenGlassPerimeterPaint);
      canvas.drawPath(rightRemnant, _brokenGlassPerimeterPaint);

      // Spiderweb fracture lines propagating from breach center
      final centerImpact = Offset(apexX, domeH * 0.45);
      canvas.drawLine(centerImpact, Offset(baseLeft.dx + 4.0, baseLeft.dy - 2.0), _spiderwebPaint);
      canvas.drawLine(centerImpact, Offset(baseRight.dx - 4.0, baseRight.dy - 2.0), _spiderwebPaint);
      canvas.drawLine(centerImpact, Offset(apexX - 6.0, apexY + 2.0), _spiderwebPaint);
      canvas.drawLine(centerImpact, Offset(apexX + 6.0, apexY + 2.0), _spiderwebPaint);
      canvas.drawLine(centerImpact, Offset(baseLeft.dx + 24.0, domeH), _spiderwebPaint);
      canvas.drawLine(centerImpact, Offset(baseRight.dx - 24.0, domeH), _spiderwebPaint);

      // Outer frame remains intact
      canvas.drawLine(baseLeft, apex, _ironFramePaint);
      canvas.drawLine(baseRight, apex, _ironFramePaint);
      canvas.drawLine(Offset(apexX - 8.0, apexY), Offset(apexX + 8.0, apexY), _ridgePaint);
    }
  }
}
