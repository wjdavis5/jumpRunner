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
}

/// A street hazard obstacle component in Courier Dash.
///
/// Moves leftward with world scrolling, carries calibrated collision hitbox,
/// damages CourierPlayer on collision, and auto-recycles past -200px offscreen.
class ObstacleComponent extends PositionComponent with CollisionCallbacks {
  ObstacleComponent({
    required this.type,
    Vector2? position,
    Vector2? size,
  }) {
    this.size = size ?? defaultSizeForType(type);
    if (position != null) {
      this.position = position;
    }
  }

  final ObstacleType type;

  Sprite? sprite;

  late final RectangleHitbox hitbox;

  bool get shouldRecycle => position.x < -200.0;

  static String spritePathForType(ObstacleType type) {
    switch (type) {
      case ObstacleType.scooter:
        return 'hazards/scooter.png';
      case ObstacleType.dog:
        return 'hazards/dog.png';
      case ObstacleType.hydrant:
        return 'hazards/hydrant.png';
      case ObstacleType.van:
        return 'hazards/van.png';
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
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      sprite = await Sprite.load(spritePathForType(type));
    } catch (_) {
      sprite = null;
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
}
