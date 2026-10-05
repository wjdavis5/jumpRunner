import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/achievements_modal.dart';
import 'package:jump_runner/ui/bodega_modal.dart';
import 'package:jump_runner/ui/daily_shift_modal.dart';
import 'package:jump_runner/ui/locker_modal.dart';
import 'package:jump_runner/ui/modal_scrim.dart';

import 'support/app_harness.dart';

/// The depot's four menu cards: the title button that opens each, and the
/// widget that should then be on screen.
final _cards = <String, (Key, Type)>{
  'Locker': (const Key('open_locker_button'), LockerModal),
  'Bodega': (const Key('open_bodega_button'), BodegaModal),
  'Trophies': (const Key('open_trophies_button'), AchievementsModal),
  'Daily Shift': (const Key('open_daily_shift_button'), DailyShiftModal),
};

void main() {
  group('Menu cards open over a dimmed backdrop', () {
    for (final entry in _cards.entries) {
      final openButton = entry.value.$1;
      final card = entry.value.$2;

      testWidgets('${entry.key}: the backdrop is dimmed and covers the screen', (tester) async {
        await bootApp(tester);
        expect(find.byType(ModalScrim), findsNothing);

        await tester.tap(find.byKey(openButton));
        await settle(tester);
        expect(find.byType(card), findsOneWidget);

        final scrim = find.byKey(const Key('modal_scrim'));
        expect(tester.getRect(scrim), equals(const Rect.fromLTWH(0, 0, 960, 540)));
        final box = tester.widget<ColoredBox>(
          find.descendant(of: scrim, matching: find.byType(ColoredBox)),
        );
        expect(box.color.a, closeTo(ModalScrim.opacity, 0.01));
      });

      testWidgets('${entry.key}: tapping outside the card closes it', (tester) async {
        await bootApp(tester);
        await tester.tap(find.byKey(openButton));
        await settle(tester);

        // The very corner of the screen is outside every card.
        await tester.tapAt(const Offset(6, 6));
        await settle(tester);

        expect(find.byType(card), findsNothing);
        expect(find.byType(ModalScrim), findsNothing);
        expect(find.text('START SHIFT'), findsOneWidget);
        expect(gameOf(tester).gameState.status, equals(GameStatus.idle));
      });

      testWidgets('${entry.key}: Esc closes it', (tester) async {
        await bootApp(tester);
        await tester.tap(find.byKey(openButton));
        await settle(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);

        expect(find.byType(card), findsNothing);
        expect(find.text('START SHIFT'), findsOneWidget);
      });
    }

    testWidgets('a tap on the card itself does not close it', (tester) async {
      await bootApp(tester);
      await tester.tap(find.byKey(const Key('open_locker_button')));
      await settle(tester);

      await tester.tap(find.text('COURIER LOCKER'));
      await settle(tester);
      expect(find.byType(LockerModal), findsOneWidget);
    });

    testWidgets('nothing behind the backdrop can be pressed', (tester) async {
      await bootApp(tester);
      await tester.tap(find.byKey(const Key('open_daily_shift_button')));
      await settle(tester);

      // The Daily Shift card is narrower than the title card, so the ends of
      // START SHIFT stick out beside it. A tap there dismisses the card; it
      // must not also start a shift.
      final startButton = tester.getRect(
        find.ancestor(of: find.text('START SHIFT'), matching: find.byType(ElevatedButton)),
      );
      await tester.tapAt(Offset(startButton.left + 10, startButton.center.dy));
      await settle(tester);

      expect(gameOf(tester).gameState.status, equals(GameStatus.idle));
      expect(find.byType(DailyShiftModal), findsNothing);
    });

    testWidgets('Esc on the bare title screen does nothing', (tester) async {
      await bootApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('START SHIFT'), findsOneWidget);
      expect(gameOf(tester).gameState.status, equals(GameStatus.idle));
    });
  });
}
