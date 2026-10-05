import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

const _cards = {
  'open_locker_button': 'LockerModal',
  'open_bodega_button': 'BodegaModal',
  'open_trophies_button': 'AchievementsModal',
  'open_daily_shift_button': 'DailyShiftModal',
};

List<String> _openCards(WidgetTester tester) =>
    _cards.values.where(gameOf(tester).overlays.isActive).toList();

void main() {
  // A button fires when the finger on it lifts. A card that opens in the
  // meantime dims the depot and takes new touches, but a finger that was
  // already down still belongs to the button under it. So: hold START
  // SHIFT, tap DAILY with the other thumb, let go of START, and the shift
  // began under the open card, the courier running into things behind it.
  group('A finger already down on the depot when a card opens', () {
    for (final card in _cards.entries) {
      testWidgets('lifting off START SHIFT under the ${card.value} does not start a shift', (tester) async {
        await bootApp(tester);
        final game = gameOf(tester);

        final held = await tester.startGesture(tester.getCenter(find.text('START SHIFT')));
        await settle(tester, frames: 2);
        await tester.tap(find.byKey(Key(card.key)));
        await settle(tester, frames: 4);
        expect(game.overlays.isActive(card.value), isTrue);

        await held.up();
        await settle(tester, frames: 6);
        expect(game.gameState.status, equals(GameStatus.idle));
        expect(game.overlays.isActive('HUD'), isFalse);
        expect(game.overlays.isActive('TitleScreen'), isTrue);
        expect(_openCards(tester), equals([card.value]));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('lifting off one card\'s button under another card does not open a second', (tester) async {
      for (final first in _cards.keys) {
        for (final second in _cards.keys.where((k) => k != first)) {
          await tester.pumpWidget(const SizedBox());
          await bootApp(tester);

          final held = await tester.startGesture(tester.getCenter(find.byKey(Key(first))));
          await settle(tester, frames: 2);
          await tester.tap(find.byKey(Key(second)));
          await settle(tester, frames: 4);
          await held.up();
          await settle(tester, frames: 4);

          expect(_openCards(tester), equals([_cards[second]]), reason: 'held $first, tapped $second');
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('One finger at a time, the depot works as it did', () {
    testWidgets('START SHIFT starts a shift', (tester) async {
      await bootApp(tester);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 8);
      expect(gameOf(tester).gameState.status, equals(GameStatus.running));
      expect(gameOf(tester).overlays.isActive('HUD'), isTrue);
    });

    testWidgets('each card opens, closes, and the next one opens', (tester) async {
      await bootApp(tester);
      for (final card in _cards.entries) {
        await tester.tap(find.byKey(Key(card.key)));
        await settle(tester, frames: 4);
        expect(_openCards(tester), equals([card.value]));
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 3);
        expect(_openCards(tester), isEmpty);
      }
    });

    testWidgets('clocking in from the Daily card closes it and starts that shift', (tester) async {
      await bootApp(tester);
      await tester.tap(find.byKey(const Key('open_daily_shift_button')));
      await settle(tester, frames: 4);
      await tester.tap(find.byKey(const Key('start_daily_shift_button')));
      await settle(tester, frames: 8);
      final game = gameOf(tester);
      expect(game.gameState.status, equals(GameStatus.running));
      expect(game.gameState.activeDailyShift, isNotNull);
      expect(_openCards(tester), isEmpty);
    });
  });
}
