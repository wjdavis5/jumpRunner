import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'courier_player.dart';

/// Types of urban street hazards the courier must leap over.
enum ObstacleType {
  scooter,
  dog,
  hydrant,
  van,
  skateMessenger,
  pigeonFlock,
}

/// A street hazard obstacle component in Courier Dash.
///
/// Moves leftward with world scrolling (and optional independent relative velocity),
/// carries calibrated collision hitbox, damages CourierPlayer on collision,
/// and auto-recycles past -200px offscreen.
class ObstacleComponent extends PositionComponent with CollisionCallbacks {
  ObstacleComponent({
    required this.type,
    Vector2? position,
    Vector2? size,
    double? relativeVelocityX,
  }) {
    this.size = size ?? defaultSizeForType(type);
    if (position != null) {
      this.position = position;
    }
    this.relativeVelocityX =
        relativeVelocityX ?? defaultRelativeVelocityForType(type);
  }

  final ObstacleType type;

  Sprite? sprite;

  late final RectangleHitbox hitbox;

  /// Dynamic horizontal velocity relative to world ground scroll (e.g. oncoming skate messenger).
  double relativeVelocityX = 0.0;

  /// Dynamic vertical velocity (e.g. for pigeon flock takeoff).
  double velocityY = 0.0;

  /// Whether a pigeon flock has been startled into flight.
  bool isFlocking = false;

  /// Internal timer for procedural movement and wing flapping animations.
  double animationTimer = 0.0;

  bool hasCollidedWithPlayer = false;
  bool hasTriggeredNearMiss = false;

  bool get shouldRecycle => position.x < -200.0 || position.y < -150.0;

  static double defaultRelativeVelocityForType(ObstacleType type) {
    switch (type) {
      case ObstacleType.skateMessenger:
        return 65.0;
      default:
        return 0.0;
    }
  }

  static String? spritePathForType(ObstacleType type) {
    switch (type) {
      case ObstacleType.scooter:
        return 'hazards/scooter.png';
      case ObstacleType.dog:
        return 'hazards/dog.png';
      case ObstacleType.hydrant:
        return 'hazards/hydrant.png';
      case ObstacleType.van:
        return 'hazards/van.png';
      case ObstacleType.skateMessenger:
      case ObstacleType.pigeonFlock:
        return null;
    }
  }

  static Vector2 defaultSizeForType(ObstacleType type) {
    switch (type) {
      case ObstacleType.scooter:
        return Vector2(48, 36);
      case ObstacleType.dog:
        return Vector2(40, 36);
      case ObstacleType.hydrant:
        return Vector2(32, 44);
      case ObstacleType.van:
        return Vector2(120, 68);
      case ObstacleType.skateMessenger:
        return Vector2(46, 42);
      case ObstacleType.pigeonFlock:
        return Vector2(44, 28);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final path = spritePathForType(type);
    if (path != null) {
      try {
        sprite = await Sprite.load(path);
      } catch (_) {
        sprite = null;
      }
    }

    // Hitbox calibrated slightly inside sprite bounds for fair gameplay
    final hitboxSize = Vector2(size.x * 0.9, size.y * 0.9);
    final hitboxPos = Vector2(size.x * 0.05, size.y * 0.1);
    hitbox = RectangleHitbox(
      position: hitboxPos,
      size: hitboxSize,
    );
    add(hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);
    animationTimer += dt;

    if (relativeVelocityX != 0.0) {
      position.x -= relativeVelocityX * dt;
    }

    if (type == ObstacleType.pigeonFlock) {
      // Courier runs around x = 120. When approaching within 180px, startle flock into air
      if (!isFlocking && (position.x - 120.0) < 180.0) {
        isFlocking = true;
        velocityY = -140.0;
      }
      if (isFlocking) {
        position.y += velocityY * dt;
        velocityY -= 15.0 * dt;
      }
    }

    if (shouldRecycle && isMounted) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is CourierPlayer) {
      hasCollidedWithPlayer = true;
      other.takeDamage();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (sprite != null) {
      sprite!.render(canvas, size: size);
      return;
    }

    switch (type) {
      case ObstacleType.scooter:
        _renderScooter(canvas);
        break;
      case ObstacleType.dog:
        _renderDog(canvas);
        break;
      case ObstacleType.hydrant:
        _renderHydrant(canvas);
        break;
      case ObstacleType.van:
        _renderVan(canvas);
        break;
      case ObstacleType.skateMessenger:
        _renderSkateMessenger(canvas);
        break;
      case ObstacleType.pigeonFlock:
        _renderPigeonFlock(canvas);
        break;
    }
  }

  void _renderScooter(Canvas canvas) {
    final framePaint = Paint()..color = const Color(0xFF27AE60);
    final wheelPaint = Paint()..color = const Color(0xFF2C3E50);

    // Wheels
    canvas.drawCircle(Offset(8, size.y - 6), 6, wheelPaint);
    canvas.drawCircle(Offset(size.x - 8, size.y - 6), 6, wheelPaint);

    // Deck & Handlebar
    canvas.drawRect(Rect.fromLTWH(8, size.y - 10, size.x - 16, 4), framePaint);
    canvas.drawLine(
      Offset(size.x - 10, size.y - 10),
      Offset(size.x - 14, 4),
      framePaint..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(size.x - 20, 4),
      Offset(size.x - 8, 4),
      framePaint..strokeWidth = 3,
    );
  }

  void _renderDog(Canvas canvas) {
    final furPaint = Paint()..color = const Color(0xFFD35400);
    final collarPaint = Paint()..color = const Color(0xFFE74C3C);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 12, size.x - 16, 18),
        const Radius.circular(6),
      ),
      furPaint,
    );
    // Head
    canvas.drawCircle(Offset(size.x - 8, 12), 8, furPaint);
    // Collar
    canvas.drawRect(Rect.fromLTWH(size.x - 14, 14, 4, 8), collarPaint);
    // Legs
    canvas.drawRect(const Rect.fromLTWH(8, 28, 4, 8), furPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 16, 28, 4, 8), furPaint);
  }

  void _renderHydrant(Canvas canvas) {
    final redPaint = Paint()..color = const Color(0xFFC0392B);
    final capPaint = Paint()..color = const Color(0xFF7F8C8D);

    // Base & Main barrel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 8, size.x - 12, size.y - 12),
        const Radius.circular(4),
      ),
      redPaint,
    );
    // Top dome
    canvas.drawArc(
      Rect.fromLTWH(6, 2, size.x - 12, 12),
      3.14159,
      3.14159,
      true,
      redPaint,
    );
    // Side nozzles
    canvas.drawRect(const Rect.fromLTWH(1, 16, 6, 6), capPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 7, 16, 6, 6), capPaint);
  }

  void _renderVan(Canvas canvas) {
    final vanPaint = Paint()..color = const Color(0xFF34495E);
    final windowPaint = Paint()..color = const Color(0xFF85C1E9);
    final wheelPaint = Paint()..color = const Color(0xFF17202A);

    // Chassis body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 6, size.x - 4, size.y - 18),
        const Radius.circular(6),
      ),
      vanPaint,
    );
    // Windshield & Side Windows
    canvas.drawRect(const Rect.fromLTWH(10, 12, 28, 18), windowPaint);
    canvas.drawRect(const Rect.fromLTWH(44, 12, 32, 18), windowPaint);

    // Wheels
    canvas.drawCircle(Offset(24, size.y - 8), 10, wheelPaint);
    canvas.drawCircle(Offset(size.x - 28, size.y - 8), 10, wheelPaint);
  }

  void _renderSkateMessenger(Canvas canvas) {
    final deckPaint = Paint()..color = const Color(0xFFE67E22);
    final wheelPaint = Paint()..color = const Color(0xFFF1C40F);
    final bodyPaint = Paint()..color = const Color(0xFF8E44AD);
    final bagPaint = Paint()..color = const Color(0xFFE74C3C);
    final helmetPaint = Paint()..color = const Color(0xFF2C3E50);
    final visorPaint = Paint()..color = const Color(0xFF00E5FF);
    final jeansPaint = Paint()..color = const Color(0xFF2980B9);
    final streakPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.5;

    // Skateboard Deck & Kicktails
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, size.y - 8, size.x - 8, 4),
        const Radius.circular(2),
      ),
      deckPaint,
    );

    // Skate Wheels
    canvas.drawCircle(Offset(10, size.y - 3), 3, wheelPaint);
    canvas.drawCircle(Offset(size.x - 10, size.y - 3), 3, wheelPaint);

    // Legs / Jeans (bent skating stance)
    canvas.drawRect(const Rect.fromLTWH(14, 28, 6, 8), jeansPaint);
    canvas.drawRect(const Rect.fromLTWH(26, 28, 6, 8), jeansPaint);

    // Torso / Purple Hoodie (crouched forward)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 16, 20, 14),
        const Radius.circular(3),
      ),
      bodyPaint,
    );

    // Red Messenger Sling Bag
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 18, 12, 10),
        const Radius.circular(2),
      ),
      bagPaint,
    );

    // Helmet & Visor
    canvas.drawCircle(const Offset(16, 12), 7, helmetPaint);
    canvas.drawLine(
      const Offset(10, 12),
      const Offset(15, 12),
      visorPaint..strokeWidth = 2,
    );

    // Speed Motion Wind Streaks trailing behind skater
    final animOffset = (animationTimer * 12.0) % 6.0;
    canvas.drawLine(
      Offset(size.x - 2, 16 + animOffset),
      Offset(size.x + 8, 16 + animOffset),
      streakPaint,
    );
    canvas.drawLine(
      Offset(size.x - 4, 24 - animOffset),
      Offset(size.x + 6, 24 - animOffset),
      streakPaint,
    );
  }

  void _renderPigeonFlock(Canvas canvas) {
    final bodyPaint = Paint()..color = const Color(0xFF7F8C8D);
    final headPaint = Paint()..color = const Color(0xFF566573);
    final beakPaint = Paint()..color = const Color(0xFFE67E22);
    final sheenPaint = Paint()..color = const Color(0xFF9B59B6);
    final wingPaint = Paint()..color = const Color(0xFF95A5A6);
    final feetPaint = Paint()
      ..color = const Color(0xFFD35400)
      ..strokeWidth = 1.5;

    final flapFrequency = isFlocking ? 24.0 : 6.0;
    final flapPhase = math.sin(animationTimer * flapFrequency);

    // Cluster coordinates for 3 pigeons in the flock
    final offsets = [
      const Offset(4, 8),
      const Offset(18, 12),
      const Offset(30, 6),
    ];

    for (int i = 0; i < offsets.length; i++) {
      final base = offsets[i];
      // When flocking, individual birds disperse slightly
      final scatterY = isFlocking ? (math.sin(animationTimer * 15.0 + i) * 3.0) : 0.0;
      final pX = base.dx;
      final pY = base.dy + scatterY;

      // Body
      canvas.drawOval(Rect.fromLTWH(pX, pY + 4, 10, 7), bodyPaint);

      // Head
      canvas.drawCircle(Offset(pX + 2, pY + 3), 3, headPaint);

      // Orange Beak
      canvas.drawRect(Rect.fromLTWH(pX - 2, pY + 2, 2, 2), beakPaint);

      // Purple/Green Neck Sheen
      canvas.drawRect(Rect.fromLTWH(pX + 1, pY + 4, 2, 2), sheenPaint);

      // Flapping Wing
      final wingYOffset = flapPhase * (isFlocking ? 5.0 : 2.0);
      final wingPath = Path()
        ..moveTo(pX + 4, pY + 5)
        ..lineTo(pX + 8, pY + 2 - wingYOffset)
        ..lineTo(pX + 9, pY + 6)
        ..close();
      canvas.drawPath(wingPath, wingPaint);

      // Feet on ground if not in flight
      if (!isFlocking) {
        canvas.drawLine(Offset(pX + 4, pY + 11), Offset(pX + 4, pY + 13), feetPaint);
        canvas.drawLine(Offset(pX + 7, pY + 11), Offset(pX + 7, pY + 13), feetPaint);
      }
    }
  }
}
