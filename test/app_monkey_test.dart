import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

/// The app's menu-card overlays.
const _menuCards = ['LockerModal', 'BodegaModal', 'AchievementsModal', 'DailyShiftModal'];

/// Taps [finder] if it is on screen. A tap on something covered by another
/// layer lands on that layer, exactly as a finger would.
Future<bool> _tapIfPresent(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return false;
  await tester.tap(finder.first, warnIfMissed: false);
  return true;
}

/// One random thing a player (or the phone) might do. Returns what it did.
Future<String> _act(WidgetTester tester, math.Random rng) async {
  final game = gameOf(tester);
  final state = game.gameState;
  Finder key(String k) => find.byKey(Key(k));

  switch (rng.nextInt(24)) {
    case 0:
    case 1:
      return await _tapIfPresent(tester, find.text('START SHIFT')) ? 'tap START SHIFT' : 'no START';
    case 2:
    case 3:
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      return 'Space';
    case 4:
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      return 'P';
    case 5:
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      return 'Esc';
    case 6:
      return await _tapIfPresent(tester, key('pause_button')) ? 'tap pause' : 'no pause button';
    case 7:
      return await _tapIfPresent(tester, key('resume_shift_button')) ? 'tap resume' : 'no resume';
    case 8:
      return await _tapIfPresent(tester, key('quit_to_depot_button')) ? 'tap quit' : 'no quit';
    case 9:
      return await _tapIfPresent(tester, key('game_over_depot_button')) ? 'tap depot' : 'no depot';
    case 10:
      return await _tapIfPresent(tester, find.text('START NEXT SHIFT')) ? 'tap next shift' : 'no next';
    case 11:
      final buttons = ['open_locker_button', 'open_bodega_button', 'open_trophies_button', 'open_daily_shift_button'];
      final pick = buttons[rng.nextInt(buttons.length)];
      return await _tapIfPresent(tester, key(pick)) ? 'tap $pick' : 'no $pick';
    case 12:
      final closers = ['locker_close_button', 'close_daily_shift_button', 'bodega_done_button'];
      final pick = closers[rng.nextInt(closers.length)];
      return await _tapIfPresent(tester, key(pick)) ? 'tap $pick' : 'no $pick';
    case 13:
      await tester.tapAt(const Offset(6, 6));
      return 'tap corner';
    case 14:
      return await _tapIfPresent(tester, key('start_daily_shift_button')) ? 'clock in' : 'no clock-in';
    case 15:
    case 16:
      // Away and back. Nothing can be tapped while the app is hidden (no
      // frames are drawn at all), so the two always come as a pair.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(milliseconds: 16));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return 'app away and back';
    case 17:
      if (state.status == GameStatus.running) {
        while (state.status == GameStatus.running) {
          state.applyHazardDamage();
        }
        return 'crash';
      }
      return 'no crash (not running)';
    case 18:
      await tester.tapAt(const Offset(480, 300));
      return 'tap street';
    case 19:
      final toggles = ['reduce_flash_toggle', 'haptics_toggle'];
      final pick = toggles[rng.nextInt(toggles.length)];
      return await _tapIfPresent(tester, key(pick)) ? 'tap $pick' : 'no $pick';
    case 20:
      // Android's back button or back swipe. At the depot with nothing open
      // it asks the system to close the app, which a test ignores.
      await tester.binding.handlePopRoute();
      return 'back';
    default:
      // Let time pass: anything from a frame to most of a second.
      final frames = 1 + rng.nextInt(45);
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      return 'wait $frames frames';
  }
}

/// What must be true of the screen whatever just happened.
String? _inconsistency(CourierGame game) {
  final overlays = game.overlays;
  bool on(String name) => overlays.isActive(name);
  final status = game.gameState.status;
  final menus = _menuCards.where(on).toList();

  if (on('PauseMenu') && on('ResumeCountdown')) return 'pause menu and countdown together';
  if (menus.length > 1) return 'two menu cards open: $menus';

  switch (status) {
    case GameStatus.idle:
      if (!on('TitleScreen')) return 'idle without the title screen';
      if (on('HUD') || on('PauseMenu') || on('GameOver') || on('ResumeCountdown')) {
        return 'idle with a shift overlay up: ${overlays.activeOverlays}';
      }
    case GameStatus.running:
      if (!on('HUD')) return 'running without the HUD';
      if (on('TitleScreen') || on('PauseMenu') || on('GameOver') || on('ResumeCountdown')) {
        return 'running under a blocking overlay: ${overlays.activeOverlays}';
      }
      if (menus.isNotEmpty) return 'running under a menu card: $menus';
    case GameStatus.paused:
      if (!on('HUD')) return 'paused without the HUD';
      if (!on('PauseMenu') && !on('ResumeCountdown')) return 'paused with nothing to resume from';
      if (on('TitleScreen') || on('GameOver')) return 'paused under ${overlays.activeOverlays}';
    case GameStatus.gameOver:
      if (on('TitleScreen') || on('PauseMenu') || on('ResumeCountdown')) {
        return 'game over under ${overlays.activeOverlays}';
      }
  }
  return null;
}

void main() {
  // A random walk over everything a player or the phone can do to the app.
  // After every step the screen has to make sense: no two blocking layers at
  // once, nothing stranded behind a missing menu, no exception. It exists to
  // catch the orderings nobody thought to write a test for. Kept short here;
  // twelve seeds of 320 steps each passed when it was written.
  for (final seed in const [1, 2]) {
    testWidgets('random walk through the app holds together (seed $seed)', (tester) async {
      await bootApp(tester);
      final rng = math.Random(seed);
      final trail = <String>[];

      for (var step = 0; step < 120; step++) {
        final did = await _act(tester, rng);
        trail.add(did);
        await settle(tester, frames: 2);

        final where = 'after step $step (${trail.skip(math.max(0, trail.length - 8)).join(' > ')})';
        expect(tester.takeException(), isNull, reason: where);

        final game = gameOf(tester);
        var problem = _inconsistency(game);
        // The results card goes up only after the shift has been banked,
        // which takes a few real milliseconds once the crash beat ends.
        for (var i = 0; i < 20 && problem == null; i++) {
          final waiting = game.gameState.status == GameStatus.gameOver &&
              !game.overlays.isActive('GameOver') &&
              !game.deathSlowmo.isActive;
          if (!waiting) break;
          await settle(tester, frames: 1);
          problem = _inconsistency(game);
          if (i == 19) problem = 'game over, but the results card never appeared';
        }
        expect(problem, isNull, reason: where);
      }

      // Let fanfare ducking timers and any count in progress run out.
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }
}
