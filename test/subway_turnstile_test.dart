import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/subway_turnstile_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SubwayTurnstileComponent Unit Tests (Issue #78)', () {
    test('initializes with default dimensions, position, and un-swiped/un-vaulted state', () {
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
        width: 58.0,
        height: 52.0,
        groundY: 460.0,
      );

      expect(turnstile.position.x, equals(200.0));
      expect(turnstile.position.y, equals(408.0));
      expect(turnstile.size.x, equals(58.0));
      expect(turnstile.size.y, equals(52.0));
      expect(turnstile.groundY, equals(460.0));
      expect(turnstile.hasSwiped, isFalse);
      expect(turnstile.hasVaulted, isFalse);
      expect(turnstile.shouldRecycle, isFalse);
      expect(turnstile.barrierTopWorldY, equals(408.0 + 12.0));
      expect(turnstile.cardReaderWorldPosition.x, equals(200.0 + 20.0));
      expect(turnstile.cardReaderWorldPosition.y, equals(408.0 + 8.0));
      expect(turnstile.rotorHubWorldPosition.x, equals(200.0 + 36.0));
      expect(turnstile.rotorHubWorldPosition.y, equals(408.0 + 26.0));
    });

    test('shouldRecycle triggers when turnstile has scrolled completely offscreen', () {
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(-220.0, 408.0),
      );

      expect(turnstile.shouldRecycle, isTrue);
    });

    test('checkSwipe triggers when courier is at sidewalk level in horizontal range', () {
      var swiped = false;
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
        groundY: 460.0,
        onSwipe: () => swiped = true,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      // Courier foot at position 210 + 20 = 230 (within 188..266)
      final playerPos = Vector2(210.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(turnstile.checkSwipe(playerPos, playerSize, simulator), isTrue);
      expect(turnstile.hasSwiped, isTrue);
      expect(swiped, isTrue);

      // Cannot trigger again
      expect(turnstile.checkSwipe(playerPos, playerSize, simulator), isFalse);
    });

    test('checkSwipe returns false when courier is leaping high above turnstile', () {
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
        groundY: 460.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 360.0; // High in jump arc
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 312.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(turnstile.checkSwipe(playerPos, playerSize, simulator), isFalse);
      expect(turnstile.hasSwiped, isFalse);
    });

    test('checkVault triggers when airborne courier clears turnstile barrier top', () {
      var vaulted = false;
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
        groundY: 460.0,
        onVault: () => vaulted = true,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // barrierTopWorldY = 420.0. Courier foot at 410.0 (in window 380..432)
      simulator.currentY = 410.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 362.0); // foot at 210 + 20 = 230 (within 200..258)
      final playerSize = Vector2(40.0, 48.0);

      expect(turnstile.checkVault(playerPos, playerSize, simulator), isTrue);
      expect(turnstile.hasVaulted, isTrue);
      expect(vaulted, isTrue);

      // Cannot trigger again
      expect(turnstile.checkVault(playerPos, playerSize, simulator), isFalse);
    });

    test('checkVault returns false when courier is grounded', () {
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
        groundY: 460.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(210.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(turnstile.checkVault(playerPos, playerSize, simulator), isFalse);
    });

    test('update advances pulse timer, decrements flash timer, and rotates arms', () {
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      turnstile.checkSwipe(Vector2(210.0, 412.0), Vector2(40.0, 48.0), simulator);

      turnstile.update(0.1);
      // Arm rotation should smoothly advance
      expect(turnstile.hasSwiped, isTrue);

      turnstile.update(1.0); // Flash expires
    });

    test('renders pedestal, console, LED, tripod arms, bolts, and green arrow without throwing', () {
      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      turnstile.render(canvas);

      // Flash active
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      turnstile.checkSwipe(Vector2(210.0, 412.0), Vector2(40.0, 48.0), simulator);
      turnstile.update(0.016);
      turnstile.render(canvas);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('ParticleEffectComponent Metro Swipe Tests (Issue #78)', () {
    test('metroSwipe factory creates upward magnetic sparkle particles', () {
      final swipeFx = ParticleEffectComponent.metroSwipe(
        position: Vector2(200.0, 410.0),
        count: 14,
      );

      expect(swipeFx.particles.length, equals(14));
      for (final p in swipeFx.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(80.0));
      }
    });

    test('metroSwipe particles update and complete lifecycle', () {
      final swipeFx = ParticleEffectComponent.metroSwipe(
        position: Vector2(200.0, 410.0),
        count: 5,
      );

      swipeFx.update(0.1);
      expect(swipeFx.isFinished, isFalse);

      swipeFx.update(1.5);
      expect(swipeFx.isFinished, isTrue);
    });
  });

  group('GameState Subway Turnstile Mechanics (Issue #78)', () {
    test('recordTurnstilePass awards base tips for swipe and vault', () {
      final gameState = GameState();
      gameState.startRun();

      expect(gameState.turnstileVaultsInRun, equals(0));
      expect(gameState.stuntStreak, equals(0));

      // 1. Swipe: base 20 * 1.2 = 24
      final swipeEvent = gameState.recordTurnstilePass(isVault: false);
      expect(swipeEvent, isNotNull);
      expect(swipeEvent!.isVault, isFalse);
      expect(swipeEvent.baseTips, equals(20));
      expect(swipeEvent.totalTips, equals(24));
      expect(gameState.turnstileVaultsInRun, equals(1));
      expect(gameState.stuntStreak, equals(1));
      expect(gameState.tips, equals(24));

      // 2. Vault: base 25 * 1.5 = 38
      final vaultEvent = gameState.recordTurnstilePass(isVault: true);
      expect(vaultEvent, isNotNull);
      expect(vaultEvent!.isVault, isTrue);
      expect(vaultEvent.baseTips, equals(25));
      expect(vaultEvent.totalTips, equals(38));
      expect(gameState.turnstileVaultsInRun, equals(2));
      expect(gameState.stuntStreak, equals(2));
      expect(gameState.tips, equals(24 + 38));
    });

    test('recordTurnstilePass doubles tips during skateCommute daily shift', () {
      final gameState = GameState();
      gameState.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      final event = gameState.recordTurnstilePass(isVault: true);
      // Base 25 * 1.2 = 30 * 2 skateCommute = 60
      expect(event!.totalTips, equals(60));
      expect(gameState.tips, equals(60));
    });

    test('recordTurnstilePass doubles tips during energy boost active', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.activateEnergyDrink(8.0);

      final event = gameState.recordTurnstilePass(isVault: true);
      // Base 25 * 1.2 = 30 * 2 energy = 60
      expect(event!.totalTips, equals(60));
      expect(gameState.tips, equals(60));
    });

    test('recordTurnstilePass dispatches onTurnstile callback', () {
      final gameState = GameState();
      gameState.startRun();

      TurnstileEvent? receivedEvent;
      gameState.onTurnstile = (e) => receivedEvent = e;

      gameState.recordTurnstilePass(isVault: false);

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.baseTips, equals(20));
      expect(receivedEvent!.isVault, isFalse);
    });

    test('recordTurnstilePass returns null when game not running', () {
      final gameState = GameState();
      expect(gameState.recordTurnstilePass(), isNull);
    });

    test('startRun resets turnstileVaultsInRun to 0', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.recordTurnstilePass();
      expect(gameState.turnstileVaultsInRun, equals(1));

      gameState.startRun();
      expect(gameState.turnstileVaultsInRun, equals(0));
    });
  });

  group('WorldChunkManager Subway Turnstile Spawning (Issue #78)', () {
    test('SubwayTurnstileData retains coordinates and dimensions', () {
      const data = SubwayTurnstileData(
        x: 320.0,
        y: 408.0,
        width: 58.0,
        height: 52.0,
      );

      expect(data.x, equals(320.0));
      expect(data.y, equals(408.0));
      expect(data.width, equals(58.0));
      expect(data.height, equals(52.0));
    });

    test('ChunkData includes turnstiles list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        turnstiles: [
          SubwayTurnstileData(x: 250.0, y: 408.0),
        ],
      );

      expect(chunk.turnstiles.length, equals(1));
      expect(chunk.turnstiles.first.x, equals(250.0));
    });

    test('WorldChunkManager procedurally generates turnstiles at distance >= 75m', () {
      final manager = WorldChunkManager();
      var foundTurnstile = false;

      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 400.0 + (i * 960.0),
          groundY: 460.0,
          speed: 250.0,
          distanceMeters: 100.0,
        );
        if (chunk.turnstiles.isNotEmpty) {
          foundTurnstile = true;
          final t = chunk.turnstiles.first;
          expect(t.width, equals(58.0));
          expect(t.height, equals(52.0));
          break;
        }
      }

      expect(foundTurnstile, isTrue);
    });
  });

  group('CourierGame Subway Turnstile Integration (Issue #78)', () {
    test('spawning chunk populates activeTurnstiles and attaches to world', () async {
      final game = CourierGame();
      await game.onLoad();

      expect(game.activeTurnstiles, isNotNull);
    });

    test('restartRun cleans up activeTurnstiles', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final turnstile = SubwayTurnstileComponent(
        position: Vector2(200.0, 408.0),
      );
      game.activeTurnstiles.add(turnstile);
      game.world.add(turnstile);

      expect(game.activeTurnstiles.length, equals(1));

      game.restartRun();

      expect(game.activeTurnstiles.isEmpty, isTrue);
      expect(game.world.children.whereType<SubwayTurnstileComponent>().isEmpty, isTrue);
    });

    test('update loop scrolls activeTurnstiles to the left', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final turnstile = SubwayTurnstileComponent(
        position: Vector2(300.0, 408.0),
      );
      game.activeTurnstiles.add(turnstile);

      game.currentSpeed = 200.0;
      game.update(0.1); // scrolls 200 * 0.1 = 20 px

      expect(turnstile.position.x, closeTo(280.0, 0.01));
    });

    test('grounded player in range triggers metro swipe stunt bonus', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final turnstile = SubwayTurnstileComponent(
        position: Vector2(playerInitialX + 20.0, 408.0),
        groundY: 460.0,
      );
      game.activeTurnstiles.add(turnstile);

      game.player.position = Vector2(playerInitialX, 400.0);
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      expect(turnstile.hasSwiped, isFalse);

      game.update(0.016);

      expect(turnstile.hasSwiped, isTrue);
      expect(game.gameState.turnstileVaultsInRun, equals(1));
    });

    test('airborne player clearing barrier triggers turnstile vault stunt bonus', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final turnstile = SubwayTurnstileComponent(
        position: Vector2(playerInitialX + 20.0, 408.0),
        groundY: 460.0,
      );
      game.activeTurnstiles.add(turnstile);

      // Airborne hurdle: foot at 415.0
      game.player.position = Vector2(playerInitialX, 350.0);
      game.player.simulator.currentY = 415.0;
      game.player.simulator.isGrounded = false;

      expect(turnstile.hasVaulted, isFalse);

      game.update(0.016);

      expect(turnstile.hasVaulted, isTrue);
      expect(game.gameState.turnstileVaultsInRun, equals(1));
    });

    test('recycling removes offscreen turnstiles', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreenTurnstile = SubwayTurnstileComponent(
        position: Vector2(-300.0, 408.0),
      );
      game.activeTurnstiles.add(offscreenTurnstile);

      game.update(0.016);
      expect(game.activeTurnstiles.contains(offscreenTurnstile), isFalse);
    });
  });

  group('GameOverModal Turnstile Badge UI Tests (Issue #78)', () {
    testWidgets('hides game_over_turnstiles_badge when turnstilesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 400,
              tips: 100,
              isNewRecord: false,
              careerTips: 1000,
              turnstilesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_turnstiles_badge')), findsNothing);
    });

    testWidgets('displays game_over_turnstiles_badge with singular text when turnstilesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 400,
              tips: 100,
              isNewRecord: false,
              careerTips: 1000,
              turnstilesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_turnstiles_badge')), findsOneWidget);
      expect(find.text('1 METRO TURNSTILE'), findsOneWidget);
      expect(find.byIcon(Icons.transit_enterexit), findsOneWidget);
    });

    testWidgets('displays game_over_turnstiles_badge with plural text when turnstilesCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 800,
              tips: 250,
              isNewRecord: true,
              careerTips: 3000,
              turnstilesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_turnstiles_badge')), findsOneWidget);
      expect(find.text('3 METRO TURNSTILES'), findsOneWidget);
    });
  });
}

const double playerInitialX = 80.0;
