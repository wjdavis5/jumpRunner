import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/achievement.dart';
import 'package:jump_runner/ui/game_over_modal.dart';

import 'support/app_harness.dart';

/// The ids of the trophies the results card is showing.
List<String> _trophiesShown(WidgetTester tester) {
  const prefix = 'game_over_trophy_';
  return [
    for (final widget in tester.allWidgets)
      if (widget.key case ValueKey<String>(value: final key) when key.startsWith(prefix))
        key.substring(prefix.length),
  ];
}

Future<void> _startShift(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  await settle(tester, frames: 10);
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

void main() {
  // A trophy earned on the street says so in a line of floating text. Some
  // trophies are only judged when the shift is over (a career's worth of
  // tips, of contracts), and theirs came up behind the results card. The
  // card itself never mentioned trophies: the only sign of a new one was the
  // count on the Trophies button going up.

  testWidgets('The results card names each trophy it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameOverModal(
            distance: 640,
            tips: 300,
            isNewRecord: false,
            careerTips: 25200,
            onRestart: () {},
            trophies: [Achievement.findById('first_delivery')!, Achievement.findById('big_tipper')!],
          ),
        ),
      ),
    );

    expect(find.text('TROPHY: FIRST DELIVERY'), findsOneWidget);
    expect(find.text('TROPHY: BIG TIPPER'), findsOneWidget);
    expect(_trophiesShown(tester), equals(['first_delivery', 'big_tipper']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('With no trophy earned it shows none', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameOverModal(distance: 64, tips: 30, isNewRecord: false, careerTips: 30, onRestart: () {}),
        ),
      ),
    );
    expect(_trophiesShown(tester), isEmpty);
    expect(find.textContaining('TROPHY'), findsNothing);
  });

  testWidgets('A trophy judged when the shift is over is on its results card', (tester) async {
    // 100 short of Big Tipper, and holding one trophy already.
    final app = await bootApp(
      tester,
      prefs: {
        'courier_career_tips': 24900,
        'courier_lifetime_tips': 24900,
        'courier_unlocked_achievements': <String>['master_acrobat'],
      },
    );
    await _startShift(tester, 'START SHIFT');
    gameOf(tester).gameState.addTip(200);
    await settle(tester, frames: 4);
    expect(app.storage.unlockedAchievements, isNot(contains('big_tipper')), reason: 'not until the shift is banked');

    await _endShift(tester);

    expect(app.storage.unlockedAchievements, contains('big_tipper'));
    expect(_trophiesShown(tester), equals(['big_tipper']), reason: 'the new one, and not the one held before');
    expect(find.text('TROPHY: BIG TIPPER'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('A trophy earned on the street is on the results card too', (tester) async {
    final app = await bootApp(tester);
    await _startShift(tester, 'START SHIFT');
    // Past the 500 m of First Delivery, which is judged as it happens.
    gameOf(tester).gameState.distanceMeters = 520.0;
    await settle(tester, frames: 6);
    expect(app.storage.unlockedAchievements, contains('first_delivery'));

    await _endShift(tester);

    expect(_trophiesShown(tester), contains('first_delivery'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('The next shift does not show it again', (tester) async {
    await bootApp(tester, prefs: {'courier_career_tips': 24900, 'courier_lifetime_tips': 24900});
    await _startShift(tester, 'START SHIFT');
    gameOf(tester).gameState.addTip(200);
    await _endShift(tester);
    expect(_trophiesShown(tester), contains('big_tipper'));

    await _startShift(tester, 'START NEXT SHIFT');
    await _endShift(tester);
    expect(_trophiesShown(tester), isEmpty, reason: 'straight on to the next shift');

    // And by way of the depot.
    await tester.tap(find.byKey(const Key('game_over_depot_button')));
    await settle(tester, frames: 8);
    await _startShift(tester, 'START SHIFT');
    await _endShift(tester);
    expect(_trophiesShown(tester), isEmpty, reason: 'after a visit to the depot');
    await tester.pump(const Duration(seconds: 5));
  });
}
