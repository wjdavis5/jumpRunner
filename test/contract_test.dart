import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/contract_manager.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/shift_contract.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/hud_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShiftContract & ContractCatalog (Issue #24)', () {
    test('catalog provides balanced default contract objectives', () {
      final contracts = ContractCatalog.generateShiftContracts();
      expect(contracts.length, greaterThanOrEqualTo(5));

      final types = contracts.map((c) => c.type).toSet();
      expect(types, contains(ContractType.fragileFreight));
      expect(types, contains(ContractType.stuntSpecialist));
      expect(types, contains(ContractType.tipCollector));
      expect(types, contains(ContractType.nightOwl));
      expect(types, contains(ContractType.speedDemon));
    });

    test('contract computes progress ratio and resets cleanly', () {
      final contract = ShiftContract(
        id: 'test_contract',
        type: ContractType.stuntSpecialist,
        title: 'Test Objective',
        description: 'Perform 4 stunts',
        targetValue: 4,
        rewardTips: 20,
      );

      expect(contract.progressRatio, equals(0.0));
      contract.currentProgress = 2;
      expect(contract.progressRatio, equals(0.5));
      contract.currentProgress = 4;
      expect(contract.progressRatio, equals(1.0));

      contract.reset();
      expect(contract.currentProgress, equals(0));
      expect(contract.isCompleted, isFalse);
      expect(contract.isFailed, isFalse);
    });
  });

  group('ContractManager Evaluation Logic', () {
    late ContractManager manager;

    setUp(() {
      manager = ContractManager();
    });

    test('stunt specialist completes upon executing required stunts', () {
      ShiftContract? completedContract;
      manager.onContractCompleted = (c) => completedContract = c;

      // Daredevil Shift requires 3 stunts
      manager.onStuntPerformed();
      manager.onStuntPerformed();
      expect(manager.completedCount, equals(0));

      manager.onStuntPerformed();
      expect(manager.completedCount, equals(1));
      expect(completedContract?.id, equals('stunts_3'));
      expect(completedContract?.isCompleted, isTrue);
      expect(manager.totalBonusTips, equals(20));
    });

    test('fragile freight fails if courier sustains hazard damage before target distance', () {
      // 300m without damage -> still in progress
      manager.onDistanceProgress(300.0, damageCount: 0);
      final fragileContract = manager.contracts.firstWhere((c) => c.type == ContractType.fragileFreight);
      expect(fragileContract.isCompleted, isFalse);
      expect(fragileContract.isFailed, isFalse);

      // Hazard damage taken
      manager.onDamageTaken();
      expect(fragileContract.isFailed, isTrue);

      // Reaching target distance after failure does NOT complete contract
      manager.onDistanceProgress(600.0, damageCount: 1);
      expect(fragileContract.isCompleted, isFalse);
    });

    test('fragile freight completes if courier reaches 500m with zero damage', () {
      manager.onDistanceProgress(550.0, damageCount: 0);
      final fragileContract = manager.contracts.firstWhere((c) => c.type == ContractType.fragileFreight);
      expect(fragileContract.isCompleted, isTrue);
      expect(fragileContract.isFailed, isFalse);
      expect(manager.totalBonusTips, equals(25));
    });

    test('tip collector completes upon gathering 15 tips', () {
      manager.onTipCollected(5);
      manager.onTipCollected(10);
      final tipContract = manager.contracts.firstWhere((c) => c.type == ContractType.tipCollector);
      expect(tipContract.isCompleted, isTrue);
      expect(tipContract.rewardTips, equals(15));
    });

    test('speed demon completes upon activating 2 energy boosts', () {
      manager.onEnergyBoostActivated();
      manager.onEnergyBoostActivated();
      final boostContract = manager.contracts.firstWhere((c) => c.type == ContractType.speedDemon);
      expect(boostContract.isCompleted, isTrue);
    });

    test('night owl completes upon reaching 2500m midnight city distance', () {
      manager.onDistanceProgress(2600.0, damageCount: 0);
      final nightContract = manager.contracts.firstWhere((c) => c.type == ContractType.nightOwl);
      expect(nightContract.isCompleted, isTrue);
      expect(nightContract.rewardTips, equals(35));
    });
  });

  group('GameState Contract Integration', () {
    test('awards bonus tips and sets celebration banner when contract completes', () {
      final state = GameState();
      state.startRun();

      expect(state.tips, equals(0));
      expect(state.isContractCelebrationVisible, isFalse);

      // Trigger stunt specialist (3 stunts)
      state.recordStunt();
      state.recordStunt();
      state.recordStunt();

      // Stunts contract completed! Stunt rewards (6 + 8 + 10 = 24 tips)
      // 'stunts_3' completed, awarding 20 bonus tips!
      expect(state.contractManager.completedCount, equals(1));
      expect(state.contractManager.totalBonusTips, equals(20));
      expect(state.tips, equals(24));
      expect(state.isContractCelebrationVisible, isTrue);
      expect(state.activeContractCelebration?.id, equals('stunts_3'));

      // Celebration banner decays over time
      state.updateContractTimer(3.5);
      expect(state.isContractCelebrationVisible, isFalse);
      expect(state.activeContractCelebration, isNull);
    });
  });

  group('HUDOverlay Contract Banner Widget Tests', () {
    testWidgets('renders contract completed celebration banner when contract completes', (tester) async {
      final state = GameState();
      state.startRun();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: state,
              builder: (context, _) => HUDOverlay(
                gameState: state,
                isMuted: false,
                onToggleMute: () {},
                onPause: () {},
              ),
            ),
          ),
        ),
      );

      // Banner initially absent
      expect(find.byKey(const Key('contract_celebration_banner')), findsNothing);

      // Complete stunt contract
      state.recordStunt();
      state.recordStunt();
      state.recordStunt();
      await tester.pump();

      // Banner appears!
      expect(find.byKey(const Key('contract_celebration_banner')), findsOneWidget);
      expect(find.textContaining('DAREDEVIL SHIFT'), findsOneWidget);
      expect(find.textContaining('20 BONUS CAREER TIPS'), findsOneWidget);

      // Timer expires -> banner fades
      state.updateContractTimer(3.5);
      await tester.pump();
      expect(find.byKey(const Key('contract_celebration_banner')), findsNothing);
    });
  });

  group('GameOverModal Contract Summary Widget Tests', () {
    testWidgets('renders fulfilled contracts summary badge when completedContracts > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 80,
              isNewRecord: false,
              careerTips: 250,
              completedContracts: 2,
              contractBonusTips: 45,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_contracts_badge')), findsOneWidget);
      expect(find.textContaining('2 CONTRACTS (+\$45 BONUS)'), findsOneWidget);
    });
  });

  group('LocalStorageService Contract Persistence Tests', () {
    test('records and increments completed contract count', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.completedContracts, equals(0));

      await storage.recordCompletedContracts(3);
      expect(storage.completedContracts, equals(3));

      await storage.recordCompletedContracts(2);
      expect(storage.completedContracts, equals(5));
    });
  });
}
