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

/// Screens the walk switches between: the web canvas, two phones held
/// sideways, a wide desktop window, and a phone held upright.
const List<Size> _screens = [
  Size(960, 540),
  Size(667, 375),
  Size(915, 412),
  Size(1280, 600),
  Size(375, 667),
];

/// The Locker's and the Bodega's buttons: buy, unlock, wear, pack.
const List<String> _shopKeys = ['unlock_button_', 'equip_button_', 'buy_booster_', 'equip_booster_'];

/// What the walk checks about the courier's money and gear after a step.
class _Books {
  _Books(this.harness, this.game)
      : tips = harness.storage.careerTips,
        status = game.gameState.status,
        distance = game.gameState.distanceMeters;

  final AppHarness harness;
  final CourierGame game;
  final int tips;
  final GameStatus status;
  final double distance;

  /// What is wrong now, given that [did] was done since these were taken.
  String? problemAfter(String did) {
    final storage = harness.storage;
    final state = game.gameState;
    final now = storage.careerTips;
    if (now < 0) return 'career tips are negative: $now';
    if (storage.lifetimeTips < now) return 'lifetime tips ${storage.lifetimeTips} under the balance $now';
    if (!storage.unlockedSkins.contains(storage.equippedSkin) && storage.equippedSkin != 'standard') {
      return 'wearing ${storage.equippedSkin}, which is not unlocked';
    }
    if (state.packages < 0 || state.packages > state.maxPackages) {
      return '${state.packages} packages of ${state.maxPackages}';
    }
    if (did.startsWith('shop ')) {
      if (now > tips) return 'a shop button raised the balance from $tips to $now';
    } else if (status == GameStatus.idle && state.status == GameStatus.idle) {
      if (now > tips) return 'the balance rose from $tips to $now at the depot';
      // A finger that lifts presses whatever is under it, and that can be
      // a BUY button it came down on earlier: the balance may fall then.
      if (now < tips && !did.startsWith('finger ')) {
        return 'the balance went from $tips to $now at the depot with nothing bought';
      }
    }
    if (status == GameStatus.paused && state.status == GameStatus.paused && state.distanceMeters != distance) {
      return 'a paused shift moved from $distance m to ${state.distanceMeters} m';
    }
    return null;
  }
}

/// Spends or wears something: any buy, unlock or equip button showing.
Future<String> _shop(WidgetTester tester, math.Random rng) async {
  final buttons = find.byWidgetPredicate((w) {
    final k = w.key;
    if (k is! ValueKey<String>) return false;
    return _shopKeys.any(k.value.startsWith);
  });
  final showing = buttons.evaluate().length;
  if (showing == 0) return 'no shop button';
  final pick = buttons.at(rng.nextInt(showing));
  final name = (tester.widget(pick).key! as ValueKey<String>).value;
  await tester.tap(pick, warnIfMissed: false);
  return 'shop $name';
}

/// One random thing a player (or the phone) might do. Returns what it did.
Future<String> _act(WidgetTester tester, math.Random rng, List<TestGesture> fingers) async {
  final game = gameOf(tester);
  final state = game.gameState;
  Finder key(String k) => find.byKey(Key(k));

  // With a shop card open, mostly shop: otherwise the walk wanders off
  // before it has bought anything.
  final shopOpen = game.overlays.isActive('LockerModal') || game.overlays.isActive('BodegaModal');
  if (shopOpen && rng.nextInt(3) != 0) return _shop(tester, rng);

  switch (rng.nextInt(38)) {
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
    case 21:
      // Away for seconds, with no frame drawn until the app is back: what a
      // phone does, and what a browser tab does when it is hidden. Whatever
      // was being timed or animated finishes all at once on the first frame
      // afterwards. This is the step that found a resume count unpausing
      // the shift behind the pause menu.
      final seconds = 1 + rng.nextInt(6);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration(seconds: seconds));
      return 'app away ${seconds}s with no frame';
    case 23:
    case 24:
      return _shop(tester, rng);
    case 25:
    case 26:
      // A finger goes down somewhere on the screen and stays down. Up to
      // three at once: two thumbs and a palm.
      if (fingers.length >= 3) return 'no free finger';
      final size = tester.view.physicalSize;
      final at = Offset(
        20 + rng.nextDouble() * (size.width - 40),
        size.height * (0.35 + rng.nextDouble() * 0.6),
      );
      fingers.add(await tester.startGesture(at));
      return 'finger down (${fingers.length} held)';
    case 27:
    case 28:
      if (fingers.isEmpty) return 'no finger to lift';
      await fingers.removeAt(rng.nextInt(fingers.length)).up();
      return 'finger up (${fingers.length} held)';
    case 29:
      // The system takes a touch away: an edge swipe, a notification.
      if (fingers.isEmpty) return 'no finger to cancel';
      await fingers.removeAt(rng.nextInt(fingers.length)).cancel();
      return 'finger cancelled (${fingers.length} held)';
    case 30:
      if (fingers.isEmpty) return 'no finger to slide';
      await fingers[rng.nextInt(fingers.length)]
          .moveBy(Offset(rng.nextDouble() * 160 - 80, rng.nextDouble() * 120 - 60));
      return 'finger slides';
    case 36:
    case 37:
      // A good shift: the walk's own jumping collects next to nothing, and
      // tips are what gets banked when a shift ends or the app is put away.
      if (state.status != GameStatus.running) return 'no tips (not running)';
      final amount = 1 + rng.nextInt(400);
      state.addTip(amount);
      return 'tips +$amount';
    case 22:
      // The window is resized, or the phone turned: any screen, mid-shift
      // or not, has to lay out at any of these.
      final size = _screens[rng.nextInt(_screens.length)];
      tester.view.physicalSize = size;
      await tester.pump(const Duration(milliseconds: 16));
      return 'screen ${size.width.round()}x${size.height.round()}';
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
  // catch the orderings nobody thought to write a test for. Kept short here:
  // three seeds chosen because between them they play shifts, earn tips,
  // leave the app, change the screen, hold and cancel touches and buy from
  // the shops. For a soak, raise the seed list and the step count by hand:
  // forty-eight seeds of 200 steps passed when the tips tally was added.
  // Run that way it has found a resume count unpausing the shift behind
  // the pause menu, the HUD's pause button off the edge of a narrow screen,
  // and a shift starting under an open menu card when a finger held on
  // START SHIFT was lifted. All three seeds here fail if a shift put away
  // and then finished is banked twice. A seed's walk changes whenever an
  // action is added, so a seed that found something is not kept: its test
  // is.
  for (final seed in const [404, 405, 420]) {
    testWidgets('random walk through the app holds together (seed $seed)', (tester) async {
      // Enough in the bank for the walk to buy things.
      final harness = await bootApp(
        tester,
        prefs: {'courier_career_tips': 30000, 'courier_lifetime_tips': 30000},
      );
      final rng = math.Random(seed);
      final trail = <String>[];

      // What each shift has earned, kept apart from what the app has banked.
      // A shift is banked when it ends and whenever the app is put away in
      // the middle of it, and the two must never add up to more than the
      // shift earned.
      final earned = <int, int>{};
      final lifetimeAtStart = harness.storage.lifetimeTips;
      final starsAtStart = harness.storage.dailyStars;

      final fingers = <TestGesture>[];

      for (var step = 0; step < 120; step++) {
        final books = _Books(harness, gameOf(tester));
        final did = await _act(tester, rng, fingers);
        trail.add(did);
        await settle(tester, frames: 2);

        final where = 'after step $step (${trail.skip(math.max(0, trail.length - 8)).join(' > ')})';
        expect(tester.takeException(), isNull, reason: where);
        expect(books.problemAfter(did), isNull, reason: where);
        // With every finger off the glass, nothing is holding the jump.
        if (fingers.isEmpty) {
          expect(gameOf(tester).player.isJumpHeld, isFalse, reason: 'jump held with no finger down, $where');
        }

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

        final state = game.gameState;
        final thisShift = state.tips + state.contractManager.totalBonusTips;
        earned[state.runNumber] = math.max(earned[state.runNumber] ?? 0, thisShift);
        // A daily goal pays a bonus of its own, outside this tally.
        if (harness.storage.dailyStars == starsAtStart) {
          final banked = harness.storage.lifetimeTips - lifetimeAtStart;
          final total = earned.values.fold<int>(0, (a, b) => a + b);
          expect(banked, lessThanOrEqualTo(total), reason: 'more tips banked than the shifts earned, $where');
          if (state.status == GameStatus.idle) {
            expect(banked, equals(total), reason: 'back at the depot with tips earned and not banked, $where');
          }
          // Putting the app away banks the shift so far, and it comes back
          // paused, where nothing more is earned.
          if (did.startsWith('app away') && state.status == GameStatus.paused) {
            expect(banked, equals(total), reason: 'the app was put away with tips not banked, $where');
          }
        }
      }

      for (final finger in fingers) {
        await finger.up();
      }
      await settle(tester, frames: 2);
      expect(gameOf(tester).player.isJumpHeld, isFalse, reason: 'jump held after the last finger lifted');

      // Let fanfare ducking timers and any count in progress run out.
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }
}
