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
      expect(find.byKey(const Key('energy_boost_badge')), findsNothing);
    });

    testWidgets('HUDOverlay displays energy boost badge when boost is active (R6)', (tester) async {
      final state = GameState()..startRun();
      state.activateEnergyDrink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );

      expect(find.byKey(const Key('energy_boost_badge')), findsOneWidget);
      expect(find.text('BOOST 5.0s (2X TIPS & MAGNET)'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('HUDOverlay renders milestone celebration banner on shift completion (R7)', (tester) async {
      final state = GameState()..startRun();
      state.applyHazardDamage(); // packages 3 -> 2
      expect(find.byKey(const Key('milestone_celebration_banner')), findsNothing);

      // Trigger 500m milestone with package restoration
      state.updateDistance(500.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );

      expect(find.byKey(const Key('milestone_celebration_banner')), findsOneWidget);
      expect(find.text('SHIFT #1 COMPLETED! (500m)'), findsOneWidget);
      expect(find.text('PACKAGE RESTORED! (+1 Delivery Box)'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('HUDOverlay renders flawless tip bonus milestone banner (R7)', (tester) async {
      final state = GameState()..startRun(); // full 3 packages

      // Trigger 500m milestone with flawless tip bonus
      state.updateDistance(500.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );

      expect(find.byKey(const Key('milestone_celebration_banner')), findsOneWidget);
      expect(find.text('SHIFT #1 COMPLETED! (500m)'), findsOneWidget);
      expect(find.text(r'FLAWLESS SHIFT BONUS: +$250 TIPS!'), findsOneWidget);
    });

    testWidgets('HUDOverlay renders pause button and triggers onPause callback', (tester) async {
      final state = GameState()..startRun();
      bool pauseTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(
              gameState: state,
              onPause: () => pauseTriggered = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('pause_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pause_button')));
      expect(pauseTriggered, isTrue);
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
      expect(find.textContaining('NEW DISTANCE RECORD!'), findsOneWidget);
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
      expect(find.text('1,250 m'), findsOneWidget);
      expect(find.text(r'$430'), findsOneWidget);

      await tester.tap(find.text('START SHIFT'));
      expect(started, isTrue);
    });

    testWidgets('celebration banners clear the two-line distance counter pill', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(500.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HUDOverlay(gameState: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final milestoneBanner = tester.getTopLeft(
        find.byKey(const Key('milestone_celebration_banner')),
      );
      // The distance pill extends to ~82px; banners must start below it.
      expect(
        milestoneBanner.dy,
        greaterThanOrEqualTo(HUDOverlay.bannerTopOffset),
        reason: 'milestone banner must not render underneath the distance pill',
      );
    });
  });
}
