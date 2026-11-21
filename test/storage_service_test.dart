import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QA blind storage (a QA build never writes the save)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('mutations are no-ops while blind', () async {
      final storage = LocalStorageService(qaBlind: true);
      await storage.init();

      final record = await storage.recordRun(distance: 6500, tips: 22000);
      expect(record, isFalse, reason: 'a blind build sets no records');
      expect(storage.highDistance, equals(0));
      expect(storage.careerTips, equals(0));

      await storage.setSoundMuted(true);
      expect(storage.isSoundMuted, isFalse);

      await storage.setReduceShake(true);
      expect(storage.isReduceShake, isFalse);

      await storage.unlockAchievement('shift_veteran');
      expect(storage.unlockedAchievements, isEmpty);

      await storage.recordDeliveries(9);
      expect(storage.lifetimeDeliveries, equals(0));
    });

    test('reads still work while blind', () async {
      SharedPreferences.setMockInitialValues({
        'courier_high_distance': 140,
        'courier_career_tips': 103,
      });
      final storage = LocalStorageService(qaBlind: true);
      await storage.init();

      expect(storage.highDistance, equals(140),
          reason: 'the game still boots with the real career');
      expect(storage.careerTips, equals(103));
    });
  });

  group('LocalStorageService & Offline Persistence (U5, AE3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with zero defaults and unmuted sound', () async {
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.highDistance, equals(0));
      expect(storage.careerTips, equals(0));
      expect(storage.isSoundMuted, isFalse);
    });

    test('Records run stats and updates career tips and high distance (AE3)', () async {
      final storage = LocalStorageService();
      await storage.init();

      // First run: 450m, $22 tips
      final isNewRecord1 = await storage.recordRun(distance: 450, tips: 22);
      expect(isNewRecord1, isTrue);
      expect(storage.highDistance, equals(450));
      expect(storage.careerTips, equals(22));

      // Second run: 300m, $15 tips (not high distance, but adds to career tips)
      final isNewRecord2 = await storage.recordRun(distance: 300, tips: 15);
      expect(isNewRecord2, isFalse);
      expect(storage.highDistance, equals(450));
      expect(storage.careerTips, equals(37));

      // Third run: 620m, $30 tips (new high distance)
      final isNewRecord3 = await storage.recordRun(distance: 620, tips: 30);
      expect(isNewRecord3, isTrue);
      expect(storage.highDistance, equals(620));
      expect(storage.careerTips, equals(67));
    });

    test('Data persists across service re-initialization (offline persistence, AE3)', () async {
      final storage1 = LocalStorageService();
      await storage1.init();
      await storage1.recordRun(distance: 780, tips: 55);
      await storage1.setSoundMuted(true);

      // Re-initialize new service instance against same storage
      final storage2 = LocalStorageService();
      await storage2.init();

      expect(storage2.highDistance, equals(780));
      expect(storage2.careerTips, equals(55));
      expect(storage2.isSoundMuted, isTrue);
    });
  });
}
