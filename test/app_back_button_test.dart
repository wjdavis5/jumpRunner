import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/resume_countdown.dart';

import 'support/app_harness.dart';

/// Counts how many times the app asks the system to close it.
List<int> _watchForExit() {
  final exits = <int>[0];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemNavigator.pop') exits[0]++;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return exits;
}

/// Android's back button or back swipe.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester, frames: 3);
}

Future<void> _startShift(WidgetTester tester) async {
  await tester.tap(find.text('START SHIFT'));
  await settle(tester, frames: 10);
  expect(gameOf(tester).gameState.status, equals(GameStatus.running));
}

void main() {
  // The app did nothing about Android's back button, so the system did the
  // default: close the app. Mid-shift that is a swipe from the edge of the
  // screen a thumb makes by accident, and the shift and its tips were gone.
  group('Android back during a shift', () {
    testWidgets('pauses it and keeps the app open', (tester) async {
      await bootApp(tester);
      final exits = _watchForExit();
      await _startShift(tester);
      final state = gameOf(tester).gameState;
      state.addTip(120);

      await _back(tester);
      expect(exits.single, equals(0));
      expect(state.status, equals(GameStatus.paused));
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
      expect(state.tips, equals(120));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('pressed again, counts the courier back in', (tester) async {
      await bootApp(tester);
      final exits = _watchForExit();
      await _startShift(tester);
      await _back(tester);
      await _back(tester);

      final game = gameOf(tester);
      expect(game.overlays.isActive('ResumeCountdown'), isTrue);
      expect(game.gameState.status, equals(GameStatus.paused));
      await tester.pump(ResumeCountdown.total + const Duration(milliseconds: 100));
      await settle(tester, frames: 2);
      expect(game.gameState.status, equals(GameStatus.running));
      expect(exits.single, equals(0));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('pressed during the count, goes back to the pause menu', (tester) async {
      await bootApp(tester);
      await _startShift(tester);
      await _back(tester);
      await tester.tap(find.byKey(const Key('resume_shift_button')));
      await tester.pump(const Duration(milliseconds: 60));
      expect(gameOf(tester).overlays.isActive('ResumeCountdown'), isTrue);

      await _back(tester);
      final game = gameOf(tester);
      expect(game.overlays.isActive('ResumeCountdown'), isFalse);
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
      expect(game.gameState.status, equals(GameStatus.paused));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Android back after a shift', () {
    Future<void> crash(WidgetTester tester) async {
      final game = gameOf(tester);
      while (game.gameState.status != GameStatus.gameOver) {
        game.gameState.applyHazardDamage();
      }
    }

    testWidgets('during the crash beat does nothing at all', (tester) async {
      await bootApp(tester);
      final exits = _watchForExit();
      await _startShift(tester);
      await crash(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect(gameOf(tester).overlays.isActive('GameOver'), isFalse);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 16));
      expect(exits.single, equals(0));
      expect(find.text('START SHIFT'), findsNothing);

      // The results card still arrives.
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 1);
      }
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('on the results card goes to the depot, with the shift banked', (tester) async {
      final harness = await bootApp(tester);
      final exits = _watchForExit();
      await _startShift(tester);
      gameOf(tester).gameState.addTip(75);
      await crash(tester);
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 1);
      }
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);

      await _back(tester);
      await settle(tester, frames: 6);
      expect(exits.single, equals(0));
      expect(find.text('START SHIFT'), findsOneWidget);
      expect(find.text('PACKAGES DROPPED!'), findsNothing);
      expect(harness.storage.careerTips, greaterThanOrEqualTo(75));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Android back at the depot', () {
    for (final card in const {
      'open_locker_button': 'LockerModal',
      'open_bodega_button': 'BodegaModal',
      'open_trophies_button': 'AchievementsModal',
      'open_daily_shift_button': 'DailyShiftModal',
    }.entries) {
      testWidgets('closes ${card.value} and stays in the app', (tester) async {
        await bootApp(tester);
        final exits = _watchForExit();
        await tester.tap(find.byKey(Key(card.key)));
        await settle(tester, frames: 4);
        expect(gameOf(tester).overlays.isActive(card.value), isTrue);

        await _back(tester);
        expect(gameOf(tester).overlays.isActive(card.value), isFalse);
        expect(exits.single, equals(0));
        expect(find.text('START SHIFT'), findsOneWidget);
      });
    }

    testWidgets('with nothing open, leaves the app, as back does everywhere else', (tester) async {
      await bootApp(tester);
      final exits = _watchForExit();
      await _back(tester);
      expect(exits.single, equals(1));
    });

    testWidgets('after a card has been closed with it, the next one leaves', (tester) async {
      await bootApp(tester);
      final exits = _watchForExit();
      await tester.tap(find.byKey(const Key('open_locker_button')));
      await settle(tester, frames: 4);
      await _back(tester);
      expect(exits.single, equals(0));
      await _back(tester);
      expect(exits.single, equals(1));
    });
  });
}
