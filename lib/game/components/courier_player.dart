import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Courier avatar state machine enum.
enum CourierState {
  running,
  jumping,
  falling,
  hurt,
}

/// The player-controlled gig economy courier.
///
/// Features calibrated torso hitbox to avoid unfair foot/limb collisions,
/// variable jump physics simulation, 1.5s post-hit invulnerability with flicker,
/// and responsive state transitions.
class CourierPlayer extends PositionComponent with CollisionCallbacks {
  CourierPlayer({
    this.groundY = 460.0,
    double initialX = 120.0,
    Vector2? playerSize,
    this.onJump,
    this.onLand,
    this.onDamage,
  }) : simulator = JumpPhysicsSimulator(groundY: groundY) {
    size = playerSize ?? Vector2(64, 64);
    position = Vector2(initialX, groundY - size.y);
  }

  final double groundY;
  final JumpPhysicsSimulator simulator;

  final VoidCallback? onJump;
  final VoidCallback? onLand;
  final VoidCallback? onDamage;

  CourierState state = CourierState.running;

  /// True when the courier is under the Cold Brew Energy Drink speed/magnet buff.
  bool isBoosted = false;

  // Invulnerability
  static const double invulnerabilityDuration = 1.5;
  double _invulnerabilityTimer = 0.0;
  bool get isInvulnerable => _invulnerabilityTimer > 0;

  // Animation cycle timer for running frames
  double _runCycleTimer = 0.0;
  int _currentRunFrame = 0;

  /// Curated Kenney character sprites for running, jumping, and hurt states.
  List<Sprite>? runSprites;
  Sprite? jumpSprite;
  Sprite? hurtSprite;

  late final RectangleHitbox torsoHitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      runSprites = await Future.wait([
        Sprite.load('courier/run_1.png'),
        Sprite.load('courier/run_2.png'),
        Sprite.load('courier/run_3.png'),
        Sprite.load('courier/run_4.png'),
      ]);
      jumpSprite = await Sprite.load('courier/jump.png');
      hurtSprite = await Sprite.load('courier/hurt.png');
    } catch (_) {
      // In headless test environments where asset bundles are mocked or unavailable,
      // fallback smoothly to procedural vector drawings.
      runSprites = null;
      jumpSprite = null;
      hurtSprite = null;
    }

    // Hitbox calibrated to the courier's torso and backpack (32x48 centered horizontally)
    // to prevent punitive collisions on swinging arms/feet.
    torsoHitbox = RectangleHitbox(
      position: Vector2((size.x - 32) / 2, size.y - 52),
      size: Vector2(32, 48),
    );
    add(torsoHitbox);
  }

  /// Triggers a jump. Returns `true` if initiated, `false` if rejected (e.g. airborne).
  bool jump() {
    if (simulator.startJump()) {
      state = CourierState.jumping;
      onJump?.call();
      return true;
    }
    return false;
  }

  /// Releases jump hold to shorten trajectory.
  void stopJump() {
    simulator.stopJump();
  }

  /// Applies damage from a hazard.
  ///
  /// Returns `true` if damage was registered; `false` if ignored due to invulnerability.
  bool takeDamage() {
    if (isInvulnerable) return false;

    _invulnerabilityTimer = invulnerabilityDuration;
    state = CourierState.hurt;
    onDamage?.call();
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final wasAirborne = !simulator.isGrounded;
    simulator.update(dt);
    position.y = simulator.currentY - size.y;

    // Handle invulnerability countdown
    if (_invulnerabilityTimer > 0) {
      _invulnerabilityTimer -= dt;
      if (_invulnerabilityTimer < 0) {
        _invulnerabilityTimer = 0;
      }
    }

    // State machine updates
    if (!simulator.isGrounded) {
      if (_invulnerabilityTimer > 0 && state == CourierState.hurt) {
        // Retain hurt visual during invulnerability
      } else if (simulator.verticalVelocity > 0) {
        state = CourierState.jumping;
      } else {
        state = CourierState.falling;
      }
    } else {
      if (wasAirborne) {
        onLand?.call();
      }
      if (_invulnerabilityTimer > 0) {
        state = CourierState.hurt;
      } else {
        state = CourierState.running;
      }
    }

    // Run animation ticker
    if (state == CourierState.running) {
      _runCycleTimer += dt;
      if (_runCycleTimer >= 0.12) {
        _runCycleTimer = 0.0;
        _currentRunFrame = (_currentRunFrame + 1) % 4;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Render electric energy aura when boosted by cold brew
    if (isBoosted) {
      _drawEnergyAura(canvas);
    }

    // Invulnerability flicker: strobe alpha at 10Hz
    if (isInvulnerable) {
      final flicker = ((_invulnerabilityTimer * 10).floor() % 2) == 0;
      if (flicker) return;
    }

    if (state == CourierState.hurt && hurtSprite != null) {
      hurtSprite!.render(canvas, size: size);
    } else if ((state == CourierState.jumping || state == CourierState.falling) && jumpSprite != null) {
      jumpSprite!.render(canvas, size: size);
    } else if (state == CourierState.running && runSprites != null && runSprites!.isNotEmpty) {
      runSprites![_currentRunFrame % runSprites!.length].render(canvas, size: size);
    } else {
      _drawCourier(canvas);
    }
  }

  void _drawEnergyAura(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final pulse = 0.5 + 0.5 * math.sin(_runCycleTimer * 25.0);

    // Glowing electric halo
    final glowPaint = Paint()
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.35 + 0.15 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 30 + 4 * pulse, glowPaint);

    final innerGlowPaint = Paint()
      ..color = const Color(0xFFF1C40F).withValues(alpha: 0.5 + 0.2 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 24, innerGlowPaint);

    // Speed trails behind the courier
    final trailPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final trailOffsets = [-6.0, 4.0, 14.0];
    for (var i = 0; i < trailOffsets.length; i++) {
      final y = center.dy + trailOffsets[i];
      final length = 18.0 + (i % 2 == 0 ? 8.0 * pulse : -4.0 * pulse);
      canvas.drawLine(
        Offset(-length, y),
        Offset(6.0, y),
        trailPaint,
      );
    }
  }

  void _drawCourier(Canvas canvas) {
    // Stylized courier rendering: courier shirt, cap, delivery backpack
    final bodyPaint = Paint()..color = const Color(0xFF2980B9);
    final backpackPaint = Paint()..color = const Color(0xFFE67E22);
    final skinPaint = Paint()..color = const Color(0xFFF5CBA7);
    final capPaint = Paint()..color = const Color(0xFFC0392B);
    final pantsPaint = Paint()..color = const Color(0xFF2C3E50);

    // Torso / Jacket
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 20, 24, 26),
        const Radius.circular(4),
      ),
      bodyPaint,
    );

    // Delivery Backpack on courier's back
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 22, 12, 22),
        const Radius.circular(3),
      ),
      backpackPaint,
    );

    // Head
    canvas.drawCircle(const Offset(30, 14), 10, skinPaint);

    // Courier Cap (visor pointing right)
    final capPath = Path()
      ..moveTo(20, 12)
      ..lineTo(40, 12)
      ..lineTo(44, 15)
      ..lineTo(20, 15)
      ..close();
    canvas.drawPath(capPath, capPaint);

    // Legs / Running pose offset
    if (state == CourierState.jumping) {
      // Tucked jump legs
      canvas.drawRect(const Rect.fromLTWH(20, 46, 8, 12), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(30, 44, 8, 10), pantsPaint);
    } else if (state == CourierState.falling) {
      // Extended landing legs
      canvas.drawRect(const Rect.fromLTWH(22, 46, 8, 16), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(32, 46, 8, 16), pantsPaint);
    } else {
      // Alternating run stride
      final legOffset = (_currentRunFrame % 2 == 0) ? 4.0 : -4.0;
      canvas.drawRect(Rect.fromLTWH(20 + legOffset, 46, 8, 16), pantsPaint);
      canvas.drawRect(Rect.fromLTWH(32 - legOffset, 46, 8, 16), pantsPaint);
    }
  }
}
