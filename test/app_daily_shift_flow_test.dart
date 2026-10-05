import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/daily_shift_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Boots the whole app and opens the Daily Shift card from the title screen.
Future<void> _openDailyCard(WidgetTester tester) async {
  await bootApp(tester);
  await tester.tap(find.byKey(const Key('open_daily_shift_button')));
  await settle(tester);
  expect(find.byType(DailyShiftModal), findsOneWidget);
}

void main() {
  // The Daily Shift card is a game overlay. It used to dismiss itself with
  // Navigator.pop, which popped the app's only screen: closing the card or
  // clocking in left a blank page until the app was restarted.
  group('Daily Shift card in the running app', () {
    testWidgets('Closing the card leaves the title screen usable', (tester) async {
      await _openDailyCard(tester);

      await tester.tap(find.byKey(const Key('close_daily_shift_button')));
      await settle(tester);

      expect(find.byType(DailyShiftModal), findsNothing);
      expect(find.byType(GameWidget<CourierGame>), findsOneWidget);
      expect(find.text('START SHIFT'), findsOneWidget);

      await tester.tap(find.text('START SHIFT'));
      await settle(tester);
      expect(find.byKey(const Key('pause_button')), findsOneWidget);
    });

    testWidgets('Clocking in starts the daily shift', (tester) async {
      await _openDailyCard(tester);

      await tester.tap(find.byKey(const Key('start_daily_shift_button')));
      await settle(tester, frames: 12);

      expect(find.byType(GameWidget<CourierGame>), findsOneWidget);
      expect(find.byType(DailyShiftModal), findsNothing);
      expect(find.text('START SHIFT'), findsNothing);
      expect(find.byKey(const Key('pause_button')), findsOneWidget);

      final game = gameOf(tester);
      expect(game.gameState.status, equals(GameStatus.running));
      expect(game.gameState.isDailyShiftActive, isTrue);
      expect(game.overlays.activeOverlays, equals(['HUD']));
    });
  });

  testWidgets('The card never pops the route it is shown in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    int closes = 0;
    int starts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: const Key('host_screen'),
          body: DailyShiftModal(
            storageService: storage,
            onStartDailyShift: (_) => starts++,
            onClose: () => closes++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('close_daily_shift_button')));
    await tester.pumpAndSettle();
    expect(closes, equals(1));
    expect(find.byKey(const Key('host_screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('start_daily_shift_button')));
    await tester.pumpAndSettle();
    expect(starts, equals(1));
    expect(find.byKey(const Key('host_screen')), findsOneWidget);
  });
}
