import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// What one [ManholeGeyserComponent.checkGeyser] call decided.
enum GeyserUpdate {
  /// Nothing happened this frame.
  none,

  /// The courier came within earshot and the lid began to rattle.
  rumblingStarted,

  /// Pressure blew this frame and the courier missed the steam column.
  erupting,

  /// Pressure blew this frame with the courier in the column: launched.
  launched,
}

/// Street-level manhole cover over a pressurized sewer main: a heavy
/// cast-iron rim with checkerboard grip and steam vent holes.
///
/// When the courier draws near, the lid rattles as pressure builds; the
/// geyser then erupts — the lid blasts off, a steam column rises, and any
/// courier standing in the column is launched skyward (+480 px/s).
class ManholeGeyserComponent extends PositionComponent {
  ManholeGeyserComponent({
    required Vector2 position,
    double width = 48.0,
    double height = 14.0,
    this.groundY = 460.0,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;

  ManholeGeyserState state = ManholeGeyserState.idle;

  /// Seconds left on the pressure-build rattle once it starts.
  double rumbleTimer = 0.0;

  /// How long the lid rattles before the eruption, in seconds.
  static const double rumbleDuration = 0.55;

  /// Horizontal distance at which the courier's approach starts the rattle.
  static const double proximityRange = 180.0;

  /// Horizontal distance at which the eruption fires without waiting for
  /// the rattle to finish, so a fast courier is not outrun by the buildup.
  static const double triggerRange = 70.0;

  /// Upward launch impulse for a courier caught in the steam column.
  static const double launchImpulse = 480.0;

  /// Half width of the steam column that catches a courier.
  static const double columnHalfWidth = 46.0;

  /// How high above the rim the column still catches a courier: higher
  /// than this and a gliding courier passes over untouched.
  static const double catchHeight = 150.0;

  /// Lid flight state after the eruption.
  double lidOffsetY = 0.0;
  double lidVelocityY = 0.0;
  double lidRotation = 0.0;

  /// Tremor jitter offset applied to the rim while pressure builds.
  double tremorX = 0.0;

  /// World-space X center of the manhole, where the column rises.
  double get centerX => position.x + size.x / 2;

  /// Center point of the rim in world coordinates, where steam anchors.
  Vector2 get rimCenterWorld =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.5));

  /// Center point of the manhole in world coordinates.
  Vector2 get centerWorldPosition => rimCenterWorld;

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);

    if (state == ManholeGeyserState.rumbling) {
      rumbleTimer -= dt;
      // Tremor: the lid jitters in its seat as pressure hammers it.
      tremorX = (math.Random().nextDouble() - 0.5) * 2.4;
    } else {
      tremorX = 0.0;
    }

    if (state == ManholeGeyserState.erupted && lidOffsetY > -420.0) {
      // The lid is blown clear: it accelerates up and spins away.
      lidVelocityY -= 1500.0 * dt;
      lidOffsetY += lidVelocityY * dt;
      lidRotation += 9.0 * dt;
    }
  }

  /// Evaluates the geyser against the approaching courier for one frame.
  ///
  /// Starts the rattle when the courier draws near, then erupts either when
  /// the pressure finishes building or the courier steps onto the lid,
  /// whichever comes first. Launches the courier when they stand in the
  /// steam column, grounded or airborne — the street itself throws them.
  GeyserUpdate checkGeyser(
    Vector2 playerPos,
    Vector2 playerSize,
    JumpPhysicsSimulator simulator,
  ) {
    if (state == ManholeGeyserState.erupted) return GeyserUpdate.none;

    final courierCenterX = playerPos.x + playerSize.x / 2;
    final distance = (courierCenterX - centerX).abs();

    if (state == ManholeGeyserState.idle) {
      if (distance < proximityRange) {
        state = ManholeGeyserState.rumbling;
        rumbleTimer = rumbleDuration;
        return GeyserUpdate.rumblingStarted;
      }
      return GeyserUpdate.none;
    }

    // Rumbling: erupt when the pressure finishes building, or immediately
    // if the courier steps onto the lid before the buildup completes.
    if (rumbleTimer > 0.0 && distance > triggerRange) {
      return GeyserUpdate.none;
    }

    // Eruption.
    state = ManholeGeyserState.erupted;
    lidVelocityY = -260.0;
    tremorX = 0.0;

    // The steam column catches a courier near the street: grounded or
    // airborne, anyone standing in it rides the blast.
    final footY = simulator.currentY;
    final inColumn = distance <= columnHalfWidth;
    final lowEnough = footY >= groundY - catchHeight && footY <= groundY + 10.0;
    if (inColumn && lowEnough) {
      simulator.launch(launchImpulse);
      return GeyserUpdate.launched;
    }
    return GeyserUpdate.erupting;
  }

  /// Marks the geyser as erupted without a courier check (test seam).
  void forceErupt() {
    state = ManholeGeyserState.erupted;
    lidVelocityY = -260.0;
    tremorX = 0.0;
  }

  // Visual styling paints
  static final Paint _rimPaint = Paint()
    ..color = const Color(0xFF37474F) // Heavy cast-iron rim
    ..style = PaintingStyle.fill;

  static final Paint _rimHighlightPaint = Paint()
    ..color = const Color(0xFF546E7A)
    ..style = PaintingStyle.fill;

  static final Paint _lidPaint = Paint()
    ..color = const Color(0xFF455A64) // The heavy iron lid
    ..style = PaintingStyle.fill;

  static final Paint _lidLinePaint = Paint()
    ..color = const Color(0xFF263238)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _gripLightPaint = Paint()
    ..color = const Color(0xFF607D8B) // Checkerboard cross-hatch grip
    ..style = PaintingStyle.fill;

  static final Paint _ventPaint = Paint()
    ..color = const Color(0xFF102027) // Steam vent holes
    ..style = PaintingStyle.fill;

  static final Paint _holePaint = Paint()
    ..color = const Color(0xFF0A1216) // The open sewer throat
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // The sewer throat beneath the lid: visible once the lid is gone.
    canvas.save();
    canvas.translate(tremorX, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 0.78,
        height: h * 0.72,
      ),
      _holePaint,
    );

    // The lid, in its seat until it blasts off.
    if (lidOffsetY > -420.0) {
      canvas.save();
      canvas.translate(w * 0.5, h * 0.5 + lidOffsetY);
      canvas.rotate(lidRotation);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.78, height: h * 0.72),
        _lidPaint,
      );

      // Checkerboard cross-hatch grip: alternating quadrant fills.
      const quads = [
        (-0.30, -0.16),
        (0.06, -0.16),
        (-0.12, 0.0),
        (0.24, 0.0),
      ];
      for (final (qx, qy) in quads) {
        canvas.drawRect(
          Rect.fromLTWH(w * qx, h * qy, w * 0.24, h * 0.16),
          _gripLightPaint,
        );
      }

      // Checkerboard line work.
      canvas.drawLine(
        Offset(-w * 0.39, -h * 0.08),
        Offset(w * 0.39, -h * 0.08),
        _lidLinePaint,
      );
      canvas.drawLine(
        Offset(-w * 0.39, h * 0.08),
        Offset(w * 0.39, h * 0.08),
        _lidLinePaint,
      );
      canvas.drawLine(
        Offset(-w * 0.18, -h * 0.36),
        Offset(-w * 0.18, h * 0.36),
        _lidLinePaint,
      );
      canvas.drawLine(
        Offset(w * 0.18, -h * 0.36),
        Offset(w * 0.18, h * 0.36),
        _lidLinePaint,
      );

      // Steam vent holes punched along the rim.
      for (final vx in [-0.32, -0.11, 0.11, 0.32]) {
        canvas.drawCircle(Offset(w * vx, -h * 0.22), 1.6, _ventPaint);
      }
      canvas.restore();
    }
    canvas.restore();

    // The cast-iron rim in the pavement, drawn over the lid edges.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5 + tremorX, h * 0.5),
        width: w,
        height: h,
      ),
      _rimPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5 + tremorX, h * 0.5),
        width: w * 0.94,
        height: h * 0.62,
      ),
      _rimHighlightPaint,
    );
  }
}

/// Lifecycle of the manhole within a run.
enum ManholeGeyserState {
  /// Waiting for the courier to draw near.
  idle,

  /// The lid rattles while pressure builds.
  rumbling,

  /// The geyser has blown; the lid is gone and the hole stands open.
  erupted,
}
