import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/models/courier_skin.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/locker_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Courier Skin & Gear Locker (Issue #17)', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
    });

    test('CourierSkin catalog contains standard, neon, high-tops, and golden skins', () {
      expect(CourierSkin.catalog.length, equals(4));
      expect(CourierSkin.findById('standard').id, equals('standard'));
      expect(CourierSkin.findById('night_shift_neon').price, equals(150));
      expect(CourierSkin.findById('high_tops').hasSpeedTrail, isTrue);
      expect(CourierSkin.findById('golden_courier').price, equals(500));

      // Fallback for unknown ID
      expect(CourierSkin.findById('unknown_alien_skin').id, equals('standard'));
    });

    test('LocalStorageService defaults to standard skin unlocked and equipped', () {
      expect(storage.unlockedSkins, equals(['standard']));
      expect(storage.equippedSkin, equals('standard'));
    });

    test('Unlocking skin validates balance, deducts career tips, and persists', () async {
      // Starting balance is $0 -> cannot afford $150 skin
      final failResult = await storage.unlockSkin('night_shift_neon', 150);
      expect(failResult, isFalse);
      expect(storage.unlockedSkins, equals(['standard']));

      // Add $200 career tips via completed run
      await storage.recordRun(distance: 500, tips: 200);
      expect(storage.careerTips, equals(200));

      // Purchase Night Shift Neon ($150)
      final successResult = await storage.unlockSkin('night_shift_neon', 150);
      expect(successResult, isTrue);
      expect(storage.careerTips, equals(50)); // $200 - $150
      expect(storage.unlockedSkins, contains('night_shift_neon'));

      // Equip newly purchased skin
      final equipResult = await storage.equipSkin('night_shift_neon');
      expect(equipResult, isTrue);
      expect(storage.equippedSkin, equals('night_shift_neon'));

      // Cannot equip locked skin (Golden Courier)
      final lockedEquipResult = await storage.equipSkin('golden_courier');
      expect(lockedEquipResult, isFalse);
      expect(storage.equippedSkin, equals('night_shift_neon'));
    });

    test('CourierPlayer binds active skin and updates color palettes', () {
      final player = CourierPlayer();
      expect(player.skin.id, equals('standard'));

      player.setSkin(CourierSkin.nightShiftNeon);
      expect(player.skin.id, equals('night_shift_neon'));
      expect(player.skin.primaryColor, equals(const Color(0xFF00E5FF)));
      expect(player.skin.glowColor, equals(const Color(0xFF00E5FF)));
    });

    testWidgets('LockerModal displays skins, balance, equipped status, and handles equip/unlock actions', (tester) async {
      String? equippedSelection;
      String? unlockedSelection;
      int? unlockedPrice;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LockerModal(
              careerTips: 200,
              unlockedSkins: const ['standard', 'night_shift_neon'],
              equippedSkin: 'standard',
              onEquipSkin: (id) => equippedSelection = id,
              onUnlockSkin: (id, price) async {
                unlockedSelection = id;
                unlockedPrice = price;
              },
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      // Verify header balance
      expect(find.text('COURIER LOCKER'), findsOneWidget);
      expect(find.text(r'$200 TIPS'), findsOneWidget);

      // Standard skin is equipped
      expect(find.byKey(const Key('equipped_badge_standard')), findsOneWidget);

      // Night Shift Neon is unlocked -> shows EQUIP button
      expect(find.byKey(const Key('equip_button_night_shift_neon')), findsOneWidget);
      await tester.tap(find.byKey(const Key('equip_button_night_shift_neon')));
      expect(equippedSelection, equals('night_shift_neon'));

      // High Tops ($300) is locked and unaffordable with $200 -> disabled BUY button
      expect(find.byKey(const Key('unlock_button_high_tops')), findsOneWidget);

      // Re-pump with sufficient funds ($350)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LockerModal(
              careerTips: 350,
              unlockedSkins: const ['standard'],
              equippedSkin: 'standard',
              onEquipSkin: (_) {},
              onUnlockSkin: (id, price) async {
                unlockedSelection = id;
                unlockedPrice = price;
              },
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      // Buy High Tops
      await tester.tap(find.byKey(const Key('unlock_button_high_tops')));
      expect(unlockedSelection, equals('high_tops'));
      expect(unlockedPrice, equals(300));

      // Close button
      await tester.tap(find.byKey(const Key('locker_close_button')));
      expect(closed, isTrue);
    });

    testWidgets('TitleScreen includes working LOCKER button opening gear locker modal', (tester) async {
      bool lockerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleScreen(
              highDistance: 1000,
              careerTips: 450,
              onStartGame: () {},
              onOpenLocker: () => lockerOpened = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('open_locker_button')), findsOneWidget);
      expect(find.text('LOCKER'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_locker_button')));
      expect(lockerOpened, isTrue);
    });
  });
}
