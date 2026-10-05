import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

/// Starts a shift, runs it for a couple of seconds, then drops every package.
Future<void> _playUntilCrash(WidgetTester tester) async {
  await tester.tap(find.text('START SHIFT'));
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final game = gameOf(tester);
  game.gameState.addTip(40);
  while (game.gameState.status != GameStatus.gameOver) {
    game.gameState.applyHazardDamage();
  }
  // Death beat, then the results card.
  for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
    await settle(tester, frames: 1);
  }
}

void main() {
  group('End of a shift in the running app', () {
    testWidgets('The results card appears with the run recorded', (tester) async {
      final storage = (await bootApp(tester)).storage;
      await _playUntilCrash(tester);

      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
      expect(find.text('START NEXT SHIFT'), findsOneWidget);
      expect(find.byKey(const Key('game_over_depot_button')), findsOneWidget);
      expect(storage.highDistance, greaterThan(0));
      expect(storage.careerTips, greaterThanOrEqualTo(40));
      // On the results card and still on the HUD's distance pill behind it.
      expect(find.text('${storage.highDistance} m'), findsWidgets);
    });

    testWidgets('Start next shift begins a fresh run', (tester) async {
      await bootApp(tester);
      await _playUntilCrash(tester);

      await tester.tap(find.text('START NEXT SHIFT'));
      await settle(tester, frames: 10);

      expect(find.text('PACKAGES DROPPED!'), findsNothing);
      final game = gameOf(tester);
      expect(game.gameState.status, equals(GameStatus.running));
      expect(game.gameState.packages, equals(GameState.defaultMaxPackages));
      expect(game.gameState.tips, equals(0));
      expect(game.player.isKnockedOut, isFalse);
      expect(game.overlays.activeOverlays, equals(['HUD']));
    });

    testWidgets('Depot goes back to a title screen showing the new record', (tester) async {
      final storage = (await bootApp(tester)).storage;
      await _playUntilCrash(tester);

      await tester.tap(find.byKey(const Key('game_over_depot_button')));
      await settle(tester);

      expect(find.text('PACKAGES DROPPED!'), findsNothing);
      expect(find.text('START SHIFT'), findsOneWidget);
      expect(find.text('${storage.highDistance} m'), findsOneWidget);
      expect(gameOf(tester).overlays.activeOverlays, equals(['TitleScreen']));
    });

    testWidgets('Space restarts from the results card, but not instantly', (tester) async {
      await bootApp(tester);
      await _playUntilCrash(tester);
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);

      // Mashing jump as the card appears must not skip it.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester, frames: 10);

      expect(find.text('PACKAGES DROPPED!'), findsNothing);
      expect(gameOf(tester).gameState.status, equals(GameStatus.running));
    });
  });

  group('Keyboard on the title screen in the running app', () {
    testWidgets('Space starts a shift', (tester) async {
      await bootApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester, frames: 10);

      expect(find.text('START SHIFT'), findsNothing);
      expect(find.byKey(const Key('pause_button')), findsOneWidget);
      expect(gameOf(tester).gameState.status, equals(GameStatus.running));
    });

    testWidgets('Space does nothing while the Locker is open', (tester) async {
      await bootApp(tester);
      await tester.tap(find.byKey(const Key('open_locker_button')));
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);

      expect(gameOf(tester).gameState.status, equals(GameStatus.idle));
      expect(find.byKey(const Key('locker_close_button')), findsOneWidget);
    });
  });
}
