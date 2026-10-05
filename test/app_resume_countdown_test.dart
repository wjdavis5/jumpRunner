import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/resume_countdown.dart';

import 'support/app_harness.dart';

String _number(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('resume_countdown_number'))).data!;

/// Boots the app, runs a shift for a moment and pauses it.
Future<void> _pausedShift(WidgetTester tester) async {
  await bootApp(tester);
  await tester.tap(find.text('START SHIFT'));
  await settle(tester, frames: 10);
  await tester.tap(find.byKey(const Key('pause_button')));
  await settle(tester, frames: 3);
  expect(find.text('SHIFT ON HOLD'), findsOneWidget);
}

void main() {
  group('The count itself', () {
    testWidgets('it counts 3, 2, 1 and then reports once', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ResumeCountdown(onDone: () => done++))),
      );
      expect(_number(tester), equals('3'));
      expect(find.text('GET READY'), findsOneWidget);

      const step = ResumeCountdown.stepDuration;
      await tester.pump(step + const Duration(milliseconds: 20));
      expect(_number(tester), equals('2'));
      await tester.pump(step);
      expect(_number(tester), equals('1'));
      expect(done, equals(0));

      await tester.pump(step);
      expect(done, equals(1));
      await tester.pump(step);
      expect(done, equals(1));
    });

    test('it is short: about a second', () {
      expect(ResumeCountdown.total, lessThanOrEqualTo(const Duration(milliseconds: 1500)));
      expect(ResumeCountdown.total, greaterThanOrEqualTo(const Duration(milliseconds: 800)));
    });
  });

  group('Resuming a paused shift in the running app', () {
    testWidgets('the street stays frozen through the count, then the shift carries on',
        (tester) async {
      await _pausedShift(tester);
      final state = gameOf(tester).gameState;
      final distance = state.distanceMeters;

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // The menu is gone, the count is up, and nothing has moved yet.
      expect(find.text('SHIFT ON HOLD'), findsNothing);
      expect(find.byType(ResumeCountdown), findsOneWidget);
      expect(_number(tester), equals('3'));
      expect(state.status, equals(GameStatus.paused));

      await tester.pump(ResumeCountdown.stepDuration * 2);
      expect(state.status, equals(GameStatus.paused));
      expect(state.distanceMeters, equals(distance));

      await tester.pump(ResumeCountdown.stepDuration + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(ResumeCountdown), findsNothing);
      expect(state.status, equals(GameStatus.running));

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.distanceMeters, greaterThan(distance));
    });

    testWidgets('P during the count goes back to the pause menu', (tester) async {
      await _pausedShift(tester);
      final state = gameOf(tester).gameState;

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ResumeCountdown), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(ResumeCountdown), findsNothing);
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);

      // And the abandoned count does not resume the shift behind the menu.
      await tester.pump(ResumeCountdown.total * 2);
      expect(state.status, equals(GameStatus.paused));
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
    });

    testWidgets('leaving the app during the count puts the menu back', (tester) async {
      await _pausedShift(tester);
      final state = gameOf(tester).gameState;

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ResumeCountdown), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(ResumeCountdown), findsNothing);
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(ResumeCountdown.total * 2);
      expect(state.status, equals(GameStatus.paused));
    });

    testWidgets('tapping Resume twice does not start two counts', (tester) async {
      await _pausedShift(tester);
      final state = gameOf(tester).gameState;
      final game = gameOf(tester);

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      // A second request before the first has even been drawn.
      game.onPauseRequested?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The second press read as "not yet" and brought the menu back.
      expect(find.byType(ResumeCountdown), findsNothing);
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
      expect(state.status, equals(GameStatus.paused));
    });
  });
}
