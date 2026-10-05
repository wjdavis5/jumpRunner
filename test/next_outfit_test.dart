import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/courier_skin.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';

import 'support/app_harness.dart';

String _goal(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('next_outfit_goal_text'))).data!;

Future<void> _pumpTitle(
  WidgetTester tester, {
  required int tips,
  CourierSkin? next,
  VoidCallback? onOpenLocker,
  Size size = const Size(960, 540),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TitleScreen(
          highDistance: 420,
          careerTips: tips,
          onStartGame: () {},
          onOpenLocker: onOpenLocker,
          nextOutfit: next,
        ),
      ),
    ),
  );
}

void main() {
  group('Which outfit a courier is saving for', () {
    test('a new courier is saving for the cheapest one', () {
      expect(CourierSkin.nextToUnlock(const ['standard']), CourierSkin.nightShiftNeon);
    });

    test('then the next cheapest, whatever order they were bought in', () {
      expect(
        CourierSkin.nextToUnlock(const ['standard', 'night_shift_neon']),
        CourierSkin.highTops,
      );
      expect(
        CourierSkin.nextToUnlock(const ['standard', 'golden_courier']),
        CourierSkin.nightShiftNeon,
      );
    });

    test('nothing, once the Locker is complete', () {
      expect(
        CourierSkin.nextToUnlock([for (final s in CourierSkin.catalog) s.id]),
        isNull,
      );
    });

    test('the free uniform is never the goal', () {
      expect(CourierSkin.nextToUnlock(const <String>[]), CourierSkin.nightShiftNeon);
    });
  });

  group('The title screen shows what the tips are for', () {
    testWidgets('how far the next outfit is', (tester) async {
      await _pumpTitle(tester, tips: 750, next: CourierSkin.nightShiftNeon);
      expect(find.text('NEXT: NIGHT SHIFT NEON'), findsOneWidget);
      expect(_goal(tester), equals(r'$1,250 to go'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('that it can be bought, once it can', (tester) async {
      await _pumpTitle(tester, tips: 2000, next: CourierSkin.nightShiftNeon);
      expect(_goal(tester), equals('READY IN LOCKER'));
    });

    testWidgets('tapping the goal opens the Locker', (tester) async {
      var opened = 0;
      await _pumpTitle(
        tester,
        tips: 2600,
        next: CourierSkin.nightShiftNeon,
        onOpenLocker: () => opened++,
      );
      await tester.tap(find.byKey(const Key('next_outfit_goal')));
      expect(opened, equals(1));
    });

    testWidgets('nothing extra when there is nothing left to buy', (tester) async {
      await _pumpTitle(tester, tips: 99000);
      expect(find.byKey(const Key('next_outfit_goal')), findsNothing);
      expect(find.text('PERSONAL BEST'), findsOneWidget);
      expect(find.text('CAREER TIPS'), findsOneWidget);
    });

    for (final size in const [Size(667, 375), Size(844, 390)]) {
      testWidgets('it fits on a ${size.width.toInt()}x${size.height.toInt()} phone', (tester) async {
        await _pumpTitle(tester, tips: 3, next: CourierSkin.goldenCourier, size: size);
        expect(tester.takeException(), isNull);
        final goal = tester.getRect(find.byKey(const Key('next_outfit_goal')));
        expect(goal.left, greaterThanOrEqualTo(0.0));
        expect(goal.right, lessThanOrEqualTo(size.width));
        expect(goal.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });

  group('The goal in the running app', () {
    testWidgets('a new career starts out saving for the first outfit', (tester) async {
      await bootApp(tester);
      expect(find.text('NEXT: NIGHT SHIFT NEON'), findsOneWidget);
      expect(_goal(tester), equals(r'$2,000 to go'));
    });

    testWidgets('buying an outfit moves the goal on to the next', (tester) async {
      final app = await bootApp(tester, prefs: const {'courier_career_tips': 5000});
      expect(_goal(tester), equals('READY IN LOCKER'));

      await tester.tap(find.byKey(const Key('next_outfit_goal')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('unlock_button_night_shift_neon')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('locker_close_button')));
      await settle(tester);

      expect(app.storage.careerTips, equals(3000));
      expect(find.text('NEXT: HIGH-TOP KICKS'), findsOneWidget);
      expect(_goal(tester), equals(r'$3,000 to go'));
    });
  });

  group('The results card shows how much closer the shift got', () {
    Future<void> pumpResults(
      WidgetTester tester, {
      required int careerTips,
      CourierSkin? next,
      Size size = const Size(960, 540),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 310,
              tips: 501,
              isNewRecord: false,
              careerTips: careerTips,
              nextOutfit: next,
              onRestart: () {},
              onReturnToDepot: () {},
            ),
          ),
        ),
      );
    }

    String text(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('game_over_outfit_goal_text'))).data!;

    double bar(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(
          find.descendant(
            of: find.byKey(const Key('game_over_outfit_goal')),
            matching: find.byType(LinearProgressIndicator),
          ),
        )
        .value!;

    testWidgets('a bar and the amount still to go', (tester) async {
      await pumpResults(tester, careerTips: 501, next: CourierSkin.nightShiftNeon);
      expect(find.text('NEXT: NIGHT SHIFT NEON'), findsOneWidget);
      expect(text(tester), equals(r'$1,499 to go'));
      expect(bar(tester), closeTo(501 / 2000, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a full bar once the outfit can be bought', (tester) async {
      await pumpResults(tester, careerTips: 2400, next: CourierSkin.nightShiftNeon);
      expect(text(tester), equals('READY IN LOCKER'));
      expect(bar(tester), equals(1.0));
    });

    testWidgets('nothing when the Locker is complete', (tester) async {
      await pumpResults(tester, careerTips: 90000);
      expect(find.byKey(const Key('game_over_outfit_goal')), findsNothing);
    });

    for (final size in const [Size(667, 375), Size(844, 390)]) {
      testWidgets('the card still fits a ${size.width.toInt()}x${size.height.toInt()} phone', (tester) async {
        await pumpResults(tester, careerTips: 501, next: CourierSkin.goldenCourier, size: size);
        expect(tester.takeException(), isNull);
        final goal = tester.getRect(find.byKey(const Key('game_over_outfit_goal')));
        final depot = tester.getRect(find.byKey(const Key('game_over_depot_button')));
        expect(goal.top, greaterThanOrEqualTo(0.0));
        expect(goal.bottom, lessThanOrEqualTo(depot.top));
        expect(depot.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('in the running app it appears after a crash', (tester) async {
      await bootApp(tester);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final state = gameOf(tester).gameState;
      while (state.status != GameStatus.gameOver) {
        state.applyHazardDamage();
      }
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 2);
      }
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
      expect(find.byKey(const Key('game_over_outfit_goal')), findsOneWidget);
      expect(find.text('NEXT: NIGHT SHIFT NEON'), findsOneWidget);
    });
  });
}
