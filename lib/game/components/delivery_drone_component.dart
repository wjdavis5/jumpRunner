import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../courier_game.dart';
import 'pickup_component.dart';

/// Aerial companion cyber drone that hovers near the courier, automatically
/// acquiring nearby pickups and retrieving them with a high-intensity cyan tractor beam.
class DeliveryDroneComponent extends PositionComponent {
  DeliveryDroneComponent({
    required this.game,
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position ?? Vector2.zero(),
          size: size ?? Vector2(36, 24),
        );

  final CourierGame game;

  /// Internal flight and rotor oscillation timer.
  double flightTimer = 0.0;

  /// Currently acquired target pickup being pulled by tractor beam.
  PickupComponent? activeTarget;

  /// Maximum sensory radius for target acquisition.
  static const double scanRadius = 260.0;

  /// Velocity at which tractor beam reels in the target pickup.
  static const double tractorPullSpeed = 620.0;

  /// Whether the drone duration has expired and it is swooping off-screen.
  bool isDeparting = false;

  @override
  void update(double dt) {
    super.update(dt);
    flightTimer += dt;

    // 1. Check expiration and handle departure swoop
    if (!game.gameState.isDroneActive) {
      isDeparting = true;
      position.x += 420.0 * dt;
      position.y -= 320.0 * dt;
      activeTarget = null;

      if ((position.y < -100 || position.x > CourierGame.virtualResolution.x + 100) &&
          isMounted) {
        removeFromParent();
      }
      return;
    }

    // 2. Smoothly follow courier player with gentle floating hover bobbing
    final player = game.player;
    final targetX = player.position.x + 34.0;
    final targetY = player.position.y - 44.0 + math.sin(flightTimer * 5.0) * 8.0;

    position.x += (targetX - position.x) * (9.0 * dt).clamp(0.0, 1.0);
    position.y += (targetY - position.y) * (9.0 * dt).clamp(0.0, 1.0);

    // 3. Scan & acquire nearest uncollected pickup
    if (activeTarget != null) {
      final target = activeTarget!;
      final diff = (target.position + target.size / 2) - (position + size / 2);
      if (target.isCollected || diff.length > scanRadius + 80.0) {
        activeTarget = null;
      }
    }

    if (activeTarget == null) {
      PickupComponent? closest;
      double closestDist = scanRadius;

      final droneCenter = position + (size / 2);
      for (final p in game.activePickups) {
        if (!p.isCollected) {
          final pCenter = p.position + (p.size / 2);
          final dist = (droneCenter - pCenter).length;
          if (dist < closestDist) {
            closestDist = dist;
            closest = p;
          }
        }
      }
      activeTarget = closest;
    }

    // 4. Reel in acquired target via tractor beam
    if (activeTarget != null) {
      final target = activeTarget!;
      final pickupCenter = target.position + (target.size / 2);
      final droneCenter = position + (size / 2);
      final diff = droneCenter - pickupCenter;
      final dist = diff.length;

      if (dist > 20.0) {
        final pull = diff.normalized() * (tractorPullSpeed * dt);
        target.position += pull;
      } else {
        // Collect!
        target.isCollected = true;
        target.onCollected?.call(target.type);
        if (target.isMounted) {
          target.removeFromParent();
        }
        activeTarget = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Render Tractor Beam if target acquired
    if (activeTarget != null && !activeTarget!.isCollected) {
      final targetCenter = activeTarget!.position + (activeTarget!.size / 2);
      final beamRel = Offset(targetCenter.x - position.x, targetCenter.y - position.y);
      final beamOrigin = Offset(size.x / 2, size.y - 2);

      // Outer wide glow beam
      final glowPaint = Paint()
        ..color = const Color(0x5500E5FF)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(beamOrigin, beamRel, glowPaint);

      // Inner concentrated beam
      final corePaint = Paint()
        ..color = const Color(0xFF00FFFF)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(beamOrigin, beamRel, corePaint);

      // Traveling energy node
      final progress = (flightTimer * 3.5) % 1.0;
      final nodePos = Offset.lerp(beamOrigin, beamRel, progress);
      if (nodePos != null) {
        canvas.drawCircle(nodePos, 3.5, Paint()..color = Colors.white);
      }
    }

    // 2. Drone Rotor Cross-Struts
    final strutPaint = Paint()
      ..color = const Color(0xFF1B2631)
      ..strokeWidth = 2.0;

    canvas.drawLine(const Offset(6, 6), Offset(size.x - 6, size.y - 6), strutPaint);
    canvas.drawLine(Offset(size.x - 6, 6), Offset(6, size.y - 6), strutPaint);

    // 3. Spinning Propeller Rotors (4 corners)
    final rotorPaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.fill;

    final rotorSpin = math.sin(flightTimer * 35.0);
    final hubs = [
      const Offset(6, 6),
      Offset(size.x - 6, 6),
      const Offset(8, 18),
      Offset(size.x - 8, 18),
    ];

    for (final hub in hubs) {
      canvas.drawOval(
        Rect.fromCenter(center: hub, width: 12.0 + rotorSpin * 2.0, height: 3.5),
        rotorPaint,
      );
      canvas.drawCircle(hub, 1.5, Paint()..color = Colors.white);
    }

    // 4. Central Aerodynamic Cyber Chassis
    final bodyPaint = Paint()..color = const Color(0xFF2C3E50);
    final bodyRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: 18,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
      bodyPaint,
    );

    // Glowing Neon Accent Stripe
    final trimPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
      trimPaint,
    );

    // 5. Optical Scanner Sensor Eye
    final lensCenter = Offset(size.x / 2 + 5, size.y / 2);
    final pulseAlpha = (180 + 75 * math.sin(flightTimer * 8.0)).toInt();
    final lensPaint = Paint()..color = const Color(0xFF00FFFF).withAlpha(pulseAlpha);

    canvas.drawCircle(lensCenter, 3.0, lensPaint);
    canvas.drawCircle(lensCenter, 1.2, Paint()..color = Colors.white);

    // Navigation Blinkers
    final blink = (flightTimer * 4).floor() % 2 == 0;
    final navPaint = Paint()
      ..color = blink ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    canvas.drawCircle(Offset(size.x / 2 - 6, size.y / 2), 1.5, navPaint);
  }
}
