import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/achievement_manager.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/courier_skin.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/game/models/shift_contract.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalStorageService> _storage([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final storage = LocalStorageService();
  await storage.init();
  return storage;
}

void main() {
  group('Amounts are written the way people read them', () {
    test('thousands are grouped', () {
      expect(dollars(0), equals(r'$0'));
      expect(dollars(950), equals(r'$950'));
      expect(dollars(1000), equals(r'$1,000'));
      expect(dollars(15000), equals(r'$15,000'));
      expect(dollars(1234567), equals(r'$1,234,567'));
      expect(dollars(-2500), equals(r'-$2,500'));
    });
  });

  group('Outfits are goals, not pocket change', () {
    // Measured on autoplayed shifts (see CourierSkin): $5,000-$6,000 of tips
    // per 1,000 m; a button-masher's median shift pays about $400.
    const typicalPoorShift = 400;

    test('no outfit is covered by one poor shift', () {
      for (final skin in CourierSkin.catalog.where((s) => s.price > 0)) {
        expect(skin.price, greaterThan(typicalPoorShift * 2), reason: skin.name);
      }
    });

    test('each outfit is a bigger goal than the one before', () {
      final prices = [for (final s in CourierSkin.catalog) s.price];
      for (var i = 1; i < prices.length; i++) {
        expect(prices[i], greaterThan(prices[i - 1]));
      }
      expect(prices.first, equals(0), reason: 'the standard uniform is free');
    });
  });

  group('Lifetime tips are every tip ever banked', () {
    test('banking a shift adds to both the balance and the lifetime total', () async {
      final storage = await _storage();
      await storage.recordRun(distance: 300, tips: 1200);
      await storage.recordRun(distance: 250, tips: 900);
      expect(storage.careerTips, equals(2100));
      expect(storage.lifetimeTips, equals(2100));
    });

    test('spending lowers the balance but not the lifetime total', () async {
      final storage = await _storage();
      await storage.recordRun(distance: 800, tips: 5000);
      final bought = await storage.unlockSkin(
        CourierSkin.nightShiftNeon.id,
        CourierSkin.nightShiftNeon.price,
      );
      expect(bought, isTrue);
      expect(storage.careerTips, equals(5000 - CourierSkin.nightShiftNeon.price));
      expect(storage.lifetimeTips, equals(5000));

      await storage.recordRun(distance: 100, tips: 250);
      expect(storage.lifetimeTips, equals(5250));
    });

    test('a career saved before the total was tracked counts what it holds', () async {
      final storage = await _storage({'courier_career_tips': 3400});
      expect(storage.lifetimeTips, equals(3400));
      await storage.recordRun(distance: 100, tips: 100);
      expect(storage.lifetimeTips, equals(3500));
    });
  });

  group('Big Tipper is a career trophy', () {
    Future<bool> earned(int lifetimeTips) async {
      final manager = AchievementManager();
      await manager.evaluateProgress(
        distanceMeters: 0,
        stuntCombo: 0,
        lifetimeContracts: 0,
        lifetimeCareerTips: lifetimeTips,
      );
      return manager.isUnlocked('big_tipper');
    }

    test('one shift does not earn it', () async {
      // It used to take $150, which any first shift clears.
      expect(await earned(150), isFalse);
      expect(await earned(5000), isFalse);
    });

    test('a career of tips does', () async {
      expect(await earned(AchievementManager.bigTipperLifetimeTips - 1), isFalse);
      expect(await earned(AchievementManager.bigTipperLifetimeTips), isTrue);
    });

    test('it asks for more than the whole Locker costs', () {
      final locker = CourierSkin.catalog.fold<int>(0, (sum, s) => sum + s.price);
      expect(AchievementManager.bigTipperLifetimeTips, greaterThanOrEqualTo(locker));
    });
  });

  // A courier 500 m in has about $2,000 of tips and one who reaches a daily
  // goal has $5,000 or more. The milestone used to pay $50 and the daily
  // goal $100 to $200.
  group('Bonuses are worth the banner that announces them', () {
    test('a flawless 500 m milestone pays a noticeable slice of the shift so far', () {
      expect(GameState.milestoneBonusTips, inInclusiveRange(150, 500));
      final state = GameState()..startRun();
      state.updateDistance(500.0);
      expect(state.tips, equals(GameState.milestoneBonusTips));
    });

    test('a milestone that restores a package pays nothing extra', () {
      final state = GameState()..startRun();
      state.applyHazardDamage();
      state.updateDistance(500.0);
      expect(state.packages, equals(GameState.defaultMaxPackages));
      expect(state.tips, equals(0));
    });

    test('the daily goal pays a dollar a metre, every day of the year', () {
      final bonuses = <int>{};
      for (var day = 0; day < 366; day++) {
        final shift = DailyShift.forDate(DateTime(2026, 1, 1).add(Duration(days: day)));
        expect(shift.completionBonusTips, equals(shift.targetDistanceMeters),
            reason: shift.dateString);
        expect(shift.completionBonusTips, inInclusiveRange(1000, 1750));
        bonuses.add(shift.completionBonusTips);
      }
      // All four goal lengths turn up, and the longer ones pay more.
      expect(bonuses, equals({1000, 1250, 1500, 1750}));
    });

    test('no single bonus buys an outfit on its own', () {
      final cheapestOutfit = CourierSkin.catalog
          .where((s) => s.price > 0)
          .map((s) => s.price)
          .reduce((a, b) => a < b ? a : b);
      expect(GameState.milestoneBonusTips, lessThan(cheapestOutfit));
      expect(DailyShift.bonusForTarget(1750), lessThan(cheapestOutfit));
      for (final contract in ContractCatalog.generateShiftContracts()) {
        expect(contract.rewardTips, lessThan(cheapestOutfit), reason: contract.title);
      }
    });
  });
}
