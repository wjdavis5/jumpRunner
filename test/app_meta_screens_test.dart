import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/models/courier_skin.dart';
import 'package:jump_runner/services/storage_service.dart';

import 'support/app_harness.dart';

const int _startingTips = 5000;

/// Boots the whole app with $5,000 of career tips to spend.
Future<LocalStorageService> _bootWithTips(WidgetTester tester) async {
  final app = await bootApp(tester, prefs: const {'courier_career_tips': _startingTips});
  return app.storage;
}

void main() {
  group('Locker in the running app', () {
    testWidgets('Buying an outfit updates the Locker at once and dresses the courier', (tester) async {
      final storage = await _bootWithTips(tester);

      await tester.tap(find.byKey(const Key('open_locker_button')));
      await settle(tester);
      expect(find.byKey(const Key('unlock_button_night_shift_neon')), findsOneWidget);

      await tester.tap(find.byKey(const Key('unlock_button_night_shift_neon')));
      await settle(tester);

      expect(storage.equippedSkin, equals('night_shift_neon'));
      final left = _startingTips - CourierSkin.nightShiftNeon.price;
      expect(storage.careerTips, equals(left));
      // The card the player is looking at must show what just happened.
      expect(find.byKey(const Key('equipped_badge_night_shift_neon')), findsOneWidget);
      expect(find.byKey(const Key('unlock_button_night_shift_neon')), findsNothing);
      expect(gameOf(tester).player.skin.id, equals('night_shift_neon'));

      await tester.tap(find.byKey(const Key('locker_close_button')));
      await settle(tester);
      expect(find.text('START SHIFT'), findsOneWidget);
      // The title's career tips reflect the purchase.
      expect(find.text('\$3,000'), findsOneWidget);
      expect(left, equals(3000));
    });
  });

  group('Bodega in the running app', () {
    testWidgets('A bought booster is equipped and used up by the next shift', (tester) async {
      final storage = await _bootWithTips(tester);

      await tester.tap(find.byKey(const Key('open_bodega_button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('buy_booster_satchel')));
      await settle(tester);
      expect(storage.getBoosterCount('satchel'), equals(1));

      // Buying a booster equips it; no second tap is needed.
      await tester.tap(find.byKey(const Key('bodega_done_button')));
      await settle(tester);
      expect(find.text('START SHIFT'), findsOneWidget);

      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);

      expect(storage.getBoosterCount('satchel'), equals(0));
      expect(gameOf(tester).gameState.maxPackages, equals(4));
      expect(find.byKey(const Key('pause_button')), findsOneWidget);
    });
  });

  group('Pause menu in the running app', () {
    testWidgets('The reduce-flash switch flips when tapped', (tester) async {
      final storage = await _bootWithTips(tester);
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester);

      final toggle = find.byKey(const Key('reduce_flash_toggle'));
      expect(toggle, findsOneWidget);
      expect(storage.isReduceFlash, isFalse);

      await tester.tap(toggle);
      await settle(tester);

      expect(storage.isReduceFlash, isTrue);
      final inside = find.descendant(of: toggle, matching: find.byType(Switch));
      final switches = inside.evaluate().isNotEmpty ? inside : find.byType(Switch);
      expect(tester.widget<Switch>(switches.first).value, isTrue);
    });
  });

  group('Title screen in the running app', () {
    testWidgets('The mute button shows the new state as soon as it is tapped', (tester) async {
      await bootApp(tester);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up));
      await settle(tester);

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsNothing);
    });

    testWidgets('Trophies opens and closes back to the title', (tester) async {
      await bootApp(tester);

      await tester.tap(find.byKey(const Key('open_trophies_button')));
      await settle(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('START SHIFT'), findsOneWidget);
    });
  });
}
