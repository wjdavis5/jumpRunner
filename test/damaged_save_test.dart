import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Every saved value, each with something of the wrong kind in it.
const Map<String, Object> _wrongKinds = {
  'courier_high_distance': '3412',
  'courier_career_tips': 'lots',
  'courier_lifetime_tips': 12.5,
  'courier_completed_contracts': true,
  'courier_daily_stars': <String>['3'],
  'courier_lifetime_deliveries': 'many',
  'courier_coach_pigeons': 0.5,
  'courier_booster_cold_brew': 'two',
  'courier_sound_muted': 1,
  'courier_reduce_flash': 'yes',
  'courier_haptics': 0,
  'courier_unlocked_skins': 'standard',
  'courier_unlocked_achievements': 7,
  'courier_equipped_skin': 7,
  'courier_last_completed_daily': 20261005,
};

Future<LocalStorageService> _storage(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final storage = LocalStorageService();
  await storage.init();
  return storage;
}

/// Opens each depot card, plays a shift to its end, and returns what went
/// wrong on the way.
Future<List<String>> _playThrough(WidgetTester tester) async {
  final problems = <String>[];
  void check(String where) {
    final error = tester.takeException();
    if (error != null) problems.add('$where: ${error.toString().split('\n').first}');
  }

  check('title');
  for (final card in const ['locker', 'bodega', 'trophies', 'daily_shift']) {
    await tester.tap(find.byKey(Key('open_${card}_button')));
    await settle(tester, frames: 5);
    check(card);
    await tester.binding.handlePopRoute();
    await settle(tester, frames: 4);
  }
  await tester.tap(find.text('START SHIFT'));
  await settle(tester, frames: 12);
  check('the shift');
  final state = gameOf(tester).gameState;
  if (state.status != GameStatus.running) problems.add('the shift did not start');
  state.addTip(250);
  while (state.status == GameStatus.running) {
    state.applyHazardDamage();
  }
  for (var i = 0; i < 40 && find.text('START NEXT SHIFT').evaluate().isEmpty; i++) {
    await settle(tester, frames: 4);
  }
  check('the results card');
  if (find.text('START NEXT SHIFT').evaluate().isEmpty) problems.add('no results card');
  // The results card's own timers run out before the test ends.
  await tester.pump(const Duration(seconds: 5));
  return problems;
}

void main() {
  // Every saved value is read while the app starts, with a getter that
  // throws when the value is of another kind. One such value and the title
  // screen never appeared: a blank page until the browser's storage was
  // cleared. A number with quotes round it is enough, which is what a
  // player editing their tips by hand is likely to write.

  test('A saved value of the wrong kind counts as never saved', () async {
    final storage = await _storage(_wrongKinds);

    expect(storage.highDistance, equals(0));
    expect(storage.careerTips, equals(0));
    expect(storage.lifetimeTips, equals(0));
    expect(storage.completedContracts, equals(0));
    expect(storage.dailyStars, equals(0));
    expect(storage.lifetimeDeliveries, equals(0));
    expect(storage.pigeonCoachRuns, equals(0));
    expect(storage.getBoosterCount('cold_brew'), equals(0));
    expect(storage.isSoundMuted, isFalse);
    expect(storage.isReduceFlash, isFalse);
    expect(storage.isHapticsEnabled, isTrue);
    expect(storage.unlockedSkins, equals(['standard']));
    expect(storage.unlockedAchievements, isEmpty);
    expect(storage.equippedSkin, equals('standard'));
    expect(storage.lastCompletedDaily, isNull);
  });

  test('A saved value of the right kind is read as it was saved', () async {
    final storage = await _storage({
      'courier_high_distance': 3412,
      'courier_career_tips': 128450,
      'courier_sound_muted': true,
      'courier_haptics': false,
      'courier_unlocked_skins': <String>['standard', 'night_shift_neon'],
      'courier_equipped_skin': 'night_shift_neon',
      'courier_last_completed_daily': '2026-10-05',
    });

    expect(storage.highDistance, equals(3412));
    expect(storage.careerTips, equals(128450));
    expect(storage.isSoundMuted, isTrue);
    expect(storage.isHapticsEnabled, isFalse);
    expect(storage.unlockedSkins, equals(['standard', 'night_shift_neon']));
    expect(storage.equippedSkin, equals('night_shift_neon'));
    expect(storage.lastCompletedDaily, equals('2026-10-05'));
  });

  test('A list keeps the names in it and drops what is not a name', () async {
    final storage = await _storage({
      'courier_unlocked_skins': <Object>['standard', 3, 'night_shift_neon'],
    });
    expect(storage.unlockedSkins, equals(['standard', 'night_shift_neon']));
  });

  testWidgets('The app starts and plays with every saved value of the wrong kind', (tester) async {
    final app = await bootApp(tester, prefs: _wrongKinds);
    expect(await _playThrough(tester), isEmpty);
    // The first thing saved over a bad value puts it right.
    expect(app.storage.careerTips, greaterThanOrEqualTo(250));
  });

  // These already worked. They are the saves an update can leave behind:
  // an outfit or a trophy that no longer exists, a date in another form.
  testWidgets('The app starts and plays with a save from another version', (tester) async {
    await bootApp(
      tester,
      prefs: {
        'courier_equipped_skin': 'retired_skin',
        'courier_unlocked_skins': <String>['retired_skin'],
        'courier_unlocked_achievements': <String>['retired_trophy', 'first_delivery'],
        'courier_last_completed_daily': 'yesterday-ish',
        'courier_booster_retired_booster': 2,
        'courier_booster_cold_brew': -3,
        'courier_career_tips': -500,
        'courier_high_distance': -40,
        'courier_daily_stars': -2,
      },
    );
    expect(await _playThrough(tester), isEmpty);
  });
}
