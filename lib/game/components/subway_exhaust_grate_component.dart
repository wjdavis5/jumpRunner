import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Sidewalk subway ventilation exhaust grate embedded into pavement,
/// featuring a recessed cast-iron mesh street grid, yellow hazard warning border trim,
/// a fluttering corner cardboard flap, and billowing turbulent white steam plumes.
///
/// Entering or hurdling across the steam column catches an aerodynamic thermal updraft (+230 px/s loft)
/// and activates the Thermal Updraft Glide buff (+35% reduced gravity descent rate).
class SubwayExhaustGrateComponent extends PositionComponent {
  SubwayExhaustGrateComponent({
    required Vector2 position,
    double width = 88.0,
    double height = 14.0,
    this.groundY = 460.0,
    this.onUpdraftCatch,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onUpdraftCatch;

  bool hasTriggered = false;
  double _steamTimer = 0.0;

  /// Top surface baseline Y of the sidewalk grate in world coordinates.
  double get grateWorldY => groundY - size.y;

  /// World space coordinate at the steam plume thermal column center for particle bursts.
  Vector2 get plumeApexWorld => Vector2(position.x + (size.x / 2), groundY - 32.0);

  /// Center point of the grate fixture in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _pitPaint = Paint()
    ..color = const Color(0xFF121212) // Deep subterranean subway ventilation shaft
    ..style = PaintingStyle.fill;

  static final Paint _ironRimPaint = Paint()
    ..color = const Color(0xFF37474F) // Heavy cast-iron curb frame
    ..style = PaintingStyle.fill;

  static final Paint _hazardStripeYellow = Paint()
    ..color = const Color(0xFFFFD600) // Caution yellow perimeter stripe
    ..style = PaintingStyle.fill;

  static final Paint _hazardStripeBlack = Paint()
    ..color = const Color(0xFF212121) // Caution black diagonal slash
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _grateBarPaint = Paint()
    ..color = const Color(0xFF78909C) // Steel mesh grate slats
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  static final Paint _cardboardPaint = Paint()
    ..color = const Color(0xFF8D6E63) // Fluttering wet cardboard newspaper scrap
    ..style = PaintingStyle.fill;

  static final Paint _steamOuterPaint = Paint()
    ..color = const Color(0x33ECEFF1) // Billowing translucent steam cloud
    ..style = PaintingStyle.fill;

  static final Paint _steamCorePaint = Paint()
    ..color = const Color(0x55FFFFFF) // Hot white steam core
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _steamTimer += dt;
  }

  /// Evaluates whether a courier enters or hurdles across the buoyant subway thermal steam column.
  bool checkUpdraft(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasTriggered) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check across grate width
    final horizontalOverlap = (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from ground baseline up into the thermal updraft column
    final windowTop = groundY - 80.0;
    final windowBottom = groundY + 6.0;
    final inUpdraftWindow = (footY >= windowTop) && (footY <= windowBottom);

    if (inUpdraftWindow) {
      hasTriggered = true;
      simulator.launch(230.0); // Aerodynamic thermal updraft lift
      onUpdraftCatch?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Billowing Subterranean Steam Plumes
    _renderSteamPlume(canvas, w, h);

    // 2. Deep Shaft Pit & Hazard Frame
    _renderShaftAndBorder(canvas, w, h);

    // 3. Cast-Iron Grate Mesh Bars
    _renderGrateBars(canvas, w, h);

    // 4. Fluttering Cardboard Baffle Scrap
    _renderCardboardFlap(canvas, w, h);
  }

  void _renderShaftAndBorder(Canvas canvas, double w, double h) {
    // Outer cast-iron border frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(2.0)),
      _ironRimPaint,
    );

    // Hazard caution rim stripe along top and bottom curb
    canvas.drawRect(Rect.fromLTWH(2, 0, w - 4, 2.5), _hazardStripeYellow);
    canvas.drawRect(Rect.fromLTWH(2, h - 2.5, w - 4, 2.5), _hazardStripeYellow);

    for (var i = 4.0; i < w - 4.0; i += 8.0) {
      canvas.drawLine(Offset(i, 0), Offset(i + 4.0, 2.5), _hazardStripeBlack);
      canvas.drawLine(Offset(i, h - 2.5), Offset(i + 4.0, h), _hazardStripeBlack);
    }

    // Deep underground shaft
    canvas.drawRect(
      Rect.fromLTWH(3.0, 2.5, w - 6.0, h - 5.0),
      _pitPaint,
    );
  }

  void _renderGrateBars(Canvas canvas, double w, double h) {
    // Horizontal longitudinal support rails
    canvas.drawLine(const Offset(3.0, 5.0), Offset(w - 3.0, 5.0), _grateBarPaint);
    canvas.drawLine(const Offset(3.0, 9.0), Offset(w - 3.0, 9.0), _grateBarPaint);

    // Vertical cast-iron crossbar slats
    const barSpacing = 5.5;
    for (var bx = 6.0; bx < w - 6.0; bx += barSpacing) {
      canvas.drawLine(Offset(bx, 2.5), Offset(bx, h - 2.5), _grateBarPaint);
    }
  }

  void _renderCardboardFlap(Canvas canvas, double w, double h) {
    final flutter = math.sin(_steamTimer * 14.0) * 2.2;

    // Corner cardboard scrap caught on grate slats
    final flapPath = Path()
      ..moveTo(6.0, 3.0)
      ..lineTo(18.0, 2.5)
      ..lineTo(16.0 + flutter, -5.0 + flutter * 0.5)
      ..lineTo(8.0, -3.0 + flutter * 0.4)
      ..close();

    canvas.drawPath(flapPath, _cardboardPaint);
  }

  void _renderSteamPlume(Canvas canvas, double w, double h) {
    final wave1 = math.sin(_steamTimer * 4.5) * 6.0;
    final wave2 = math.cos(_steamTimer * 5.5) * 8.0;
    final wave3 = math.sin(_steamTimer * 6.5) * 5.0;

    final centerX = w * 0.5;

    // Layer 1: Large outer expanding thermal vapor cloud
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + wave1, -22.0),
        width: 52.0 + wave2.abs(),
        height: 38.0,
      ),
      _steamOuterPaint,
    );

    // Layer 2: Higher dispersing puff
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - wave2, -42.0),
        width: 64.0 + wave3.abs(),
        height: 34.0,
      ),
      _steamOuterPaint,
    );

    // Layer 3: Concentrated hot white steam core rushing from grate center
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + wave3 * 0.5, -12.0),
        width: 32.0,
        height: 22.0,
      ),
      _steamCorePaint,
    );
  }
}
