import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Window-washer's suspended cradle: a steel platform hanging from two
/// cables off a rooftop davit boom, bobbing slowly between floors while the
/// washer up board squeegees the glass.
///
/// A courier who leaps onto the platform rides it as it rises and falls.
/// Crossing the bob's apex mid-ride pays a timing bonus; jumping bails off
/// the ordinary way, and the platform never comes low enough to crowd the
/// sidewalk.
class WindowWasherCradleComponent extends PositionComponent {
  WindowWasherCradleComponent({
    required Vector2 position,
    double width = 120.0,
    double height = 300.0,
    this.groundY = 460.0,
    double phase = 0.0,
  })  : _phase = phase,
        super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;

  /// Bob phase offset in radians at spawn.
  final double _phase;

  /// Seconds of bobbing accumulated since spawn; drives the platform.
  double bobTime = 0.0;

  /// Whether a courier has already ridden this cradle across an apex.
  bool hasAwardedRide = false;

  /// Platform surface at its lowest point, in world coordinates.
  double get platformLowY => groundY - 92.0;

  /// Bob half-travel: the platform rises this far above [platformLowY].
  static const double bobAmplitude = 66.0;

  /// Full bob period in seconds.
  static const double bobPeriod = 2.2;

  /// Platform span inset from the rig's edges.
  static const double platformInset = 5.0;

  /// The platform's top surface in world coordinates right now.
  double get surfaceY => platformLowY -
      bobAmplitude * (0.5 - 0.5 * math.cos(2 * math.pi * bobTime / bobPeriod + _phase));

  /// The platform's span in world coordinates at the current height.
  Rect get platformSpanWorld => Rect.fromLTWH(
        position.x + platformInset,
        surfaceY,
        size.x - platformInset * 2,
        10.0,
      );

  /// Whether the rig has scrolled completely past active camera view.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    bobTime += dt;
  }

  // Visual styling paints
  static final Paint _boomPaint = Paint()
    ..color = const Color(0xFF455A64) // Davit boom steel
    ..style = PaintingStyle.fill;

  static final Paint _mastPaint = Paint()
    ..color = const Color(0xFF546E7A)
    ..style = PaintingStyle.fill;

  static final Paint _cablePaint = Paint()
    ..color = const Color(0xFF90A4AE) // Suspension cables
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  static final Paint _deckPaint = Paint()
    ..color = const Color(0xFF37474F) // Platform deck
    ..style = PaintingStyle.fill;

  static final Paint _deckEdgePaint = Paint()
    ..color = const Color(0xFFF9A825) // Hazard-striped front lip
    ..style = PaintingStyle.fill;

  static final Paint _railingPaint = Paint()
    ..color = const Color(0xFFB0BEC5)
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke;

  static final Paint _workerPaint = Paint()
    ..color = const Color(0xFF26A69A) // Washer's teal overalls
    ..style = PaintingStyle.fill;

  static final Paint _hatPaint = Paint()
    ..color = const Color(0xFFFDD835) // Hard hat
    ..style = PaintingStyle.fill;

  static final Paint _skinPaint = Paint()
    ..color = const Color(0xFF8D5524)
    ..style = PaintingStyle.fill;

  static final Paint _squeegeePaint = Paint()
    ..color = const Color(0xFF455A64)
    ..style = PaintingStyle.fill;

  static final Paint _bucketPaint = Paint()
    ..color = const Color(0xFFE53935) // Red soap bucket
    ..style = PaintingStyle.fill;

  static final Paint _sudPaint = Paint()
    ..color = const Color(0xFFE1F5FE).withValues(alpha: 0.85)
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Rooftop davit boom across the top, with its tie-back mast on the
    //    right edge running down to the pavement.
    canvas.drawRect(Rect.fromLTWH(0.0, 6.0, w, 10.0), _boomPaint);
    canvas.drawRect(Rect.fromLTWH(w - 18.0, 16.0, 10.0, h - 20.0), _mastPaint);
    canvas.drawRect(Rect.fromLTWH(w - 26.0, h - 10.0, 26.0, 8.0), _mastPaint);

    // 2. Suspension cables from the boom down to the platform corners.
    final surfaceLocalY = surfaceY - position.y;
    final deckTop = surfaceLocalY;
    canvas.drawLine(const Offset(10.0, 16.0), Offset(10.0, deckTop), _cablePaint);
    canvas.drawLine(
        Offset(w - 14.0, 16.0), Offset(w - 14.0, deckTop), _cablePaint);

    // 3. Platform: steel deck with hazard-striped front lip and railing.
    final deck = Rect.fromLTWH(
        platformInset, deckTop, w - platformInset * 2, 10.0);
    canvas.drawRect(deck, _deckPaint);
    canvas.drawRect(
      Rect.fromLTWH(deck.left, deck.bottom - 3.0, deck.width, 3.0),
      _deckEdgePaint,
    );
    canvas.drawLine(
      Offset(deck.left + 2.0, deckTop - 12.0),
      Offset(deck.right - 2.0, deckTop - 12.0),
      _railingPaint,
    );
    for (final rx in [deck.left + 2.0, w * 0.5, deck.right - 2.0]) {
      canvas.drawLine(Offset(rx, deckTop), Offset(rx, deckTop - 12.0), _railingPaint);
    }

    // 4. The washer, squeegee sweeping in a slow wipe.
    final wipe = math.sin(bobTime * 3.4);
    final workerX = w * 0.36;
    final workerY = deckTop - 14.0;
    canvas.drawRect(
      Rect.fromLTWH(workerX - 5.0, workerY - 8.0, 10.0, 14.0),
      _workerPaint,
    );
    canvas.drawCircle(Offset(workerX, workerY - 12.0), 4.5, _skinPaint);
    // Hard hat with a little brim.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(workerX, workerY - 13.0), radius: 5.0),
      math.pi,
      math.pi,
      false,
      _hatPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(workerX - 6.0, workerY - 14.0, 12.0, 1.6),
      _hatPaint,
    );
    // Squeegee arm sweeping the glass ahead of the platform.
    final armX = workerX + 10.0 + wipe * 7.0;
    canvas.drawLine(Offset(workerX + 4.0, workerY - 4.0), Offset(armX, workerY - 7.0), _workerPaint);
    canvas.drawRect(Rect.fromLTWH(armX - 1.5, workerY - 12.0, 3.0, 10.0), _squeegeePaint);

    // 5. Red soap bucket at the deck's far end.
    canvas.drawRect(
      Rect.fromLTWH(deck.right - 12.0, deckTop - 8.0, 9.0, 8.0),
      _bucketPaint,
    );

    // 6. Soap suds dripping off the deck's front lip.
    for (var s = 0; s < 3; s++) {
      final cycle = ((bobTime * 0.55 + s * 0.37) % 1.0);
      final dripY = deck.bottom + cycle * 34.0;
      final dripX = deck.left + 12.0 + s * (deck.width - 20.0) / 2.0;
      canvas.drawCircle(Offset(dripX, dripY), 1.6 + (1.0 - cycle) * 0.8, _sudPaint);
    }
  }
}
