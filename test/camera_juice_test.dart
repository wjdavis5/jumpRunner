import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/camera_juice_controller.dart';

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

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopAmbience() async {}

  @override
  Future<void> setAmbienceVolume(double volume) async {}

  @override
  Future<void> startLayer(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}

  @override
  Future<void> setLayerPlaybackRate(double rate) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraJuiceController (Issue #21)', () {
    late CameraJuiceController controller;

    setUp(() {
      controller = CameraJuiceController(
        random: math.Random(42),
      );
    });

    test('initializes with zero trauma and baseline zoom', () {
      expect(controller.trauma, equals(0.0));
      expect(controller.shakeIntensity, equals(0.0));
      expect(controller.currentZoom, equals(1.0));
      expect(controller.shakeOffset, equals(Vector2.zero()));
      expect(controller.shakeAngle, equals(0.0));
    });

    test('addTrauma accumulates and clamps to 1.0', () {
      controller.addTrauma(0.4);
      expect(controller.trauma, closeTo(0.4, 0.001));
      expect(controller.shakeIntensity, closeTo(0.16, 0.001)); // 0.4^2

      controller.addTrauma(0.8);
      expect(controller.trauma, equals(1.0)); // Clamped to 1.0
      expect(controller.shakeIntensity, equals(1.0));
    });

    test('trauma decays linearly over time', () {
      controller.addTrauma(1.0);
      expect(controller.trauma, equals(1.0));

      // Decay rate is 1.6/sec -> after 0.25s, trauma drops by 0.4 to 0.6
      controller.update(0.25, currentSpeed: 200.0);
      expect(controller.trauma, closeTo(0.6, 0.001));

      // After another 0.5s (0.8 decay), trauma clamps to 0.0
      controller.update(0.5, currentSpeed: 200.0);
      expect(controller.trauma, equals(0.0));
      expect(controller.shakeOffset, equals(Vector2.zero()));
      expect(controller.shakeAngle, equals(0.0));
    });

    test('calculates velocity framing zoom for speed progression', () {
      // Speeds <= 200px/s remain at 1.0x
      expect(controller.calculateZoomForSpeed(150.0), equals(1.0));
      expect(controller.calculateZoomForSpeed(200.0), equals(1.0));

      // Mid-speed (325px/s): halfway between 1.0 and 0.94 -> 0.97
      expect(controller.calculateZoomForSpeed(325.0), closeTo(0.97, 0.001));

      // Top speeds >= 450px/s clamp at 0.94x
      expect(controller.calculateZoomForSpeed(450.0), closeTo(0.94, 0.001));
      expect(controller.calculateZoomForSpeed(600.0), closeTo(0.94, 0.001));
    });

    test('updates smoothly interpolate zoom toward velocity framing target', () {
      expect(controller.currentZoom, equals(1.0));

      // High-speed run at 450 px/s over several ticks
      for (var i = 0; i < 20; i++) {
        controller.update(0.05, currentSpeed: 450.0);
      }
      expect(controller.currentZoom, closeTo(0.94, 0.01));

      // Slowing down interpolates back toward 1.0
      for (var i = 0; i < 20; i++) {
        controller.update(0.05, currentSpeed: 200.0);
      }
      expect(controller.currentZoom, closeTo(1.0, 0.01));
    });

    test('reset zeroes trauma, shake displacement, and restores base zoom', () {
      controller.addTrauma(0.9);
      controller.update(0.1, currentSpeed: 450.0);

      expect(controller.trauma, greaterThan(0.0));
      expect(controller.shakeOffset.length, greaterThan(0.0));

      controller.reset();
      expect(controller.trauma, equals(0.0));
      expect(controller.currentZoom, equals(1.0));
      expect(controller.shakeOffset, equals(Vector2.zero()));
      expect(controller.shakeAngle, equals(0.0));
    });
  });

  group('CourierGame Camera Juice Integration (Issue #21)', () {
    test('CourierGame initializes centered viewfinder and responds to damage screen shake',
        () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: _MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final expectedCenter = Vector2(CourierGame.virtualResolution.x / 2, CourierGame.virtualResolution.y / 2);
      expect(game.camera.viewfinder.position.x, closeTo(expectedCenter.x, 0.01));
      expect(game.camera.viewfinder.position.y, closeTo(expectedCenter.y, 0.01));
      expect(game.camera.viewfinder.zoom, equals(1.0));

      // Trigger hazard collision screen shake
      game.triggerScreenShake(0.75);
      expect(game.cameraJuice.trauma, closeTo(0.75, 0.001));

      // Advance game loop
      game.update(0.016);

      // Camera position displaced by shake offset
      final displacement = (game.camera.viewfinder.position - expectedCenter).length;
      expect(displacement, greaterThan(0.0));

      // Restart run cleanly resets camera transforms
      game.restartRun();
      expect(game.cameraJuice.trauma, equals(0.0));
      expect(game.camera.viewfinder.position.x, closeTo(expectedCenter.x, 0.001));
      expect(game.camera.viewfinder.position.y, closeTo(expectedCenter.y, 0.001));
      expect(game.camera.viewfinder.zoom, equals(1.0));
      expect(game.camera.viewfinder.angle, equals(0.0));
    });
  });
}
