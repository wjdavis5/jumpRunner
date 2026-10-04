import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// State of an individual pigeon within a rooftop or sidewalk flock.
class PigeonState {
  PigeonState({
    required this.localPos,
    required this.velocity,
    required this.flapPhase,
    required this.neckColor,
    this.isFacingRight = false,
  });

  Offset localPos;
  Vector2 velocity;
  double flapPhase;
  Color neckColor;
  bool isFacingRight;
  double peckTimer = 0.0;
  bool isAirborne = false;
}

/// Interactive urban pigeon flock roosting on rooftop ledges, scaffolding, and sidewalks.
///
/// When the courier approaches within proximity (~150px), the flock panics and scatters
/// into the air with fluttering wing kinematics and a cloud of feathers.
/// Leaping through the dispersing flock in mid-air awards a 'FLOCK SCATTER!' stunt bonus.
class PigeonFlockComponent extends PositionComponent {
  PigeonFlockComponent({
    required Vector2 position,
    int pigeonCount = 6,
    this.groundY = 460.0,
    this.onScatterTriggered,
  })  : count = pigeonCount,
        super(
          position: position,
          size: Vector2(70.0, 24.0),
        ) {
    _initPigeons();
  }

  final int count;
  final double groundY;
  final VoidCallback? onScatterTriggered;

  final List<PigeonState> pigeons = [];
  bool isScattered = false;
  bool hasAwardedStunt = false;
  double _elapsedTime = 0.0;

  void _initPigeons() {
    final rng = math.Random((position.x * 13 + position.y * 7).toInt());
    for (var i = 0; i < count; i++) {
      final offsetX = (i * 11.0) + (rng.nextDouble() * 6.0 - 3.0);
      final offsetY = (rng.nextDouble() * 4.0 - 2.0);
      final neckPalette = [
        const Color(0xFF26A69A), // Iridescent green
        const Color(0xFFAB47BC), // Iridescent violet
      ];

      pigeons.add(
        PigeonState(
          localPos: Offset(offsetX, offsetY),
          velocity: Vector2.zero(),
          flapPhase: rng.nextDouble() * math.pi * 2,
          neckColor: neckPalette[rng.nextInt(neckPalette.length)],
          isFacingRight: rng.nextBool(),
        ),
      );
    }
  }

  /// Triggers the entire flock to scatter upward and away in panic.
  void scatter() {
    if (isScattered) return;
    isScattered = true;

    final rng = math.Random();
    for (var i = 0; i < pigeons.length; i++) {
      final p = pigeons[i];
      p.isAirborne = true;
      // Launch upwards and forward/backward with parabolic flutter
      final upwardSpeed = -150.0 - rng.nextDouble() * 140.0;
      final horizontalSpeed = (rng.nextDouble() * 120.0 - 40.0) + (i % 2 == 0 ? 50.0 : -30.0);
      p.velocity = Vector2(horizontalSpeed, upwardSpeed);
      p.isFacingRight = horizontalSpeed > 0;
    }

    onScatterTriggered?.call();
  }

  /// Checks if the courier has reached proximity to trigger scattering.
  void checkProximity(Vector2 playerPos, Vector2 playerSize) {
    if (isScattered) return;

    final playerCenterX = playerPos.x + (playerSize.x / 2);
    final flockCenterX = position.x + (size.x / 2);

    final playerBottomY = playerPos.y + playerSize.y;
    final flockY = position.y + size.y;

    final horizontalDist = (playerCenterX - flockCenterX).abs();
    final verticalDist = (playerBottomY - flockY).abs();

    if (horizontalDist <= 145.0 && verticalDist <= 75.0) {
      scatter();
    }
  }

  /// Checks if the courier mid-air leap intersects the dispersing flock to award stunt combo tips.
  bool checkCourierIntersection(Vector2 playerPos, Vector2 playerSize) {
    if (!isScattered || hasAwardedStunt) return false;

    final playerRect = Rect.fromLTWH(playerPos.x, playerPos.y, playerSize.x, playerSize.y);

    for (final p in pigeons) {
      if (!p.isAirborne) continue;
      final pigeonWorldPos = Offset(position.x + p.localPos.dx, position.y + p.localPos.dy);
      final pigeonRect = Rect.fromCenter(center: pigeonWorldPos, width: 22.0, height: 18.0);

      if (playerRect.overlaps(pigeonRect)) {
        hasAwardedStunt = true;
        return true;
      }
    }

    return false;
  }

  /// Whether all pigeons have dispersed or scrolled past screen edge.
  bool get shouldRecycle {
    if (position.x + size.x < -180.0) return true;
    if (isScattered && _elapsedTime > 3.0) return true;
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedTime += dt;

    for (final p in pigeons) {
      if (p.isAirborne) {
        // High frequency wing flapping
        p.flapPhase += dt * 26.0;

        // Aerodynamic flutter: gentle lift countering gravity
        p.velocity.y += 65.0 * dt; // Light gravity
        p.localPos = Offset(
          p.localPos.dx + p.velocity.x * dt,
          p.localPos.dy + p.velocity.y * dt,
        );
      } else {
        // Roosting head bob and pecking cadence
        p.peckTimer += dt * 3.5;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final p in pigeons) {
      canvas.save();
      canvas.translate(p.localPos.dx, p.localPos.dy);

      if (p.isAirborne) {
        _renderFlyingPigeon(canvas, p);
      } else {
        _renderRoostingPigeon(canvas, p);
      }

      canvas.restore();
    }
  }

  void _renderRoostingPigeon(Canvas canvas, PigeonState p) {
    final direction = p.isFacingRight ? 1.0 : -1.0;
    final bob = math.sin(p.peckTimer) * 1.5;

    // 1. Pigeon Feet (coral / bright orange)
    final footPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-2.0, 10.0), const Offset(-2.0, 14.0), footPaint);
    canvas.drawLine(const Offset(2.0, 10.0), const Offset(2.0, 14.0), footPaint);

    // 2. Body (Blue-grey / slate)
    final bodyPaint = Paint()..color = const Color(0xFF607D8B);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.0, 6.0), width: 14.0, height: 10.0),
      bodyPaint,
    );

    // 3. Wing (Darker slate with dual wing bars)
    final wingPaint = Paint()..color = const Color(0xFF455A64);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-direction * 2.0, 5.0), width: 10.0, height: 7.0),
      wingPaint,
    );
    final wingBarPaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-direction * 4.0, 4.0),
      Offset(-direction * 1.0, 7.0),
      wingBarPaint,
    );

    // 4. Iridescent Neck Stripe (teal or purple shimmer)
    final neckPaint = Paint()..color = p.neckColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(direction * 4.5, 2.0 + bob * 0.5), width: 4.5, height: 4.5),
        const Radius.circular(2.0),
      ),
      neckPaint,
    );

    // 5. Head & Beak
    final headPaint = Paint()..color = const Color(0xFF78909C);
    final headCenter = Offset(direction * 5.5, bob);
    canvas.drawCircle(headCenter, 3.2, headPaint);

    // Eye (Orange with black pupil)
    final eyePaint = Paint()..color = const Color(0xFFFF9800);
    canvas.drawCircle(Offset(headCenter.dx + direction * 1.0, headCenter.dy - 0.8), 0.9, eyePaint);

    // Beak
    final beakPaint = Paint()..color = const Color(0xFFFFA000);
    final beakPath = Path()
      ..moveTo(headCenter.dx + direction * 2.8, headCenter.dy - 0.8)
      ..lineTo(headCenter.dx + direction * 5.2, headCenter.dy + 0.4)
      ..lineTo(headCenter.dx + direction * 2.8, headCenter.dy + 1.2)
      ..close();
    canvas.drawPath(beakPath, beakPaint);
  }

  void _renderFlyingPigeon(Canvas canvas, PigeonState p) {
    final direction = p.isFacingRight ? 1.0 : -1.0;
    final flap = math.sin(p.flapPhase);

    // Slight bank angle based on trajectory
    final flightAngle = (math.atan2(p.velocity.y, p.velocity.x) * 0.4).clamp(-0.5, 0.5);
    canvas.rotate(flightAngle);

    // 1. Tucked Feet
    final footPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-3.0, 5.0), const Offset(-1.0, 6.0), footPaint);

    // 2. Sleek Body
    final bodyPaint = Paint()..color = const Color(0xFF607D8B);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.0, 1.0), width: 15.0, height: 8.5),
      bodyPaint,
    );

    // 3. Iridescent Neck
    final neckPaint = Paint()..color = p.neckColor;
    canvas.drawCircle(Offset(direction * 4.5, -0.5), 3.0, neckPaint);

    // 4. Head & Beak
    final headPaint = Paint()..color = const Color(0xFF78909C);
    canvas.drawCircle(Offset(direction * 6.0, -1.0), 3.0, headPaint);
    final beakPaint = Paint()..color = const Color(0xFFFFA000);
    final beakPath = Path()
      ..moveTo(direction * 8.0, -1.8)
      ..lineTo(direction * 11.0, -0.8)
      ..lineTo(direction * 8.0, 0.2)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    // 5. Dynamic Flapping Wings (Extending up or down based on flapPhase)
    final wingPaint = Paint()..color = const Color(0xFF455A64);
    final wingTipPaint = Paint()..color = const Color(0xFF263238);

    final wingSweepY = flap * 11.0;

    // Near wing
    final nearWing = Path()
      ..moveTo(-1.0, 0.0)
      ..quadraticBezierTo(0.0, wingSweepY, direction * 2.0, wingSweepY - 3.0)
      ..lineTo(-direction * 5.0, wingSweepY + 2.0)
      ..close();
    canvas.drawPath(nearWing, wingPaint);

    // Wingtip accent
    final wingtip = Path()
      ..moveTo(direction * 2.0, wingSweepY - 3.0)
      ..lineTo(direction * 5.0, wingSweepY - 5.0)
      ..lineTo(-direction * 2.0, wingSweepY)
      ..close();
    canvas.drawPath(wingtip, wingTipPaint);

    // Tail feathers
    final tailPaint = Paint()..color = const Color(0xFF37474F);
    final tail = Path()
      ..moveTo(-direction * 6.0, 0.0)
      ..lineTo(-direction * 12.0, -1.5)
      ..lineTo(-direction * 11.5, 2.5)
      ..close();
    canvas.drawPath(tail, tailPaint);
  }
}
