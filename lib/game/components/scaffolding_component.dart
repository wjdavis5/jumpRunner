import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Elevated construction scaffolding walkway that creates an aerial traversal route
/// above street level.
///
/// Features industrial steel framing, yellow-black hazard edge markings,
/// and vertical truss pillars reaching down to the sidewalk floor.
class ScaffoldingComponent extends PositionComponent {
  ScaffoldingComponent({
    required Vector2 position,
    required Vector2 size,
    this.groundY = 460.0,
  }) : super(position: position, size: size);

  final double groundY;

  /// Top surface Y coordinate where the courier walks.
  double get surfaceY => position.y;

  /// Whether this scaffolding segment has scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -120.0;

  static final Paint _deckPaint = Paint()..color = const Color(0xFF2C3E50);
  static final Paint _hazardYellowPaint = Paint()..color = const Color(0xFFF1C40F);
  static final Paint _trussPaint = Paint()
    ..color = const Color(0xFF7F8C8D)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _railingPaint = Paint()
    ..color = const Color(0xFFBDC3C7)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  static final Paint _beaconPaint = Paint()..color = const Color(0xFFFF9F43);

  double _beaconTimer = 0.0;
  bool _beaconFlash = false;

  @override
  void update(double dt) {
    super.update(dt);
    _beaconTimer += dt;
    if (_beaconTimer >= 0.35) {
      _beaconTimer = 0.0;
      _beaconFlash = !_beaconFlash;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    const deckHeight = 12.0;
    final deckRect = Rect.fromLTWH(0, 0, size.x, deckHeight);

    // 1. Structural steel support pillars reaching to groundY
    const deckBottom = deckHeight;
    final totalLegHeight = (groundY - position.y) - deckBottom;

    if (totalLegHeight > 0) {
      const legSpacing = 90.0;
      double legX = 20.0;
      while (legX < size.x - 10.0) {
        // Vertical post
        canvas.drawLine(
          Offset(legX, deckBottom),
          Offset(legX, deckBottom + totalLegHeight),
          _trussPaint,
        );

        // Cross-brace diagonal
        final nextLegX = legX + legSpacing;
        if (nextLegX <= size.x) {
          canvas.drawLine(
            Offset(legX, deckBottom),
            Offset(nextLegX, deckBottom + totalLegHeight),
            _trussPaint,
          );
          canvas.drawLine(
            Offset(nextLegX, deckBottom),
            Offset(legX, deckBottom + totalLegHeight),
            _trussPaint,
          );
        }
        legX += legSpacing;
      }
    }

    // 2. Safety Railing along the back edge of the scaffolding
    canvas.drawLine(const Offset(0, -14), Offset(size.x, -14), _railingPaint);
    for (double rx = 0; rx <= size.x; rx += 45.0) {
      canvas.drawLine(Offset(rx, 0), Offset(rx, -14), _railingPaint);
    }

    // 3. Walkway Deck
    canvas.drawRRect(
      RRect.fromRectAndRadius(deckRect, const Radius.circular(3)),
      _deckPaint,
    );

    // 4. Hazard Warning Stripes along front lip
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(deckRect, const Radius.circular(3)));
    const stripeWidth = 12.0;
    for (double sx = -stripeWidth; sx < size.x + stripeWidth; sx += stripeWidth * 2) {
      final path = Path()
        ..moveTo(sx, deckHeight)
        ..lineTo(sx + stripeWidth, 0)
        ..lineTo(sx + stripeWidth * 1.8, 0)
        ..lineTo(sx + stripeWidth * 0.8, deckHeight)
        ..close();
      canvas.drawPath(path, _hazardYellowPaint);
    }
    canvas.restore();

    // 5. Corner Safety Beacons (amber strobe)
    if (_beaconFlash) {
      canvas.drawCircle(const Offset(6, -4), 4.5, _beaconPaint);
      canvas.drawCircle(Offset(size.x - 6, -4), 4.5, _beaconPaint);
    }
  }
}
