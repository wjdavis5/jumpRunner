import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Interactive urban street intersection crosswalk with zebra pavement markings,
/// countdown traffic signals, and curb pedestrians offering sprint-by high-fives.
///
/// Running or vaulting past the pedestrian's raised hand triggers a 'HIGH FIVE!' reaction,
/// awarding combo tips and audio cheering reactions.
class CrosswalkZoneComponent extends PositionComponent {
  CrosswalkZoneComponent({
    required Vector2 position,
    double width = 140.0,
    this.groundY = 460.0,
    this.signalCountdown = 9,
    this.onHighFive,
  }) : super(
          position: position,
          size: Vector2(width, 56.0),
        );

  final double groundY;
  final int signalCountdown;
  final VoidCallback? onHighFive;

  bool isHighFived = false;
  double _signalTimer = 0.0;
  double _clapAnimTimer = 0.0;

  /// World coordinate position of the pedestrian's outstretched palm.
  Vector2 get handWorldPosition => Vector2(position.x + size.x - 22.0, position.y + 18.0);

  /// Whether the crosswalk has scrolled past the active world view.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    _signalTimer += dt;
    if (_clapAnimTimer > 0) {
      _clapAnimTimer = math.max(0.0, _clapAnimTimer - dt);
    }
  }

  /// Determines whether the courier's bounding box makes contact with the high-five palm.
  bool checkHighFiveProximity(Vector2 playerPos, Vector2 playerSize) {
    if (isHighFived) return false;

    final handX = handWorldPosition.x;
    final handY = handWorldPosition.y;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final playerTop = playerPos.y;
    final playerBottom = playerPos.y + playerSize.y;

    // Contact tolerance around the raised hand
    final inHorizontalRange = playerRight >= handX - 24.0 && playerLeft <= handX + 28.0;
    final inVerticalRange = playerBottom >= handY - 26.0 && playerTop <= handY + 36.0;

    if (inHorizontalRange && inVerticalRange) {
      isHighFived = true;
      _clapAnimTimer = 0.5;
      onHighFive?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Asphalt Road Zebra Crosswalk Stripes
    _renderZebraStripes(canvas, w, h);

    // 2. Sidewalk Curb Line & Tactile Paving
    _renderCurb(canvas, w, h);

    // 3. Pedestrian Traffic Signal Beacon Post
    _renderSignalPost(canvas, w, h);

    // 4. Cheerful Curb Pedestrian offering High-Five
    _renderPedestrian(canvas, w, h);
  }

  void _renderZebraStripes(Canvas canvas, double w, double h) {
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;

    const stripeWidth = 11.0;
    const stripeGap = 9.0;
    const stripeHeight = 14.0;
    final stripeY = h - stripeHeight;

    final stripeCount = (w / (stripeWidth + stripeGap)).floor();
    for (var i = 0; i < stripeCount; i++) {
      final stripeX = 8.0 + i * (stripeWidth + stripeGap);
      if (stripeX + stripeWidth <= w - 6.0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(stripeX, stripeY, stripeWidth, stripeHeight),
            const Radius.circular(1.5),
          ),
          stripePaint,
        );
      }
    }
  }

  void _renderCurb(Canvas canvas, double w, double h) {
    // Concrete sidewalk curb edge
    final curbPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0.0, h - 16.0), Offset(w, h - 16.0), curbPaint);

    // Yellow tactile ADA warning paving at curb ramp
    final tactilePaint = Paint()..color = const Color(0xFFF1C40F).withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(w - 48.0, h - 19.0, 36.0, 3.0), tactilePaint);
  }

  void _renderSignalPost(Canvas canvas, double w, double h) {
    const postX = 14.0;
    final postBaseY = h - 16.0;

    // Metal signal pole
    final polePaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(postX, postBaseY), const Offset(postX, 10.0), polePaint);

    // Signal Housing Box
    final boxRect = Rect.fromCenter(center: const Offset(postX, 12.0), width: 14.0, height: 18.0);
    final boxPaint = Paint()..color = const Color(0xFF212121);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(2.0)), boxPaint);
    final visorPaint = Paint()..color = const Color(0xFF1B1B1B);
    canvas.drawRect(Rect.fromLTWH(boxRect.left - 1.0, boxRect.top - 2.0, boxRect.width + 2.0, 2.0), visorPaint);

    // Illuminated Pedestrian Signal Display (Blinks walk / countdown)
    final isWalkPhase = (_signalTimer % 2.4) < 1.4;
    final signalGlyphPaint = Paint()
      ..color = isWalkPhase ? const Color(0xFFFFFFFF) : const Color(0xFFFF9800);

    if (isWalkPhase) {
      // Walking silhouette icon
      canvas.drawCircle(const Offset(postX, 7.5), 1.6, signalGlyphPaint);
      canvas.drawRect(const Rect.fromLTWH(postX - 1.0, 9.5, 2.0, 4.0), signalGlyphPaint);
      canvas.drawLine(const Offset(postX - 1.0, 13.5), const Offset(postX - 2.8, 17.5), signalGlyphPaint..strokeWidth = 1.0);
      canvas.drawLine(const Offset(postX + 1.0, 13.5), const Offset(postX + 2.8, 17.5), signalGlyphPaint);
    } else {
      // Amber Hand Don't Walk symbol
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(postX, 12.0), width: 6.0, height: 7.0),
          const Radius.circular(1.0),
        ),
        signalGlyphPaint,
      );
    }
  }

  void _renderPedestrian(Canvas canvas, double w, double h) {
    final pedX = w - 24.0;
    final pedBaseY = h - 17.0;

    // 1. Legs & Shoes
    final pantsPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(pedX - 2.5, pedBaseY - 14.0), Offset(pedX - 3.5, pedBaseY), pantsPaint);
    canvas.drawLine(Offset(pedX + 2.5, pedBaseY - 14.0), Offset(pedX + 1.5, pedBaseY), pantsPaint);

    final shoePaint = Paint()..color = const Color(0xFFE74C3C);
    canvas.drawRect(Rect.fromLTWH(pedX - 5.5, pedBaseY - 2.0, 4.0, 2.5), shoePaint);
    canvas.drawRect(Rect.fromLTWH(pedX - 0.5, pedBaseY - 2.0, 4.0, 2.5), shoePaint);

    // 2. Torso & Jacket (Vibrant turquoise / teal hoodie)
    final jacketPaint = Paint()..color = const Color(0xFF1ABC9C);
    final torsoRect = Rect.fromLTWH(pedX - 5.5, pedBaseY - 28.0, 11.0, 15.0);
    canvas.drawRRect(RRect.fromRectAndRadius(torsoRect, const Radius.circular(2.5)), jacketPaint);

    // 3. Head & Knit Beanie Cap
    final headPaint = Paint()..color = const Color(0xFFFFCCBC);
    final headCenter = Offset(pedX, pedBaseY - 33.0);
    canvas.drawCircle(headCenter, 4.0, headPaint);

    final beaniePaint = Paint()..color = const Color(0xFFE67E22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headCenter.dx - 4.5, headCenter.dy - 5.5, 9.0, 5.0),
        const Radius.circular(2.5),
      ),
      beaniePaint,
    );

    // 4. Raised High-Five Arm & Open Palm
    final armPaint = Paint()
      ..color = const Color(0xFF16A085)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final armRoot = Offset(pedX - 4.0, pedBaseY - 25.0);
    final handPos = Offset(pedX - 12.0, pedBaseY - 20.0);

    if (isHighFived && _clapAnimTimer > 0) {
      // Rebounding enthusiastic wave after high five
      canvas.drawLine(armRoot, Offset(pedX - 8.0, pedBaseY - 32.0), armPaint);
      final palmPaint = Paint()..color = const Color(0xFFFFCCBC);
      canvas.drawCircle(Offset(pedX - 8.0, pedBaseY - 34.0), 3.0, palmPaint);

      // Gold celebratory clap starburst
      final starPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: (_clapAnimTimer / 0.5))
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(handPos, 6.0 + (1.0 - _clapAnimTimer / 0.5) * 8.0, starPaint);
    } else {
      // Outstretched arm facing oncoming runner
      canvas.drawLine(armRoot, handPos, armPaint);

      // Open High-Five Palm (glove / hand with fingers spread)
      final palmPaint = Paint()..color = const Color(0xFFFFD54F);
      canvas.drawCircle(handPos, 3.2, palmPaint);
      final thumbPaint = Paint()..color = const Color(0xFFFFCA28);
      canvas.drawCircle(Offset(handPos.dx - 1.2, handPos.dy - 2.0), 1.5, thumbPaint);
    }
  }
}
