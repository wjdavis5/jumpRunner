import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/daily_shift_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyShift Model & Deterministic Seeding (Issue #36)', () {
    test('DailyShift.forDate returns consistent parameters for same calendar date', () {
      final date1 = DateTime.utc(2026, 10, 3, 9, 30);
      final date2 = DateTime.utc(2026, 10, 3, 23, 59);

      final shift1 = DailyShift.forDate(date1);
      final shift2 = DailyShift.forDate(date2);

      expect(shift1.dateString, equals('2026-10-03'));
      expect(shift2.dateString, equals('2026-10-03'));
      expect(shift1.modifier, equals(shift2.modifier));
      expect(shift1.targetDistanceMeters, equals(shift2.targetDistanceMeters));
      expect(shift1.completionBonusTips, equals(shift2.completionBonusTips));
    });

    test('All 4 DailyModifiers have valid titles, descriptions, icons, and colors', () {
      expect(DailyModifier.values.length, equals(4));

      for (final mod in DailyModifier.values) {
        expect(mod.title.isNotEmpty, isTrue);
        expect(mod.description.isNotEmpty, isTrue);
        expect(mod.icon, isNotNull);
        expect(mod.color, isNotNull);
      }
    });
  });

  group('LocalStorageService Daily Shift Persistence', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
    });

    test('records daily shift completion, increments stars, and prevents duplicate payout', () async {
      expect(storage.isDailyShiftCompleted('2026-10-03'), isFalse);
      expect(storage.dailyStars, equals(0));
      expect(storage.careerTips, equals(0));

      final success1 = await storage.completeDailyShift(
        dateString: '2026-10-03',
        bonusTips: 150,
      );

      expect(success1, isTrue);
      expect(storage.isDailyShiftCompleted('2026-10-03'), isTrue);
      expect(storage.dailyStars, equals(1));
      expect(storage.careerTips, equals(150));
      expect(storage.lastCompletedDaily, equals('2026-10-03'));

      // Attempt duplicate completion for same date
      final success2 = await storage.completeDailyShift(
        dateString: '2026-10-03',
        bonusTips: 150,
      );

      expect(success2, isFalse);
      expect(storage.dailyStars, equals(1));
      expect(storage.careerTips, equals(150));
    });
  });

  group('GameState Daily Shift Modifiers & Goal Evaluation', () {
    test('fragileFreight limits max packages to 1 and triples tips', () {
      const shift = DailyShift(
        dateString: '2026-10-03',
        modifier: DailyModifier.fragileFreight,
        targetDistanceMeters: 1000,
        completionBonusTips: 150,
      );

      final state = GameState();
      state.startRun(dailyShift: shift);

      expect(state.isDailyShiftActive, isTrue);
      expect(state.maxPackages, equals(1));
      expect(state.packages, equals(1));

      // Regular tip $1 is tripled to $3
      state.addTip(1);
      expect(state.tips, equals(3));
    });

    test('rainyRush doubles tip collections', () {
      const shift = DailyShift(
        dateString: '2026-10-03',
        modifier: DailyModifier.rainyRush,
        targetDistanceMeters: 1250,
        completionBonusTips: 100,
      );

      final state = GameState();
      state.startRun(dailyShift: shift);

      state.addTip(5);
      expect(state.tips, equals(10));
    });

    test('nightDash extends energy drink buff by 1.5x', () {
      const shift = DailyShift(
        dateString: '2026-10-03',
        modifier: DailyModifier.nightDash,
        targetDistanceMeters: 1500,
        completionBonusTips: 200,
      );

      final state = GameState();
      state.startRun(dailyShift: shift);

      state.activateEnergyDrink(5.0);
      expect(state.energyDrinkTimer, equals(7.5));
    });

    test('skateCommute doubles near-miss stunt tip rewards', () {
      const shift = DailyShift(
        dateString: '2026-10-03',
        modifier: DailyModifier.skateCommute,
        targetDistanceMeters: 1000,
        completionBonusTips: 100,
      );

      final state = GameState();
      state.startRun(dailyShift: shift);

      // Base stunt is $5 * 1.2 = $6; doubled with skateCommute is $12
      state.recordStunt();
      expect(state.tips, equals(12));
    });

    test('reaching targetDistanceMeters completes daily shift and awards bonus tips', () {
      const shift = DailyShift(
        dateString: '2026-10-03',
        modifier: DailyModifier.rainyRush,
        targetDistanceMeters: 1000,
        completionBonusTips: 150,
      );

      final state = GameState();
      state.startRun(dailyShift: shift);

      expect(state.hasCompletedDailyShiftInRun, isFalse);
      expect(state.tips, equals(0));

      state.updateDistance(500.0);
      expect(state.hasCompletedDailyShiftInRun, isFalse);

      state.updateDistance(1005.0);
      expect(state.hasCompletedDailyShiftInRun, isTrue);
      // $500 from 2 shift milestones (500m, 1000m) + $150 daily shift reward
      expect(state.tips, equals(2 * GameState.milestoneBonusTips + 150));
      expect(state.tips, equals(650));
    });
  });

  group('DailyShiftModal & TitleScreen UI Integration', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
    });

    testWidgets('DailyShiftModal displays modifier breakdown and handles start action', (tester) async {
      DailyShift? startedShift;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyShiftModal(
              storageService: storage,
              customDate: DateTime.utc(2026, 10, 3),
              onStartDailyShift: (shift) => startedShift = shift,
            ),
          ),
        ),
      );

      expect(find.text('DAILY GIG SHIFT'), findsOneWidget);
      expect(find.text('2026-10-03'), findsOneWidget);
      expect(find.byKey(const Key('start_daily_shift_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('start_daily_shift_button')));
      await tester.pump();

      expect(startedShift, isNotNull);
      expect(startedShift!.dateString, equals('2026-10-03'));
    });

    testWidgets('DailyShiftModal shows completed badge when already completed today', (tester) async {
      await storage.completeDailyShift(dateString: '2026-10-03', bonusTips: 100);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyShiftModal(
              storageService: storage,
              customDate: DateTime.utc(2026, 10, 3),
              onStartDailyShift: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('SHIFT COMPLETED TODAY!'), findsOneWidget);
      expect(find.byKey(const Key('start_daily_shift_button')), findsNothing);
    });

    testWidgets('TitleScreen displays open_daily_shift_button with career star count', (tester) async {
      bool opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleScreen(
              highDistance: 450,
              careerTips: 250,
              dailyStars: 3,
              onStartGame: () {},
              onOpenDailyShift: () => opened = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('open_daily_shift_button')), findsOneWidget);
      expect(find.text('DAILY (3 ⭐)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_daily_shift_button')));
      await tester.pump();

      expect(opened, isTrue);
    });
  });
}
