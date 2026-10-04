import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ObstacleComponent Mailbox & Vaultability (Issue #45)', () {
    test('ObstacleType.mailbox has calibrated dimensions and vaultability', () {
      final mailbox = ObstacleComponent(type: ObstacleType.mailbox);
      expect(mailbox.size.x, equals(30));
      expect(mailbox.size.y, equals(42));
      expect(mailbox.isVaultable, isTrue);
      expect(mailbox.hasBeenVaulted, isFalse);
    });

    test('isVaultable is true only for low rigid obstacles (hydrant, mailbox, scooter)', () {
      expect(ObstacleComponent(type: ObstacleType.hydrant).isVaultable, isTrue);
      expect(ObstacleComponent(type: ObstacleType.mailbox).isVaultable, isTrue);
      expect(ObstacleComponent(type: ObstacleType.scooter).isVaultable, isTrue);

      expect(ObstacleComponent(type: ObstacleType.dog).isVaultable, isFalse);
      expect(ObstacleComponent(type: ObstacleType.van).isVaultable, isFalse);
      expect(ObstacleComponent(type: ObstacleType.skateMessenger).isVaultable, isFalse);
      expect(ObstacleComponent(type: ObstacleType.pigeonFlock).isVaultable, isFalse);
    });

    test('Mailbox procedural vector rendering executes cleanly without exceptions', () {
      final mailbox = ObstacleComponent(type: ObstacleType.mailbox);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => mailbox.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('Player avoids collision damage when hasBeenVaulted or player.isVaulting is true', () async {
      final obstacle = ObstacleComponent(type: ObstacleType.mailbox);
      await obstacle.onLoad();

      // Case 1: obstacle has been vaulted
      obstacle.hasBeenVaulted = true;
      var damageCount = 0;
      final playerWithDamage = CourierPlayer(
        onDamage: () => damageCount++,
      );
      await playerWithDamage.onLoad();

      obstacle.onCollisionStart({}, playerWithDamage);
      expect(damageCount, equals(0));
      expect(obstacle.hasCollidedWithPlayer, isFalse);

      // Case 2: player is in vaulting state
      obstacle.hasBeenVaulted = false;
      playerWithDamage.startVault();
      expect(playerWithDamage.isVaulting, isTrue);

      obstacle.onCollisionStart({}, playerWithDamage);
      expect(damageCount, equals(0));
      expect(obstacle.hasCollidedWithPlayer, isFalse);
    });
  });

  group('CourierPlayer Vaulting State Machine (Issue #45)', () {
    test('startVault initiates vaulting state and physics launch', () {
      final player = CourierPlayer();
      player.startVault(impulse: 230.0);

      expect(player.state, equals(CourierState.vaulting));
      expect(player.isVaulting, isTrue);
      expect(player.simulator.verticalVelocity, equals(230.0));
    });

    test('CourierPlayer updates through vaulting and returns to running on ground contact', () {
      var landed = false;
      final player = CourierPlayer(
        groundY: 460.0,
        onLand: () => landed = true,
      );

      player.startVault(impulse: 150.0);
      expect(player.isVaulting, isTrue);

      // Step physics into air
      player.update(0.1);
      expect(player.isVaulting, isTrue);

      // Step physics until grounded again
      for (var i = 0; i < 20; i++) {
        player.update(0.05);
      }

      expect(player.simulator.isGrounded, isTrue);
      expect(player.state, equals(CourierState.running));
      expect(landed, isTrue);
    });

    test('CourierPlayer procedural drawing in vaulting state executes cleanly', () {
      final player = CourierPlayer();
      player.startVault();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => player.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('GameState Parkour Vault Scoring & Events (Issue #45)', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState();
      gameState.startRun();
    });

    test('recordVault increments counters and streaks', () {
      VaultEvent? receivedEvent;
      gameState.onVault = (event) => receivedEvent = event;

      final event = gameState.recordVault(obstacleType: ObstacleType.mailbox);

      expect(event, isNotNull);
      expect(receivedEvent, equals(event));
      expect(event!.obstacleType, equals(ObstacleType.mailbox));
      expect(gameState.vaultsInRun, equals(1));
      expect(gameState.stuntStreak, equals(1));
      // Base tip 15 * 1.2 (stuntStreak 1) = 18 tips
      expect(gameState.tips, equals(18));
      expect(gameState.stuntStreakTimer, equals(GameState.stuntComboDuration));
    });

    test('recordVault multiplies tips with active stunt multiplier and energy drink', () {
      // Build up stunt multiplier
      gameState.recordVault(obstacleType: ObstacleType.hydrant); // streak 1 (1.2x): 18 tips
      gameState.recordVault(obstacleType: ObstacleType.mailbox); // streak 2 (1.5x): 15 * 1.5 = 23 tips

      expect(gameState.vaultsInRun, equals(2));
      expect(gameState.stuntStreak, equals(2));
      expect(gameState.tips, equals(18 + 23));

      // Activate Cold Brew energy boost (doubles tips)
      gameState.activateEnergyDrink();
      gameState.recordVault(obstacleType: ObstacleType.scooter); // streak 3 (2.0x): 15 * 2.0 = 30 * 2 = 60 tips

      expect(gameState.vaultsInRun, equals(3));
      expect(gameState.stuntStreak, equals(3));
      expect(gameState.tips, equals(18 + 23 + 60));
    });

    test('recordVault awards double tips under DailyModifier.skateCommute', () {
      final dailyState = GameState();
      dailyState.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-03',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      final event = dailyState.recordVault(obstacleType: ObstacleType.hydrant);
      expect(event!.totalTips, equals(36)); // 18 * 2
      expect(dailyState.tips, equals(36));
    });

    test('recordVault returns null and does nothing when game is not running', () {
      gameState.status = GameStatus.gameOver;
      final event = gameState.recordVault(obstacleType: ObstacleType.mailbox);

      expect(event, isNull);
      expect(gameState.vaultsInRun, equals(0));
    });

    test('startRun resets vaultsInRun to 0', () {
      gameState.recordVault(obstacleType: ObstacleType.mailbox);
      expect(gameState.vaultsInRun, equals(1));

      gameState.startRun();
      expect(gameState.vaultsInRun, equals(0));
    });
  });

  group('CourierGame Parkour Vault Integration Tests (Issue #45)', () {
    late CourierGame game;

    setUp(() async {
      game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
    });

    tearDown(() {
      game.gameState.status = GameStatus.idle;
    });

    test('CourierGame triggers parkour vault when jumping near a vaultable obstacle', () {
      // Place mailbox in front of courier within approach window (e.g. 30px ahead)
      final courierFrontX = game.player.position.x + game.player.size.x;
      final mailbox = ObstacleComponent(
        type: ObstacleType.mailbox,
        position: Vector2(courierFrontX + 30.0, CourierGame.groundY - 42.0),
      );
      game.world.add(mailbox);
      game.activeObstacles.add(mailbox);

      expect(mailbox.hasBeenVaulted, isFalse);
      expect(game.player.state, equals(CourierState.running));

      // Trigger jump
      final jumped = game.player.jump();
      expect(jumped, isTrue);
      expect(game.player.isVaulting, isTrue);
      expect(mailbox.hasBeenVaulted, isTrue);
      expect(game.gameState.vaultsInRun, equals(1));

      // Floating text component should be spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('PARKOUR VAULT!')), isTrue);
    });

    test('CourierGame does NOT trigger parkour vault for non-vaultable obstacle (dog)', () {
      final courierFrontX = game.player.position.x + game.player.size.x;
      final dog = ObstacleComponent(
        type: ObstacleType.dog,
        position: Vector2(courierFrontX + 30.0, CourierGame.groundY - 36.0),
      );
      game.world.add(dog);
      game.activeObstacles.add(dog);

      final jumped = game.player.jump();
      expect(jumped, isTrue);
      expect(game.player.isVaulting, isFalse);
      expect(game.player.state, equals(CourierState.jumping));
      expect(dog.hasBeenVaulted, isFalse);
      expect(game.gameState.vaultsInRun, equals(0));
    });

    test('CourierGame applies +25% forward parkour velocity boost while vaulting', () {
      game.gameState.distanceMeters = 0.0;
      game.update(0.01);
      final baseSpeed = game.currentSpeed;

      // Enter vaulting
      game.player.startVault();
      game.update(0.01);

      expect(game.player.isVaulting, isTrue);
      expect(game.currentSpeed, closeTo(baseSpeed * 1.25, 0.5));
    });

    test('restartRun cleans up vault target and resets vaultsInRun', () {
      final courierFrontX = game.player.position.x + game.player.size.x;
      final hydrant = ObstacleComponent(
        type: ObstacleType.hydrant,
        position: Vector2(courierFrontX + 20.0, CourierGame.groundY - 44.0),
      );
      game.world.add(hydrant);
      game.activeObstacles.add(hydrant);

      game.player.jump();
      expect(game.gameState.vaultsInRun, equals(1));

      game.restartRun();
      expect(game.gameState.vaultsInRun, equals(0));
      expect(game.activeObstacles.contains(hydrant), isFalse);
    });
  });

  group('GameOverModal Vaults Badge UI Tests (Issue #45)', () {
    testWidgets('GameOverModal displays game_over_vaults_badge when vaultsCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 420,
              tips: 85,
              careerTips: 450,
              isNewRecord: false,
              vaultsCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_vaults_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('3 PARKOUR VAULTS'), findsOneWidget);
    });

    testWidgets('GameOverModal formats singular vault badge correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 150,
              tips: 30,
              careerTips: 200,
              isNewRecord: false,
              vaultsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_vaults_badge')), findsOneWidget);
      expect(find.text('1 PARKOUR VAULT'), findsOneWidget);
    });

    testWidgets('GameOverModal hides game_over_vaults_badge when vaultsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 150,
              tips: 30,
              careerTips: 200,
              isNewRecord: false,
              vaultsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_vaults_badge')), findsNothing);
    });
  });
}
