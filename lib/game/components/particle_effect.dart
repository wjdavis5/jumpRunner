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

  /// Friction sparks and brick mortar particles when grabbing and dropping a metal fire escape ladder.
  factory ParticleEffectComponent.fireEscapeSparks({
    required Vector2 position,
    int count = 18,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFFD54F), // Friction spark yellow
      Color(0xFFFF9800), // Hot iron amber
      Color(0xFFFFFFFF), // Specular white hot spark
      Color(0xFFD84315), // Brick red terracotta dust
      Color(0xFF795548), // Brownstone mortar flake
      Color(0xFF455A64), // Cast-iron rust flake
    ];

    for (var i = 0; i < count; i++) {
      final vx = (rng.nextDouble() - 0.4) * 220.0;
      final vy = -40.0 + rng.nextDouble() * 180.0;

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: Vector2(vx, vy),
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.4,
          maxLife: 0.4 + rng.nextDouble() * 0.35,
          gravity: 280.0,
          drag: 0.88,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Golden-amber oil droplets, mustard yellow streaks, and sizzling skillet steam from a food truck grease slick drift.
  factory ParticleEffectComponent.greaseSpray({
    required Vector2 position,
    int count = 16,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFFB300), // Culinary amber oil
      Color(0xFFFFEA00), // Spicy yellow mustard streak
      Color(0xFFF57F17), // Deep fryer golden crisp
      Color(0xFFFFF9C4), // Sizzling skillet vapor
      Color(0xFFFFFFFF), // Hot oil snap droplet
    ];

    for (var i = 0; i < count; i++) {
      final vx = 40.0 + rng.nextDouble() * 220.0;
      final vy = -30.0 - rng.nextDouble() * 120.0;

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: Vector2(vx, vy),
          color: palette[rng.nextInt(palette.length)],
          radius: 1.6 + rng.nextDouble() * 2.8,
          maxLife: 0.35 + rng.nextDouble() * 0.3,
          gravity: 240.0,
          drag: 0.90,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Safety cone orange plastic shards, retro-reflective vinyl flecks, and amber lantern sparks from a construction sawhorse hurdle vault.
  factory ParticleEffectComponent.sawhorseSparks({
    required Vector2 position,
    int count = 16,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFF6D00), // Safety orange plastic
      Color(0xFFFFD600), // Warning amber lantern flash
      Color(0xFFFFFFFF), // Reflective white vinyl
      Color(0xFF8D6E63), // Sawhorse timber splinter
      Color(0xFFFFAB00), // Flasher beacon glow
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed - 60.0);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.6 + rng.nextDouble() * 2.4,
          maxLife: 0.35 + rng.nextDouble() * 0.3,
          gravity: 220.0,
          drag: 0.90,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Expanding cyan microwave transmission pulses, telemetry sparks, and aluminum flecks
  /// from a rooftop satellite dish parabolic leap pad launch.
  factory ParticleEffectComponent.satellitePulse({
    required Vector2 position,
    int count = 20,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF00E5FF), // Pulsing cyan microwave beacon
      Color(0xFF00B0FF), // Electric radio telemetry
      Color(0xFFFFFFFF), // High-frequency data carrier white
      Color(0xFF7C4DFF), // Deep orbital violet ion
      Color(0xFFB0BEC5), // Polished aluminum dish fleck
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 100.0 + rng.nextDouble() * 200.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed - 120.0);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.6,
          maxLife: 0.40 + rng.nextDouble() * 0.35,
          gravity: 160.0,
          drag: 0.92,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Fluttering priority airmail envelopes, golden wax seals, and postage stamp flecks
  /// from a street postal collection mailbox hurdle vault.
  factory ParticleEffectComponent.mailScatter({
    required Vector2 position,
    int count = 18,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFFFFFF), // Crisp white priority mail envelope
      Color(0xFFD32F2F), // Express airmail red border
      Color(0xFF1976D2), // Municipal post office blue
      Color(0xFFFFD700), // Golden certification wax seal
      Color(0xFFFFCA28), // Perforated postage stamp amber
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 80.0 + rng.nextDouble() * 170.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed - 80.0);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.2,
          maxLife: 0.38 + rng.nextDouble() * 0.32,
          gravity: 190.0,
          drag: 0.91,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Chilled condensation mist plumes, copper radiator fin flecks, and thermal updraft vapor
  /// from a rooftop industrial air conditioning condenser exhaust fan.
  factory ParticleEffectComponent.condenserMist({
    required Vector2 position,
    int count = 20,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFE0F7FA), // Chilled condensation white-cyan mist
      Color(0xFF80DEEA), // Aqua thermal vapor plume
      Color(0xFFD87D4A), // Metallic copper radiator fin fleck
      Color(0xFFFFFFFF), // Specular water droplet
      Color(0xFFFFE082), // Warm ambient exhaust shimmer gold
    ];

    for (var i = 0; i < count; i++) {
      final angle = (rng.nextDouble() * math.pi) + math.pi; // Upward hemisphere arc
      final speed = 90.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(math.cos(angle) * speed * 0.7, -70.0 - rng.nextDouble() * 140.0);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.0 + rng.nextDouble() * 2.6,
          maxLife: 0.42 + rng.nextDouble() * 0.35,
          gravity: 70.0,
          drag: 0.93,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates glittering crystal shards, translucent tempered glass fragments,
  /// and sparkling prismatic dust erupting from a shattered rooftop glass skylight dome.
  factory ParticleEffectComponent.glassShatter({
    required Vector2 position,
    int count = 24,
  }) {
    final particles = <GameParticle>[];
    final rng = math.Random();

    const palette = [
      Color(0xFFE0F7FA), // Translucent cyan crystal shard
      Color(0xFFB2EBF2), // Aqua tempered glass fragment
      Color(0xFF80DEEA), // Diamond specular glint
      Color(0xFFFFFFFF), // Brilliant white prism sparkle
      Color(0xFF4DD0E1), // Deep architectural glass edge
      Color(0xFFFFE082), // Golden sunlight glint fleck
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2.0 * math.pi;
      final speed = 70.0 + rng.nextDouble() * 210.0;
      final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed * 0.75 - 40.0);

      particles.add(
        GameParticle(
          position: position.clone(),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.6,
          maxLife: 0.45 + rng.nextDouble() * 0.35,
          gravity: 220.0,
          drag: 0.92,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates swirling multi-colored floral petals, tulip blossoms, and botanical flecks
  /// erupting from a sidewalk flower vendor kiosk hurdle vault.
  factory ParticleEffectComponent.petalBurst({
    required Vector2 position,
    int count = 22,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFE91E63), // Vibrant crimson tulip red
      Color(0xFFFF4081), // Blush rose pink
      Color(0xFFFFD54F), // Sunflower golden yellow
      Color(0xFFFF7043), // Marigold orange
      Color(0xFFAB47BC), // Lavender violet purple
      Color(0xFF66BB6A), // Fresh botanical leaf green
    ];

    for (var i = 0; i < count; i++) {
      final angle = (rng.nextDouble() * math.pi) + math.pi; // Upward fanning hemisphere
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed * 0.85 - 50.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 16.0, (rng.nextDouble() - 0.5) * 8.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.2 + rng.nextDouble() * 2.4,
          maxLife: 0.55 + rng.nextDouble() * 0.40,
          gravity: 80.0,
          drag: 0.88,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates a rushing cascade of water droplets, frothing foam spray,
  /// and splintered cedar wooden stave planks erupting from a rooftop water tower breach.
  factory ParticleEffectComponent.waterTowerDeluge({
    required Vector2 position,
    int count = 26,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFE0F7FA), // Translucent cyan water drop
      Color(0xFF80DEEA), // Frothing wave spray
      Color(0xFF00E5FF), // Pressurized aquamarine torrent
      Color(0xFFFFFFFF), // Brilliant white aerated foam
      Color(0xFF8D6E63), // Splintered cedar wood stave fleck
      Color(0xFF5D4037), // Dark rustic cedar wood fiber
    ];

    for (var i = 0; i < count; i++) {
      // Fan outward and forward in a rushing hydraulic arc
      final angle = -math.pi * 0.15 + (rng.nextDouble() - 0.5) * 1.8;
      final speed = 90.0 + rng.nextDouble() * 200.0;
      final velocity = Vector2(
        math.cos(angle) * speed + 60.0,
        math.sin(angle) * speed * 0.8 - 40.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 20.0, (rng.nextDouble() - 0.5) * 14.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.0 + rng.nextDouble() * 2.8,
          maxLife: 0.50 + rng.nextDouble() * 0.35,
          gravity: 240.0,
          drag: 0.86,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates a cloud of fluttering printed newsprint sheets, headline clippings,
  /// and glossy magazine paper fragments fluttering in the urban breeze after a newsstand vault.
  factory ParticleEffectComponent.newsprintScatter({
    required Vector2 position,
    int count = 24,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFF5F5DC), // Newsprint parchment off-white
      Color(0xFFFFFDD0), // Aged paper cream
      Color(0xFFECEFF1), // Crisp paper white
      Color(0xFF37474F), // Newsprint headline dark ink
      Color(0xFFFF5252), // Tabloid headline red
      Color(0xFFFFD700), // Glossy cover golden yellow
      Color(0xFF00E5FF), // Glossy cover cyan
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 1.6;
      final speed = 80.0 + rng.nextDouble() * 140.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 16.0, (rng.nextDouble() - 0.5) * 10.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.4 + rng.nextDouble() * 2.6,
          maxLife: 0.65 + rng.nextDouble() * 0.40,
          gravity: 48.0, // Gentle floating fluttering drift
          drag: 1.65, // High air resistance for fluttering paper
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates a kinetic burst of dark rich espresso coffee droplets, golden crema foam,
  /// and white ceramic porcelain cup shards shattering upon a sidewalk cafe bistro table vault.
  factory ParticleEffectComponent.espressoPorcelainBurst({
    required Vector2 position,
    int count = 26,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF3E2723), // Dark roasted espresso liquid
      Color(0xFF4E342E), // Rich coffee drop
      Color(0xFFD7CCC8), // Golden hazelnut crema froth
      Color(0xFFFFE082), // Golden crema amber sparkle
      Color(0xFFFFFFFF), // Glazed white porcelain shard
      Color(0xFFECEFF1), // Ceramic shard
      Color(0xFFD32F2F), // Checkered tablecloth thread red
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 2.0;
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 30.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 14.0, (rng.nextDouble() - 0.5) * 10.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.2,
          maxLife: 0.45 + rng.nextDouble() * 0.35,
          gravity: 210.0, // Kinetic downward splash arc
          drag: 0.95,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates an ascending fountain burst of gleaming brass gold, jazz violet,
  /// electric cyan, and melodic sparkle particles upon encountering a sidewalk jazz saxophonist.
  factory ParticleEffectComponent.musicalNoteFountain({
    required Vector2 position,
    int count = 28,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFFD700), // Gleaming alto sax brass gold
      Color(0xFFFFB300), // Warm amber brass tone
      Color(0xFF9C27B0), // Jazz club deep violet
      Color(0xFFBA68C8), // Light jazz lavender
      Color(0xFF00E5FF), // Electric groove cyan
      Color(0xFFE91E63), // High-note saxophone magenta
      Color(0xFFFFFFFF), // Crisp acoustic chime white
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 1.6;
      final speed = 70.0 + rng.nextDouble() * 150.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 20.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 16.0, (rng.nextDouble() - 0.5) * 12.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.0 + rng.nextDouble() * 2.2,
          maxLife: 0.65 + rng.nextDouble() * 0.35,
          gravity: -42.0, // Buoyant upward acoustic harmonic drift
          drag: 1.1,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Generates a high-pressure kinetic plume of foaming water droplets, cyan spray beads,
  /// and shimmering rainbow sunlight prism particles upon a fire hydrant spray traverse.
  factory ParticleEffectComponent.hydrantWaterPlume({
    required Vector2 position,
    int count = 28,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF00E5FF), // Electric cyan water droplet
      Color(0xFF40C4FF), // Sky blue water bead
      Color(0xFF80D8FF), // Light translucent water bead
      Color(0xFFFFFFFF), // Foaming white spray crest
      Color(0xFFE0F7FA), // Soft mist white
      Color(0xFFFFD54F), // Refracted sunlight amber prism
      Color(0xFFFF80AB), // Refracted sunlight pink prism
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.45 + (rng.nextDouble() - 0.5) * 1.8;
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(
        math.cos(angle) * speed + 30.0, // Forward-downward rushing arc
        math.sin(angle) * speed - 15.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 16.0, (rng.nextDouble() - 0.5) * 10.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.2,
          maxLife: 0.50 + rng.nextDouble() * 0.35,
          gravity: 220.0, // Kinetic downward splash arc
          drag: 0.96,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Billowing cotton linen fiber wisps, colorful fabric swatches, and birch clothespin splinters from a clothesline hurdle rebound.
  factory ParticleEffectComponent.clotheslineLinenScatter({
    required Vector2 position,
    int count = 26,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFFFFFF), // Pure white cotton bedsheet
      Color(0xFFFFF9C4), // Lemon yellow pastel towel
      Color(0xFFFF8A80), // Coral red striped fabric
      Color(0xFF80D8FF), // Sky blue chambray cotton
      Color(0xFFE1BEE7), // Lavender pastel shirt
      Color(0xFFFFD180), // Amber wooden clothespin splinter
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 2.2;
      final speed = 60.0 + rng.nextDouble() * 140.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 20.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 24.0, (rng.nextDouble() - 0.5) * 12.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.6,
          maxLife: 0.55 + rng.nextDouble() * 0.40,
          gravity: 140.0, // Gentle buoyant cotton flutter
          drag: 0.94,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Billowing buoyant semi-transparent steam puffs, warm vapor eddies, and cardboard flecks from a sidewalk subway exhaust grate updraft.
  factory ParticleEffectComponent.subwayExhaustSteam({
    required Vector2 position,
    int count = 30,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xCCFFFFFF), // Pure white hot steam core
      Color(0xB3ECEFF1), // Light vapor cloud
      Color(0x99CFD8DC), // Cool gray steam condensation
      Color(0x80B0BEC5), // Street exhaust mist
      Color(0x80FFF8E1), // Warm underground tunnel ambient glow
      Color(0xFF8D6E63), // Soggy cardboard fragment
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 1.4;
      final speed = 70.0 + rng.nextDouble() * 150.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 25.0, // Upward buoyant thermal velocity
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 28.0, (rng.nextDouble() - 0.5) * 8.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 2.2 + rng.nextDouble() * 3.4,
          maxLife: 0.60 + rng.nextDouble() * 0.45,
          gravity: -54.0, // Upward buoyant thermal drift
          drag: 0.92,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// High-voltage electric blue corona discharge arcs and bright welding sparks from an aerial catenary power line zipline slide.
  factory ParticleEffectComponent.ziplineSparks({
    required Vector2 position,
    int count = 24,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFF00E5FF), // Electric cyan arc discharge
      Color(0xFF2979FF), // High-voltage cobalt blue
      Color(0xFF80D8FF), // Glowing plasma light blue
      Color(0xFFFFFFFF), // Blinding white spark core
      Color(0xFFE040FB), // High-frequency violet corona
      Color(0xFFFFD700), // Molten copper wire friction fleck
    ];

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 80.0 + rng.nextDouble() * 160.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 15.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 8.0, (rng.nextDouble() - 0.5) * 6.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.4 + rng.nextDouble() * 2.2,
          maxLife: 0.28 + rng.nextDouble() * 0.24,
          gravity: 80.0,
          drag: 0.94,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Digital LED route timetable pixel sparks and vibrant amber/cyan illumination bursts from a transit bus stop shelter vault.
  factory ParticleEffectComponent.transitLedSparks({
    required Vector2 position,
    int count = 26,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFFD54F), // Amber LED pixel
      Color(0xFFFFA000), // Deep orange-amber timetable display
      Color(0xFF00E5FF), // Transit cyan backlight
      Color(0xFF80D8FF), // Frosted glass highlight
      Color(0xFFFFFFFF), // Crisp LED white dot
      Color(0xFF00B0FF), // Metro route blue
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 1.8;
      final speed = 80.0 + rng.nextDouble() * 150.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 20.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 18.0, (rng.nextDouble() - 0.5) * 6.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.4,
          maxLife: 0.40 + rng.nextDouble() * 0.30,
          gravity: 120.0,
          drag: 0.93,
        ),
      );
    }

    return ParticleEffectComponent(particles: particles);
  }

  /// Vibrant aerosol spray paint flecks and metallic friction sparks from an industrial security shutter wall kick rebound.
  factory ParticleEffectComponent.securityShutterSparks({
    required Vector2 position,
    int count = 28,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final particles = <GameParticle>[];

    const palette = [
      Color(0xFFFF007F), // Neon hot magenta spray paint
      Color(0xFF00E5FF), // Electric cyan graffiti aerosol
      Color(0xFFFFD600), // Vivid chrome yellow tag paint
      Color(0xFF76FF03), // Lime spray splatter
      Color(0xFFFFFFFF), // Galvanized steel friction spark
      Color(0xFFB0BEC5), // Metallic zinc flake
      Color(0xFFFF1744), // Crimson aerosol mist
    ];

    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.5 + (rng.nextDouble() - 0.5) * 2.2;
      final speed = 90.0 + rng.nextDouble() * 170.0;
      final velocity = Vector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 40.0,
      );

      particles.add(
        GameParticle(
          position: position.clone() +
              Vector2((rng.nextDouble() - 0.5) * 16.0, (rng.nextDouble() - 0.5) * 16.0),
          velocity: velocity,
          color: palette[rng.nextInt(palette.length)],
          radius: 1.8 + rng.nextDouble() * 2.6,
          maxLife: 0.38 + rng.nextDouble() * 0.32,
          gravity: 140.0,
          drag: 0.92,
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
