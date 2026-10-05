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
  mailbox,
  van,
  skateMessenger,
  pigeonFlock,
  thirdRail,
  subwayTrain,
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

  /// How fast the street is scrolling, in px/s. The game keeps this current;
  /// a flock uses it to decide when to take off.
  double streetSpeed = 200.0;

  /// The closest a courier gets to a roosting flock before it takes off.
  static const double pigeonStartleDistance = 180.0;

  /// How long before the courier arrives a flock takes off. It climbs at
  /// 140 px/s, so this lifts it clear of a courier running or hopping
  /// underneath, whatever the speed of the street. (A hop puts the top of
  /// the courier's head about 123 px up, and at walking pace the hop can
  /// peak a fifth of a second before the two cross.)
  ///
  /// The take-off used to be at [pigeonStartleDistance] and nothing else.
  /// That is 0.9 s of warning at the start of a shift and a third of a
  /// second at top speed, by which time the flock was at head height: early
  /// on the way through was to keep running, later the same flock hit a
  /// courier who kept running and could not be hopped at all.
  static const double pigeonStartleSeconds = 1.2;

  /// How far ahead of the courier a flock takes off at the current speed.
  double get pigeonStartleRange =>
      math.max(pigeonStartleDistance, streetSpeed * pigeonStartleSeconds);

  /// Internal timer for procedural movement and wing flapping animations.
  double animationTimer = 0.0;

  bool hasCollidedWithPlayer = false;
  bool hasTriggeredNearMiss = false;

  /// Whether this obstacle is a low, rigid urban fixture eligible for agile parkour vaulting.
  bool get isVaultable =>
      type == ObstacleType.hydrant ||
      type == ObstacleType.mailbox ||
      type == ObstacleType.scooter ||
      type == ObstacleType.thirdRail;

  /// Whether the courier has already initiated an agile parkour vault over this obstacle.
  bool hasBeenVaulted = false;

  bool get shouldRecycle => position.x < -200.0 || position.y < -150.0;

  static double defaultRelativeVelocityForType(ObstacleType type) {
    switch (type) {
      case ObstacleType.skateMessenger:
        return 65.0;
      case ObstacleType.subwayTrain:
        return 80.0;
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
      case ObstacleType.mailbox:
      case ObstacleType.skateMessenger:
      case ObstacleType.pigeonFlock:
      case ObstacleType.thirdRail:
      case ObstacleType.subwayTrain:
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
      case ObstacleType.mailbox:
        return Vector2(30, 42);
      case ObstacleType.van:
        return Vector2(120, 68);
      case ObstacleType.skateMessenger:
        return Vector2(46, 42);
      case ObstacleType.pigeonFlock:
        return Vector2(44, 28);
      case ObstacleType.thirdRail:
        return Vector2(58, 24);
      case ObstacleType.subwayTrain:
        return Vector2(110, 64);
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
      if (!isFlocking && (position.x - 120.0) < pigeonStartleRange) {
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
      if (hasBeenVaulted || other.isVaulting) return;
      hasCollidedWithPlayer = true;
      other.takeDamage(source: type);
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
      case ObstacleType.mailbox:
        _renderMailbox(canvas);
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
      case ObstacleType.thirdRail:
        _renderThirdRail(canvas);
        break;
      case ObstacleType.subwayTrain:
        _renderSubwayTrain(canvas);
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

  void _renderMailbox(Canvas canvas) {
    final bodyPaint = Paint()..color = const Color(0xFF003882); // Classic USPS Blue
    final darkBodyPaint = Paint()..color = const Color(0xFF002255);
    final handlePaint = Paint()..color = const Color(0xFFBDC3C7);
    final whitePaint = Paint()..color = Colors.white;
    final legPaint = Paint()..color = const Color(0xFF2C3E50);

    const legHeight = 4.0;
    final boxHeight = size.y - legHeight;

    // 1. Support legs at bottom corners
    canvas.drawRect(Rect.fromLTWH(2, boxHeight, 5, legHeight), legPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 7, boxHeight, 5, legHeight), legPaint);

    // 2. Main collection box rounded body
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 8, size.x, boxHeight - 8),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      bodyPaint,
    );

    // 3. Rounded top curved hood
    final domePath = Path()
      ..moveTo(0, 8)
      ..quadraticBezierTo(size.x / 2, -2, size.x, 8)
      ..close();
    canvas.drawPath(domePath, bodyPaint);

    // Inner shadow under drop chute hood
    canvas.drawRect(Rect.fromLTWH(3, 10, size.x - 6, 8), darkBodyPaint);

    // 4. Drop-down parcel chute flap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 11, size.x - 8, 6),
        const Radius.circular(1.5),
      ),
      handlePaint,
    );
    // Chute handle grip
    canvas.drawRect(Rect.fromLTWH((size.x / 2) - 4, 13, 8, 2), whitePaint);

    // 5. White postal collection plaque / emblem
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 22, size.x - 12, 10),
        const Radius.circular(2),
      ),
      whitePaint,
    );
    final blueBarPaint = Paint()..color = const Color(0xFF003882);
    canvas.drawRect(Rect.fromLTWH(8, 24, size.x - 16, 2), blueBarPaint);
    canvas.drawRect(Rect.fromLTWH(8, 28, size.x - 20, 2), blueBarPaint);
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

  void _renderThirdRail(Canvas canvas) {
    // 1. Ceramic Insulator Standoff Pedestals
    final insulatorPaint = Paint()..color = const Color(0xFFE67E22);
    final bracketPaint = Paint()..color = const Color(0xFF7F8C8D);

    // Two support brackets along the base
    canvas.drawRect(Rect.fromLTWH(8, size.y - 8, 10, 8), bracketPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(9, size.y - 14, 8, 8), const Radius.circular(2)),
      insulatorPaint,
    );

    canvas.drawRect(Rect.fromLTWH(size.x - 18, size.y - 8, 10, 8), bracketPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.x - 17, size.y - 14, 8, 8), const Radius.circular(2)),
      insulatorPaint,
    );

    // 2. High-Voltage Steel Conductor Third Rail
    final railPaint = Paint()..color = const Color(0xFF2C3E50);
    final railHighlight = Paint()..color = const Color(0xFF7F8C8D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, size.y - 20, size.x, 8), const Radius.circular(2)),
      railPaint,
    );
    canvas.drawLine(
      Offset(2, size.y - 19),
      Offset(size.x - 2, size.y - 19),
      railHighlight..strokeWidth = 1.5,
    );

    // 3. Wooden / Composite Protective Safety Cover Board
    final coverPaint = Paint()..color = const Color(0xFF6C3428);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-2, size.y - 24, size.x + 4, 4), const Radius.circular(1.5)),
      coverPaint,
    );

    // 4. Animated Electric Arc Discharge Sparks
    final sparkPhase = (animationTimer * 12.0).toInt() % 4;
    final sparkPaint = Paint()
      ..color = sparkPhase.isEven ? const Color(0xFF00E5FF) : const Color(0xFFFFFF00)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0x6600E5FF)
      ..style = PaintingStyle.fill;

    // Glowing electric nodes
    final sparkX1 = 12.0 + (math.sin(animationTimer * 15.0) * 8.0);
    final sparkX2 = size.x - 14.0 + (math.cos(animationTimer * 18.0) * 8.0);
    canvas.drawCircle(Offset(sparkX1, size.y - 16), 3.5, glowPaint);
    canvas.drawCircle(Offset(sparkX2, size.y - 16), 3.5, glowPaint);

    // Jagged electric spark lines
    final sparkPath1 = Path()
      ..moveTo(sparkX1 - 4, size.y - 16)
      ..lineTo(sparkX1, size.y - 22)
      ..lineTo(sparkX1 + 3, size.y - 18)
      ..lineTo(sparkX1 + 7, size.y - 24);
    canvas.drawPath(sparkPath1, sparkPaint);

    final sparkPath2 = Path()
      ..moveTo(sparkX2 - 5, size.y - 16)
      ..lineTo(sparkX2 - 2, size.y - 23)
      ..lineTo(sparkX2 + 2, size.y - 17)
      ..lineTo(sparkX2 + 6, size.y - 21);
    canvas.drawPath(sparkPath2, sparkPaint);
  }

  void _renderSubwayTrain(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // 1. Heavy Steel Undercarriage & Wheels
    final chassisPaint = Paint()..color = const Color(0xFF1A1A1D);
    final wheelPaint = Paint()..color = const Color(0xFF2C3E50);
    final wheelRim = Paint()
      ..color = const Color(0xFF7F8C8D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Undercarriage base
    canvas.drawRect(Rect.fromLTWH(6, h - 8, w - 12, 5), chassisPaint);

    // Steel wheels
    for (final x in [14.0, 32.0, w - 36.0, w - 18.0]) {
      canvas.drawCircle(Offset(x, h - 5), 5.0, wheelPaint);
      canvas.drawCircle(Offset(x, h - 5), 5.0, wheelRim);
    }

    // 2. Stainless Steel Car Body
    final bodyPaint = Paint()..color = const Color(0xFFBDC3C7);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 4, w, h - 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Roof curve cap
    final roofPaint = Paint()..color = const Color(0xFF7F8C8D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, 8), const Radius.circular(4)),
      roofPaint,
    );

    // 3. Corrugated Horizontal Fluting Panels
    final flutingPaint = Paint()
      ..color = const Color(0xFF7F8C8D)
      ..strokeWidth = 1.5;
    for (double y = h - 28.0; y <= h - 14.0; y += 4.0) {
      canvas.drawLine(Offset(4, y), Offset(w - 4, y), flutingPaint);
    }

    // 4. Front Cab Windshield
    final windowPaint = Paint()..color = const Color(0xFF1C2833);
    final cabWindowRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 10, 26, 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(cabWindowRect, windowPaint);

    // Passenger Side Windows with Warm Interior Glow
    final interiorLightPaint = Paint()..color = const Color(0xFFFFF9C4);
    for (double wx = 36.0; wx < w - 16.0; wx += 22.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(wx, 12, 16, 14), const Radius.circular(2)),
        interiorLightPaint,
      );
      // Window frame
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(wx, 12, 16, 14), const Radius.circular(2)),
        Paint()
          ..color = const Color(0xFF2C3E50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // 5. Destination Rollsign ("EXP 1")
    final signBg = Paint()..color = const Color(0xFFC0392B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6, 4, 30, 6), const Radius.circular(2)),
      signBg,
    );
    final signTextPainter = TextPainter(
      text: const TextSpan(
        text: 'EXP 1',
        style: TextStyle(
          color: Colors.white,
          fontSize: 4.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    signTextPainter.paint(canvas, const Offset(8, 4.5));

    // 6. High-Beam Halogen Headlights & Forward Light Cones
    final headlightGlow = Paint()
      ..color = const Color(0x33FFF59D)
      ..style = PaintingStyle.fill;
    final headlightBulb = Paint()..color = const Color(0xFFFFF176);

    // Leftward forward light beam projection
    final lightBeam = Path()
      ..moveTo(4, h - 18)
      ..lineTo(-35, h - 30)
      ..lineTo(-35, h + 4)
      ..lineTo(4, h - 12)
      ..close();
    canvas.drawPath(lightBeam, headlightGlow);

    // Twin front headlight bulbs
    canvas.drawCircle(Offset(4, h - 18), 3.0, headlightBulb);
    canvas.drawCircle(Offset(4, h - 12), 3.0, headlightBulb);

    // Red safety clearance lights at top corners
    final redMarker = Paint()..color = const Color(0xFFFF3838);
    canvas.drawCircle(const Offset(2, 6), 1.5, redMarker);
    canvas.drawCircle(Offset(w - 2, 6), 1.5, redMarker);
  }
}
