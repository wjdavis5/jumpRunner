import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/postal_mailbox_component.dart';
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

  group('PostalMailboxComponent Unit Tests (Issue #92)', () {
    test('initializes with default dimensions, position, and unvaulted state', () {
      final mailbox = PostalMailboxComponent(
        position: Vector2(240.0, 406.0),
        width: 42.0,
        height: 54.0,
        groundY: 460.0,
      );

      expect(mailbox.position.x, equals(240.0));
      expect(mailbox.position.y, equals(406.0));
      expect(mailbox.size.x, equals(42.0));
      expect(mailbox.size.y, equals(54.0));
      expect(mailbox.groundY, equals(460.0));
      expect(mailbox.hasVaulted, isFalse);
      expect(mailbox.shouldRecycle, isFalse);
      expect(mailbox.vaultTopWorldY, equals(460.0 - 54.0));
      expect(mailbox.chuteWorldPosition, equals(Vector2(240.0 + 21.0, 406.0 + 12.0)));
      expect(mailbox.centerWorldPosition, equals(Vector2(240.0 + 21.0, 406.0 + 27.0)));
    });

    test('shouldRecycle triggers when mailbox scrolls offscreen', () {
      final offscreen = PostalMailboxComponent(
        position: Vector2(-250.0, 406.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = PostalMailboxComponent(
        position: Vector2(100.0, 406.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update decays chute vibration after vaulting', () {
      final mailbox = PostalMailboxComponent(
        position: Vector2(200.0, 406.0),
      );
      mailbox.hasVaulted = true;
      mailbox.update(0.1);
      expect(mailbox.hasVaulted, isTrue);
    });

    test('checkVault returns false when courier is grounded', () {
      final mailbox = PostalMailboxComponent(
        position: Vector2(200.0, 406.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(210.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(mailbox.checkVault(playerPos, playerSize, simulator), isFalse);
      expect(mailbox.hasVaulted, isFalse);
    });

    test('checkVault returns false when courier is outside horizontal span', () {
      final mailbox = PostalMailboxComponent(
        position: Vector2(300.0, 406.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 400.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 352.0); // Far away horizontally
      final playerSize = Vector2(40.0, 48.0);

      expect(mailbox.checkVault(playerPos, playerSize, simulator), isFalse);
      expect(mailbox.hasVaulted, isFalse);
    });

    test('checkVault returns false when foot Y is outside vault clearance window', () {
      final mailbox = PostalMailboxComponent(
        position: Vector2(200.0, 406.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 320.0; // Too high above mailbox
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 272.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(mailbox.checkVault(playerPos, playerSize, simulator), isFalse);
      expect(mailbox.hasVaulted, isFalse);
    });

    test('checkVault triggers vault when airborne courier hurdles rounded mailbox dome', () {
      var vaulted = false;
      final mailbox = PostalMailboxComponent(
        position: Vector2(200.0, 406.0),
        groundY: 460.0,
        onVault: () {
          vaulted = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // vaultTopWorldY = 460.0 - 54.0 = 406.0. Window: 406.0 + 12.0 down to 406.0 - 50.0.
      simulator.currentY = 395.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 347.0);
      final playerSize = Vector2(40.0, 48.0);

      final result = mailbox.checkVault(playerPos, playerSize, simulator);
      expect(result, isTrue);
      expect(mailbox.hasVaulted, isTrue);
      expect(vaulted, isTrue);

      // Subsequent checks should return false
      expect(mailbox.checkVault(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints steel cabinet, anchor legs, dome, pull handle, and placard without errors', () {
      final mailbox = PostalMailboxComponent(
        position: Vector2(100.0, 406.0),
        groundY: 460.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => mailbox.render(canvas), returnsNormally);

      // Render during chute flap vibration
      mailbox.hasVaulted = true;
      mailbox.update(0.05);
      expect(() => mailbox.render(canvas), returnsNormally);
    });
  });

  group('GameState Postal Mailbox Vault Tracking (Issue #92)', () {
    test('recordMailboxVault awards base tips scaled by stunt multiplier and advances streak', () {
      final state = GameState();
      state.startRun();

      PostalMailboxEvent? receivedEvent;
      state.onPostalMailboxVault = (event) {
        receivedEvent = event;
      };

      expect(state.mailboxVaultsInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordMailboxVault(baseTips: 25);
      expect(event, isNotNull);
      expect(state.mailboxVaultsInRun, equals(1));
      expect(state.stuntStreak, equals(1));

      // Streak 1 -> 1.2x multiplier -> round(25 * 1.2) = 30 tips
      expect(event!.baseTips, equals(25));
      expect(event.totalTips, equals(30));
      expect(event.multiplier, equals(1.2));
      expect(event.stuntStreak, equals(1));
      expect(state.tips, equals(30));
      expect(receivedEvent, equals(event));
    });

    test('recordMailboxVault scales with DailyModifier.skateCommute (doubles) and energy boost', () {
      final state = GameState();
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      state.activateEnergyDrink(10.0);
      final event = state.recordMailboxVault(baseTips: 25);
      expect(event, isNotNull);
      // Base: round(25 * 1.2) = 30. With skateCommute: 30 * 2 = 60. With energy drink: 60 * 2 = 120.
      expect(event!.totalTips, equals(120));
      expect(state.tips, equals(120));
    });

    test('recordMailboxVault returns null when game is not running', () {
      final state = GameState();
      expect(state.recordMailboxVault(), isNull);
    });

    test('startRun resets mailboxVaultsInRun counter', () {
      final state = GameState();
      state.startRun();
      state.recordMailboxVault();
      expect(state.mailboxVaultsInRun, equals(1));

      state.startRun();
      expect(state.mailboxVaultsInRun, equals(0));
    });
  });

  group('WorldChunkManager Postal Mailbox Procedural Generation (Issue #92)', () {
    test('generates postal mailboxes after 60m threshold', () {
      final chunkManager = WorldChunkManager();
      var generatedMailbox = false;

      for (var chunkIndex = 0; chunkIndex < 50; chunkIndex++) {
        final chunk = chunkManager.generateChunk(
          startX: chunkIndex * 960.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 320.0,
          distanceMeters: 70.0 + (chunkIndex * 20.0),
        );

        if (chunk.postalMailboxes.isNotEmpty) {
          generatedMailbox = true;
          for (final mb in chunk.postalMailboxes) {
            expect(mb.width, equals(42.0));
            expect(mb.height, equals(54.0));
            expect(mb.y, equals(460.0 - 54.0));
          }
          break;
        }
      }

      expect(generatedMailbox, isTrue);
    });

    test('PostalMailboxData holds specified coordinates and default dimensions', () {
      const data = PostalMailboxData(
        x: 350.0,
        y: 406.0,
      );
      expect(data.x, equals(350.0));
      expect(data.y, equals(406.0));
      expect(data.width, equals(42.0));
      expect(data.height, equals(54.0));
    });
  });

  group('ParticleEffectComponent.mailScatter Tests (Issue #92)', () {
    test('creates priority airmail flutter particles with red, blue, and white palette', () {
      final scatter = ParticleEffectComponent.mailScatter(
        position: Vector2(250.0, 406.0),
        count: 18,
      );

      expect(scatter.particles.length, equals(18));
      for (final p in scatter.particles) {
        expect(p.position.x, equals(250.0));
        expect(p.position.y, equals(406.0));
        expect(p.maxLife, greaterThan(0.0));
        expect(p.gravity, equals(190.0));
        expect(p.drag, equals(0.91));
      }
    });
  });

  group('CourierGame Integration with PostalMailboxComponent (Issue #92)', () {
    testWidgets('spawns, updates, scrolls, and resets mailboxes in run lifecycle', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final mailbox = PostalMailboxComponent(
        position: Vector2(400.0, 406.0),
        groundY: 460.0,
      );
      game.activeMailboxes.add(mailbox);
      game.world.add(mailbox);

      expect(game.activeMailboxes.contains(mailbox), isTrue);

      final initialX = mailbox.position.x;
      game.update(0.05);
      expect(mailbox.position.x, lessThan(initialX));

      game.restartRun();
      expect(game.activeMailboxes, isEmpty);
    });

    testWidgets('triggers mailbox vault stunt when airborne courier hurdles mailbox', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final mailbox = PostalMailboxComponent(
        position: Vector2(game.player.position.x + 10.0, 406.0),
        groundY: 460.0,
      );
      game.activeMailboxes.add(mailbox);
      game.world.add(mailbox);

      // Make player airborne over mailbox dome
      game.player.simulator.currentY = 395.0;
      game.player.simulator.isGrounded = false;

      expect(game.gameState.mailboxVaultsInRun, equals(0));
      game.update(0.02);

      expect(mailbox.hasVaulted, isTrue);
      expect(game.gameState.mailboxVaultsInRun, equals(1));
    });

    testWidgets('recycles offscreen mailboxes cleanly', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreen = PostalMailboxComponent(
        position: Vector2(-250.0, 406.0),
        groundY: 460.0,
      );
      game.activeMailboxes.add(offscreen);
      game.world.add(offscreen);

      game.update(0.02);
      expect(game.activeMailboxes.contains(offscreen), isFalse);
    });
  });

  group('GameOverModal Mailbox Badge UI Tests (Issue #92)', () {
    testWidgets('renders game_over_mailbox_badge when mailboxesCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 150,
              isNewRecord: false,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              grindsCompleted: 2,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              craneSwingsCompleted: 0,
              vipDeliveriesCompleted: 0,
              mailboxesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_mailbox_badge')), findsOneWidget);
      expect(find.text('3 MAILBOX VAULTS'), findsOneWidget);
      expect(find.byIcon(Icons.markunread_mailbox), findsOneWidget);
    });

    testWidgets('renders singular text when mailboxesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 150,
              isNewRecord: false,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              grindsCompleted: 2,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              craneSwingsCompleted: 0,
              vipDeliveriesCompleted: 0,
              mailboxesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_mailbox_badge')), findsOneWidget);
      expect(find.text('1 MAILBOX VAULT'), findsOneWidget);
    });

    testWidgets('does not render game_over_mailbox_badge when mailboxesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 150,
              isNewRecord: false,
              careerTips: 2500,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              grindsCompleted: 2,
              vaultsCompleted: 1,
              glidesCompleted: 0,
              subwayStationsCompleted: 0,
              craneSwingsCompleted: 0,
              vipDeliveriesCompleted: 0,
              mailboxesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_mailbox_badge')), findsNothing);
    });
  });
}
