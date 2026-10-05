import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/hud_overlay.dart';
import 'package:jump_runner/ui/resume_countdown.dart';

import 'support/app_harness.dart';

/// Whether [finder]'s one widget lies wholly on a screen of [size].
bool _onScreen(WidgetTester tester, Finder finder, Size size) {
  final rect = tester.getRect(finder);
  return rect.left >= 0 && rect.top >= 0 && rect.right <= size.width && rect.bottom <= size.height;
}

Finder _muteButton() => find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.volume_up || w.icon == Icons.volume_off),
    );

void main() {
  // The web build lets a player keep a phone upright ("Play upright anyway"),
  // and a desktop browser window can be any width. The HUD and the two shop
  // cards are rows of fixed-size parts, and under about 540 px they ran off
  // the right-hand edge: at 375 px the pause and mute buttons were off the
  // screen altogether, and so were the Locker's buy buttons.
  const narrow = {
    'a small phone upright, 320x568': Size(320, 568),
    'a phone upright, 375x667': Size(375, 667),
    'a large phone upright, 430x932': Size(430, 932),
    'a narrow window, 480x800': Size(480, 800),
  };

  for (final entry in narrow.entries) {
    final size = entry.value;

    testWidgets('On ${entry.key}, every screen lays out', (tester) async {
      await bootApp(tester, size: size, prefs: {'courier_career_tips': 250000});
      await settle(tester, frames: 3);
      expect(tester.takeException(), isNull, reason: 'title');

      for (final card in const ['locker', 'bodega', 'trophies', 'daily_shift']) {
        await tester.tap(find.byKey(Key('open_${card}_button')));
        await settle(tester, frames: 4);
        expect(tester.takeException(), isNull, reason: card);
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 3);
      }

      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final state = gameOf(tester).gameState;
      state.activateEnergyDrink();
      state.activateDrone();
      state.addTip(1250000);
      await settle(tester, frames: 6);
      expect(tester.takeException(), isNull, reason: 'HUD with two status badges and a long tip count');

      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 4);
      expect(state.status, equals(GameStatus.paused));
      expect(tester.takeException(), isNull, reason: 'pause menu');

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(ResumeCountdown.total + const Duration(milliseconds: 100));
      await settle(tester, frames: 2);
      expect(state.status, equals(GameStatus.running));
      while (state.status == GameStatus.running) {
        state.applyHazardDamage();
      }
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 1);
      }
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'results');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('On ${entry.key}, pause and mute are on the screen and work', (tester) async {
      await bootApp(tester, size: size);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final state = gameOf(tester).gameState;

      final pause = find.byKey(const Key('pause_button'));
      expect(_onScreen(tester, pause, size), isTrue, reason: 'pause at ${tester.getRect(pause)}');
      final mute = find.descendant(of: find.byType(HUDOverlay), matching: _muteButton());
      expect(_onScreen(tester, mute, size), isTrue, reason: 'mute at ${tester.getRect(mute)}');

      await tester.tap(pause);
      await settle(tester, frames: 4);
      expect(state.status, equals(GameStatus.paused));
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
    });

    testWidgets('On ${entry.key}, the shop buttons are on the screen', (tester) async {
      await bootApp(tester, size: size, prefs: {'courier_career_tips': 9000});
      await tester.tap(find.byKey(const Key('open_locker_button')));
      await settle(tester, frames: 4);
      expect(_onScreen(tester, find.byKey(const Key('locker_close_button')), size), isTrue);
      final unlock = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('unlock_button_'),
      );
      expect(unlock, findsWidgets);
      expect(_onScreen(tester, unlock.first, size), isTrue, reason: '${tester.getRect(unlock.first)}');
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 3);

      await tester.tap(find.byKey(const Key('open_bodega_button')));
      await settle(tester, frames: 4);
      expect(_onScreen(tester, find.byKey(const Key('bodega_close_button')), size), isTrue);
      final buy = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('buy_booster_'),
      );
      expect(buy, findsWidgets);
      expect(_onScreen(tester, buy.first, size), isTrue, reason: '${tester.getRect(buy.first)}');
      expect(tester.takeException(), isNull);
    });
  }

  // Not a narrow-screen fault, but found by the same sweep: the three career
  // figures on the title card were a row of fixed parts too. A six-figure tip
  // total beside "Ready in the Locker" ran 20 px off the end at any size.
  testWidgets('The title card holds a six-figure tip total on any screen', (tester) async {
    for (final size in const [Size(960, 540), Size(667, 375), Size(375, 667)]) {
      for (final tips in const [250000, 999999]) {
        await tester.pumpWidget(const SizedBox());
        await bootApp(tester, size: size, prefs: {'courier_career_tips': tips});
        await settle(tester, frames: 3);
        expect(tester.takeException(), isNull, reason: '\$$tips at $size');
        expect(find.byKey(const Key('next_outfit_goal_text')), findsOneWidget);
      }
    }
  });

  testWidgets('On a screen wide enough, nothing is scaled', (tester) async {
    for (final size in const [Size(667, 375), Size(960, 540)]) {
      await tester.pumpWidget(const SizedBox());
      await bootApp(tester, size: size);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final pause = tester.getRect(find.byKey(const Key('pause_button')));
      expect(pause.width, equals(48.0), reason: '$size');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('On 375 px the pause button is smaller, not gone', (tester) async {
    await bootApp(tester, size: const Size(375, 667));
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    final pause = tester.getRect(find.byKey(const Key('pause_button')));
    expect(pause.width, closeTo(48.0 * 375 / HUDOverlay.minWidth, 0.5));
    expect(pause.width, greaterThanOrEqualTo(30.0));
  });
}
