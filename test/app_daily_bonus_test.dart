import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

void main() {
  // Reaching the daily goal pays a completion bonus. The bonus goes into the
  // shift's own tips (the HUD shows it at once), and the shift's tips are
  // banked when the shift ends. The storage layer used to be handed the same
  // bonus at the moment of completion as well, so it reached career tips
  // twice.
  testWidgets('The daily completion bonus is paid once', (tester) async {
    final app = await bootApp(tester);
    final storage = app.storage;
    expect(storage.careerTips, equals(0));

    await tester.tap(find.byKey(const Key('open_daily_shift_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('start_daily_shift_button')));
    await settle(tester, frames: 12);

    final game = gameOf(tester);
    final state = game.gameState;
    final shift = state.activeDailyShift!;
    expect(state.isDailyShiftActive, isTrue);

    // Carry the courier to the goal line.
    state.updateDistance(shift.targetDistanceMeters.toDouble());
    await settle(tester, frames: 6);
    expect(state.hasCompletedDailyShiftInRun, isTrue);
    expect(storage.isDailyShiftCompleted(shift.dateString), isTrue);
    expect(storage.dailyStars, equals(1));
    // The bonus shows in the shift's tips straight away...
    expect(state.tips, greaterThanOrEqualTo(shift.completionBonusTips));
    // ...and has not been slipped into the career total behind its back.
    expect(storage.careerTips, equals(0));

    // End the shift and let it be banked.
    while (state.status != GameStatus.gameOver) {
      state.applyHazardDamage();
    }
    for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
      await settle(tester, frames: 2);
    }
    expect(find.text('PACKAGES DROPPED!'), findsOneWidget);

    final earned = state.tips + state.contractManager.totalBonusTips;
    expect(storage.careerTips, equals(earned));

    // The milestone fanfares duck the music on a timer; let those run out.
    await tester.pump(const Duration(seconds: 2));
  });
}
