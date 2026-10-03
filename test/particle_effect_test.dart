import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/courier_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParticleEffectComponent & VFX (Issue #9)', () {
    test('Dust effect initializes particles and auto-recycles on expiry', () {
      final dust = ParticleEffectComponent.dust(
        position: Vector2(100, 460),
        count: 5,
      );

      expect(dust.particles.length, equals(5));
      for (final p in dust.particles) {
        expect(p.isAlive, isTrue);
        expect(p.progress, closeTo(1.0, 0.01));
        // Dust velocity drifts backward (negative X)
        expect(p.velocity.x, lessThan(0.0));
      }

      // Simulate full lifecycle
      dust.update(0.6);
      expect(dust.particles.every((p) => !p.isAlive), isTrue);
    });

    test('Sparkles effect initializes radial velocities and custom colors', () {
      final sparkles = ParticleEffectComponent.sparkles(
        position: Vector2(200, 300),
        color: const Color(0xFF2ECC71),
        count: 8,
      );

      expect(sparkles.particles.length, equals(8));
      for (final p in sparkles.particles) {
        expect(p.isAlive, isTrue);
        expect(p.velocity.length, greaterThan(0.0));
      }

      // Advance time step
      sparkles.update(0.1);
      for (final p in sparkles.particles) {
        expect(p.position, isNot(equals(Vector2(200, 300))));
      }
    });

    test('Confetti effect initializes gravity-influenced particles', () {
      final confetti = ParticleEffectComponent.confetti(
        position: Vector2(480, 100),
        count: 10,
      );

      expect(confetti.particles.length, equals(10));
      for (final p in confetti.particles) {
        expect(p.gravity, greaterThan(0.0));
      }

      final initialYVel = confetti.particles.first.velocity.y;
      confetti.update(0.2);
      expect(confetti.particles.first.velocity.y, greaterThan(initialYVel));
    });

    test('Impact effect creates debris particles with drag and gravity', () {
      final impact = ParticleEffectComponent.impact(
        position: Vector2(120, 420),
        count: 6,
      );

      expect(impact.particles.length, equals(6));
      impact.update(0.05);
      expect(impact.particles.every((p) => p.life > 0), isTrue);
    });

    test('CourierGame spawns particles on landing and milestone', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // 1. Spawning dust manually or through helper
      game.spawnDust(Vector2(120, 460));
      var effects = game.world.children.whereType<ParticleEffectComponent>();
      expect(effects.length, equals(1));

      // 2. Triggering milestone spawns confetti
      game.gameState.updateDistance(500.0);
      effects = game.world.children.whereType<ParticleEffectComponent>();
      expect(effects.length, greaterThanOrEqualTo(2));

      // 3. Restarting run clears lingering particle effects
      game.restartRun();
      effects = game.world.children.whereType<ParticleEffectComponent>();
      expect(effects.length, equals(0));
    });
  });
}
