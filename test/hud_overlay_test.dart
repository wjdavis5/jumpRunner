import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/hud_overlay.dart';
import 'package:jump_runner/ui/title_screen.dart';

void main() {
  group('UI Widgets (HUD, GameOverModal, TitleScreen) (U5)', () {
    testWidgets('HUDOverlay renders packages, distance, and tips', (tester) async {
      final state = GameState()..startRun();
      state.addTip(25);
      state.updateDistance(350.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );

      expect(find.text('PACKAGES: '), findsOneWidget);
      expect(find.text('350 m'), findsOneWidget);
      expect(find.text(r'$25'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2), findsNWidgets(3));
    });

    testWidgets('GameOverModal renders stats and triggers restart callback', (tester) async {
      bool restarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 820,
              tips: 45,
              isNewRecord: true,
              careerTips: 120,
              onRestart: () => restarted = true,
            ),
          ),
        ),
      );

      expect(find.text('PACKAGES DROPPED!'), findsOneWidget);
      expect(find.text('★ NEW DISTANCE RECORD! ★'), findsOneWidget);
      expect(find.text('820 m'), findsOneWidget);
      expect(find.text(r'$45'), findsOneWidget);
      expect(find.text(r'$120'), findsOneWidget);

      await tester.tap(find.text('START NEXT SHIFT'));
      expect(restarted, isTrue);
    });

    testWidgets('TitleScreen renders career stats and triggers start game callback', (tester) async {
      bool started = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleScreen(
              highDistance: 1250,
              careerTips: 430,
              onStartGame: () => started = true,
            ),
          ),
        ),
      );

      expect(find.text('COURIER DASH'), findsOneWidget);
      expect(find.text('1250 m'), findsOneWidget);
      expect(find.text(r'$430'), findsOneWidget);

      await tester.tap(find.text('START SHIFT'));
      expect(started, isTrue);
    });
  });
}
