import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Interactive cast-iron street storm drain vault grate embedded in asphalt.
///
/// Running or landing across the grate triggers an explosive high-pressure steam geyser
/// launching the courier upward (+450 px/s) while erupting a coin arc into the sky.
class StormDrainComponent extends PositionComponent {
  StormDrainComponent({
    required Vector2 position,
    double width = 56.0,
    double height = 18.0,
    this.groundY = 460.0,
    this.launchImpulse = 450.0,
    this.onTrigger,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final double launchImpulse;
  final VoidCallback? onTrigger;

  bool hasTriggered = false;
  double _vaporTimer = 0.0;
  double _geyserAnimTimer = 0.0;

  /// Top surface baseline Y of the storm drain grate in world coordinates.
  double get grateTopWorldY => position.y;

  /// World coordinate at the center of the storm drain for particle bursts.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the storm drain has scrolled offscreen and should be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    _vaporTimer += dt * 3.5;
    if (_geyserAnimTimer > 0) {
      _geyserAnimTimer = math.max(0.0, _geyserAnimTimer - dt);
    }
  }

  /// Evaluates whether the courier steps on, slides over, or lands on the drain grate.
  bool checkTrigger(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasTriggered) return false;

    final footX = playerPos.x + (playerSize.x / 2);
    final footY = simulator.currentY;

    final inHorizontalRange = footX >= position.x - 8.0 && footX <= position.x + size.x + 8.0;
    final inVerticalRange = footY >= groundY - 20.0 && footY <= groundY + 8.0;

    if (inHorizontalRange && inVerticalRange) {
      hasTriggered = true;
      _geyserAnimTimer = 0.6;
      simulator.launch(launchImpulse);
      onTrigger?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Dark Subterranean Drainage Vault Cavity
    final pitRect = Rect.fromLTWH(2.0, 3.0, w - 4.0, h - 3.0);
    final pitPaint = Paint()..color = const Color(0xFF0D1B24);
    canvas.drawRRect(RRect.fromRectAndRadius(pitRect, const Radius.circular(2.0)), pitPaint);

    // 2. Cast Iron Grate Outer Frame with Corner Bolts
    final framePaint = Paint()
      ..color = const Color(0xFF34495E)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(pitRect, const Radius.circular(2.0)), framePaint);

    final boltPaint = Paint()..color = const Color(0xFF7F8C8D);
    canvas.drawCircle(const Offset(4.0, 5.0), 1.2, boltPaint);
    canvas.drawCircle(Offset(w - 4.0, 5.0), 1.2, boltPaint);
    canvas.drawCircle(Offset(4.0, h - 3.0), 1.2, boltPaint);
    canvas.drawCircle(Offset(w - 4.0, h - 3.0), 1.2, boltPaint);

    // 3. Heavy Iron Slotted Drainage Bars
    final barPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    const barSpacing = 6.0;
    final barCount = ((w - 12.0) / barSpacing).floor();
    for (var i = 0; i < barCount; i++) {
      final barX = 7.0 + (i * barSpacing);
      canvas.drawLine(Offset(barX, 4.0), Offset(barX, h - 2.0), barPaint);
    }

    // 4. Warning Yellow Hazard Curb Trim at top edge
    final hazardPaint = Paint()..color = const Color(0xFFF1C40F);
    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, w, 2.5), hazardPaint);

    // 5. Pre-Eruption Simmering Steam Vapor Wisps
    if (!hasTriggered || _geyserAnimTimer <= 0) {
      final vaporPaint = Paint()
        ..color = const Color(0x66E0F7FA)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final wave1 = math.sin(_vaporTimer) * 2.5;
      final wave2 = math.cos(_vaporTimer * 1.3) * 2.5;
      canvas.drawLine(const Offset(16.0, 3.0), Offset(16.0 + wave1, -6.0), vaporPaint);
      canvas.drawLine(const Offset(38.0, 3.0), Offset(38.0 + wave2, -8.0), vaporPaint);
    } else {
      // 6. Active Explosive Steam Geyser Column Plume
      final progress = 1.0 - (_geyserAnimTimer / 0.6);
      final plumeAlpha = (1.0 - progress).clamp(0.0, 1.0);
      final plumeHeight = 45.0 + math.sin(progress * math.pi) * 35.0;

      final geyserPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: plumeAlpha * 0.5)
        ..style = PaintingStyle.fill;
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: plumeAlpha * 0.7)
        ..style = PaintingStyle.fill;

      // Expanding upward steam plume
      final plumeRect = Rect.fromLTWH(10.0, -plumeHeight, w - 20.0, plumeHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(plumeRect, const Radius.circular(8.0)), geyserPaint);
      final coreRect = Rect.fromLTWH(18.0, -plumeHeight * 0.85, w - 36.0, plumeHeight * 0.85);
      canvas.drawRRect(RRect.fromRectAndRadius(coreRect, const Radius.circular(4.0)), corePaint);
    }
  }
}
