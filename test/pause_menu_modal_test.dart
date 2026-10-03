import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';

void main() {
  group('PauseMenuModal Tests', () {
    testWidgets('PauseMenuModal renders shift stats and handles actions', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(450.0);
      state.addTip(35);
      state.applyHazardDamage(); // packages 3 -> 2
      state.pauseRun();

      bool resumed = false;
      bool quit = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenuModal(
              gameState: state,
              onResume: () => resumed = true,
              onQuit: () => quit = true,
            ),
          ),
        ),
      );

      // Verify titles & stats
      expect(find.text('SHIFT ON HOLD'), findsOneWidget);
      expect(find.text('Break Time, Courier'), findsOneWidget);
      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text(r'$35'), findsOneWidget);

      // Tap Resume
      await tester.tap(find.byKey(const Key('resume_shift_button')));
      expect(resumed, isTrue);

      // Tap Quit to Depot
      await tester.tap(find.byKey(const Key('quit_to_depot_button')));
      expect(quit, isTrue);
    });
  });
}
