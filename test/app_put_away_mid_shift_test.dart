import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

/// The app is put away: the events a phone sends, in the order it sends them.
Future<void> _putAway(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await settle(tester, frames: 4);
}

Future<void> _comeBack(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await settle(tester, frames: 4);
}

/// Resumes from the pause menu and waits out the count.
Future<void> _resume(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('resume_shift_button')));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(gameOf(tester).gameState.status, equals(GameStatus.running));
}

Future<void> _endShift(WidgetTester tester) async {
  final state = gameOf(tester).gameState;
  while (state.status == GameStatus.running) {
    state.applyHazardDamage();
  }
  for (var i = 0; i < 40 && find.text('START NEXT SHIFT').evaluate().isEmpty; i++) {
    await settle(tester, frames: 4);
  }
  expect(find.text('START NEXT SHIFT'), findsOneWidget, reason: 'the results card never appeared');
}

/// The results card's own timers run out before the test ends.
Future<void> _letTimersRunOut(WidgetTester tester) => tester.pump(const Duration(seconds: 5));

void main() {
  // A shift was banked when it ended and at no other time. A phone may close
  // an app that has been put away, and a browser tab can simply be closed:
  // a shift interrupted by a phone call lost its tips and its record.

  testWidgets('Putting the app away in the middle of a shift banks it so far', (tester) async {
    final app = await bootApp(tester, prefs: {'courier_high_distance': 100});
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    final state = gameOf(tester).gameState;
    state.addTip(250);
    state.distanceMeters = 320.0;

    await _putAway(tester);

    expect(app.storage.careerTips, equals(250));
    expect(app.storage.lifetimeTips, equals(250));
    expect(app.storage.highDistance, equals(320));
    // The shift itself is only paused.
    expect(state.status, equals(GameStatus.paused));
    expect(state.tips, equals(250));
  });

  testWidgets('Coming back and finishing the shift adds only what was earned since', (tester) async {
    final app = await bootApp(tester);
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    final state = gameOf(tester).gameState;
    state.addTip(250);

    await _putAway(tester);
    await _comeBack(tester);
    await _resume(tester);
    state.addTip(100);
    await _endShift(tester);

    expect(app.storage.careerTips, equals(350), reason: 'not 600: the first 250 were banked already');
    expect(app.storage.lifetimeTips, equals(350));
    expect(find.text('\$350'), findsWidgets, reason: 'the results card shows the whole shift');
    await _letTimersRunOut(tester);
  });

  testWidgets('A record banked while away is still a record on the results card', (tester) async {
    final app = await bootApp(tester, prefs: {'courier_high_distance': 100});
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    final state = gameOf(tester).gameState;
    state.distanceMeters = 320.0;

    await _putAway(tester);
    expect(app.storage.highDistance, equals(320));
    await _comeBack(tester);
    // The shift ends from the pause menu's side of things: no further ground
    // is covered, so the distance is no longer above the saved one.
    await _resume(tester);
    await _endShift(tester);

    expect(find.textContaining('NEW DISTANCE RECORD!'), findsOneWidget);
    await _letTimersRunOut(tester);
  });

  testWidgets('Putting the app away again with nothing new saves nothing new', (tester) async {
    final app = await bootApp(tester);
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    gameOf(tester).gameState.addTip(250);

    await _putAway(tester);
    await _comeBack(tester);
    await _putAway(tester);
    await _comeBack(tester);

    expect(app.storage.careerTips, equals(250));
    expect(app.storage.lifetimeTips, equals(250));
  });

  testWidgets('Returning to the depot after coming back counts nothing twice', (tester) async {
    final app = await bootApp(tester);
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    final state = gameOf(tester).gameState;
    // Enough for the "collect \$500 in one shift" contract and its bonus.
    state.addTip(600);
    final withBonus = 600 + state.contractManager.totalBonusTips;
    expect(state.contractManager.completedCount, equals(1));

    await _putAway(tester);
    expect(app.storage.careerTips, equals(withBonus));
    expect(app.storage.completedContracts, equals(1));

    await _comeBack(tester);
    await tester.tap(find.byKey(const Key('quit_to_depot_button')));
    await settle(tester, frames: 8);

    expect(find.text('START SHIFT'), findsOneWidget);
    expect(app.storage.careerTips, equals(withBonus));
    expect(app.storage.completedContracts, equals(1));
  });

  testWidgets('The next shift is banked in full', (tester) async {
    final app = await bootApp(tester);
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    gameOf(tester).gameState.addTip(250);
    await _putAway(tester);
    await _comeBack(tester);
    await _resume(tester);
    await _endShift(tester);
    expect(app.storage.careerTips, equals(250));

    // A tally carried over from the shift before would hold these back.
    await tester.tap(find.text('START NEXT SHIFT'));
    await settle(tester, frames: 10);
    final next = gameOf(tester).gameState;
    expect(next.status, equals(GameStatus.running));
    next.addTip(40);
    await _endShift(tester);

    expect(app.storage.careerTips, equals(290));
    await _letTimersRunOut(tester);
  });

  testWidgets('Nothing is banked from the depot or from the results card', (tester) async {
    final app = await bootApp(tester, prefs: {'courier_career_tips': 75});
    await _putAway(tester);
    await _comeBack(tester);
    expect(app.storage.careerTips, equals(75));

    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    gameOf(tester).gameState.addTip(30);
    await _endShift(tester);
    expect(app.storage.careerTips, equals(105));

    await _putAway(tester);
    await _comeBack(tester);
    expect(app.storage.careerTips, equals(105));
    await _letTimersRunOut(tester);
  });
}
