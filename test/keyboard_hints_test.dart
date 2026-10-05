import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(960, 540),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
}

Widget _title({VoidCallback? onStart}) => TitleScreen(
      highDistance: 0,
      careerTips: 0,
      onStartGame: onStart ?? () {},
    );

Widget _results({VoidCallback? onRestart}) => GameOverModal(
      distance: 240,
      tips: 12,
      isNewRecord: false,
      careerTips: 12,
      onRestart: onRestart ?? () {},
      onReturnToDepot: () {},
    );

Widget _pause() => PauseMenuModal(
      gameState: GameState()
        ..startRun()
        ..pauseRun(),
      onResume: () {},
      onQuit: () {},
    );

/// Runs [body] as if on [platform], restoring the default before the test
/// framework checks that no override leaked.
Future<void> _on(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  const desktops = [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ];
  const phones = [TargetPlatform.android, TargetPlatform.iOS];

  group('A desktop player is shown which keys to use', () {
    for (final platform in desktops) {
      testWidgets('title screen on ${platform.name}', (tester) async {
        await _on(platform, () async {
          var starts = 0;
          await _pump(tester, _title(onStart: () => starts++));
          expect(tester.takeException(), isNull);

          final guide = tester.widget<Text>(find.byKey(const Key('control_guide')));
          expect(guide.data, contains('Space'));
          expect(guide.data, contains('P = Pause'));
          expect(find.byKey(const Key('key_hint_SPACE')), findsOneWidget);

          // The label is still the button.
          await tester.tap(find.text('START SHIFT'));
          expect(starts, equals(1));
        });
      });
    }

    testWidgets('results screen', (tester) async {
      await _on(TargetPlatform.windows, () async {
        var restarts = 0;
        await _pump(tester, _results(onRestart: () => restarts++));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('key_hint_SPACE')), findsOneWidget);
        await tester.tap(find.text('START NEXT SHIFT'));
        expect(restarts, equals(1));
      });
    });

    testWidgets('pause menu', (tester) async {
      await _on(TargetPlatform.windows, () async {
        await _pump(tester, _pause());
        expect(find.byKey(const Key('pause_keyboard_hint')), findsOneWidget);
      });
    });

    testWidgets('the keycap still fits when the window is small', (tester) async {
      await _on(TargetPlatform.windows, () async {
        for (final size in const [Size(667, 375), Size(420, 700)]) {
          await _pump(tester, _title(), size: size);
          expect(tester.takeException(), isNull, reason: 'title at $size');
          await _pump(tester, _results(), size: size);
          expect(tester.takeException(), isNull, reason: 'results at $size');
        }
      });
    });
  });

  group('A phone is not shown keys it does not have', () {
    for (final platform in phones) {
      testWidgets('title screen on ${platform.name}', (tester) async {
        await _on(platform, () async {
          await _pump(tester, _title());
          final guide = tester.widget<Text>(find.byKey(const Key('control_guide')));
          expect(guide.data, startsWith('Short Tap = Hop'));
          expect(guide.data, isNot(contains('Space')));
          expect(find.byKey(const Key('key_hint_SPACE')), findsNothing);
          expect(find.text('START SHIFT'), findsOneWidget);
        });
      });

      testWidgets('results and pause on ${platform.name}', (tester) async {
        await _on(platform, () async {
          await _pump(tester, _results());
          expect(find.byKey(const Key('key_hint_SPACE')), findsNothing);
          expect(find.text('START NEXT SHIFT'), findsOneWidget);

          await _pump(tester, _pause());
          expect(find.byKey(const Key('pause_keyboard_hint')), findsNothing);
          expect(find.textContaining('[Esc]'), findsNothing);
        });
      });
    }
  });
}
