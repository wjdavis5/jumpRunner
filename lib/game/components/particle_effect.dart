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

  /// Factory for footstep and landing puddle water splashes when wet/raining.
  factory ParticleEffectComponent.splash({
    required Vector2 position,
    int count = 8,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF81D4FA), // Light Blue
      Color(0xFFB3E5FC), // Pale droplet
      Color(0xFFE1F5FE), // Foam highlight
      Color(0xFFFFFFFF), // Pure droplet reflection
    ];

    for (var i = 0; i < count; i++) {
      // Fan upward and slightly backward
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.4;
      final speed = 40.0 + rng.nextDouble() * 70.0;
      final velocity = Vector2(math.cos(angle) * speed - 15.0, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() + Vector2((rng.nextDouble() - 0.5) * 8, (rng.nextDouble() - 0.5) * 3),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 1.8,
          maxLife: 0.25 + rng.nextDouble() * 0.15,
          gravity: 220.0,
          drag: 1.0,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for dynamic urban puddle splash bursts fanning outward with water droplet spray.
  factory ParticleEffectComponent.waterSpray({
    required Vector2 position,
    int count = 14,
    double direction = -1.0,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF81D4FA), // Light aqua
      Color(0xFF4FC3F7), // Droplet blue
      Color(0xFFB3E5FC), // Pale droplet
      Color(0xFFE1F5FE), // Foam highlight
      Color(0xFFFFFFFF), // Pure reflection white
    ];

    for (var i = 0; i < count; i++) {
      // Fan upward and outward in directional parabolic arc
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.8 + (direction < 0 ? -0.2 : 0.2);
      final speed = 60.0 + rng.nextDouble() * 110.0;
      final velocity = Vector2(math.cos(angle) * speed + (direction * 30.0), math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 14.0, (rng.nextDouble() - 0.5) * 4.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.0 + rng.nextDouble() * 2.2,
          maxLife: 0.35 + rng.nextDouble() * 0.25,
          gravity: 280.0,
          drag: 1.1,
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

  /// Factory for flock panic and courier scatter feather bursts.
  factory ParticleEffectComponent.feathers({
    required Vector2 position,
    int count = 12,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFECEFF1), // Light Pigeon Down
      Color(0xFFB0BEC5), // Slate Grey
      Color(0xFF78909C), // Steel Feather
      Color(0xFF37474F), // Dark Wingtip
      Color(0xFF80CBC4), // Iridescent Neck Green
      Color(0xFFCE93D8), // Iridescent Neck Purple
    ];

    for (var i = 0; i < count; i++) {
      // Scatter upwards and outward in all directions
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.2;
      final speed = 40.0 + rng.nextDouble() * 110.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 12, (rng.nextDouble() - 0.5) * 8),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.2 + rng.nextDouble() * 2.4,
          maxLife: 0.65 + rng.nextDouble() * 0.45,
          gravity: 45.0, // Slow gentle floating drift
          drag: 1.8, // High air resistance for fluttering feathers
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for hot dog / taco food cart umbrella bounce spice cloud puffs (chili, paprika, turmeric, cumin).
  factory ParticleEffectComponent.spiceCloud({
    required Vector2 position,
    int count = 16,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFE74C3C), // Chili red
      Color(0xFFD35400), // Smoked paprika
      Color(0xFFFF9800), // Cayenne orange
      Color(0xFFF1C40F), // Turmeric gold
      Color(0xFFFFE082), // Cumin dust
    ];

    for (var i = 0; i < count; i++) {
      // Fan radial outward with upward bias
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.8;
      final speed = 50.0 + rng.nextDouble() * 110.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 16.0, (rng.nextDouble() - 0.5) * 6.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.5 + rng.nextDouble() * 2.8,
          maxLife: 0.45 + rng.nextDouble() * 0.3,
          gravity: 80.0, // Soft floating drift
          drag: 1.4, // Air resistance dispersing the dust cloud
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for kinetic rooftop solar panel slide and electric surge spark bursts.
  factory ParticleEffectComponent.electricSparks({
    required Vector2 position,
    int count = 12,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF00E5FF), // Electric cyan
      Color(0xFF18FFFF), // Neon bright cyan
      Color(0xFFFFD700), // Voltage gold
      Color(0xFFFFF176), // Bright voltage yellow
      Color(0xFFFFFFFF), // Lightning white
    ];

    for (var i = 0; i < count; i++) {
      // Erratic multidirectional dispersion with slight upward bias
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.8;
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 8.0, (rng.nextDouble() - 0.5) * 4.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.2,
          maxLife: 0.22 + rng.nextDouble() * 0.18,
          gravity: 60.0,
          drag: 1.5,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for industrial HVAC exhaust wind tunnel vortex debris (swirling newspaper, paper cups, air turbulence).
  factory ParticleEffectComponent.windDebris({
    required Vector2 position,
    int count = 14,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFAFAFA), // Crisp white newspaper
      Color(0xFFCFD8DC), // Printed newsprint grey
      Color(0xFF8D6E63), // Kraft paper coffee cup
      Color(0xFF80DEEA), // Cyan aerodynamic streamline
      Color(0xFFE0F7FA), // Translucent wind wisp
    ];

    for (var i = 0; i < count; i++) {
      // Horizontal rightward jet stream with vortex turbulence
      final speed = 140.0 + rng.nextDouble() * 180.0;
      final angle = (rng.nextDouble() - 0.5) * 0.4;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 20.0, (rng.nextDouble() - 0.5) * 24.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.0 + rng.nextDouble() * 2.8,
          maxLife: 0.45 + rng.nextDouble() * 0.35,
          gravity: -10.0 + (rng.nextDouble() * 20.0),
          drag: 0.6,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for urban subway turnstile magnetic metro card swipe sparkles.
  factory ParticleEffectComponent.metroSwipe({
    required Vector2 position,
    int count = 14,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF00E5FF), // Magnetic cyan
      Color(0xFFFFD700), // Gold transit token
      Color(0xFF00E676), // Validator emerald LED
      Color(0xFFFFFFFF), // Specular spark
      Color(0xFF80D8FF), // Metro card strip highlight
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.5; // fan upward
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 10.0, (rng.nextDouble() - 0.5) * 6.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.2,
          maxLife: 0.35 + rng.nextDouble() * 0.25,
          gravity: 80.0,
          drag: 1.2,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Factory for high-altitude delivery drone cargo crate interception and supply drop sparks.
  factory ParticleEffectComponent.droneCargo({
    required Vector2 position,
    int count = 16,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFE67E22), // Courier Orange cargo crate
      Color(0xFFFFD700), // Gold latch clamp
      Color(0xFF00E5FF), // Cyan magnetic pulse
      Color(0xFF2ECC71), // Emerald supply restock glow
      Color(0xFFFFFFFF), // Specular snap spark
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 100.0 + rng.nextDouble() * 180.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.2 + rng.nextDouble() * 2.6,
          maxLife: 0.45 + rng.nextDouble() * 0.3,
          gravity: 120.0,
          drag: 0.9,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  final List<GameParticle> particles;

  /// Whether all particles in this effect have completed their lifecycle.
  bool get isFinished => particles.every((p) => !p.isAlive);

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

    if (!hasLiving && isMounted && (parent?.isMounted ?? false)) {
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
