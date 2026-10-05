import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/ui/hud_overlay.dart';

Future<void> _pumpHud(WidgetTester tester, GameState state) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: state,
          builder: (context, _) => HUDOverlay(gameState: state),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('A celebration banner does not linger behind the results screen', (tester) async {
    final state = GameState()..startRun();
    state.updateDistance(500.0); // shift milestone: banner goes up
    await _pumpHud(tester, state);
    const banner = Key('milestone_celebration_banner');
    expect(find.byKey(banner), findsOneWidget);

    // The last package drops while the banner is still showing. Its timer
    // only runs during a live shift, so it would never expire on its own.
    while (state.status != GameStatus.gameOver) {
      state.applyHazardDamage();
    }
    await tester.pump();

    expect(state.isMilestoneBannerVisible, isTrue, reason: 'the timer is frozen, as described');
    expect(find.byKey(banner), findsNothing);
  });

  testWidgets('The banner is back for the next shift\'s milestone', (tester) async {
    final state = GameState()..startRun();
    state.updateDistance(500.0);
    while (state.status != GameStatus.gameOver) {
      state.applyHazardDamage();
    }

    state.startRun();
    state.updateDistance(500.0);
    await _pumpHud(tester, state);

    expect(find.byKey(const Key('milestone_celebration_banner')), findsOneWidget);
  });

  testWidgets('The pause button goes when the shift is over; mute stays', (tester) async {
    final state = GameState()..startRun();
    var pauses = 0;
    var mutes = 0;
    Future<void> pump() => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: state,
                builder: (context, _) => HUDOverlay(
                  gameState: state,
                  onPause: () => pauses++,
                  onToggleMute: () => mutes++,
                ),
              ),
            ),
          ),
        );

    await pump();
    const pause = Key('pause_button');
    await tester.tap(find.byKey(pause));
    expect(pauses, equals(1));

    while (state.status != GameStatus.gameOver) {
      state.applyHazardDamage();
    }
    await tester.pump();
    // Nothing is left to pause: the button used to sit there doing nothing.
    expect(find.byKey(pause), findsNothing);
    // Sound can still be switched off from the results screen.
    await tester.tap(find.byIcon(Icons.volume_up));
    expect(mutes, equals(1));

    state.startRun();
    await tester.pump();
    expect(find.byKey(pause), findsOneWidget);
  });

  testWidgets('The goal label follows the shift', (tester) async {
    String label() => tester.widget<Text>(find.byKey(const Key('hud_goal_label'))).data!;

    // A regular shift aims at the next 500 m milestone.
    final regular = GameState()..startRun();
    await _pumpHud(tester, regular);
    expect(label(), equals('Shift Goal: 500m'));
    regular.updateDistance(520.0);
    await tester.pump();
    expect(label(), equals('Shift Goal: 1000m'));

    // A daily shift aims at its own goal, and says when it has been met.
    final daily = GameState()
      ..startRun(dailyShift: DailyShift.forDate(DateTime(2026, 10, 5)));
    final shift = daily.activeDailyShift!;
    await _pumpHud(tester, daily);
    expect(label(), contains('DAILY GOAL: ${shift.targetDistanceMeters}m'));

    daily.updateDistance(shift.targetDistanceMeters.toDouble());
    await tester.pump();
    expect(label(), startsWith('DAILY GOAL COMPLETE'));
    expect(label(), isNot(contains('${shift.targetDistanceMeters}m')));
  });
}
