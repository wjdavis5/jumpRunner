import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/money.dart';

import 'support/app_harness.dart';

Future<void> _pumpResults(
  WidgetTester tester, {
  required int distance,
  required bool isNewRecord,
  int personalBest = 0,
  int tips = 80,
  Size size = const Size(960, 540),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GameOverModal(
          distance: distance,
          tips: tips,
          isNewRecord: isNewRecord,
          personalBest: personalBest,
          careerTips: 2500,
          onRestart: () {},
        ),
      ),
    ),
  );
}

String _distanceLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('game_over_distance_label'))).data!;

void main() {
  group('Distances and tips are written the way people read them', () {
    test('metres are grouped in thousands', () {
      expect(meters(0), equals('0 m'));
      expect(meters(412), equals('412 m'));
      expect(meters(2330), equals('2,330 m'));
      expect(meters(12500), equals('12,500 m'));
    });

    testWidgets('a long shift reads 2,330 m and \$13,845, not 2330 m and \$13845',
        (tester) async {
      await _pumpResults(tester, distance: 2330, tips: 13845, isNewRecord: true);
      expect(find.text('2,330 m'), findsOneWidget);
      expect(find.text(r'$13,845'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // The results card said how far the shift went and nothing about the
  // courier's best, unless the shift beat it. "How close was that?" is the
  // thought that starts the next shift.
  group('A shift that fell short says what it fell short of', () {
    testWidgets('the best is named beside the distance', (tester) async {
      await _pumpResults(tester, distance: 365, isNewRecord: false, personalBest: 412);
      expect(find.text('365 m'), findsOneWidget);
      expect(_distanceLabel(tester), equals('Distance · best 412 m'));
      expect(find.textContaining('NEW DISTANCE RECORD!'), findsNothing);
    });

    testWidgets('a record shift keeps its banner and a plain label', (tester) async {
      await _pumpResults(tester, distance: 520, isNewRecord: true, personalBest: 520);
      expect(find.textContaining('NEW DISTANCE RECORD!'), findsOneWidget);
      expect(_distanceLabel(tester), equals('Distance'));
    });

    testWidgets('a shift that only equalled the best has nothing to add', (tester) async {
      await _pumpResults(tester, distance: 412, isNewRecord: false, personalBest: 412);
      expect(_distanceLabel(tester), equals('Distance'));
    });

    testWidgets('with no best on record the label is plain', (tester) async {
      await _pumpResults(tester, distance: 90, isNewRecord: false);
      expect(_distanceLabel(tester), equals('Distance'));
    });

    for (final size in const [Size(667, 375), Size(844, 390), Size(960, 540)]) {
      testWidgets('it fits a ${size.width.toInt()}x${size.height.toInt()} screen with a long best',
          (tester) async {
        await _pumpResults(tester,
            distance: 9870, tips: 68885, isNewRecord: false, personalBest: 12345, size: size);
        expect(tester.takeException(), isNull);
        expect(_distanceLabel(tester), equals('Distance · best 12,345 m'));
        final label = tester.getRect(find.byKey(const Key('game_over_distance_label')));
        final tips = tester.getRect(find.text(r'$68,885'));
        // The longer label stays inside the screen and clear of the next column.
        expect(label.left, greaterThanOrEqualTo(0.0));
        expect(label.right, lessThan(tips.left));
      });
    }
  });

  group('In the running app', () {
    Future<void> crash(WidgetTester tester) async {
      await tester.tap(find.text('START SHIFT'));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final game = gameOf(tester);
      while (game.gameState.status != GameStatus.gameOver) {
        game.gameState.applyHazardDamage();
      }
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 1);
      }
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
    }

    testWidgets('a short shift after a long one names the saved best', (tester) async {
      await bootApp(tester, prefs: {'courier_high_distance': 5000});
      // The title screen writes it the same way.
      expect(find.text('5,000 m'), findsOneWidget);
      await crash(tester);
      expect(_distanceLabel(tester), equals('Distance · best 5,000 m'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a first shift is a record and says so instead', (tester) async {
      await bootApp(tester);
      await crash(tester);
      expect(find.textContaining('NEW DISTANCE RECORD!'), findsOneWidget);
      expect(_distanceLabel(tester), equals('Distance'));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
