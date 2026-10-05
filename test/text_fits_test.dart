import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/achievements_modal.dart';

import 'support/app_harness.dart';
import 'support/real_fonts.dart';

void main() {
  // Every other test measures text in the test font, where each letter is a
  // square, so none of them can say whether a label fits. This one loads
  // the fonts a phone uses and reads every screen for text that is shown
  // with part of it missing.
  //
  // Seen on a phone held upright before this test existed: the Trophies
  // card ended every requirement with an ellipsis ("Complete a 500m shift
  // delivery mi..."), and the results card's button read START NEXT.
  setUpAll(loadRealFonts);

  const screens = {
    'a small phone upright, 320x568': Size(320, 568),
    'a phone upright, 375x667': Size(375, 667),
    'a large phone upright, 430x932': Size(430, 932),
    'a small phone, 568x320': Size(568, 320),
    'a phone, 667x375': Size(667, 375),
    'a phone, 844x390': Size(844, 390),
    'the design size, 960x540': Size(960, 540),
    'a laptop, 1366x768': Size(1366, 768),
  };

  for (final entry in screens.entries) {
    testWidgets('On ${entry.key}, no text is cut off', (tester) async {
      await bootApp(
        tester,
        size: entry.value,
        prefs: {
          'courier_career_tips': 128450,
          'courier_lifetime_tips': 245300,
          'courier_high_distance': 3412,
          'courier_daily_stars': 14,
        },
      );
      final problems = <String>[];
      void read(String screen) {
        final error = tester.takeException();
        if (error != null) problems.add('$screen: $error');
        for (final text in cutOffText(tester)) {
          problems.add('$screen: cut off: "$text"');
        }
        for (final text in wrappedButtonLabels(tester)) {
          problems.add('$screen: button label on two lines: "$text"');
        }
      }

      await settle(tester, frames: 3);
      read('title');

      for (final card in const ['locker', 'bodega', 'trophies', 'daily_shift']) {
        await tester.tap(find.byKey(Key('open_${card}_button')));
        await settle(tester, frames: 6);
        read(card);
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 4);
      }

      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final state = gameOf(tester).gameState;
      state.activateEnergyDrink();
      state.activateDrone();
      // Seven figures with both status badges up: the widest the HUD gets.
      state.addTip(1250000);
      await settle(tester, frames: 6);
      read('HUD');

      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 6);
      expect(state.status, equals(GameStatus.paused));
      read('pause menu');

      await tester.tap(find.byKey(const Key('quit_to_depot_button')));
      await settle(tester, frames: 6);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final next = gameOf(tester).gameState;
      next.addTip(4321);
      while (next.status == GameStatus.running) {
        next.applyHazardDamage();
      }
      for (var i = 0; i < 40 && find.text('START NEXT SHIFT').evaluate().isEmpty; i++) {
        await settle(tester, frames: 4);
      }
      expect(find.text('START NEXT SHIFT'), findsOneWidget, reason: 'the results card never appeared');
      read('results');
      // Whole is not enough: squeezed beside DEPOT on a 320 px screen, this
      // label was all there and 5.5 px tall.
      final nextShift = tester.getRect(find.text('START NEXT SHIFT'));
      if (nextShift.height < 12.0) {
        problems.add('results: START NEXT SHIFT is ${nextShift.height.toStringAsFixed(1)} px tall');
      }
      // The results card's own timers run out before the test ends.
      await tester.pump(const Duration(seconds: 5));

      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  // The walk above reads the trophies the card has built, which on a short
  // screen is the first few. This reads all ten at every width, on both
  // sides of where the list goes from one column to two.
  testWidgets('Every trophy and its requirement is readable in full at any width', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    for (var width = 320.0; width <= 1100.0; width += 10.0) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsModal(unlockedAchievementIds: const ['first_delivery'], onClose: () {}),
          ),
        ),
      );
      await tester.pump();
      final cut = {...cutOffText(tester)};
      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      await tester.pump();
      cut.addAll(cutOffText(tester));
      expect(cut, isEmpty, reason: 'at $width px wide: ${cut.join(' | ')}');
    }
  });
}
