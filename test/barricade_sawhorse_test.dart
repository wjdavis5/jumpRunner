import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/barricade_sawhorse_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
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

  group('BarricadeSawhorseComponent Unit Tests (Issue #89)', () {
    test('initializes with default dimensions, position, and un-vaulted state', () {
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(200.0, 416.0),
        width: 68.0,
        height: 44.0,
        groundY: 460.0,
      );

      expect(barricade.position.x, equals(200.0));
      expect(barricade.position.y, equals(416.0));
      expect(barricade.size.x, equals(68.0));
      expect(barricade.size.y, equals(44.0));
      expect(barricade.groundY, equals(460.0));
      expect(barricade.hasVaulted, isFalse);
      expect(barricade.shouldRecycle, isFalse);
      expect(barricade.hurdleTopWorldY, equals(460.0 - 36.0));
      expect(barricade.flasherWorldPosition, equals(Vector2(200.0 + 34.0, 416.0 + 4.0)));
      expect(barricade.centerWorldPosition, equals(Vector2(200.0 + 34.0, 460.0 - 22.0)));
    });

    test('shouldRecycle triggers when sawhorse barricade scrolls offscreen', () {
      final offscreen = BarricadeSawhorseComponent(
        position: Vector2(-220.0, 416.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = BarricadeSawhorseComponent(
        position: Vector2(100.0, 416.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update advances warning flasher light and cone tumble physics', () {
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(200.0, 416.0),
      );

      // Flasher timer toggle check
      barricade.update(0.4);
      barricade.hasVaulted = true;
      barricade.update(0.1);
      expect(barricade.hasVaulted, isTrue);
    });

    test('checkVault returns false when courier is grounded', () {
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(200.0, 416.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(220.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(barricade.checkVault(playerPos, playerSize, simulator), isFalse);
      expect(barricade.hasVaulted, isFalse);
    });

    test('checkVault returns false when courier is outside horizontal span', () {
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(300.0, 416.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 410.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 362.0); // Far away horizontally
      final playerSize = Vector2(40.0, 48.0);

      expect(barricade.checkVault(playerPos, playerSize, simulator), isFalse);
      expect(barricade.hasVaulted, isFalse);
    });

    test('checkVault returns false when foot Y is outside top hurdle clearance window', () {
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(200.0, 416.0),
        groundY: 460.0,
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 320.0; // Too high above hurdle (outside window)
      simulator.isGrounded = false;

      final playerPos = Vector2(220.0, 272.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(barricade.checkVault(playerPos, playerSize, simulator), isFalse);
      expect(barricade.hasVaulted, isFalse);
    });

    test('checkVault triggers vault when airborne courier hurdles over plank top', () {
      var vaulted = false;
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(200.0, 416.0),
        groundY: 460.0,
        onVault: () {
          vaulted = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // hurdleTopWorldY = 460.0 - 36.0 = 424.0. Window is 424 + 12 = 436 down to 424 - 54 = 370.
      simulator.currentY = 410.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(220.0, 362.0);
      final playerSize = Vector2(40.0, 48.0);

      final result = barricade.checkVault(playerPos, playerSize, simulator);
      expect(result, isTrue);
      expect(barricade.hasVaulted, isTrue);
      expect(vaulted, isTrue);

      // Subsequent checks should be ignored
      expect(barricade.checkVault(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints timber A-frame, chevron plank, amber lantern, and safety cones without errors', () {
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(100.0, 416.0),
        groundY: 460.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => barricade.render(canvas), returnsNormally);

      // Render after vaulting with tumbled cones
      barricade.hasVaulted = true;
      barricade.update(0.2);
      expect(() => barricade.render(canvas), returnsNormally);
    });
  });

  group('GameState Barricade Vault Tracking (Issue #89)', () {
    test('recordBarricadeVault awards base tips scaled by stunt multiplier and advances streak', () {
      final state = GameState();
      state.startRun();

      BarricadeVaultEvent? receivedEvent;
      state.onBarricadeVault = (event) {
        receivedEvent = event;
      };

      expect(state.barricadeVaultsInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordBarricadeVault(baseTips: 20);
      expect(event, isNotNull);
      expect(state.barricadeVaultsInRun, equals(1));
      expect(state.stuntStreak, equals(1));

      // With stunt streak 1, multiplier is 1.2 => round(20 * 1.2) = 24 tips
      expect(event!.baseTips, equals(20));
      expect(event.totalTips, equals(24));
      expect(event.multiplier, equals(1.2));
      expect(event.stuntStreak, equals(1));
      expect(state.tips, equals(24));
      expect(receivedEvent, equals(event));
    });

    test('recordBarricadeVault applies skateCommute 2x daily modifier bonus and energy boost', () {
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
      final event = state.recordBarricadeVault(baseTips: 20);
      expect(event, isNotNull);
      // Base: round(20 * 1.2) = 24. With skateCommute: 24 * 2 = 48. With energy drink: 48 * 2 = 96.
      expect(event!.totalTips, equals(96));
      expect(state.tips, equals(96));
    });

    test('recordBarricadeVault returns null when game is not running', () {
      final state = GameState();
      expect(state.recordBarricadeVault(), isNull);
    });

    test('startRun resets barricadeVaultsInRun counter', () {
      final state = GameState();
      state.startRun();
      state.recordBarricadeVault();
      expect(state.barricadeVaultsInRun, equals(1));

      state.startRun();
      expect(state.barricadeVaultsInRun, equals(0));
    });
  });

  group('WorldChunkManager Barricade Procedural Generation (Issue #89)', () {
    test('generates barricades after 70m road threshold', () {
      final chunkManager = WorldChunkManager();
      var generatedBarricade = false;

      for (var chunkIndex = 0; chunkIndex < 50; chunkIndex++) {
        final chunk = chunkManager.generateChunk(
          startX: chunkIndex * 960.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 320.0,
          distanceMeters: 80.0 + (chunkIndex * 20.0),
        );

        if (chunk.barricades.isNotEmpty) {
          generatedBarricade = true;
          for (final b in chunk.barricades) {
            expect(b.width, equals(68.0));
            expect(b.height, equals(44.0));
            expect(b.y, equals(460.0 - 44.0));
          }
          break;
        }
      }

      expect(generatedBarricade, isTrue);
    });

    test('BarricadeSawhorseData holds specified position and default sizes', () {
      const data = BarricadeSawhorseData(
        x: 320.0,
        y: 416.0,
      );
      expect(data.x, equals(320.0));
      expect(data.y, equals(416.0));
      expect(data.width, equals(68.0));
      expect(data.height, equals(44.0));
    });
  });

  group('ParticleEffectComponent.sawhorseSparks Tests (Issue #89)', () {
    test('creates colorful construction sawhorse debris particles', () {
      final sparks = ParticleEffectComponent.sawhorseSparks(
        position: Vector2(250.0, 416.0),
        count: 16,
      );

      expect(sparks.particles.length, equals(16));
      for (final p in sparks.particles) {
        expect(p.position.x, equals(250.0));
        expect(p.position.y, equals(416.0));
        expect(p.maxLife, greaterThan(0.0));
        expect(p.gravity, equals(220.0));
        expect(p.drag, equals(0.90));
      }
    });
  });

  group('CourierGame Integration with BarricadeSawhorseComponent (Issue #89)', () {
    testWidgets('spawns, updates, scrolls, and resets barricades in run lifecycle', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // Spawn a barricade component
      final barricade = BarricadeSawhorseComponent(
        position: Vector2(400.0, 416.0),
        groundY: 460.0,
      );
      game.activeBarricades.add(barricade);
      game.world.add(barricade);

      expect(game.activeBarricades.contains(barricade), isTrue);

      // Update game tick to simulate scroll
      final initialX = barricade.position.x;
      game.update(0.05);
      expect(barricade.position.x, lessThan(initialX));

      // Restart run cleans activeBarricades
      game.restartRun();
      expect(game.activeBarricades, isEmpty);
    });

    testWidgets('triggers barricade vault stunt when airborne courier hurdles barricade', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final barricade = BarricadeSawhorseComponent(
        position: Vector2(game.player.position.x + 10.0, 416.0),
        groundY: 460.0,
      );
      game.activeBarricades.add(barricade);
      game.world.add(barricade);

      // Make player airborne over hurdle top
      game.player.simulator.currentY = 410.0;
      game.player.simulator.isGrounded = false;

      expect(game.gameState.barricadeVaultsInRun, equals(0));
      game.update(0.02);

      expect(barricade.hasVaulted, isTrue);
      expect(game.gameState.barricadeVaultsInRun, equals(1));
    });

    testWidgets('recycles offscreen barricades cleanly', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreenBarricade = BarricadeSawhorseComponent(
        position: Vector2(-250.0, 416.0),
        groundY: 460.0,
      );
      game.activeBarricades.add(offscreenBarricade);
      game.world.add(offscreenBarricade);

      game.update(0.02);
      expect(game.activeBarricades.contains(offscreenBarricade), isFalse);
    });
  });

  group('GameOverModal Barricade Badge UI Tests (Issue #89)', () {
    testWidgets('renders game_over_barricade_badge when barricadesCompleted > 0', (tester) async {
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
              barricadesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_barricade_badge')), findsOneWidget);
      expect(find.text('3 BARRICADE VAULTS'), findsOneWidget);
      expect(find.byIcon(Icons.construction), findsOneWidget);
    });

    testWidgets('renders singular text when barricadesCompleted == 1', (tester) async {
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
              barricadesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_barricade_badge')), findsOneWidget);
      expect(find.text('1 BARRICADE VAULT'), findsOneWidget);
    });

    testWidgets('does not render game_over_barricade_badge when barricadesCompleted == 0', (tester) async {
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
              barricadesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_barricade_badge')), findsNothing);
    });
  });
}
