import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Metal fire escape drop ladder mounted on apartment building facades.
///
/// Features a cast-iron balcony grate, safety railings, building anchor struts,
/// and a suspended counterweight drop ladder. When an airborne courier leaps up
/// and grabs the dangling ladder, it slides downward with chain rattle tension,
/// catapulting the courier upward onto the balcony or towards rooftops (+420 px/s).
class FireEscapeLadderComponent extends PositionComponent {
  FireEscapeLadderComponent({
    required Vector2 position,
    double width = 84.0,
    double height = 140.0,
    this.groundY = 460.0,
    this.launchImpulse = 420.0,
    this.onLadderGrab,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final double launchImpulse;
  final VoidCallback? onLadderGrab;

  bool hasDropped = false;
  double _dropProgress = 0.0;
  double _chainRattleTimer = 0.0;

  /// Top surface baseline Y of the fire escape balcony platform in world coordinates.
  double get balconyTopWorldY => position.y;

  /// World coordinates of the ladder grab hook point for particle effects.
  Vector2 get ladderGrabWorldPosition => Vector2(position.x + 55.0, position.y + 78.0);

  /// Grab hitbox for airborne courier to catch the dangling ladder rungs.
  Rect get ladderGrabWorldRect => Rect.fromLTWH(
        position.x + 36.0,
        position.y + 48.0,
        36.0,
        50.0,
      );

  /// Whether the fire escape has scrolled past the screen edge.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _ironStructurePaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.fill;

  static final Paint _ironRailingPaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _ladderRailPaint = Paint()
    ..color = const Color(0xFF263238)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  static final Paint _ladderRungPaint = Paint()
    ..color = const Color(0xFF455A64)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _chainPaint = Paint()
    ..color = const Color(0xFF78909C)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _counterweightPaint = Paint()
    ..color = const Color(0xFF1E272C)
    ..style = PaintingStyle.fill;

  static final Paint _counterweightHighlightPaint = Paint()
    ..color = const Color(0xFF546E7A)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _hazardPaint = Paint()
    ..color = const Color(0xFFF1C40F)
    ..strokeWidth = 2.0;

  @override
  void update(double dt) {
    super.update(dt);
    if (hasDropped) {
      if (_dropProgress < 1.0) {
        _dropProgress = math.min(1.0, _dropProgress + dt * 4.5);
      }
      if (_chainRattleTimer > 0) {
        _chainRattleTimer = math.max(0.0, _chainRattleTimer - dt);
      }
    }
  }

  /// Evaluates whether an airborne courier leaps up and grabs the dangling ladder.
  bool checkLadderGrab(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasDropped) return false;

    // Must be airborne to leap and grab ladder
    if (simulator.isGrounded) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final playerTop = playerPos.y;
    final playerBottom = playerPos.y + playerSize.y;

    final grabHitbox = ladderGrabWorldRect.inflate(10.0);

    final overlapsX = playerRight >= grabHitbox.left && playerLeft <= grabHitbox.right;
    final overlapsY = playerBottom >= grabHitbox.top && playerTop <= grabHitbox.bottom;

    if (overlapsX && overlapsY) {
      hasDropped = true;
      _chainRattleTimer = 0.35;
      simulator.launch(launchImpulse);
      onLadderGrab?.call();
      return true;
    }

    return false;
  }

  /// Checks if the courier is landing or standing on the fire escape balcony platform.
  bool isCourierOnBalcony(Vector2 playerPos, Vector2 playerSize, double footY) {
    final footX = playerPos.x + (playerSize.x / 2);
    final inX = footX >= position.x && footX <= position.x + size.x;
    final inY = (footY - balconyTopWorldY).abs() <= 8.0;
    return inX && inY;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    const balconyDeckHeight = 10.0;
    const balconyRailingHeight = 24.0;

    // 1. Structural wall mounting anchor struts
    final anchorPaint = Paint()
      ..color = const Color(0xFF1B262C)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Diagonal bracket braces beneath balcony
    canvas.drawLine(const Offset(8.0, balconyDeckHeight), const Offset(0.0, balconyDeckHeight + 28.0), anchorPaint);
    canvas.drawLine(Offset(w - 8.0, balconyDeckHeight), Offset(w - 20.0, balconyDeckHeight + 28.0), anchorPaint);

    // Wall mounting plates
    final platePaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRect(const Rect.fromLTWH(0.0, balconyDeckHeight + 24.0, 6.0, 8.0), platePaint);
    canvas.drawRect(Rect.fromLTWH(w - 24.0, balconyDeckHeight + 24.0, 6.0, 8.0), platePaint);

    // 2. Cast-iron Balcony Deck Platform
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0.0, 0.0, w, balconyDeckHeight), const Radius.circular(2.0)),
      _ironStructurePaint,
    );

    // Iron grating surface pattern
    final gratePaint = Paint()
      ..color = const Color(0xFF455A64)
      ..strokeWidth = 1.0;
    for (var gx = 4.0; gx < w - 4.0; gx += 6.0) {
      canvas.drawLine(Offset(gx, 1.0), Offset(gx, balconyDeckHeight - 1.0), gratePaint);
    }

    // 3. Safety Railings with Vertical Balusters
    // Top handrail
    canvas.drawLine(
      const Offset(0.0, -balconyRailingHeight),
      Offset(w, -balconyRailingHeight),
      _ironRailingPaint,
    );
    // Mid railing bar
    canvas.drawLine(
      const Offset(0.0, -balconyRailingHeight / 2),
      Offset(w, -balconyRailingHeight / 2),
      _ironRailingPaint,
    );
    // Vertical balusters
    for (var bx = 6.0; bx < w; bx += 10.0) {
      canvas.drawLine(
        Offset(bx, 0.0),
        Offset(bx, -balconyRailingHeight),
        _ironRailingPaint,
      );
    }

    // 4. Counterweight Pulley & Steel Chain
    const pulleyX = 18.0;
    const pulleyY = balconyDeckHeight + 4.0;

    // Pulley wheel
    final pulleyPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawCircle(const Offset(pulleyX, pulleyY), 4.5, pulleyPaint);

    // Counterweight bob moves UP when ladder drops
    final dropOffset = _dropProgress * 44.0;
    final counterweightY = (balconyDeckHeight + 52.0) - dropOffset;

    // Steel chain link from pulley to counterweight
    canvas.drawLine(const Offset(pulleyX - 2.0, pulleyY), Offset(pulleyX - 2.0, counterweightY), _chainPaint);

    // Cylindrical Iron Counterweight Bob
    final bobRect = Rect.fromCenter(center: Offset(pulleyX - 2.0, counterweightY + 12.0), width: 14.0, height: 24.0);
    final bobRRect = RRect.fromRectAndRadius(bobRect, const Radius.circular(3.0));
    canvas.drawRRect(bobRRect, _counterweightPaint);
    canvas.drawRRect(bobRRect, _counterweightHighlightPaint);

    // 5. Sliding Drop Ladder
    // Ladder moves DOWN when dropped
    final ladderY = balconyDeckHeight + 4.0 + dropOffset;
    const ladderX = 46.0;
    const ladderWidth = 22.0;
    const ladderLength = 76.0;

    // Connection chain from pulley to ladder top
    canvas.drawLine(const Offset(pulleyX + 2.0, pulleyY), Offset(ladderX + 2.0, ladderY), _chainPaint);

    // Dual vertical iron ladder rails
    canvas.drawLine(Offset(ladderX, ladderY), Offset(ladderX, ladderY + ladderLength), _ladderRailPaint);
    canvas.drawLine(
      Offset(ladderX + ladderWidth, ladderY),
      Offset(ladderX + ladderWidth, ladderY + ladderLength),
      _ladderRailPaint,
    );

    // Horizontal rungs
    for (var ry = ladderY + 6.0; ry < ladderY + ladderLength; ry += 10.0) {
      canvas.drawLine(Offset(ladderX, ry), Offset(ladderX + ladderWidth, ry), _ladderRungPaint);
    }

    // Safety hazard warning stripe on bottom rung
    final bottomRungY = ladderY + ladderLength - 2.0;
    canvas.drawLine(Offset(ladderX, bottomRungY), Offset(ladderX + ladderWidth, bottomRungY), _hazardPaint);
  }
}
