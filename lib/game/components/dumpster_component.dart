import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game_font.dart';

import '../logic/jump_physics.dart';

/// Street-level curbside dumpster: a heavy commercial steel bin on grease
/// covered caster wheels, with ribbed structural walls, hazard chevron
/// stripes, stenciled serial lettering and dual spring-loaded rubber lids
/// held slightly open.
///
/// An airborne courier who lands on the angled lids compresses the spring
/// hinges, which snap back and catapult them upward (+240 px/s rebound).
class DumpsterComponent extends PositionComponent {
  DumpsterComponent({
    required Vector2 position,
    double width = 76.0,
    double height = 50.0,
    this.groundY = 460.0,
    this.onBounce,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onBounce;

  bool hasBounced = false;

  /// Seconds left on the lid snap-back animation, running from
  /// [lidSnapDuration] down to zero after a bounce.
  double lidSnapTimer = 0.0;

  /// How long the lids stay flung open after a spring bounce.
  static const double lidSnapDuration = 0.35;

  /// Rest angle of the rubber lids off horizontal, in radians (~15°).
  static const double lidRestAngle = 0.26;

  /// Extra angle the lids swing to while the spring snaps back.
  static const double lidSnapAngle = 0.85;

  /// Top surface of the bin walls in world coordinates.
  double get lidTopY => groundY - size.y;

  /// Center of the lid hinge line in world coordinates, where spring
  /// particles are anchored.
  Vector2 get lidHingeWorld =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.06));

  /// World space coordinate at the catapult apex for launch particles.
  Vector2 get bounceApexWorld =>
      Vector2(position.x + (size.x * 0.5), position.y - 14.0);

  /// Center point of the dumpster in world coordinates.
  Vector2 get centerWorldPosition =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.5));

  /// Current lid swing: the rest angle, wider while the spring snaps back.
  double get currentLidAngle =>
      lidRestAngle +
      (lidSnapTimer > 0.0
          ? lidSnapAngle * (lidSnapTimer / lidSnapDuration)
          : 0.0);

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    if (lidSnapTimer > 0.0) {
      lidSnapTimer = (lidSnapTimer - dt).clamp(0.0, lidSnapDuration);
    }
  }

  /// Evaluates whether an approaching courier lands on the spring-loaded
  /// lids for a catapult bounce.
  ///
  /// Only an airborne courier can compress the hinges; a grounded courier
  /// runs past in front of the bin and leaves it fresh for a real bounce.
  bool checkLidBounce(
    Vector2 playerPos,
    Vector2 playerSize,
    JumpPhysicsSimulator simulator,
  ) {
    if (hasBounced) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check: tight contact window with the bin.
    final horizontalOverlap =
        (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from just above the lids to the pavement.
    final windowTop = lidTopY - 26.0;
    final windowBottom = groundY + 4.0;
    final inBounceWindow = (footY >= windowTop) && (footY <= windowBottom);
    if (!inBounceWindow) return false;

    if (simulator.isGrounded) return false;

    hasBounced = true;
    lidSnapTimer = lidSnapDuration;
    simulator.launch(240.0); // Spring hinge catapult off the rubber lids.
    onBounce?.call();
    return true;
  }

  /// Manually mark the dumpster as bounced.
  void markBounced() {
    hasBounced = true;
  }

  // Visual styling paints
  static final Paint _bodyPaint = Paint()
    ..color = const Color(0xFF33503F) // Forest-green commercial steel
    ..style = PaintingStyle.fill;

  static final Paint _bodyShadePaint = Paint()
    ..color = const Color(0xFF27402F)
    ..style = PaintingStyle.fill;

  static final Paint _ribPaint = Paint()
    ..color = const Color(0xFF24382C) // Ribbed structural side walls
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _lidPaint = Paint()
    ..color = const Color(0xFF1B1B1B) // Black rubber flip lids
    ..style = PaintingStyle.fill;

  static final Paint _lidEdgePaint = Paint()
    ..color = const Color(0xFF3C3C3C)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _chevronPaint = Paint()
    ..color = const Color(0xFFFDD835) // Yellow hazard chevrons
    ..style = PaintingStyle.fill;

  static final Paint _casterPaint = Paint()
    ..color = const Color(0xFF424242) // Grease-covered caster wheels
    ..style = PaintingStyle.fill;

  static final Paint _casterHubPaint = Paint()
    ..color = const Color(0xFF9E9E9E)
    ..style = PaintingStyle.fill;

  static final Paint _stencilPaint = Paint()
    ..color = const Color(0xFFCFD8DC) // White stencil plate
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Steel bin body with ribbed walls
    canvas.drawRect(Rect.fromLTWH(2.0, h * 0.14, w - 4.0, h * 0.80), _bodyPaint);
    for (var i = 1; i < 4; i++) {
      final x = 2.0 + (w - 4.0) * i / 4.0;
      canvas.drawLine(Offset(x, h * 0.16), Offset(x, h * 0.92), _ribPaint);
    }
    // Top rim and tapered base shading
    canvas.drawRect(Rect.fromLTWH(2.0, h * 0.14, w - 4.0, 3.0), _bodyShadePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.06, h * 0.90, w * 0.88, h * 0.05), _bodyShadePaint);

    // 2. Yellow warning chevron band across the lower body
    final bandTop = h * 0.66;
    final bandHeight = h * 0.14;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(2.0, bandTop, w - 4.0, bandHeight));
    for (var x = -6.0; x < w + 6.0; x += 12.0) {
      final chevron = Path()
        ..moveTo(x, bandTop + bandHeight)
        ..lineTo(x + 6.0, bandTop)
        ..lineTo(x + 10.0, bandTop)
        ..lineTo(x + 4.0, bandTop + bandHeight)
        ..close();
      canvas.drawPath(chevron, _chevronPaint);
    }
    canvas.restore();

    // 3. Stenciled serial plate
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.42, w * 0.40, h * 0.13), _stencilPaint);
    const serial = TextSpan(
      text: 'JR-0427',
      style: TextStyle(
        fontFamily: gameFontFamily,
        color: Color(0xFF263238),
        fontSize: 7,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
    final serialPainter = TextPainter(text: serial, textDirection: TextDirection.ltr)
      ..layout();
    serialPainter.paint(
      canvas,
      Offset(w * 0.30 + (w * 0.40 - serialPainter.width) / 2, h * 0.42 + 1.5),
    );

    // 4. Dual spring-loaded rubber lids, hinged at the center line
    final lidAngle = currentLidAngle;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(w * 0.5, h * 0.10);
      canvas.rotate(side * lidAngle);
      final lid = Rect.fromLTWH(
        side < 0 ? -w * 0.46 : 0.0,
        -6.0,
        w * 0.46,
        7.0,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(lid, const Radius.circular(3.0)), _lidPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(lid, const Radius.circular(3.0)), _lidEdgePaint);
      canvas.restore();
    }

    // 5. Dual grease-covered caster wheels under the base
    const casterR = 5.0;
    for (final cx in [w * 0.22, w * 0.72]) {
      canvas.drawCircle(Offset(cx, h - casterR + 1.0), casterR, _casterPaint);
      canvas.drawCircle(Offset(cx, h - casterR + 1.0), 1.8, _casterHubPaint);
    }
  }
}
