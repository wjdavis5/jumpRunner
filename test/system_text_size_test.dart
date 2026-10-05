import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/resume_countdown.dart';

import 'support/app_harness.dart';

/// Boots the app on a phone whose system text size is [scale] times normal.
Future<void> _bootWithTextSize(WidgetTester tester, double scale, {Size size = const Size(667, 375)}) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await bootApp(tester, size: size);
}

double _heightOf(WidgetTester tester, String text) => tester.getSize(find.text(text)).height;

void main() {
  // Every screen was laid out and tested at the default text size. Plenty of
  // phones are not set to it. With system text at 130% the title, pause,
  // Locker, Trophies and daily cards all overflowed, and three of them did
  // at 115%. The cards are fixed compositions, already scaled as a whole to
  // fit the screen, so the game now draws its text at its own sizes.
  group('The phone\'s text-size setting does not resize the game\'s text', () {
    testWidgets('text is the same size at 200% as at 100%', (tester) async {
      await _bootWithTextSize(tester, 1.0);
      final normal = _heightOf(tester, 'START SHIFT');
      final normalTitle = _heightOf(tester, 'COURIER DASH');

      await tester.pumpWidget(const SizedBox());
      await _bootWithTextSize(tester, 2.0);
      expect(_heightOf(tester, 'START SHIFT'), equals(normal));
      expect(_heightOf(tester, 'COURIER DASH'), equals(normalTitle));
    });

    testWidgets('and the same at 85%', (tester) async {
      await _bootWithTextSize(tester, 1.0);
      final normal = _heightOf(tester, 'START SHIFT');
      await tester.pumpWidget(const SizedBox());
      await _bootWithTextSize(tester, 0.85);
      expect(_heightOf(tester, 'START SHIFT'), equals(normal));
    });

    testWidgets('inside the app the scale reads as 1', (tester) async {
      await _bootWithTextSize(tester, 1.6);
      final context = tester.element(find.text('START SHIFT'));
      expect(MediaQuery.textScalerOf(context).scale(20.0), equals(20.0));
    });
  });

  group('With system text at 200% on a small phone, nothing overflows', () {
    testWidgets('the title and its four cards', (tester) async {
      await _bootWithTextSize(tester, 2.0);
      expect(tester.takeException(), isNull);
      for (final card in const {
        'open_locker_button': 'LockerModal',
        'open_bodega_button': 'BodegaModal',
        'open_trophies_button': 'AchievementsModal',
        'open_daily_shift_button': 'DailyShiftModal',
      }.entries) {
        await tester.tap(find.byKey(Key(card.key)));
        await settle(tester, frames: 4);
        expect(gameOf(tester).overlays.isActive(card.value), isTrue, reason: card.value);
        expect(tester.takeException(), isNull, reason: card.value);
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 3);
        expect(gameOf(tester).overlays.isActive(card.value), isFalse, reason: card.value);
      }
    });

    testWidgets('the HUD, the pause menu and the results card', (tester) async {
      await _bootWithTextSize(tester, 2.0);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final state = gameOf(tester).gameState;
      state.activateEnergyDrink();
      state.activateDrone();
      state.addTip(1250);
      await settle(tester, frames: 8);
      expect(tester.takeException(), isNull, reason: 'HUD');

      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 4);
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'pause menu');

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      await tester.pump(const Duration(milliseconds: 60));
      expect(gameOf(tester).overlays.isActive('ResumeCountdown'), isTrue);
      expect(tester.takeException(), isNull, reason: 'resume countdown');
      await tester.pump(ResumeCountdown.total + const Duration(milliseconds: 100));
      await settle(tester, frames: 2);
      expect(state.status, equals(GameStatus.running));
      // Only a running shift takes damage, so this cannot spin on a paused one.
      while (state.status == GameStatus.running) {
        state.applyHazardDamage();
      }
      expect(state.status, equals(GameStatus.gameOver));
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 1);
      }
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'results card');
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
