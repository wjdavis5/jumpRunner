import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Construction wrecking ball: a lattice crane mast standing in the street
/// background with a heavy steel ball swinging from its boom on a cable,
/// sweeping across the courier's path in a slow metronomic arc.
///
/// The ball is a pure hazard: time the run through while it is on the far
/// side of its swing, or hop it at the top of its arc. Contact knocks a
/// package loose.
class WreckingBallComponent extends PositionComponent {
  WreckingBallComponent({
    required Vector2 position,
    double width = 300.0,
    double height = 380.0,
    this.groundY = 460.0,
    double phase = 0.0,
  })  : _phase = phase,
        super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;

  /// Seconds of swing elapsed since spawn; drives the metronomic arc.
  double swingTime = 0.0;

  /// Phase offset in radians so consecutive balls do not swing in step.
  final double _phase;

  /// Swing half-arc in radians (~54 degrees each side of vertical).
  static const double swingAmplitude = 0.95;

  /// Full swing period in seconds.
  static const double swingPeriod = 2.4;

  /// Wrecking ball radius in pixels.
  static const double ballRadius = 26.0;

  /// Where the cable hangs from, relative to the component's top-left:
  /// partway along the boom arm that reaches over the street.
  Offset get anchorLocal => Offset(size.x * 0.5, 26.0);

  /// The cable is sized so the ball's low point mows across a grounded
  /// courier's upper body: its bottom clears the sidewalk by a hand's width,
  /// and a well-timed hop passes over the arc instead.
  double get cableLength {
    final anchorY = position.y + anchorLocal.dy;
    return (groundY - 36.0) - anchorY;
  }

  /// Current pendulum deflection in radians (0 = straight down).
  double get swingAngle =>
      swingAmplitude * math.sin(2 * math.pi * swingTime / swingPeriod + _phase);

  /// The ball's center in world coordinates for the current swing angle.
  Vector2 get ballCenterWorld {
    final angle = swingAngle;
    final ax = position.x + anchorLocal.dx;
    final ay = position.y + anchorLocal.dy;
    return Vector2(
      ax + math.sin(angle) * cableLength,
      ay + math.cos(angle) * cableLength,
    );
  }

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);
    swingTime += dt;
  }

  /// Evaluates whether the swinging ball is currently crushing the courier.
  ///
  /// Circle-versus-rectangle: the closest point of the courier's box to the
  /// ball's center must sit inside the ball. Damage itself flows through
  /// [CourierPlayer.takeDamage], which honors invulnerability.
  bool checkBallHit(Vector2 playerPos, Vector2 playerSize) {
    final ball = ballCenterWorld;

    // Closest point of the courier's box to the ball's center.
    final closestX = ball.x.clamp(playerPos.x, playerPos.x + playerSize.x);
    final closestY = ball.y.clamp(playerPos.y, playerPos.y + playerSize.y);

    final dx = ball.x - closestX;
    final dy = ball.y - closestY;
    return dx * dx + dy * dy <= ballRadius * ballRadius;
  }

  // Visual styling paints
  static final Paint _mastPaint = Paint()
    ..color = const Color(0xFF5D4037) // Weathered lattice tower
    ..style = PaintingStyle.fill;

  static final Paint _mastTrussPaint = Paint()
    ..color = const Color(0xFF4E342A)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _boomPaint = Paint()
    ..color = const Color(0xFFF9A825) // Safety-yellow boom arm
    ..style = PaintingStyle.fill;

  static final Paint _boomStripePaint = Paint()
    ..color = const Color(0xFF37474F)
    ..style = PaintingStyle.fill;

  static final Paint _cablePaint = Paint()
    ..color = const Color(0xFF90A4AE) // Braided steel cable
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;

  static final Paint _ballPaint = Paint()
    ..color = const Color(0xFF37474F) // Heavy steel ball
    ..style = PaintingStyle.fill;

  static final Paint _ballBandPaint = Paint()
    ..color = const Color(0xFF546E7A)
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke;

  static final Paint _ballSheenPaint = Paint()
    ..color = const Color(0xFF78909C).withValues(alpha: 0.7)
    ..style = PaintingStyle.fill;

  static final Paint _hazardPaint = Paint()
    ..color = const Color(0xFFFFD600) // Hazard band across the ball
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Lattice mast tower at the back of the component.
    _renderMast(canvas, w, h);

    // 2. Boom arm reaching over the street.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.14, anchorLocal.dy - 9.0, w * 0.72, 12.0),
      _boomPaint,
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.20 + i * w * 0.17, anchorLocal.dy - 9.0, 6.0, 12.0),
        _boomStripePaint,
      );
    }

    // 3. Cable and wrecking ball.
    final ball = ballCenterWorld;
    final anchor = Offset(position.x + anchorLocal.dx, position.y + anchorLocal.dy)
        .translate(-position.x, -position.y);
    canvas.drawLine(anchor, Offset(ball.x - position.x, ball.y - position.y), _cablePaint);

    canvas.drawCircle(
      Offset(ball.x - position.x, ball.y - position.y),
      ballRadius,
      _ballPaint,
    );
    // Banding and hazard stripe read the ball's spin-less heavy swing.
    canvas.drawCircle(
      Offset(ball.x - position.x, ball.y - position.y),
      ballRadius - 3.0,
      _ballBandPaint,
    );
    canvas.drawCircle(
      Offset(ball.x - position.x - 8.0, ball.y - position.y - 9.0),
      6.0,
      _ballSheenPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(ball.x - position.x, ball.y - position.y + ballRadius * 0.35),
        width: ballRadius * 1.5,
        height: 6.0,
      ),
      _hazardPaint,
    );
  }

  void _renderMast(Canvas canvas, double w, double h) {
    const mastWidth = 34.0;
    final mastX = w * 0.14;
    final mastTop = anchorLocal.dy - 9.0;

    canvas.drawRect(Rect.fromLTWH(mastX, mastTop, mastWidth, h - mastTop - 4.0), _mastPaint);

    // Lattice cross-bracing.
    for (var y = mastTop + 10.0; y < h - 14.0; y += 26.0) {
      canvas.drawLine(Offset(mastX, y), Offset(mastX + mastWidth, y + 22.0), _mastTrussPaint);
      canvas.drawLine(Offset(mastX + mastWidth, y), Offset(mastX, y + 22.0), _mastTrussPaint);
    }

    // Base plate where the mast meets the pavement.
    canvas.drawRect(
      Rect.fromLTWH(mastX - 10.0, h - 12.0, mastWidth + 20.0, 10.0),
      _mastPaint,
    );
  }
}
