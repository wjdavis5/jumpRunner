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
  drone,
  vipPackage,
}

/// A collectible pickup component featuring floating sine-wave bobbing animation.
class PickupComponent extends PositionComponent with CollisionCallbacks {
  PickupComponent({
    required this.type,
    Vector2? position,
    Vector2? size,
    this.onCollected,
  }) {
    this.size = size ?? (type == PickupType.vipPackage ? Vector2(32, 28) : Vector2(28, 28));
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
  double _glowTimer = 0.0;
  bool isCollected = false;

  /// True while the energy-drink coin magnet is pulling this pickup.
  ///
  /// While set, the bobbing anchor is disabled so the magnet owns the
  /// position, and a pulsing gold glow marks the coin as attracted.
  bool isMagnetized = false;

  /// Countdown until the next magnet trail glint spawns (game-managed).
  double magnetTrailTimer = 0.0;

  bool get shouldRecycle => position.x < -200.0;

  late final RectangleHitbox hitbox;

  static String? spritePathForType(PickupType type) {
    switch (type) {
      case PickupType.coin:
      case PickupType.coin5:
        return 'pickups/coin.png';
      case PickupType.energyDrink:
        return 'pickups/energy_drink.png';
      case PickupType.packageRestore:
        return 'pickups/package_box.png';
      case PickupType.drone:
      case PickupType.vipPackage:
        return null;
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
    } else {
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

    // Sine-wave bobbing animation; suspended while the coin magnet owns
    // the position so its radial pull is not cancelled every frame.
    _bobTimer += dt;
    _glowTimer += dt;
    if (isMagnetized) {
      _baseY = position.y;
    } else {
      position.y = _baseY + math.sin(_bobTimer * 4.0) * 6.0;
    }
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

    if (isMagnetized) {
      // Pulsing gold halo marking the coin as caught in the magnet field.
      final pulse = 0.5 + 0.5 * math.sin(_glowTimer * 10.0);
      final haloPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.22 + 0.18 * pulse);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * (0.78 + 0.16 * pulse),
        haloPaint,
      );
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.30 * pulse);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.45,
        corePaint,
      );
    }

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
      case PickupType.drone:
        _renderDronePickup(canvas);
        break;
      case PickupType.vipPackage:
        _renderVipPackage(canvas);
        break;
    }
  }

  void _renderDronePickup(Canvas canvas) {
    final casePaint = Paint()..color = const Color(0xFF1C2833);
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final glowPaint = Paint()..color = const Color(0xFF00E5FF);

    // Crate container
    final rect = Rect.fromLTWH(2, 2, size.x - 4, size.y - 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      casePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    final center = Offset(size.x / 2, size.y / 2);

    // Quad rotor mounts (corner discs)
    canvas.drawCircle(Offset(center.dx - 6, center.dy - 6), 2.5, glowPaint);
    canvas.drawCircle(Offset(center.dx + 6, center.dy - 6), 2.5, glowPaint);
    canvas.drawCircle(Offset(center.dx - 6, center.dy + 6), 2.5, glowPaint);
    canvas.drawCircle(Offset(center.dx + 6, center.dy + 6), 2.5, glowPaint);

    // Connecting struts
    final strutPaint = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(160)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(center.dx - 6, center.dy - 6), Offset(center.dx + 6, center.dy + 6), strutPaint);
    canvas.drawLine(Offset(center.dx + 6, center.dy - 6), Offset(center.dx - 6, center.dy + 6), strutPaint);

    // Central cyber drone scanner eye
    canvas.drawCircle(center, 3.5, glowPaint);
    canvas.drawCircle(center, 1.5, Paint()..color = Colors.white);
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

  void _renderVipPackage(Canvas canvas) {
    // Luxury gold metallic briefcase with chrome corner guards, lock, and pulsing dispatch beacon
    final bodyPaint = Paint()..color = const Color(0xFFFFD700);
    final borderPaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final handlePaint = Paint()
      ..color = const Color(0xFF856404)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final chromePaint = Paint()..color = const Color(0xFFECEFF1);
    final latchPaint = Paint()..color = const Color(0xFFFFF8DC);

    // Briefcase top handle
    final handlePath = Path()
      ..moveTo(size.x / 2 - 6, 6)
      ..lineTo(size.x / 2 - 6, 2)
      ..lineTo(size.x / 2 + 6, 2)
      ..lineTo(size.x / 2 + 6, 6);
    canvas.drawPath(handlePath, handlePaint);

    // Main briefcase body
    final bodyRect = Rect.fromLTWH(2, 6, size.x - 4, size.y - 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      borderPaint,
    );

    // Center dividing seam
    final seamPaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(2, size.y / 2 + 1),
      Offset(size.x - 2, size.y / 2 + 1),
      seamPaint,
    );

    // Metallic corner guards (4 corners)
    const cornerSize = 4.0;
    canvas.drawRect(const Rect.fromLTWH(2, 6, cornerSize, cornerSize), chromePaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 2 - cornerSize, 6, cornerSize, cornerSize), chromePaint);
    canvas.drawRect(Rect.fromLTWH(2, size.y - 2 - cornerSize, cornerSize, cornerSize), chromePaint);
    canvas.drawRect(
      Rect.fromLTWH(size.x - 2 - cornerSize, size.y - 2 - cornerSize, cornerSize, cornerSize),
      chromePaint,
    );

    // Center lock & combination latch
    final lockRect = Rect.fromLTWH(size.x / 2 - 3, size.y / 2 - 2, 6, 6);
    canvas.drawRect(lockRect, latchPaint);
    final keyholePaint = Paint()..color = const Color(0xFF2C3E50);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2 + 1), 1.2, keyholePaint);

    // Pulsing red/gold dispatch beacon
    final pulse = (math.sin(_bobTimer * 8.0) + 1.0) / 2.0;
    final beaconGlowPaint = Paint()
      ..color = const Color(0xFFFF3838).withValues(alpha: 0.3 + (0.5 * pulse));
    final beaconCorePaint = Paint()..color = const Color(0xFFFF2222);

    canvas.drawCircle(Offset(size.x - 5, 9), 3.5 + (1.5 * pulse), beaconGlowPaint);
    canvas.drawCircle(Offset(size.x - 5, 9), 2.0, beaconCorePaint);

    // VIP text monogram
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'VIP',
        style: TextStyle(
          color: Color(0xFF5A381E),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        size.x / 2 - textPainter.width / 2,
        size.y / 2 - textPainter.height / 2 - 3.5,
      ),
    );
  }
}
