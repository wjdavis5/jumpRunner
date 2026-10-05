import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/coach_hint_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoachHintComponent', () {
    test('persists until dismissed and does not self-remove early', () {
      final hint = CoachHintComponent(
        text: 'TAP & HOLD TO LEAP!',
        position: Vector2(200, 300),
      );

      // Well short of the 7s failsafe: still visible, not dismissing.
      for (var i = 0; i < 60; i++) {
        hint.update(0.1);
      }
      expect(hint.isDismissing, isFalse);
      expect(hint.isFinished, isFalse);
      expect(hint.isMounted, isFalse, reason: 'component not added to a tree yet');
    });

    test('dismiss fades the hint out over the fade duration', () {
      final hint = CoachHintComponent(
        text: 'TAP & HOLD TO LEAP!',
        position: Vector2(200, 300),
      );
      hint.update(0.1);

      hint.dismiss();
      expect(hint.isDismissing, isTrue);

      hint.update(0.1);
      expect(hint.isFinished, isFalse, reason: 'fade is still in progress');

      hint.update(CoachHintComponent.fadeDuration);
      expect(hint.isFinished, isTrue);
    });

    test('dismiss is idempotent and restarts nothing once fading', () {
      final hint = CoachHintComponent(
        text: 'TAP & HOLD TO LEAP!',
        position: Vector2(200, 300),
      );
      hint.update(1.0);

      hint.dismiss();
      hint.update(CoachHintComponent.fadeDuration / 2);
      hint.dismiss(); // repeated call must not reset the fade
      hint.update(CoachHintComponent.fadeDuration / 2);

      expect(hint.isFinished, isTrue);
    });

    test('failsafe timeout dismisses the hint automatically', () {
      final hint = CoachHintComponent(
        text: 'TAP & HOLD TO LEAP!',
        position: Vector2(200, 300),
      );
      hint.update(3.0);
      expect(hint.isDismissing, isFalse);

      hint.update(5.0); // total 8s > 7s failsafe
      expect(hint.isDismissing, isTrue);

      hint.update(CoachHintComponent.fadeDuration);
      expect(hint.isFinished, isTrue);
    });

    test('bobs gently around its anchored position without drifting away', () {
      final hint = CoachHintComponent(
        text: 'TAP & HOLD TO LEAP!',
        position: Vector2(200, 300),
      );

      var minY = double.infinity;
      var maxY = double.negativeInfinity;
      for (var i = 0; i < 240; i++) {
        hint.update(1 / 60);
        minY = minY < hint.position.y ? minY : hint.position.y;
        maxY = maxY > hint.position.y ? maxY : hint.position.y;
      }

      expect(minY, greaterThanOrEqualTo(292.0), reason: 'bob amplitude stays tight');
      expect(maxY, lessThanOrEqualTo(308.0));
      expect(minY, lessThan(maxY), reason: 'the hint actually bobs');
    });

    test('lifecycle calls are safe before the hint is mounted', () async {
      final hint = CoachHintComponent(
        text: 'TAP & HOLD TO LEAP!',
        position: Vector2(200, 300),
      );

      hint.update(1.0);
      hint.dismiss();
      hint.update(CoachHintComponent.fadeDuration);

      expect(hint.isFinished, isTrue);
      expect(hint.isMounted, isFalse, reason: 'nothing mounted it yet');
    });
  });
}
