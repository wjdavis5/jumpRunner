import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/models/achievement.dart';
import 'package:jump_runner/game/models/courier_skin.dart';
import 'package:jump_runner/game/models/run_booster.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/achievements_modal.dart';
import 'package:jump_runner/ui/bodega_modal.dart';
import 'package:jump_runner/ui/locker_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget card, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
}

/// Lets the Locker's outfit pictures decode, which needs real time.
Future<void> _letPicturesLoad(WidgetTester tester) async {
  final last = find.byKey(Key('outfit_preview_${CourierSkin.catalog.first.id}'));
  for (var i = 0; i < 40 && last.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pump();
}

ScrollPosition _positionIn(WidgetTester tester, Key scrollbar) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byKey(scrollbar), matching: find.byType(Scrollable)),
    )
    .position;

Scrollbar _barIn(WidgetTester tester, Key scrollbar) => tester.widget<Scrollbar>(
      find.descendant(of: find.byKey(scrollbar), matching: find.byType(Scrollbar)),
    );

void main() {
  const lockerBar = Key('locker_scrollbar');
  const bodegaBar = Key('bodega_scrollbar');

  Widget locker() => LockerModal(
        careerTips: 2000,
        unlockedSkins: const ['standard'],
        equippedSkin: 'standard',
        onEquipSkin: (_) {},
        onUnlockSkin: (id, _) async {},
        onClose: () {},
      );

  group('The Locker shows when there are more outfits below', () {
    testWidgets('on a small phone the list scrolls and says so', (tester) async {
      await _pump(tester, locker(), const Size(667, 375));
      await _letPicturesLoad(tester);
      expect(tester.takeException(), isNull);

      expect(_positionIn(tester, lockerBar).maxScrollExtent, greaterThan(0.0));
      // The thumb is drawn without the list being touched.
      expect(_barIn(tester, lockerBar).thumbVisibility, isTrue);
    });

    testWidgets('the last outfit can be scrolled to and bought', (tester) async {
      String? bought;
      await _pump(
        tester,
        LockerModal(
          careerTips: CourierSkin.goldenCourier.price,
          unlockedSkins: const ['standard'],
          equippedSkin: 'standard',
          onEquipSkin: (_) {},
          onUnlockSkin: (id, _) async => bought = id,
          onClose: () {},
        ),
        const Size(667, 375),
      );
      await _letPicturesLoad(tester);

      // The list builds rows as they come into view, so the last one does
      // not exist until the list has been scrolled to it.
      final buyGold = find.byKey(const Key('unlock_button_golden_courier'));
      await tester.scrollUntilVisible(
        buyGold,
        60.0,
        scrollable: find.descendant(
          of: find.byKey(lockerBar),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(buyGold);
      expect(button.bottom, lessThanOrEqualTo(375.0));
      await tester.tap(buyGold);
      await tester.pump();
      expect(bought, equals('golden_courier'));
    });
  });

  group('The Bodega shows when there are more boosters below', () {
    testWidgets('its list has the same always-on scrollbar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      await _pump(
        tester,
        BodegaModal(
          storageService: storage,
          equippedBoosters: const {},
          onEquippedBoostersChanged: (_) {},
          onClose: () {},
        ),
        const Size(667, 375),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_barIn(tester, bodegaBar).thumbVisibility, isTrue);
      // Whatever the list needs, the scrollbar is wired to that same list.
      expect(_positionIn(tester, bodegaBar).maxScrollExtent, greaterThanOrEqualTo(0.0));
    });
  });

  group('The Bodega says what a button costs', () {
    testWidgets('buy buttons read BUY and the price, as in the Locker', (tester) async {
      SharedPreferences.setMockInitialValues({'courier_career_tips': 2000});
      final storage = LocalStorageService();
      await storage.init();
      await _pump(
        tester,
        BodegaModal(
          storageService: storage,
          equippedBoosters: const {},
          onEquippedBoostersChanged: (_) {},
          onClose: () {},
        ),
        const Size(960, 540),
      );
      await tester.pump();

      final first = RunBooster.values.first;
      final button = find.byKey(Key('buy_booster_${first.id}'));
      expect(
        find.descendant(of: button, matching: find.text('BUY \$${first.cost}')),
        findsOneWidget,
      );
      // A bare "+$150" read like a reward.
      expect(find.textContaining('+\$'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('The Trophies card shows every trophy', () {
    const trophiesBar = Key('trophies_scrollbar');
    Widget trophies() => AchievementsModal(
          unlockedAchievementIds: const [],
          onClose: () {},
        );

    testWidgets('ten are more than the base screen holds: the grid scrolls and says so',
        (tester) async {
      await _pump(tester, trophies(), const Size(960, 540));
      expect(tester.takeException(), isNull);
      expect(_positionIn(tester, trophiesBar).maxScrollExtent, greaterThan(0.0));
      expect(_barIn(tester, trophiesBar).thumbVisibility, isTrue);

      // The first rows are whole and on screen without scrolling.
      final grid = tester.getRect(find.byKey(trophiesBar));
      for (final trophy in Achievement.catalog.take(4)) {
        final title = tester.getRect(find.text(trophy.title));
        expect(title.top, greaterThanOrEqualTo(grid.top), reason: trophy.title);
        expect(title.bottom, lessThanOrEqualTo(grid.bottom), reason: trophy.title);
      }
    });

    testWidgets('every trophy can be scrolled into view, whole', (tester) async {
      await _pump(tester, trophies(), const Size(960, 540));
      final grid = tester.getRect(find.byKey(trophiesBar));
      final scrollable = find.descendant(
        of: find.byKey(trophiesBar),
        matching: find.byType(Scrollable),
      );
      for (final trophy in Achievement.catalog) {
        final tile = find.byKey(Key('trophy_tile_${trophy.id}'), skipOffstage: false);
        await tester.scrollUntilVisible(tile, 40.0, scrollable: scrollable.first);
        await tester.ensureVisible(tile);
        await tester.pump();
        final rect = tester.getRect(tile);
        expect(rect.top, greaterThanOrEqualTo(grid.top - 0.5), reason: trophy.title);
        expect(rect.bottom, lessThanOrEqualTo(grid.bottom + 0.5), reason: trophy.title);
        expect(find.descendant(of: tile, matching: find.text(trophy.title)), findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text(trophy.description)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a small phone the grid scrolls and says so', (tester) async {
      await _pump(tester, trophies(), const Size(667, 375));
      expect(tester.takeException(), isNull);
      expect(_positionIn(tester, trophiesBar).maxScrollExtent, greaterThan(0.0));
      expect(_barIn(tester, trophiesBar).thumbVisibility, isTrue);
    });

    testWidgets('a locked trophy can still be read', (tester) async {
      await _pump(tester, trophies(), const Size(960, 540));
      // What a locked trophy asks for is the player's to-do list.
      final description = tester.widget<Text>(
        find.text(Achievement.catalog.first.description),
      );
      expect(description.style!.color!.a, greaterThanOrEqualTo(0.5));
    });
  });
}
