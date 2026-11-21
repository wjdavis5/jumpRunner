import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/game_over_modal.dart';

const Size _phone = Size(844, 390);

Future<void> _pumpResults(
  WidgetTester tester,
  GameState? gameState, {
  int stunts = 0,
  Size size = _phone,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GameOverModal(
          gameState: gameState,
          distance: 450,
          tips: 120,
          isNewRecord: false,
          careerTips: 400,
          completedContracts: gameState?.contractManager.completedCount ?? 0,
          contractBonusTips: 0,
          cradleRidesCompleted: stunts >= 41 ? 1 : 0,
          onRestart: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Results Screen Contract Summary', () {
    testWidgets('the results screen lists the shift contracts with progress',
        (tester) async {
      final state = GameState()..startRun();
      await _pumpResults(tester, state);

      expect(find.text('SHIFT CONTRACTS'), findsOneWidget);
      expect(find.byKey(const Key('results_contracts_summary')), findsOneWidget);
      expect(find.text('0 of 5 done'), findsOneWidget);

      // Every contract row carries its live progress as its status.
      final rows = find.byKey(const Key('results_contracts_panel'));
      expect(rows, findsOneWidget);
      final statuses = tester.widgetList<Text>(
        find.descendant(
          of: rows,
          matching: find.byWidgetPredicate(
            (w) => w.key != null &&
                w.key.toString().contains('results_contract_status_'),
          ),
        ),
      ).toList();
      expect(statuses, hasLength(5));
    });

    testWidgets('a completed contract reads DONE on the results screen',
        (tester) async {
      final state = GameState()..startRun();
      state.contractManager.contracts.first
        ..currentProgress = 20
        ..isCompleted = true;
      await _pumpResults(tester, state);

      expect(find.text('1 of 5 done'), findsOneWidget);
      final status = find
          .byKey(Key('results_contract_status_${state.contractManager.contracts.first.id}'));
      expect(tester.widget<Text>(status).data, equals('DONE'));
    });

    testWidgets('the results screen built from plain numbers has no panel',
        (tester) async {
      await _pumpResults(tester, null);

      expect(find.text('SHIFT CONTRACTS'), findsNothing);
    });

    testWidgets('the summary sits in the badge scroller with every badge',
        (tester) async {
      // A results screen for a strong run on the short phone: the contracts
      // panel and all 41 badges live in one scroll view.
      final state = GameState()..startRun();
      state.contractManager.contracts.first
        ..currentProgress = 300
        ..isCompleted = true;
      await _pumpResults(
        tester,
        state,
        stunts: 41,
      );

      final scroller = find.byKey(const Key('game_over_badges_scroll'));
      expect(scroller, findsOneWidget);
      expect(
        find.descendant(of: scroller, matching: find.text('SHIFT CONTRACTS')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: scroller,
          matching: find.byKey(const Key('game_over_cradle_badge')),
        ),
        findsOneWidget,
      );

      // The last badge stays reachable by scrolling, panel above or not.
      final lastBadge =
          find.byKey(const Key('game_over_cradle_badge'));
      await tester.ensureVisible(lastBadge);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
