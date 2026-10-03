import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'courier_player.dart';

/// Types of collectible pickups encountered during a courier sprint.
enum PickupType {
  coin,
  coin5,
  energyDrink,
  packageRestore,
}

/// A collectible pickup component featuring floating sine-wave bobbing animation.
class PickupComponent extends PositionComponent with CollisionCallbacks {
  PickupComponent({
    required this.type,
    Vector2? position,
    Vector2? size,
    this.onCollected,
  }) {
    this.size = size ?? Vector2(28, 28);
    if (position != null) {
      this.position = position;
    }
    _baseY = this.position.y;
  }

  final PickupType type;
  final ValueChanged<PickupType>? onCollected;

  Sprite? sprite;

  late double _baseY;
  double _bobTimer = 0.0;
  bool isCollected = false;

  bool get shouldRecycle => position.x < -200.0;

  late final RectangleHitbox hitbox;

  static String spritePathForType(PickupType type) {
    switch (type) {
      case PickupType.coin:
      case PickupType.coin5:
        return 'pickups/coin.png';
      case PickupType.energyDrink:
        return 'pickups/energy_drink.png';
      case PickupType.packageRestore:
        return 'pickups/package_box.png';
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

    hitbox = RectangleHitbox(
      position: Vector2.zero(),
      size: size,
    );
    add(hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (shouldRecycle && isMounted) {
      removeFromParent();
      return;
    }

    // Sine-wave bobbing animation
    _bobTimer += dt;
    position.y = _baseY + math.sin(_bobTimer * 4.0) * 6.0;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is CourierPlayer && !isCollected) {
      isCollected = true;
      onCollected?.call(type);
      if (isMounted) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (sprite != null) {
      sprite!.render(canvas, size: size);
      if (type == PickupType.coin5) {
        // Distinguishing badge for $5 coin
        final badgePaint = Paint()..color = const Color(0xFFE67E22);
        canvas.drawCircle(Offset(size.x - 5, 5), 4, badgePaint);
      }
      return;
    }

    switch (type) {
      case PickupType.coin:
        _renderCoin(canvas, const Color(0xFFF1C40F), r'$1');
        break;
      case PickupType.coin5:
        _renderCoin(canvas, const Color(0xFFE67E22), r'$5');
        break;
      case PickupType.energyDrink:
        _renderEnergyDrink(canvas);
        break;
      case PickupType.packageRestore:
        _renderPackageRestore(canvas);
        break;
    }
  }

  void _renderCoin(Canvas canvas, Color coinColor, String label) {
    final coinPaint = Paint()..color = coinColor;
    final rimPaint = Paint()
      ..color = const Color(0xFFB7950B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2 - 2;

    canvas.drawCircle(center, radius, coinPaint);
    canvas.drawCircle(center, radius, rimPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _renderEnergyDrink(Canvas canvas) {
    final canPaint = Paint()..color = const Color(0xFF2ECC71);
    final tabPaint = Paint()..color = const Color(0xFFBDC3C7);
    final boltPaint = Paint()..color = const Color(0xFFF1C40F);

    // Can body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 2, size.x - 12, size.y - 4),
        const Radius.circular(3),
      ),
      canPaint,
    );
    // Can top tab
    canvas.drawRect(Rect.fromLTWH(10, 0, size.x - 20, 2), tabPaint);

    // Lightning bolt logo on can
    final path = Path()
      ..moveTo(size.x / 2 + 2, 6)
      ..lineTo(size.x / 2 - 4, size.y / 2)
      ..lineTo(size.x / 2, size.y / 2)
      ..lineTo(size.x / 2 - 2, size.y - 6)
      ..lineTo(size.x / 2 + 4, size.y / 2 - 2)
      ..lineTo(size.x / 2, size.y / 2 - 2)
      ..close();
    canvas.drawPath(path, boltPaint);
  }

  void _renderPackageRestore(Canvas canvas) {
    final boxPaint = Paint()..color = const Color(0xFFD35400);
    final tapePaint = Paint()..color = const Color(0xFFF39C12);

    // Parcel box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, size.x - 6, size.y - 6),
        const Radius.circular(3),
      ),
      boxPaint,
    );
    // Parcel tape cross
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 2, 3, 4, size.y - 6),
      tapePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(3, size.y / 2 - 2, size.x - 6, 4),
      tapePaint,
    );
  }
}
