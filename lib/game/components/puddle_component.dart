import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Dynamic urban sidewalk and asphalt rainwater puddle featuring procedural asphalt shorelines,
/// concentric ripple animations, sky reflections, and water splash/skim physics.
class PuddleComponent extends PositionComponent {
  PuddleComponent({
    required Vector2 position,
    Vector2? size,
    this.groundY = 460.0,
  }) : super(
          position: position,
          size: size ?? Vector2(74.0, 14.0),
        );

  final double groundY;

  /// Whether the courier has stepped or landed in this puddle, triggering a water splash burst.
  bool hasSplashed = false;

  /// Whether the courier has cleanly cleared or skimmed over this puddle for stunt bonus.
  bool hasSkimmed = false;

  /// Whether dynamic rain is falling, causing enhanced ripples and surface plinks.
  bool isRaining = false;

  double _rippleTimer = 0.0;

  /// Top surface coordinate of the puddle water.
  double get surfaceY => position.y;

  /// Center world coordinate of the puddle.
  Vector2 get centerWorld => Vector2(position.x + size.x / 2, position.y + size.y / 2);

  /// Whether this puddle has scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -120.0;

  // Visual styling paints
  static final Paint _rimPaint = Paint()
    ..color = const Color(0xFF1C2833) // Dark wet asphalt rim
    ..style = PaintingStyle.fill;

  static final Paint _waterBasePaint = Paint()
    ..color = const Color(0xFF212F3D) // Deep reflective pool
    ..style = PaintingStyle.fill;

  static final Paint _reflectionPaint = Paint()
    ..color = const Color(0x3381D4FA) // Cyan sky specular sheen
    ..style = PaintingStyle.fill;

  /// Checks if the courier's foot touches the puddle surface while grounded.
  bool checkSplash(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasSplashed) return false;

    final footX = playerPos.x + playerSize.x / 2;
    final footY = simulator.currentY;

    final horizontalOverlap = footX >= position.x && footX <= position.x + size.x;
    final verticalOverlap = footY >= position.y - 6.0 && footY <= position.y + size.y + 8.0;

    return horizontalOverlap && verticalOverlap && simulator.isGrounded;
  }

  /// Checks if the courier has leapt completely past this puddle without splashing.
  bool checkSkim(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasSplashed || hasSkimmed) return false;

    final footX = playerPos.x + playerSize.x / 2;
    final pastRightEdge = footX > position.x + size.x;

    return pastRightEdge;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rippleTimer += dt * (isRaining ? 4.5 : 2.5);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Wet Asphalt Shoreline Rim
    final rimRect = Rect.fromLTWH(0, 0, w, h);
    final rimRRect = RRect.fromRectAndRadius(rimRect, Radius.circular(h / 2));
    canvas.drawRRect(rimRRect, _rimPaint);

    // 2. Reflective Water Basin
    final waterRect = Rect.fromLTWH(2.0, 1.5, w - 4.0, h - 3.0);
    final waterRRect = RRect.fromRectAndRadius(waterRect, Radius.circular((h - 3.0) / 2));
    canvas.drawRRect(waterRRect, _waterBasePaint);

    // 3. Specular Sky Reflection Sheen (diagonal crescent)
    final sheenPath = Path()
      ..moveTo(8.0, 2.5)
      ..quadraticBezierTo(w * 0.45, 2.0, w * 0.75, 4.0)
      ..quadraticBezierTo(w * 0.45, h * 0.55, 6.0, h * 0.6)
      ..close();
    canvas.drawPath(sheenPath, _reflectionPaint);

    // 4. Concentric Ripple Rings
    final ripple1Phase = (_rippleTimer * 0.8) % 1.0;
    final ripple1RadiusX = 6.0 + ripple1Phase * 16.0;
    final ripple1RadiusY = 1.5 + ripple1Phase * 3.5;
    final ripple1Alpha = ((1.0 - ripple1Phase) * 120).toInt();

    final r1Paint = Paint()
      ..color = const Color(0xFF81D4FA).withAlpha(ripple1Alpha)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.38, h * 0.55),
        width: ripple1RadiusX * 2,
        height: ripple1RadiusY * 2,
      ),
      r1Paint,
    );

    final ripple2Phase = ((_rippleTimer * 0.8) + 0.5) % 1.0;
    final ripple2RadiusX = 4.0 + ripple2Phase * 14.0;
    final ripple2RadiusY = 1.2 + ripple2Phase * 3.0;
    final ripple2Alpha = ((1.0 - ripple2Phase) * 100).toInt();

    final r2Paint = Paint()
      ..color = const Color(0xFFB3E5FC).withAlpha(ripple2Alpha)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.68, h * 0.5),
        width: ripple2RadiusX * 2,
        height: ripple2RadiusY * 2,
      ),
      r2Paint,
    );

    // 5. Rain Plink Droplet Rings when wet/raining
    if (isRaining) {
      final plinkPhase = (_rippleTimer * 1.6) % 1.0;
      final plinkRadius = 2.0 + plinkPhase * 7.0;
      final plinkAlpha = ((1.0 - plinkPhase) * 180).toInt();
      final pPaint = Paint()
        ..color = Colors.white.withAlpha(plinkAlpha)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.52, h * 0.45),
          width: plinkRadius * 2,
          height: plinkRadius * 0.7,
        ),
        pPaint,
      );
    }
  }
}
