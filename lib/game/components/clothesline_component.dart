import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Rooftop tenement laundry clothesline strung between two weathered brick chimney stubs,
/// featuring sagging catenary braided hemp rope, billowing multicolored linens
/// (cotton bedsheets, striped towels, pastel shirts), and birch wooden clothespins.
///
/// Hurdle-vaulting through the clothesline triggers an elastic rope rebound impulse (+220 px/s loft)
/// and scatters billowing linen particles into the breeze.
class ClotheslineComponent extends PositionComponent {
  ClotheslineComponent({
    required Vector2 position,
    double width = 96.0,
    double height = 48.0,
    this.roofY = 280.0,
    this.onHurdle,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double roofY;
  final VoidCallback? onHurdle;

  bool hasHurdled = false;
  double _windTimer = 0.0;
  double _reboundTimer = 0.0;

  /// Top surface baseline Y of the sagging clothesline rope in world coordinates.
  double get ropeSagWorldY => position.y + 14.0;

  /// World space coordinate at the clothesline center for particle bursts.
  Vector2 get centerApexWorld => Vector2(position.x + (size.x / 2), position.y + 16.0);

  /// Center point of the clothesline fixture in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _brickPaint = Paint()
    ..color = const Color(0xFF8D4B38) // Tenement red brick chimney
    ..style = PaintingStyle.fill;

  static final Paint _mortarPaint = Paint()
    ..color = const Color(0xFF5D3024) // Chimney mortar shadow & cap
    ..style = PaintingStyle.fill;

  static final Paint _terracottaCapPaint = Paint()
    ..color = const Color(0xFFD87040) // Terracotta flue liner cap
    ..style = PaintingStyle.fill;

  static final Paint _ropePaint = Paint()
    ..color = const Color(0xFFD7CCC8) // Braided hemp rope
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;

  static final Paint _pinPaint = Paint()
    ..color = const Color(0xFFFFCC80) // Birch wooden clothespin
    ..style = PaintingStyle.fill;

  static final Paint _sheetWhitePaint = Paint()
    ..color = const Color(0xFFF5F5F5) // Cotton bedsheet
    ..style = PaintingStyle.fill;

  static final Paint _towelCoralPaint = Paint()
    ..color = const Color(0xFFFF7043) // Coral striped towel
    ..style = PaintingStyle.fill;

  static final Paint _towelStripePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  static final Paint _shirtBluePaint = Paint()
    ..color = const Color(0xFF4FC3F7) // Sky blue chambray cotton shirt
    ..style = PaintingStyle.fill;

  static final Paint _dressVioletPaint = Paint()
    ..color = const Color(0xFFCE93D8) // Pastel lavender cloth
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _windTimer += dt;
    if (_reboundTimer > 0) {
      _reboundTimer = math.max(0.0, _reboundTimer - dt);
    }
  }

  /// Evaluates whether a courier vaults into or hurdle-rebounds off the clothesline.
  bool checkHurdle(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasHurdled) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check across clothesline span
    final horizontalOverlap = (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from above rope down to rooftop baseline
    final windowTop = position.y - 12.0;
    final windowBottom = roofY + 6.0;
    final inInteractionWindow = (footY >= windowTop) && (footY <= windowBottom);

    if (inInteractionWindow) {
      hasHurdled = true;
      _reboundTimer = 0.45; // Elastic rope oscillation flourish
      simulator.launch(220.0); // Elastic rope vault rebound lift
      onHurdle?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // Elastic bounce offset if recently hurdled
    final reboundSag = _reboundTimer > 0 ? math.sin(_reboundTimer * 28.0) * 6.0 : 0.0;
    final windWave = math.sin(_windTimer * 5.0) * 1.5;

    // 1. Hanging Laundry Linens
    _renderLinens(canvas, w, h, windWave, reboundSag);

    // 2. Braided Hemp Catenary Clothesline Rope
    _renderRope(canvas, w, h, reboundSag);

    // 3. Wooden Clothespins
    _renderClothespins(canvas, w, h, reboundSag);

    // 4. Brick Chimney Posts on Ends
    _renderChimneys(canvas, w, h);
  }

  void _renderChimneys(Canvas canvas, double w, double h) {
    const chimneyW = 12.0;
    final chimneyH = h - 6.0;

    // Left chimney
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, h - chimneyH, chimneyW, chimneyH), const Radius.circular(2.0)),
      _brickPaint,
    );
    // Left flue cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-1.5, h - chimneyH - 4.0, chimneyW + 3.0, 4.5), const Radius.circular(1.5)),
      _terracottaCapPaint,
    );
    // Left chimney rim shadow
    canvas.drawRect(Rect.fromLTWH(0, h - chimneyH + 8.0, chimneyW, 2.0), _mortarPaint);
    canvas.drawRect(Rect.fromLTWH(0, h - chimneyH + 18.0, chimneyW, 2.0), _mortarPaint);

    // Right chimney
    final rightX = w - chimneyW;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rightX, h - chimneyH, chimneyW, chimneyH), const Radius.circular(2.0)),
      _brickPaint,
    );
    // Right flue cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rightX - 1.5, h - chimneyH - 4.0, chimneyW + 3.0, 4.5), const Radius.circular(1.5)),
      _terracottaCapPaint,
    );
    // Right chimney rim shadow
    canvas.drawRect(Rect.fromLTWH(rightX, h - chimneyH + 8.0, chimneyW, 2.0), _mortarPaint);
    canvas.drawRect(Rect.fromLTWH(rightX, h - chimneyH + 18.0, chimneyW, 2.0), _mortarPaint);
  }

  void _renderRope(Canvas canvas, double w, double h, double reboundSag) {
    const leftAnchorX = 8.0;
    const leftAnchorY = 8.0;
    final rightAnchorX = w - 8.0;
    const rightAnchorY = 8.0;

    final sagY = 16.0 + reboundSag;

    final ropePath = Path()
      ..moveTo(leftAnchorX, leftAnchorY)
      ..quadraticBezierTo(w / 2, sagY, rightAnchorX, rightAnchorY);

    canvas.drawPath(ropePath, _ropePaint);
  }

  void _renderLinens(Canvas canvas, double w, double h, double windWave, double reboundSag) {
    final flutter = math.sin(_windTimer * 8.0) * 3.0;

    // Item 1: White bedsheet (left-center, wide)
    final sheetPath = Path()
      ..moveTo(18.0, 11.0 + (reboundSag * 0.4))
      ..lineTo(38.0, 14.0 + (reboundSag * 0.7))
      ..lineTo(39.0 + flutter, 38.0)
      ..lineTo(16.0 + windWave, 36.0)
      ..close();
    canvas.drawPath(sheetPath, _sheetWhitePaint);

    // Item 2: Coral striped towel (center)
    final towelPath = Path()
      ..moveTo(42.0, 15.0 + (reboundSag * 0.8))
      ..lineTo(56.0, 15.5 + (reboundSag * 0.9))
      ..lineTo(57.0 + windWave, 42.0)
      ..lineTo(41.0 + flutter, 40.0)
      ..close();
    canvas.drawPath(towelPath, _towelCoralPaint);
    // Towel stripes
    canvas.drawLine(
      Offset(41.5 + (flutter * 0.6), 26.0),
      Offset(56.5 + (windWave * 0.6), 27.0),
      _towelStripePaint,
    );
    canvas.drawLine(
      Offset(41.2 + (flutter * 0.8), 34.0),
      Offset(56.8 + (windWave * 0.8), 35.0),
      _towelStripePaint,
    );

    // Item 3: Sky blue t-shirt (center-right)
    final shirtPath = Path()
      ..moveTo(60.0, 15.0 + (reboundSag * 0.8))
      ..lineTo(74.0, 13.5 + (reboundSag * 0.6))
      ..lineTo(76.0 + flutter, 34.0)
      ..lineTo(58.0 + windWave, 33.0)
      ..close();
    canvas.drawPath(shirtPath, _shirtBluePaint);

    // Item 4: Pastel lavender cloth (far right)
    final dressPath = Path()
      ..moveTo(77.0, 13.0 + (reboundSag * 0.5))
      ..lineTo(86.0, 10.5 + (reboundSag * 0.3))
      ..lineTo(88.0 + windWave, 29.0)
      ..lineTo(76.0 + flutter, 30.0)
      ..close();
    canvas.drawPath(dressPath, _dressVioletPaint);
  }

  void _renderClothespins(Canvas canvas, double w, double h, double reboundSag) {
    // Clothespin coordinates along rope curve
    final pinsX = [19.0, 37.0, 43.0, 55.0, 61.0, 73.0, 78.0, 85.0];
    for (final px in pinsX) {
      final t = (px - 8.0) / (w - 16.0);
      final py = (8.0 * (1 - t) * (1 - t)) + ((16.0 + reboundSag) * 2 * (1 - t) * t) + (8.0 * t * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(px - 1.2, py - 3.5, 2.4, 6.0), const Radius.circular(0.8)),
        _pinPaint,
      );
    }
  }
}
