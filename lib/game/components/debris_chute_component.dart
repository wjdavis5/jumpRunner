import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Construction debris chute: the ribbed corrugated plastic tube hanging off
/// the trailing edge of a scaffolding deck, angling down to the sidewalk so
/// renovation scraps can be dropped straight into a bin.
///
/// A courier who runs off the deck rides the tube instead: they slide its
/// descending surface to street level, collect the tips taped along the
/// inside, and pop out at the bottom mouth. Jumping mid-slide bails out the
/// ordinary way.
class DebrisChuteComponent extends PositionComponent {
  DebrisChuteComponent({
    required Vector2 position,
    double width = 170.0,
    double height = 120.0,
    this.groundY = 460.0,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;

  /// Whether a courier has already ridden this chute down.
  bool hasSlid = false;

  /// Seconds of debris-flow animation accumulated since spawn.
  double debrisPhase = 0.0;

  /// Tube thickness measured perpendicular to the slide line.
  static const double tubeWidth = 26.0;

  /// Whether the chute has fully scrolled past active camera view.
  bool get shouldRecycle => position.x + size.x < -180.0;

  /// The slide surface in world coordinates at world [worldX]: the tube's
  /// upper inner line, from the hopper mouth at deck level to the bottom
  /// mouth on the sidewalk. Outside the tube it clamps to the nearer mouth.
  double surfaceYAt(double worldX) {
    final t = ((worldX - position.x) / size.x).clamp(0.0, 1.0);
    return position.y + t * size.y;
  }

  /// Where the courier exits at the bottom mouth, for dust bursts.
  Vector2 get exitWorld =>
      Vector2(position.x + size.x, position.y + size.y);

  /// The hopper mouth where the deck hands the courier over.
  Vector2 get mouthWorld => Vector2(position.x, position.y);

  @override
  void update(double dt) {
    super.update(dt);
    debrisPhase += dt * 2.6;
  }

  // Visual styling paints
  static final Paint _tubePaint = Paint()
    ..color = const Color(0xFF4A90D9) // Corrugated construction blue
    ..style = PaintingStyle.fill;

  static final Paint _tubeShadePaint = Paint()
    ..color = const Color(0xFF3572B5)
    ..style = PaintingStyle.fill;

  static final Paint _ribPaint = Paint()
    ..color = const Color(0xFF2C5A8F)
    ..style = PaintingStyle.fill;

  static final Paint _hopperPaint = Paint()
    ..color = const Color(0xFF37474F) // Steel hopper bolted to the deck
    ..style = PaintingStyle.fill;

  static final Paint _strapPaint = Paint()
    ..color = const Color(0xFFF9A825) // Safety-yellow mounting straps
    ..style = PaintingStyle.fill;

  static final Paint _tarpPaint = Paint()
    ..color = const Color(0xFFB0BEC5) // Debris bin tarp at the bottom mouth
    ..style = PaintingStyle.fill;

  static final Paint _debrisPaint = Paint()
    ..color = const Color(0xFF8D6E63) // Plaster chunks sliding inside
    ..style = PaintingStyle.fill;

  static final Paint _debrisDarkPaint = Paint()
    ..color = const Color(0xFF6D4C41)
    ..style = PaintingStyle.fill;

  static final Paint _sheenPaint = Paint()
    ..color = const Color(0xFFBBDEFB).withValues(alpha: 0.35)
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    final slope = math.atan2(h, w);
    final dirX = math.cos(slope);
    final dirY = math.sin(slope);

    // The tube runs from the hopper mouth (deck edge) down to the bottom
    // mouth (sidewalk), drawn as corrugated segments along that line.
    final length = math.sqrt(w * w + h * h);

    Offset lineAt(double along) => Offset(dirX * along, dirY * along);

    // 1. Steel hopper bolted to the deck's trailing edge.
    final mouth = lineAt(0.0);
    final hopper = Path()
      ..moveTo(mouth.dx - 10.0, mouth.dy - tubeWidth / 2 - 4.0)
      ..lineTo(mouth.dx + 12.0, mouth.dy - tubeWidth / 2)
      ..lineTo(mouth.dx + 12.0, mouth.dy + tubeWidth / 2)
      ..lineTo(mouth.dx - 10.0, mouth.dy + tubeWidth / 2 + 4.0)
      ..close();
    canvas.drawPath(hopper, _hopperPaint);
    // Yellow strap cinching the hopper to the deck.
    canvas.drawRect(
      Rect.fromLTWH(mouth.dx - 6.0, mouth.dy - tubeWidth / 2 - 5.0, 4.0, tubeWidth + 10.0),
      _strapPaint,
    );

    // 2. Corrugated tube: alternating segment bands along the slide line.
    const segmentLength = 22.0;
    var i = 0;
    for (var along = 0.0; along < length - 4.0; along += segmentLength) {
      const half = tubeWidth / 2;
      final end = math.min(along + segmentLength, length);
      final a = lineAt(along);
      final b = lineAt(end);
      final nx = -dirY * half;
      final ny = dirX * half;
      final seg = Path()
        ..moveTo(a.dx + nx, a.dy + ny)
        ..lineTo(b.dx + nx, b.dy + ny)
        ..lineTo(b.dx - nx, b.dy - ny)
        ..lineTo(a.dx - nx, a.dy - ny)
        ..close();
      canvas.drawPath(seg, i.isEven ? _tubePaint : _tubeShadePaint);

      // Rib ring at each segment joint.
      final rib = Path()
        ..moveTo(b.dx + nx * 1.15, b.dy + ny * 1.15)
        ..lineTo(b.dx + nx * 1.15 - dirX * 3.0, b.dy + ny * 1.15 - dirY * 3.0)
        ..lineTo(b.dx - nx * 1.15 - dirX * 3.0, b.dy - ny * 1.15 - dirY * 3.0)
        ..lineTo(b.dx - nx * 1.15, b.dy - ny * 1.15)
        ..close();
      canvas.drawPath(rib, _ribPaint);
      i++;
    }

    // 3. Mounting straps every few segments, tied back toward the scaffold.
    for (final along in [length * 0.3, length * 0.62]) {
      final p = lineAt(along);
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 2.5, p.dy - tubeWidth / 2 - 3.0, 5.0, tubeWidth + 6.0),
        _strapPaint,
      );
    }

    // 4. Sheen along the tube's upper edge: translucent plastic catching sun.
    final sheen = Path()
      ..moveTo(lineAt(6.0).dx - dirY * (tubeWidth / 2 - 5.0),
          lineAt(6.0).dy + dirX * (tubeWidth / 2 - 5.0))
      ..lineTo(lineAt(length - 6.0).dx - dirY * (tubeWidth / 2 - 5.0),
          lineAt(length - 6.0).dy + dirX * (tubeWidth / 2 - 5.0))
      ..lineTo(lineAt(length - 6.0).dx - dirY * (tubeWidth / 2 - 11.0),
          lineAt(length - 6.0).dy + dirX * (tubeWidth / 2 - 11.0))
      ..lineTo(lineAt(6.0).dx - dirY * (tubeWidth / 2 - 11.0),
          lineAt(6.0).dy + dirX * (tubeWidth / 2 - 11.0))
      ..close();
    canvas.drawPath(sheen, _sheenPaint);

    // 5. Plaster chunks tumbling down the tube's interior.
    for (var d = 0; d < 4; d++) {
      final cycle = ((debrisPhase * 0.35 + d * 0.27) % 1.0);
      final along = cycle * (length - 10.0) + 5.0;
      final p = lineAt(along);
      final radius = 2.4 + (d % 2) * 1.2;
      canvas.drawCircle(
        Offset(p.dx - dirY * 2.0, p.dy + dirX * 2.0),
        radius,
        d.isEven ? _debrisPaint : _debrisDarkPaint,
      );
    }

    // 6. Bottom mouth: flared skirt over the debris bin's tarp.
    final exit = lineAt(length);
    final skirt = Path()
      ..moveTo(exit.dx - dirX * 4.0 + dirY * tubeWidth / 2,
          exit.dy - dirY * 4.0 - dirX * tubeWidth / 2)
      ..lineTo(exit.dx + 14.0 + dirY * (tubeWidth / 2 + 8.0),
          exit.dy + dirX * (tubeWidth / 2 + 8.0))
      ..lineTo(exit.dx + 14.0 - dirY * (tubeWidth / 2 + 8.0),
          exit.dy - dirX * (tubeWidth / 2 + 8.0))
      ..close();
    canvas.drawPath(skirt, _tubeShadePaint);
    canvas.drawCircle(
      Offset(exit.dx + 10.0, exit.dy - 2.0),
      9.0,
      _tarpPaint,
    );
  }
}
