import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Industrial roll-up security shutter door mounted on storefronts and alleyway walls,
/// featuring corrugated galvanized steel slats, colorful graffiti street art murals,
/// heavy guide track rails, and a hazard-striped bottom bumper bar.
///
/// An agile courier can perform an acrobatic wall-kick rebound leap off the shutter face,
/// gaining a high-velocity vertical boost (+240 px/s loft) and launching colorful aerosol
/// spray paint flecks and metallic friction sparks.
class SecurityShutterComponent extends PositionComponent {
  SecurityShutterComponent({
    required Vector2 position,
    double width = 48.0,
    double height = 80.0,
    this.groundY = 460.0,
    this.onRebound,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onRebound;

  bool hasRebounded = false;

  /// Top surface baseline Y of the shutter drum housing in world coordinates.
  double get shutterTopY => groundY - size.y;

  /// World space coordinate at the central impact zone of the shutter for rebound particles.
  Vector2 get reboundApexWorld => Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.45));

  /// Center point of the shutter in world coordinates.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.5));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _wallFramePaint = Paint()
    ..color = const Color(0xFF37474F) // Dark alley masonry frame
    ..style = PaintingStyle.fill;

  static final Paint _slatBasePaint = Paint()
    ..color = const Color(0xFF607D8B) // Corrugated galvanized steel
    ..style = PaintingStyle.fill;

  static final Paint _slatHighlightPaint = Paint()
    ..color = const Color(0xFF78909C)
    ..style = PaintingStyle.fill;

  static final Paint _slatGroovePaint = Paint()
    ..color = const Color(0xFF263238)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _trackPaint = Paint()
    ..color = const Color(0xFF1E272C) // Cast iron guide channel
    ..style = PaintingStyle.fill;

  static final Paint _drumHousingPaint = Paint()
    ..color = const Color(0xFF455A64) // Overhead roll drum housing
    ..style = PaintingStyle.fill;

  static final Paint _drumHighlightPaint = Paint()
    ..color = const Color(0xFF90A4AE)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _bumperPaint = Paint()
    ..color = const Color(0xFF212121) // Bottom heavy steel bumper bar
    ..style = PaintingStyle.fill;

  static final Paint _hazardStripePaint = Paint()
    ..color = const Color(0xFFFFD600) // Caution yellow stripe
    ..style = PaintingStyle.fill;

  static final Paint _haspPaint = Paint()
    ..color = const Color(0xFFB0BEC5) // Heavy padlock hasp
    ..style = PaintingStyle.fill;

  // Graffiti mural paints
  static final Paint _graffitiPinkPaint = Paint()
    ..color = const Color(0xFFFF007F) // Hot neon magenta
    ..style = PaintingStyle.fill;

  static final Paint _graffitiCyanPaint = Paint()
    ..color = const Color(0xFF00E5FF) // Vivid aerosol cyan
    ..style = PaintingStyle.fill;

  static final Paint _graffitiYellowPaint = Paint()
    ..color = const Color(0xFFFFD600) // Chrome yellow tag
    ..style = PaintingStyle.fill;

  static final Paint _graffitiLimePaint = Paint()
    ..color = const Color(0xFF76FF03) // Acid lime splatter
    ..style = PaintingStyle.fill;

  static final Paint _rivetPaint = Paint()
    ..color = const Color(0xFF90A4AE)
    ..style = PaintingStyle.fill;

  static final Paint _bracketPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  /// Evaluates whether an approaching courier performs a wall-kick rebound off the shutter face.
  bool checkShutterRebound(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasRebounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final courierTop = playerPos.y;
    final courierFootY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check: tight contact window with shutter face
    final horizontalOverlap = (courierRight >= fixtureLeft - 4.0) && (courierLeft <= fixtureRight + 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from drum housing apex down to sidewalk pavement
    final windowTop = shutterTopY - 24.0;
    final windowBottom = groundY + 4.0;
    final inReboundWindow = (courierFootY >= windowTop) && (courierTop <= windowBottom);

    if (inReboundWindow) {
      hasRebounded = true;
      simulator.launch(240.0); // Explosive upward wall-kick rebound impulse
      onRebound?.call();
      return true;
    }

    return false;
  }

  /// Manually mark the shutter as rebounded.
  void markRebounded() {
    hasRebounded = true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Surrounding Masonry Wall Recess
    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, w, h), _wallFramePaint);

    // 2. Corrugated Galvanized Steel Slats
    const slatH = 5.0;
    final slatCount = ((h - 22.0) / slatH).floor();
    for (var i = 0; i < slatCount; i++) {
      final y = 14.0 + (i * slatH);
      final isAlternate = (i % 2 == 1);
      final paint = isAlternate ? _slatHighlightPaint : _slatBasePaint;
      canvas.drawRect(Rect.fromLTWH(4.0, y, w - 8.0, slatH), paint);
      canvas.drawLine(Offset(4.0, y), Offset(w - 4.0, y), _slatGroovePaint);
    }

    // 3. Colorful Graffiti Mural Street Art (midsection overlay)
    _renderGraffitiMural(canvas, w, h);

    // 4. Vertical Cast-Iron Guide Track Channels (left & right)
    canvas.drawRect(Rect.fromLTWH(0.0, 10.0, 4.5, h - 10.0), _trackPaint);
    canvas.drawRect(Rect.fromLTWH(w - 4.5, 10.0, 4.5, h - 10.0), _trackPaint);

    // Track rivets
    for (var ry = 22.0; ry < h - 14.0; ry += 16.0) {
      canvas.drawCircle(Offset(2.2, ry), 1.0, _rivetPaint);
      canvas.drawCircle(Offset(w - 2.2, ry), 1.0, _rivetPaint);
    }

    // 5. Overhead Roll-Up Drum Enclosure Casing
    _renderDrumCasing(canvas, w);

    // 6. Heavy Bottom Steel Bumper Bar with Hazard Striping
    _renderBottomBumper(canvas, w, h);
  }

  void _renderDrumCasing(Canvas canvas, double w) {
    // Drum cylindrical box
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0.0, 0.0, w, 14.0), const Radius.circular(3.0)),
      _drumHousingPaint,
    );

    // Drum highlight rim
    canvas.drawLine(const Offset(2.0, 3.0), Offset(w - 2.0, 3.0), _drumHighlightPaint);

    // End mounting bracket caps
    canvas.drawRect(const Rect.fromLTWH(0.0, 0.0, 5.0, 14.0), _bracketPaint);
    canvas.drawRect(Rect.fromLTWH(w - 5.0, 0.0, 5.0, 14.0), _bracketPaint);
  }

  void _renderGraffitiMural(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final cy = h * 0.52;

    // Neon magenta base tag bubble letters
    final magentaPath = Path()
      ..moveTo(cx - 14.0, cy - 8.0)
      ..cubicTo(cx - 18.0, cy - 14.0, cx - 4.0, cy - 16.0, cx - 2.0, cy - 8.0)
      ..cubicTo(cx + 4.0, cy - 16.0, cx + 18.0, cy - 12.0, cx + 14.0, cy - 4.0)
      ..cubicTo(cx + 18.0, cy + 6.0, cx + 4.0, cy + 12.0, cx - 4.0, cy + 8.0)
      ..cubicTo(cx - 14.0, cy + 12.0, cx - 18.0, cy + 2.0, cx - 14.0, cy - 8.0)
      ..close();
    canvas.drawPath(magentaPath, _graffitiPinkPaint);

    // Electric cyan inner tag flare
    final cyanPath = Path()
      ..moveTo(cx - 10.0, cy - 5.0)
      ..quadraticBezierTo(cx - 2.0, cy - 12.0, cx + 8.0, cy - 6.0)
      ..quadraticBezierTo(cx + 12.0, cy + 4.0, cx + 2.0, cy + 5.0)
      ..quadraticBezierTo(cx - 8.0, cy + 8.0, cx - 10.0, cy - 5.0)
      ..close();
    canvas.drawPath(cyanPath, _graffitiCyanPaint);

    // Chrome yellow starburst highlight
    canvas.drawCircle(Offset(cx - 3.0, cy - 2.0), 3.2, _graffitiYellowPaint);
    canvas.drawCircle(Offset(cx + 6.0, cy + 1.0), 2.4, _graffitiYellowPaint);

    // Lime green spray drip droplets
    canvas.drawCircle(Offset(cx - 11.0, cy + 14.0), 1.5, _graffitiLimePaint);
    canvas.drawCircle(Offset(cx - 11.0, cy + 18.0), 1.0, _graffitiLimePaint);
    canvas.drawCircle(Offset(cx + 9.0, cy + 12.0), 1.4, _graffitiLimePaint);
  }

  void _renderBottomBumper(Canvas canvas, double w, double h) {
    const barH = 8.0;
    final barY = h - barH;

    // Base dark bumper
    canvas.drawRect(Rect.fromLTWH(0.0, barY, w, barH), _bumperPaint);

    // Diagonal hazard stripes
    const stripeW = 6.0;
    for (var x = 4.0; x < w - 6.0; x += stripeW * 2.0) {
      final stripePath = Path()
        ..moveTo(x, barY + barH)
        ..lineTo(x + stripeW, barY)
        ..lineTo(x + stripeW + 3.0, barY)
        ..lineTo(x + 3.0, barY + barH)
        ..close();
      canvas.drawPath(stripePath, _hazardStripePaint);
    }

    // Heavy central padlock hasp
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.5 - 3.5, barY + 1.5, 7.0, 5.0), const Radius.circular(1.0)),
      _haspPaint,
    );
  }
}
