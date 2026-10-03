import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/hud_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Near-Miss Stunt & Combo Multiplier (Issue #16)', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState();
      gameState.startRun();
    });

    test('Initializes with 0 stunt streak and 1.0x default multiplier', () {
      expect(gameState.stuntStreak, equals(0));
      expect(gameState.stuntMultiplier, equals(1.0));
      expect(gameState.isComboActive, isFalse);
    });

    test('Consecutive stunts scale multiplier and award compounding bonus tips', () {
      StuntEvent? lastEvent;
      gameState.onStunt = (event) => lastEvent = event;

      // Stunt 1: streak 1 -> 1.2x, base tip 5 * 1.2 = 6 tips
      gameState.recordStunt(clearance: 25.0);
      expect(gameState.stuntStreak, equals(1));
      expect(gameState.stuntMultiplier, equals(1.2));
      expect(gameState.tips, equals(6));
      expect(gameState.isComboActive, isFalse); // Combo activates when streak > 1
      expect(lastEvent?.streak, equals(1));
      expect(lastEvent?.multiplier, equals(1.2));

      // Stunt 2: streak 2 -> 1.5x, base tip 5 * 1.5 = 8 tips (6 + 8 = 14)
      gameState.recordStunt(clearance: 15.0);
      expect(gameState.stuntStreak, equals(2));
      expect(gameState.stuntMultiplier, equals(1.5));
      expect(gameState.tips, equals(14));
      expect(gameState.isComboActive, isTrue);

      // Stunt 3: streak 3 -> 2.0x, base tip 5 * 2.0 = 10 tips (14 + 10 = 24)
      gameState.recordStunt(clearance: 8.0);
      expect(gameState.stuntStreak, equals(3));
      expect(gameState.stuntMultiplier, equals(2.0));
      expect(gameState.tips, equals(24));
      expect(gameState.isComboActive, isTrue);

      // Stunt 4: streak 4 -> 2.5x cap, base tip 5 * 2.5 = 13 tips (24 + 13 = 37)
      gameState.recordStunt(clearance: 5.0);
      expect(gameState.stuntStreak, equals(4));
      expect(gameState.stuntMultiplier, equals(2.5));
      expect(gameState.tips, equals(37));
    });

    test('Cold Brew Energy Drink doubles stunt tip rewards', () {
      gameState.activateEnergyDrink();
      expect(gameState.isEnergyBoostActive, isTrue);

      // Stunt 1 under energy boost: 6 * 2 = 12 tips
      gameState.recordStunt(clearance: 20.0);
      expect(gameState.tips, equals(12));
    });

    test('Stunt streak decays after countdown timer expires', () {
      gameState.recordStunt();
      gameState.recordStunt();
      expect(gameState.stuntStreak, equals(2));
      expect(gameState.isComboActive, isTrue);

      // Advance timer by 2 seconds (half of 4.0s duration)
      gameState.updateStuntTimer(2.0);
      expect(gameState.stuntStreak, equals(2));
      expect(gameState.isComboActive, isTrue);

      // Advance remaining 2.1s -> combo expires
      gameState.updateStuntTimer(2.1);
      expect(gameState.stuntStreak, equals(0));
      expect(gameState.isComboActive, isFalse);
    });

    test('Hazard damage breaks active stunt combo and resets streak to 0', () {
      gameState.recordStunt();
      gameState.recordStunt();
      gameState.recordStunt();
      expect(gameState.stuntStreak, equals(3));

      // Colliding with hazard
      gameState.applyHazardDamage();
      expect(gameState.stuntStreak, equals(0));
      expect(gameState.stuntMultiplier, equals(1.0));
      expect(gameState.isComboActive, isFalse);
    });

    test('FloatingTextComponent drifts upward and auto-expires', () {
      final popup = FloatingTextComponent(
        text: 'STUNT! 1.5x',
        position: Vector2(100, 200),
        duration: 0.8,
        driftVelocity: -60.0,
      );

      expect(popup.position.y, equals(200.0));

      // Advance 0.5s -> drifts upward by 30px
      popup.update(0.5);
      expect(popup.position.y, equals(170.0));

      // Advance past duration
      popup.update(0.4);
      expect(popup.isMounted, isFalse);
    });

    testWidgets('HUDOverlay renders stunt combo badge when combo > 1', (tester) async {
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

      // Initially no combo badge
      expect(find.byKey(const Key('stunt_combo_badge')), findsNothing);

      // Stunt 1 -> streak 1, no combo badge yet
      state.recordStunt();
      await tester.pump();
      expect(find.byKey(const Key('stunt_combo_badge')), findsNothing);

      // Stunt 2 -> streak 2, combo badge appears!
      state.recordStunt();
      await tester.pump();
      expect(find.byKey(const Key('stunt_combo_badge')), findsOneWidget);
      expect(find.textContaining('STUNT COMBO 1.5x (2)'), findsOneWidget);

      // Expire timer -> combo badge disappears
      state.updateStuntTimer(4.5);
      await tester.pump();
      expect(find.byKey(const Key('stunt_combo_badge')), findsNothing);
    });

    test('CourierGame near-miss proximity detection triggers stunt on tight leap', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // Spawn an obstacle directly ahead
      final obstacle = ObstacleComponent(
        type: ObstacleType.hydrant,
        position: Vector2(120.0, CourierGame.groundY - 44.0), // Under player X
      );
      await game.world.add(obstacle);
      await game.ready();
      game.activeObstacles.add(obstacle);

      // Position courier right above obstacle within tight clearance (20px)
      // Hydrant top = 460 - 44 = 416. Player bottom = 396 -> clearance = 20px
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 396.0;
      game.player.position = Vector2(120.0, 396.0 - game.player.size.y);

      // Execute update loop
      game.update(0.016);

      expect(obstacle.hasTriggeredNearMiss, isTrue);
      expect(game.gameState.stuntStreak, equals(1));
      expect(game.gameState.tips, greaterThan(0));

      // Floating text component spawned
      final popups = game.world.children.whereType<FloatingTextComponent>();
      expect(popups.length, equals(1));
      expect(popups.first.text, contains('STUNT!'));
    });
  });
}
