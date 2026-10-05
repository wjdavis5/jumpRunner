// Pictures of every screen of the app, without a phone or a browser.
//
//   flutter test tool/screens.dart
//   flutter test tool/screens.dart --dart-define=ONLY=upright-375
//
// writes PNGs to build/screens/ (or --dart-define=OUT=some/dir): the title
// card, the four depot cards, the HUD, the pause menu and the results card,
// at each of the sizes below. It takes about ten seconds.
//
// The app's own text is drawn in Roboto, as on Android. Text the game
// paints on its canvas (signs, floating scores, hints) names no font and
// comes out as solid bars. Sprites, the HUD and the cards are as shipped.
//
// It is not part of the test suite: `flutter test` only runs files named
// *_test.dart under test/.
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import '../test/support/app_harness.dart';
import '../test/support/real_fonts.dart';

const _sizes = {
  'upright-320': Size(320, 568),
  'upright-375': Size(375, 667),
  'upright-430': Size(430, 932),
  'phone-568': Size(568, 320),
  'phone-667': Size(667, 375),
  'phone-844': Size(844, 390),
  'design-960': Size(960, 540),
  'laptop-1366': Size(1366, 768),
};

const _only = String.fromEnvironment('ONLY');
const _out = String.fromEnvironment('OUT', defaultValue: 'build/screens');

Future<void> _shot(WidgetTester tester, String name) async {
  await settle(tester, frames: 3);
  final file = File('${Directory.current.path}/$_out/$name.png');
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(file.uri));
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (i % 20 == 0) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
}

void main() {
  // "Golden" files that are always rewritten: this only takes pictures.
  autoUpdateGoldenFiles = true;
  setUpAll(() async {
    await loadRealFonts();
    Directory('${Directory.current.path}/$_out').createSync(recursive: true);
  });

  for (final entry in _sizes.entries) {
    final name = entry.key;
    if (_only.isNotEmpty && _only != name) continue;

    testWidgets('screens at $name', (tester) async {
      await bootApp(
        tester,
        size: entry.value,
        prefs: {
          'courier_career_tips': 128450,
          'courier_lifetime_tips': 245300,
          'courier_high_distance': 3412,
          'courier_lifetime_deliveries': 1287,
          'courier_daily_stars': 14,
        },
      );
      await _shot(tester, '$name-1-title');

      for (final card in const ['locker', 'bodega', 'trophies', 'daily_shift']) {
        await tester.tap(find.byKey(Key('open_${card}_button')));
        await settle(tester, frames: 8);
        await _shot(tester, '$name-2-$card');
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 8);
      }

      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 8);
      final state = gameOf(tester).gameState;
      // Three seconds of street, kept alive, with a five-figure tip count.
      for (var i = 0; i < 10; i++) {
        state.packages = state.maxPackages;
        await _frames(tester, 20);
      }
      state.addTip(98765);
      await _shot(tester, '$name-3-hud');

      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 8);
      await _shot(tester, '$name-4-pause');

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      // The resume count, then on with the shift.
      await _frames(tester, 260);
      while (state.status == GameStatus.running) {
        state.applyHazardDamage();
      }
      for (var i = 0; i < 40 && find.text('START NEXT SHIFT').evaluate().isEmpty; i++) {
        await _frames(tester, 10);
      }
      await _shot(tester, '$name-5-results');
      // The results card's own timers run out before the test ends.
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
