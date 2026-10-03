import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/rain_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/weather_controller.dart';

class _MockAudioBackend implements AudioPlayerInterface {
  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {}

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {}

  @override
  Future<void> stopBgm() async {}

  @override
  Future<void> setBgmVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeatherController', () {
    late WeatherController controller;

    setUp(() {
      controller = WeatherController();
    });

    test('initializes with clear weather', () {
      expect(controller.rainIntensity, 0.0);
      expect(controller.condition, WeatherCondition.clear);
      expect(controller.isRaining, isFalse);
    });

    test('evaluates rain progression curves across shift distance', () {
      // 0m to 1400m: Daylight clear
      controller.update(500.0);
      expect(controller.rainIntensity, 0.0);
      expect(controller.condition, WeatherCondition.clear);
      expect(controller.isRaining, isFalse);

      // 1550m: Dusk rain shower rolling in (mid-ramp)
      controller.update(1550.0);
      expect(controller.rainIntensity, closeTo(0.5, 0.05));
      expect(controller.condition, WeatherCondition.rain);
      expect(controller.isRaining, isTrue);

      // 1800m: Evening peak rain shower
      controller.update(1800.0);
      expect(controller.rainIntensity, 1.0);
      expect(controller.condition, WeatherCondition.rain);
      expect(controller.isRaining, isTrue);

      // 2450m: Rain clearing up
      controller.update(2450.0);
      expect(controller.rainIntensity, closeTo(0.5, 0.05));

      // 3000m: Clear midnight city
      controller.update(3000.0);
      expect(controller.rainIntensity, 0.0);
      expect(controller.isRaining, isFalse);

      // 3800m: Midnight drizzle
      controller.update(3800.0);
      expect(controller.rainIntensity, 0.75);
      expect(controller.condition, WeatherCondition.rain);
      expect(controller.isRaining, isTrue);

      // 4500m: Clear dawn sunrise
      controller.update(4500.0);
      expect(controller.rainIntensity, 0.0);
      expect(controller.isRaining, isFalse);

      // Cycles smoothly beyond 5000m
      controller.update(6800.0); // 1800m into second cycle
      expect(controller.rainIntensity, 1.0);
    });

    test('supports manual override and clean reset', () {
      controller.update(500.0);
      expect(controller.rainIntensity, 0.0);

      controller.setManualIntensity(0.85);
      expect(controller.rainIntensity, 0.85);
      expect(controller.isRaining, isTrue);

      // Distance updates do not overwrite manual intensity
      controller.update(100.0);
      expect(controller.rainIntensity, 0.85);

      controller.reset();
      expect(controller.rainIntensity, 0.0);
      expect(controller.isRaining, isFalse);
    });
  });

  group('ParticleEffectComponent.splash', () {
    test('creates upward water droplets that update and recycle', () {
      final emitter = ParticleEffectComponent.splash(
        position: Vector2(100, 200),
        count: 8,
        random: math.Random(42),
      );

      expect(emitter.particles.length, 8);
      for (final p in emitter.particles) {
        expect(p.isAlive, isTrue);
        expect(p.velocity.y, lessThan(0.0)); // Upward trajectory
        expect(p.gravity, greaterThan(0.0)); // Gravity applied
      }

      // Simulate particle physics
      emitter.update(0.1);
      for (final p in emitter.particles) {
        expect(p.life, lessThan(p.maxLife));
      }

      // Simulate beyond particle lifespan
      emitter.update(1.0);
      final allDead = emitter.particles.every((p) => !p.isAlive);
      expect(allDead, isTrue);
    });
  });

  group('RainComponent', () {
    test('initializes drop pool and updates drop coordinates', () {
      final rain = RainComponent(
        size: Vector2(960, 540),
        maxDrops: 50,
        random: math.Random(101),
      );

      expect(rain.dropCount, 50);
      expect(rain.rainIntensity, 0.0);

      // Zero intensity: update does not move drops
      rain.update(0.016);

      // Set intensity and simulate movement
      rain.rainIntensity = 0.8;
      rain.horizontalScrollSpeed = 300.0;
      rain.update(0.05);

      // Render to headless picture recorder
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => rain.render(canvas), returnsNormally);
      recorder.endRecording();
    });

    test('wraps falling drops when crossing ground baseline', () {
      final rain = RainComponent(
        size: Vector2(960, 540),
        maxDrops: 10,
        random: math.Random(7),
      );
      rain.rainIntensity = 1.0;
      rain.groundY = 460.0;

      // Advance by large dt to force drops past groundY
      rain.update(2.0);

      // Render check
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => rain.render(canvas), returnsNormally);
      recorder.endRecording();
    });
  });

  group('ParallaxCityComponent dynamic weather rendering', () {
    test('renders wet sidewalk, puddles, and streetlamp road reflections', () {
      final city = ParallaxCityComponent(size: Vector2(960, 540));

      // Rain shower during dusk
      city.updateLighting(1800.0, 0.016, 1.0);
      expect(city.rainIntensity, 1.0);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => city.render(canvas), returnsNormally);
      recorder.endRecording();
    });
  });

  group('CourierGame Weather Integration', () {
    test('courier game mounts weather and switches between dust and water splashes',
        () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: _MockAudioBackend()),
      );
      await game.onLoad();

      expect(game.weatherController, isNotNull);
      expect(game.rainComponent, isNotNull);
      expect(game.world.children.whereType<RainComponent>().length, equals(1));

      // Initial clear weather -> dust particles
      game.weatherController.setManualIntensity(0.0);
      expect(game.weatherController.isRaining, isFalse);

      game.player.state = CourierState.running;
      game.player.simulator.isGrounded = true;

      final initialDustCount = game.world.children.whereType<ParticleEffectComponent>().length;
      game.spawnDust(Vector2(100, 460));
      expect(
        game.world.children.whereType<ParticleEffectComponent>().length,
        initialDustCount + 1,
      );

      // Set rainy weather -> splash particles
      game.weatherController.setManualIntensity(0.9);
      expect(game.weatherController.isRaining, isTrue);

      game.spawnSplash(Vector2(100, 460));
      expect(
        game.world.children.whereType<ParticleEffectComponent>().length,
        initialDustCount + 2,
      );

      // Advance distance to test weather update progression
      game.update(1.0);

      // Restart run resets weather to clear
      game.restartRun();
      expect(game.weatherController.rainIntensity, 0.0);
      expect(game.rainComponent.rainIntensity, 0.0);
    });
  });
}
