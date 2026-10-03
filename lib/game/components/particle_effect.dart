import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Individual procedural particle state within an effect emitter.
class GameParticle {
  GameParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    required this.maxLife,
    this.gravity = 0.0,
    this.drag = 0.0,
  }) : life = maxLife;

  Vector2 position;
  Vector2 velocity;
  Color color;
  double radius;
  double life;
  double maxLife;
  double gravity;
  double drag;

  bool get isAlive => life > 0;

  double get progress => (life / maxLife).clamp(0.0, 1.0);
}

/// Lightweight procedural particle emitter component for courier dust, coin sparks, and celebrations.
///
/// Recycles automatically by removing itself from the component tree when all particles expire.
class ParticleEffectComponent extends PositionComponent {
  ParticleEffectComponent({
    required this.particles,
  });

  /// Factory for footstep and landing sidewalk dust puffs.
  factory ParticleEffectComponent.dust({
    required Vector2 position,
    int count = 6,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    for (var i = 0; i < count; i++) {
      final angle = math.pi + (rng.nextDouble() - 0.5) * 0.8; // backward and slightly upward
      final speed = 30.0 + rng.nextDouble() * 50.0;
      final velocity = Vector2(math.cos(angle) * speed, -rng.nextDouble() * 25.0);

      particles.add(
        GameParticle(
          position: position.clone() + Vector2(rng.nextDouble() * 6 - 3, rng.nextDouble() * 4 - 2),
          velocity: velocity,
          color: const Color(0xFFBDC3C7),
          radius: 2.5 + rng.nextDouble() * 2.5,
          maxLife: 0.35 + rng.nextDouble() * 0.15,
          drag: 1.5,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for coin and pickup collection sparkles.
  factory ParticleEffectComponent.sparkles({
    required Vector2 position,
    Color color = const Color(0xFFF1C40F),
    int count = 12,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 60.0 + rng.nextDouble() * 120.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      // Alternate color highlights with white or yellow
      final particleColor = rng.nextBool() ? color : Colors.white;

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: particleColor,
          radius: 2.0 + rng.nextDouble() * 2.5,
          maxLife: 0.35 + rng.nextDouble() * 0.2,
          drag: 2.0,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for milestone shift completion confetti fireworks.
  factory ParticleEffectComponent.confetti({
    required Vector2 position,
    int count = 35,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFF1C40F), // Gold
      Color(0xFFE74C3C), // Crimson
      Color(0xFF2ECC71), // Emerald
      Color(0xFF3498DB), // Sky Blue
      Color(0xFF9B59B6), // Purple
      Color(0xFFE67E22), // Courier Orange
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.8; // fan upwards
      final speed = 120.0 + rng.nextDouble() * 200.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 3.0 + rng.nextDouble() * 3.0,
          maxLife: 0.9 + rng.nextDouble() * 0.6,
          gravity: 240.0,
          drag: 0.8,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for hazard impact / damage package fumbles.
  factory ParticleEffectComponent.impact({
    required Vector2 position,
    int count = 14,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFE74C3C), // Red
      Color(0xFFE67E22), // Orange cardboard
      Color(0xFFD35400), // Dark rust
      Color(0xFFFFFFFF), // Spark white
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 80.0 + rng.nextDouble() * 140.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.5 + rng.nextDouble() * 2.5,
          maxLife: 0.4 + rng.nextDouble() * 0.25,
          gravity: 180.0,
          drag: 1.2,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  final List<GameParticle> particles;

  @override
  void update(double dt) {
    super.update(dt);

    var hasLiving = false;
    for (final p in particles) {
      if (p.isAlive) {
        p.velocity.y += p.gravity * dt;
        p.velocity.x *= math.max(0.0, 1.0 - p.drag * dt);
        p.position += p.velocity * dt;
        p.life -= dt;
        if (p.life > 0) {
          hasLiving = true;
        }
      }
    }

    if (!hasLiving && isMounted) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final p in particles) {
      if (!p.isAlive) continue;

      final alpha = (p.progress * 255).clamp(0, 255).toInt();
      final paint = Paint()..color = p.color.withAlpha(alpha);

      final currentRadius = p.radius * (0.4 + 0.6 * p.progress);
      canvas.drawCircle(Offset(p.position.x, p.position.y), currentRadius, paint);
    }
  }
}
