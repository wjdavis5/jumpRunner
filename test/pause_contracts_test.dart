import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/shift_contract.dart';
import 'package:jump_runner/ui/money.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';

Future<void> _pumpPauseMenu(
  WidgetTester tester,
  GameState state, {
  Size size = const Size(960, 540),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PauseMenuModal(
          gameState: state,
          onResume: () {},
          onQuit: () {},
        ),
      ),
    ),
  );
}

String _status(WidgetTester tester, String contractId) {
  final finder = find.byKey(Key('pause_contract_status_$contractId'));
  return tester.widget<Text>(finder).data!;
}

void main() {
  group('The pause menu lists the shift contracts', () {
    testWidgets('every contract shows its goal and reward', (tester) async {
      final state = GameState()..startRun();
      state.pauseRun();
      await _pumpPauseMenu(tester, state);

      for (final contract in ContractCatalog.generateShiftContracts()) {
        final row = find.byKey(Key('pause_contract_${contract.id}'));
        expect(row, findsOneWidget, reason: contract.id);
        expect(
          find.descendant(of: row, matching: find.text(contract.title)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(contract.description)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('+${dollars(contract.rewardTips)}'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('0 of 5 done'), findsOneWidget);
    });

    testWidgets('progress follows what happened in the run', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(220.0);
      state.recordStunt(clearance: 10.0);
      state.pauseRun();
      await _pumpPauseMenu(tester, state);

      expect(_status(tester, 'fragile_300'), equals('220/300'));
      expect(_status(tester, 'night_shift'), equals('220/2500'));
      expect(_status(tester, 'stunts_20'), equals('1/20'));
      expect(_status(tester, 'boosts_2'), equals('0/2'));
      // The stunt itself paid a tip, which counts towards the tips contract.
      expect(_status(tester, 'tips_500'), equals('${state.tips}/500'));
      expect(state.tips, greaterThan(0));
    });

    testWidgets('a finished contract reads as done', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(300.0);
      state.pauseRun();
      await _pumpPauseMenu(tester, state);

      expect(_status(tester, 'fragile_300'), equals('DONE'));
      expect(find.text('1 of 5 done'), findsOneWidget);
    });

    testWidgets('a damaged package fails the fragile contract', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(200.0);
      state.applyHazardDamage();
      state.updateDistance(260.0);
      state.pauseRun();
      await _pumpPauseMenu(tester, state);

      expect(_status(tester, 'fragile_300'), equals('FAILED'));
      // The other distance contract is unaffected.
      expect(_status(tester, 'night_shift'), equals('260/2500'));
    });
  });

  group('The contracts do not cost the pause menu its size', () {
    for (final size in const [Size(667, 375), Size(844, 390), Size(960, 540)]) {
      testWidgets('landscape ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        final state = GameState()..startRun();
        state.pauseRun();
        await _pumpPauseMenu(tester, state, size: size);
        expect(tester.takeException(), isNull);

        final panel = tester.getRect(find.byKey(const Key('pause_contracts_panel')));
        final resume = tester.getRect(find.byKey(const Key('resume_shift_button')));
        // Side by side: the panel starts to the right of the buttons.
        expect(panel.left, greaterThan(resume.right));
        expect(panel.right, lessThanOrEqualTo(size.width));
        expect(panel.bottom, lessThanOrEqualTo(size.height));

        // The card is drawn at no less than 85% of its design size, so the
        // resume button stays a comfortable touch target.
        expect(resume.height, greaterThanOrEqualTo(46 * 0.85));
      });
    }

    testWidgets('a tall window stacks the contracts under the buttons',
        (tester) async {
      final state = GameState()..startRun();
      state.pauseRun();
      await _pumpPauseMenu(tester, state, size: const Size(480, 900));
      expect(tester.takeException(), isNull);

      final panel = tester.getRect(find.byKey(const Key('pause_contracts_panel')));
      final quit = tester.getRect(find.byKey(const Key('quit_to_depot_button')));
      expect(panel.top, greaterThan(quit.bottom));
      expect(panel.bottom, lessThanOrEqualTo(900));
    });
  });
}
