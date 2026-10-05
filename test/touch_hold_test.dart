import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

const Offset _left = Offset(300, 250);
const Offset _right = Offset(700, 250);

/// Boots the app on a phone held sideways and starts a shift.
///
/// The street's first hazard is built a screen and a half ahead, about 40 m,
/// so the jumps these tests make in the first 30 m meet nothing.
Future<CourierGame> _startShift(WidgetTester tester) async {
  await bootApp(tester, size: const Size(915, 412));
  await tester.tap(find.text('START SHIFT'));
  await settle(tester, frames: 10);
  return gameOf(tester);
}

/// Pumps [frames] frames, running [each] before every one, and returns how
/// far above where it started the courier got.
Future<double> _rise(
  WidgetTester tester, {
  int frames = 50,
  Future<void> Function(int frame)? each,
}) async {
  final player = gameOf(tester).player;
  final from = player.position.y;
  var top = from;
  for (var i = 0; i < frames; i++) {
    if (each != null) await each(i);
    await tester.pump(const Duration(milliseconds: 16));
    if (player.position.y < top) top = player.position.y;
  }
  return from - top;
}

/// The height of the shift's first jump when the press that makes it does
/// [during] while it is down. Each call is a fresh app.
Future<double> _firstJump(
  WidgetTester tester,
  Future<void> Function(TestGesture press, int frame) during,
) async {
  await tester.pumpWidget(const SizedBox());
  final game = await _startShift(tester);
  final press = await tester.startGesture(_left);
  expect(game.player.state, equals(CourierState.jumping));
  final rise = await _rise(tester, each: (frame) => during(press, frame));
  expect(game.gameState.packages, equals(game.gameState.maxPackages), reason: 'nothing was hit');
  return rise;
}

void main() {
  // A press on the street has no position, only a start and an end. Flutter's
  // tap recognizers give up on a touch once it has moved 18 logical pixels,
  // about 3 mm, which a thumb pressed hard for a long jump easily does; the
  // jump was then let go on the way up and came down as the smallest hop.
  group('A held jump is a full jump', () {
    testWidgets('however far the thumb slides while it is down', (tester) async {
      final still = await _firstJump(tester, (press, frame) async {});
      for (final slide in const [19.0, 40.0, 150.0]) {
        final slid = await _firstJump(tester, (press, frame) async {
          if (frame == 3) await press.moveBy(Offset(slide * 0.6, slide * 0.8));
        });
        expect(slid, closeTo(still, 0.01), reason: 'a ${slide.round()} px slide, 48 ms into the press');
      }
    });

    testWidgets('and a slide leaves the press held until the thumb lifts', (tester) async {
      final game = await _startShift(tester);
      final press = await tester.startGesture(_left);
      await tester.pump(const Duration(milliseconds: 16));
      await press.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.player.isJumpHeld, isTrue);

      await press.up();
      expect(game.player.isJumpHeld, isFalse);
    });

    testWidgets('a quick tap is still the short hop', (tester) async {
      final still = await _firstJump(tester, (press, frame) async {});
      final tap = await _firstJump(tester, (press, frame) async {
        if (frame == 3) await press.up();
      });
      expect(tap, lessThan(still * 0.5));
      expect(tap, greaterThan(40));
    });

    testWidgets('a touch the system takes away lets go', (tester) async {
      final still = await _firstJump(tester, (press, frame) async {});
      final taken = await _firstJump(tester, (press, frame) async {
        if (frame == 3) await press.cancel();
      });
      expect(taken, lessThan(still * 0.5));
      expect(gameOf(tester).player.isJumpHeld, isFalse);
    });
  });

  // Played with two thumbs, the next press often lands before the last thumb
  // has left the glass. The hold belongs to the latest press and nothing else.
  group('Two thumbs', () {
    testWidgets('the first thumb coming off does not cut the second thumb\'s jump short', (tester) async {
      final still = await _firstJump(tester, (press, frame) async {});

      await tester.pumpWidget(const SizedBox());
      final game = await _startShift(tester);
      final first = await tester.startGesture(_left, pointer: 31);
      await _rise(tester, frames: 80);
      expect(game.player.state, equals(CourierState.running), reason: 'landed, first thumb still down');

      final second = await tester.startGesture(_right, pointer: 32);
      expect(game.player.state, equals(CourierState.jumping));
      final rise = await _rise(tester, each: (frame) async {
        if (frame == 3) await first.up();
      });
      expect(game.player.isJumpHeld, isTrue);
      expect(rise, closeTo(still, 0.01));

      await second.up();
      expect(game.player.isJumpHeld, isFalse);
    });

    testWidgets('a thumb resting on the screen does not turn the other thumb\'s taps into full jumps', (tester) async {
      final still = await _firstJump(tester, (press, frame) async {});

      await tester.pumpWidget(const SizedBox());
      final game = await _startShift(tester);
      final resting = await tester.startGesture(_left, pointer: 41);
      await _rise(tester, frames: 80);
      expect(game.player.state, equals(CourierState.running));

      final tap = await tester.startGesture(_right, pointer: 42);
      final rise = await _rise(tester, each: (frame) async {
        if (frame == 3) await tap.up();
      });
      expect(rise, lessThan(still * 0.5));
      await resting.up();
    });
  });

  group('What is not a jump', () {
    testWidgets('pressing the pause button', (tester) async {
      final game = await _startShift(tester);
      final ground = game.player.position.y;
      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 3);
      expect(game.gameState.status, equals(GameStatus.paused));
      expect(game.player.isJumpHeld, isFalse);
      expect(game.player.position.y, equals(ground));
    });
  });

  group('Keys follow the same rule', () {
    testWidgets('another key coming up does not let go of the one that jumped', (tester) async {
      final game = await _startShift(tester);
      game.holdJump(LogicalKeyboardKey.space);
      expect(game.player.isJumpHeld, isTrue);

      game.letGoOfJump(LogicalKeyboardKey.keyW);
      expect(game.player.isJumpHeld, isTrue);

      game.letGoOfJump(LogicalKeyboardKey.space);
      expect(game.player.isJumpHeld, isFalse);
    });
  });
}
