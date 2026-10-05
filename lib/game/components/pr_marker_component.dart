import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_font.dart';

/// Animated neon holographic sidewalk totem marking the player's Personal Record (PR).
///
/// Spawns at the player's personal best distance, projects a pulsing vertical beam and
/// holographic badge, and triggers celebratory visual feedback when the courier dashes past it.
class PersonalRecordMarkerComponent extends PositionComponent {
  PersonalRecordMarkerComponent({
    required this.prDistance,
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position ?? Vector2.zero(),
          size: size ?? Vector2(36, 80),
        );

  final int prDistance;

  /// Whether the courier player has crossed/surpassed this milestone.
  bool hasBeenSurpassed = false;

  /// Internal animation timer for beam pulsing and beacon oscillations.
  double animationTimer = 0.0;

  /// Color scheme of the holographic totem (Neon Cyan when approaching, Triumphant Gold when beaten).
  Color get primaryColor => hasBeenSurpassed
      ? const Color(0xFFF1C40F) // Triumphant Gold
      : const Color(0xFF00E5FF); // Neon Cyan

  bool get shouldRecycle => position.x < -200.0;

  @override
  void update(double dt) {
    super.update(dt);
    animationTimer += dt;

    if (shouldRecycle && isMounted) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulse = 0.6 + 0.3 * math.sin(animationTimer * 4.5);
    final glowAlpha = (pulse * 255).clamp(80, 240).toInt();

    // 1. Sidewalk Ground Emitter Base
    final basePaint = Paint()..color = const Color(0xFF1B2631);
    final emitterPlate = Rect.fromLTWH(2, size.y - 8, size.x - 4, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(emitterPlate, const Radius.circular(3)),
      basePaint,
    );

    // Glowing emitter strip
    final stripPaint = Paint()..color = primaryColor.withAlpha(glowAlpha);
    canvas.drawRect(Rect.fromLTWH(6, size.y - 6, size.x - 12, 3), stripPaint);

    // 2. Holographic Projection Beams (Two vertical laser guides)
    final beamPaint = Paint()
      ..color = primaryColor.withAlpha((pulse * 180).toInt())
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(8, size.y - 8),
      const Offset(8, 22),
      beamPaint,
    );
    canvas.drawLine(
      Offset(size.x - 8, size.y - 8),
      Offset(size.x - 8, 22),
      beamPaint,
    );

    // Translucent vertical holographic light curtain
    final curtainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          primaryColor.withAlpha((pulse * 90).toInt()),
          primaryColor.withAlpha(20),
        ],
      ).createShader(Rect.fromLTWH(8, 22, size.x - 16, size.y - 30));

    canvas.drawRect(Rect.fromLTWH(8, 22, size.x - 16, size.y - 30), curtainPaint);

    // 3. Floating Holographic Diamond Badge
    final badgeCenterY = 16.0 + math.sin(animationTimer * 3.0) * 2.5;
    final badgeCenterX = size.x / 2;

    final badgePath = Path()
      ..moveTo(badgeCenterX, badgeCenterY - 14)
      ..lineTo(badgeCenterX + 14, badgeCenterY)
      ..lineTo(badgeCenterX, badgeCenterY + 14)
      ..lineTo(badgeCenterX - 14, badgeCenterY)
      ..close();

    final badgeFill = Paint()
      ..color = const Color(0xFF141D26).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final badgeBorder = Paint()
      ..color = primaryColor.withAlpha(glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(badgePath, badgeFill);
    canvas.drawPath(badgePath, badgeBorder);

    // Badge Text (PR)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PR',
        style: TextStyle(
          fontFamily: gameFontFamily,
          color: primaryColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(badgeCenterX - textPainter.width / 2, badgeCenterY - textPainter.height / 2),
    );

    // 4. Distance Label floating underneath badge
    final distPainter = TextPainter(
      text: TextSpan(
        text: '${prDistance}m',
        style: TextStyle(
          fontFamily: gameFontFamily,
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withValues(alpha: 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    distPainter.paint(
      canvas,
      Offset(badgeCenterX - distPainter.width / 2, badgeCenterY + 16),
    );

    // 5. Ground projection line on sidewalk
    final groundLinePaint = Paint()
      ..color = primaryColor.withAlpha((pulse * 200).toInt())
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(-12, size.y - 1),
      Offset(size.x + 12, size.y - 1),
      groundLinePaint,
    );
  }
}
