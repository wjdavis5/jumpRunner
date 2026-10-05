import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/ui/hud_overlay.dart';
import 'package:jump_runner/ui/throttled_listenable_builder.dart';

import 'support/app_harness.dart';

const _interval = Duration(milliseconds: 80);

Future<ValueNotifier<int>> _pump(WidgetTester tester, {ValueNotifier<int>? counter}) async {
  final value = counter ?? ValueNotifier<int>(0);
  await tester.pumpWidget(
    MaterialApp(
      home: ThrottledListenableBuilder(
        listenable: value,
        minInterval: _interval,
        builder: (context) => Text('${value.value}'),
      ),
    ),
  );
  return value;
}

int _builds(WidgetTester tester) => tester
    .state<ThrottledListenableBuilderState>(find.byType(ThrottledListenableBuilder))
    .buildCount;

void main() {
  // The game state tells its listeners about every tip, stunt and metre,
  // several times a frame. The HUD was rebuilt and laid out for each frame of
  // a shift, a sixth of the main thread's work in the web build, to redraw
  // numbers that change a few times a second.
  group('A throttled builder', () {
    testWidgets('shows the first change at once', (tester) async {
      final value = await _pump(tester);
      expect(find.text('0'), findsOneWidget);
      value.value = 1;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('folds a burst of changes into one rebuild now and one at the end',
        (tester) async {
      final value = await _pump(tester);
      final before = _builds(tester);
      for (var i = 1; i <= 100; i++) {
        value.value = i;
      }
      await tester.pump();
      expect(_builds(tester), equals(before + 1));
      // The burst was still going when that rebuild was asked for, so it
      // shows the first of the hundred or the last, never anything else.
      await tester.pump(_interval);
      expect(find.text('100'), findsOneWidget);
      expect(_builds(tester), equals(before + 2));
    });

    testWidgets('always ends on the last value, without another change to prompt it',
        (tester) async {
      final value = await _pump(tester);
      value.value = 1;
      await tester.pump();
      value.value = 2;
      await tester.pump(const Duration(milliseconds: 20));
      value.value = 3;
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('3'), findsNothing, reason: 'still inside the interval');
      await tester.pump(_interval);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a change every frame for a second costs about a dozen rebuilds, not sixty',
        (tester) async {
      final value = await _pump(tester);
      final before = _builds(tester);
      for (var frame = 1; frame <= 60; frame++) {
        value.value = frame;
        await tester.pump(const Duration(milliseconds: 16));
      }
      final builds = _builds(tester) - before;
      expect(builds, inInclusiveRange(9, 14));
      await tester.pump(_interval);
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets('nothing changes, nothing rebuilds', (tester) async {
      await _pump(tester);
      final before = _builds(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_builds(tester), equals(before));
    });

    testWidgets('a rebuild from the parent is not held back', (tester) async {
      final value = await _pump(tester);
      value.value = 1;
      await tester.pump();
      // The parent rebuilds with the same notifier, inside the interval.
      value.value = 2;
      await _pump(tester, counter: value);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('it follows a new listenable and lets go of the old one', (tester) async {
      final first = await _pump(tester);
      final second = ValueNotifier<int>(500);
      await _pump(tester, counter: second);
      expect(find.text('500'), findsOneWidget);

      final before = _builds(tester);
      first.value = 99;
      await tester.pump(_interval);
      expect(_builds(tester), equals(before));
      second.value = 501;
      await tester.pump();
      expect(find.text('501'), findsOneWidget);
    });

    testWidgets('taken off screen mid-interval, it leaves no timer behind', (tester) async {
      final value = await _pump(tester);
      value.value = 1;
      await tester.pump();
      value.value = 2;
      await tester.pumpWidget(const SizedBox());
      // A pending timer here would fail the test when it ends.
      value.value = 3;
      await tester.pump(_interval);
      expect(tester.takeException(), isNull);
    });
  });

  group('The HUD in the running app', () {
    testWidgets('is rebuilt a fraction as often as the game draws', (tester) async {
      await bootApp(tester);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final refresher = tester.state<ThrottledListenableBuilderState>(
        find.byKey(const Key('hud_refresher')),
      );
      final game = gameOf(tester);
      final before = refresher.buildCount;
      final startMeters = game.gameState.distanceMeters;
      for (var frame = 0; frame < 120; frame++) {
        if (game.gameState.packages < 3) game.gameState.packages = 3;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.gameState.distanceMeters, greaterThan(startMeters + 10),
          reason: 'the shift did not run');
      // 120 frames is 1.92 s: 24 intervals.
      expect(refresher.buildCount - before, inInclusiveRange(15, 30));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('still shows the true distance, tips and packages', (tester) async {
      await bootApp(tester);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final game = gameOf(tester);
      for (var frame = 0; frame < 90; frame++) {
        if (game.gameState.packages < 3) game.gameState.packages = 3;
        await tester.pump(const Duration(milliseconds: 16));
      }
      game.gameState.addTip(37);
      // Freeze the shift and give the HUD its interval to catch up.
      game.pauseEngine();
      await tester.pump(_interval);
      await tester.pump(_interval);

      final hud = find.byType(HUDOverlay);
      final state = game.gameState;
      expect(find.descendant(of: hud, matching: find.text('${state.distanceMeters.floor()} m')),
          findsOneWidget);
      expect(find.descendant(of: hud, matching: find.text('\$${state.tips}')), findsOneWidget);
      game.resumeEngine();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows the pause button\'s effect without waiting for the game', (tester) async {
      await bootApp(tester);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 3);
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
