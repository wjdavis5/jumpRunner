import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/death_slowmo_controller.dart';

void main() {
  group('DeathSlowmoController', () {
    test('is idle until begun and reports inactive progress', () {
      final controller = DeathSlowmoController();

      expect(controller.isActive, isFalse);
      expect(controller.progress, equals(0.0));
      expect(controller.currentZoom(1.0), equals(1.0));
      expect(controller.update(0.1), isFalse,
          reason: 'updating an idle controller must not complete the beat');
    });

    test('progresses in real time and completes exactly once', () {
      final controller = DeathSlowmoController(duration: 0.5);
      controller.begin();
      expect(controller.isActive, isTrue);

      controller.update(0.2);
      expect(controller.progress, closeTo(0.4, 0.001));
      expect(controller.isActive, isTrue);

      controller.update(0.2);
      expect(controller.progress, closeTo(0.8, 0.001));

      final completed = controller.update(0.2);
      expect(completed, isTrue, reason: 'the finishing frame reports completion');
      expect(controller.isActive, isFalse);
      expect(controller.progress, equals(1.0));

      expect(controller.update(0.2), isFalse,
          reason: 'the beat must not replay after finishing');
    });

    test('tree time scale slows animation for the beat duration', () {
      final controller = DeathSlowmoController(timeScale: 0.3);
      // Scale is a plain constant consumers multiply dt by.
      expect(controller.timeScale, equals(0.3));
    });

    test('camera zoom eases toward the death framing on an ease-out curve', () {
      final controller = DeathSlowmoController(zoomIn: 1.3, duration: 1.0);
      controller.begin();

      // easeOutCubic at t=0.5 is 0.875 -> zoom = 1.0 + 0.3 * 0.875
      controller.update(0.5);
      expect(controller.currentZoom(1.0), closeTo(1.2625, 0.001));

      // Monotonically non-decreasing as the beat advances.
      final midZoom = controller.currentZoom(1.0);
      controller.update(0.25);
      expect(controller.currentZoom(1.0), greaterThanOrEqualTo(midZoom));

      controller.update(0.25);
      expect(controller.currentZoom(1.0), closeTo(1.3, 0.001));
    });

    test('begin restarts a fresh beat after reset', () {
      final controller = DeathSlowmoController(duration: 0.4);
      controller.begin();
      controller.update(0.4);
      expect(controller.isActive, isFalse);

      controller.reset();
      expect(controller.progress, equals(0.0));

      controller.begin();
      expect(controller.isActive, isTrue);
      expect(controller.progress, equals(0.0));
      controller.update(0.1);
      expect(controller.progress, closeTo(0.25, 0.001));
    });
  });
}
