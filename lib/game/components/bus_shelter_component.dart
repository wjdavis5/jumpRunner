import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street transit bus stop shelter along the sidewalk, featuring a tempered glass canopy roof,
/// illuminated digital LED route departure marquee, backlit ad display poster, and commuter bench.
///
/// Hurdling or vaulting across the tempered glass roof imparts an upward launch hop (+210 px/s loft)
/// and spawns vibrant digital amber/cyan LED spark bursts.
class BusShelterComponent extends PositionComponent {
  BusShelterComponent({
    required Vector2 position,
    double width = 96.0,
    double height = 54.0,
    this.groundY = 460.0,
    this.onShelterVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onShelterVault;

  bool hasVaulted = false;
  double _tickerTimer = 0.0;

  /// Top surface baseline Y of the shelter canopy roof in world coordinates.
  double get roofWorldY => groundY - size.y;

  /// World space coordinate at the LED route marquee apex for particle bursts.
  Vector2 get marqueeApexWorld => Vector2(position.x + (size.x * 0.5), roofWorldY + 8.0);

  /// Center point of the bus shelter in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.5));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _framePaint = Paint()
    ..color = const Color(0xFF263238) // Dark industrial charcoal steel
    ..style = PaintingStyle.fill;

  static final Paint _glassCanopyPaint = Paint()
    ..color = const Color(0x6680DEEA) // Tinted cyan tempered safety glass
    ..style = PaintingStyle.fill;

  static final Paint _glassFramePaint = Paint()
    ..color = const Color(0xAAECEFF1) // White/chrome safety glass perimeter trim
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _glassRearWallPaint = Paint()
    ..color = const Color(0x33B2EBF2) // Transparent rear safety glass wall
    ..style = PaintingStyle.fill;

  static final Paint _adBacklightGlow = Paint()
    ..color = const Color(0x4400E5FF) // Ambient cyan ad backlight
    ..style = PaintingStyle.fill;

  static final Paint _adBoxBgPaint = Paint()
    ..color = const Color(0xFF102027) // Dark display cabinet frame
    ..style = PaintingStyle.fill;

  static final Paint _adPosterPaint = Paint()
    ..color = const Color(0xFF0288D1) // Vibrant transit poster graphic
    ..style = PaintingStyle.fill;

  static final Paint _adPosterAccentPaint = Paint()
    ..color = const Color(0xFFFFB300)
    ..style = PaintingStyle.fill;

  static final Paint _ledMarqueeBgPaint = Paint()
    ..color = const Color(0xFF121212) // Black matrix ticker housing
    ..style = PaintingStyle.fill;

  static final Paint _ledAmberDotPaint = Paint()
    ..color = const Color(0xFFFFB300) // Amber route text dot
    ..style = PaintingStyle.fill;

  static final Paint _ledAmberGlowPaint = Paint()
    ..color = const Color(0x66FFB300) // Amber ambient glow
    ..style = PaintingStyle.fill;

  static final Paint _benchSlatsPaint = Paint()
    ..color = const Color(0xFF8D6E63) // Weathered oak wood slats
    ..style = PaintingStyle.fill;

  static final Paint _benchLegsPaint = Paint()
    ..color = const Color(0xFF78909C) // Brushed aluminum bench frame
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;

  @override
  void update(double dt) {
    super.update(dt);
    _tickerTimer += dt;
  }

  /// Evaluates whether an approaching courier hurdles or bounds across the shelter canopy roof.
  bool checkShelterVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from roof canopy down to sidewalk ground
    final windowTop = roofWorldY - 24.0;
    final windowBottom = groundY + 4.0;
    final inVaultWindow = (footY >= windowTop) && (footY <= windowBottom);

    if (inVaultWindow) {
      hasVaulted = true;
      if (!simulator.isGrounded) {
        simulator.launch(210.0); // Upward loft rebound off tempered glass canopy
      }
      onShelterVault?.call();
      return true;
    }

    return false;
  }

  /// Manually mark the shelter as vaulted.
  void markVaulted() {
    hasVaulted = true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Rear Transparent Glass Windbreak Wall
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(8.0, 10.0, w - 16.0, h - 14.0), const Radius.circular(2.0)),
      _glassRearWallPaint,
    );

    // 2. Backlit Advertising Poster Cabinet (Right Section)
    _renderAdCabinet(canvas, w - 30.0, 12.0, 22.0, h - 22.0);

    // 3. Commuter Transit Bench (Left Section)
    _renderBench(canvas, 10.0, h - 18.0, 48.0, 14.0);

    // 4. Steel Support Pillars and Wall Channel Posts
    canvas.drawRect(Rect.fromLTWH(6.0, 8.0, 4.0, h - 8.0), _framePaint);
    canvas.drawRect(Rect.fromLTWH(w - 10.0, 8.0, 4.0, h - 8.0), _framePaint);
    canvas.drawRect(Rect.fromLTWH(60.0, 8.0, 3.0, h - 8.0), _framePaint);

    // 5. Overhead Cantilever Canopy Roof
    _renderCanopyRoof(canvas, w);

    // 6. Digital Amber LED Route Ticker Marquee Display
    _renderLedMarquee(canvas, w);
  }

  void _renderAdCabinet(Canvas canvas, double x, double y, double width, double height) {
    // Ambient backlight halo
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x - 2.0, y - 2.0, width + 4.0, height + 4.0), const Radius.circular(3.0)),
      _adBacklightGlow,
    );

    // Cabinet outer frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, width, height), const Radius.circular(2.0)),
      _adBoxBgPaint,
    );

    // Poster artwork
    canvas.drawRect(Rect.fromLTWH(x + 2.0, y + 2.0, width - 4.0, height - 4.0), _adPosterPaint);
    canvas.drawCircle(Offset(x + width * 0.5, y + height * 0.4), 4.5, _adPosterAccentPaint);
    canvas.drawRect(Rect.fromLTWH(x + 4.0, y + height - 8.0, width - 8.0, 2.5), _adPosterAccentPaint);
  }

  void _renderBench(Canvas canvas, double x, double y, double width, double height) {
    // Aluminum legs
    canvas.drawLine(Offset(x + 4.0, y + 4.0), Offset(x + 4.0, y + height), _benchLegsPaint);
    canvas.drawLine(Offset(x + width - 4.0, y + 4.0), Offset(x + width - 4.0, y + height), _benchLegsPaint);

    // Wood seat slats
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 2.0, width, 3.5), const Radius.circular(1.5)),
      _benchSlatsPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 7.0, width, 3.5), const Radius.circular(1.5)),
      _benchSlatsPaint,
    );
  }

  void _renderCanopyRoof(Canvas canvas, double w) {
    // Curved cantilever tempered glass roof
    final roofPath = Path()
      ..moveTo(0.0, 6.0)
      ..quadraticBezierTo(w * 0.5, 0.0, w, 4.0)
      ..lineTo(w, 8.0)
      ..quadraticBezierTo(w * 0.5, 3.0, 0.0, 8.0)
      ..close();

    canvas.drawPath(roofPath, _glassCanopyPaint);
    canvas.drawPath(roofPath, _glassFramePaint);

    // Stainless steel front fascia lip
    canvas.drawRect(Rect.fromLTWH(0.0, 7.0, w, 2.5), _framePaint);
  }

  void _renderLedMarquee(Canvas canvas, double w) {
    const mx = 12.0;
    const my = 2.0;
    final mw = w - 24.0;
    const mh = 5.5;

    // Marquee frame casing
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx, my, mw, mh), const Radius.circular(1.5)),
      _ledMarqueeBgPaint,
    );

    // Animated scrolling amber LED dots
    final scrollOffset = (_tickerTimer * 26.0) % 18.0;
    for (var x = mx + 2.0; x < mx + mw - 2.0; x += 3.5) {
      final dotPos = (x + scrollOffset) % 10.0;
      if (dotPos > 2.0) {
        canvas.drawCircle(Offset(x, my + 2.8), 0.9, _ledAmberDotPaint);
      }
    }

    // Soft marquee ambient glow
    canvas.drawRect(Rect.fromLTWH(mx + 1.0, my + 1.0, mw - 2.0, mh - 2.0), _ledAmberGlowPaint);
  }
}
