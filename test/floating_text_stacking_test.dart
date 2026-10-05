// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/courier_game.dart';

Future<CourierGame> _mountedGame() async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  return game;
}

/// Adds [texts] to the world one after another, letting each mount.
Future<void> _show(CourierGame game, List<FloatingTextComponent> texts) async {
  for (final text in texts) {
    game.world.add(text);
    game.update(0);
    await game.ready();
  }
}

FloatingTextComponent _text(String label, double x, double y) =>
    FloatingTextComponent(text: label, position: Vector2(x, y));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Simultaneous reward text stays readable', () {
    test('Indicators spawned on the same spot stack into separate lines', () async {
      final game = await _mountedGame();
      final texts = [
        _text('STUNT! +\$5', 120, 360),
        _text('PARKOUR VAULT! +\$20', 110, 362),
        _text('TROPHY: First Delivery!', 100, 356),
      ];
      await _show(game, texts);

      final ys = texts.map((t) => t.position.y).toList()..sort();
      for (var i = 1; i < ys.length; i++) {
        expect(
          ys[i] - ys[i - 1],
          greaterThanOrEqualTo(FloatingTextComponent.lineHeight),
          reason: 'lines at ${ys[i - 1]} and ${ys[i]} overlap',
        );
      }
      // The first indicator is never moved; later ones go above it.
      expect(texts.first.position.y, equals(360.0));
      expect(texts[1].position.y, lessThan(360.0));
      expect(texts[2].position.y, lessThan(texts[1].position.y));
    });

    test('A lone indicator keeps the position it was given', () async {
      final game = await _mountedGame();
      final text = _text('RAMP BOOST!', 120, 360);
      await _show(game, [text]);
      expect(text.position.y, equals(360.0));
    });

    test('Indicators far apart on screen do not push each other', () async {
      final game = await _mountedGame();
      final near = _text('STUNT!', 120, 360);
      final far = _text('NEW RECORD!', 120 + FloatingTextComponent.columnWidth + 40, 360);
      await _show(game, [near, far]);
      expect(near.position.y, equals(360.0));
      expect(far.position.y, equals(360.0));
    });

    test('Stacked lines keep their spacing as they drift', () async {
      final game = await _mountedGame();
      final first = _text('STUNT!', 120, 360);
      final second = _text('VAULT!', 120, 360);
      await _show(game, [first, second]);

      final gapAtSpawn = first.position.y - second.position.y;
      for (var i = 0; i < 20; i++) {
        game.update(1.0 / 60.0);
      }
      expect(first.position.y - second.position.y, closeTo(gapAtSpawn, 0.001));
      expect(gapAtSpawn, greaterThanOrEqualTo(FloatingTextComponent.lineHeight));
    });
  });
}
