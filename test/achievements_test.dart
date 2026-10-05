import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/achievement_manager.dart';
import 'package:jump_runner/game/models/achievement.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/achievements_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Career Shift Achievements & Trophy System (Issue #28)', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
    });

    test('Achievement catalog contains all 6 required career milestones', () {
      expect(Achievement.catalog.length, equals(10));

      final ids = Achievement.catalog.map((a) => a.id).toSet();
      expect(ids, contains('first_delivery'));
      expect(ids, contains('shift_veteran'));
      expect(ids, contains('master_acrobat'));
      expect(ids, contains('contract_specialist'));
      expect(ids, contains('big_tipper'));
      expect(ids, contains('rain_rider'));

      expect(Achievement.findById('first_delivery'), isNotNull);
      expect(Achievement.findById('unknown_trophy'), isNull);
    });

    test('LocalStorageService unlocks and persists achievements without duplicates', () async {
      expect(storage.unlockedAchievements, isEmpty);

      final success1 = await storage.unlockAchievement('first_delivery');
      expect(success1, isTrue);
      expect(storage.unlockedAchievements, equals(['first_delivery']));

      // Attempt duplicate unlock
      final success2 = await storage.unlockAchievement('first_delivery');
      expect(success2, isFalse);
      expect(storage.unlockedAchievements, equals(['first_delivery']));

      final success3 = await storage.unlockAchievement('master_acrobat');
      expect(success3, isTrue);
      expect(storage.unlockedAchievements, containsAll(['first_delivery', 'master_acrobat']));
    });

    test('AchievementManager evaluates distance, stunt, contract, and tips milestones', () async {
      final manager = AchievementManager(storageService: storage);
      final unlockedNotifications = <String>[];
      manager.onAchievementUnlocked = (ach) {
        unlockedNotifications.add(ach.id);
      };

      expect(manager.unlockedCount, equals(0));
      expect(manager.totalCount, equals(10));

      // Initial early shift: no unlocks
      final round1 = await manager.evaluateProgress(
        distanceMeters: 200.0,
        stuntCombo: 2,
        lifetimeContracts: 3,
        lifetimeCareerTips: 50,
      );
      expect(round1, isEmpty);
      expect(manager.unlockedCount, equals(0));

      // Cross 500m distance and 4 stunt combo
      final round2 = await manager.evaluateProgress(
        distanceMeters: 550.0,
        stuntCombo: 4,
        lifetimeContracts: 3,
        lifetimeCareerTips: 50,
      );
      expect(round2.map((a) => a.id), containsAll(['first_delivery', 'master_acrobat']));
      expect(manager.isUnlocked('first_delivery'), isTrue);
      expect(manager.isUnlocked('master_acrobat'), isTrue);
      expect(unlockedNotifications, containsAll(['first_delivery', 'master_acrobat']));

      // Cross Midnight City 2500m, 10 contracts, the Big Tipper total, and
      // 5 wet hazards
      final round3 = await manager.evaluateProgress(
        distanceMeters: 2600.0,
        stuntCombo: 1,
        lifetimeContracts: 12,
        lifetimeCareerTips: AchievementManager.bigTipperLifetimeTips + 30,
        wetHazardsCleared: 6,
      );
      expect(
        round3.map((a) => a.id),
        containsAll(['shift_veteran', 'contract_specialist', 'big_tipper', 'rain_rider']),
      );
      // The original six, plus Long Haul: 2,600 m is past its 1,000 m too.
      expect(round3.map((a) => a.id), contains('long_haul'));
      expect(manager.unlockedCount, equals(7));
    });

    testWidgets('AchievementsModal renders trophy shelf, progress bar, and handles close', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsModal(
              unlockedAchievementIds: const ['first_delivery', 'big_tipper'],
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      // Verify header and progress
      expect(find.text('CAREER TROPHIES'), findsOneWidget);
      expect(find.text('2 / 10 UNLOCKED'), findsOneWidget);

      // Verify specific achievements
      expect(find.text('First Delivery'), findsOneWidget);
      expect(find.text('Big Tipper'), findsOneWidget);
      expect(find.text('Shift Veteran'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('TitleScreen renders Trophies button and triggers callback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool openedTrophies = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleScreen(
              highDistance: 1200,
              careerTips: 85,
              unlockedAchievementsCount: 3,
              totalAchievementsCount: 6,
              onOpenAchievements: () => openedTrophies = true,
              onStartGame: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('open_trophies_button')), findsOneWidget);
      expect(find.text('TROPHIES (3/6)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_trophies_button')));
      await tester.pump();
      expect(openedTrophies, isTrue);
    });
  });
}
