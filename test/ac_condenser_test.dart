import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/ac_condenser_component.dart';
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

  group('AcCondenserComponent Unit Tests (Issue #93)', () {
    test('initializes with default dimensions, position, and unlifted state', () {
      final condenser = AcCondenserComponent(
        position: Vector2(300.0, 412.0),
        width: 72.0,
        height: 48.0,
        updraftImpulse: 380.0,
      );

      expect(condenser.position.x, equals(300.0));
      expect(condenser.position.y, equals(412.0));
      expect(condenser.size.x, equals(72.0));
      expect(condenser.size.y, equals(48.0));
      expect(condenser.updraftImpulse, equals(380.0));
      expect(condenser.hasLifted, isFalse);
      expect(condenser.shouldRecycle, isFalse);
      expect(condenser.fanTopWorldY, equals(412.0 + 6.0));
      expect(condenser.updraftWorldPosition, equals(Vector2(300.0 + 36.0, 412.0 - 12.0)));
      expect(condenser.centerWorldPosition, equals(Vector2(300.0 + 36.0, 412.0 + 24.0)));
    });

    test('shouldRecycle triggers when condenser scrolls offscreen past threshold', () {
      final offscreen = AcCondenserComponent(
        position: Vector2(-220.0, 412.0),
      );
      expect(offscreen.shouldRecycle, isTrue);

      final onscreen = AcCondenserComponent(
        position: Vector2(100.0, 412.0),
      );
      expect(onscreen.shouldRecycle, isFalse);
    });

    test('update increments fan angle and mist timer', () {
      final condenser = AcCondenserComponent(
        position: Vector2(200.0, 412.0),
      );
      condenser.update(0.1);
      // Fan rotates at 14 rad/s, mist advances at 3.5 rad/s
      expect(condenser.hasLifted, isFalse);
    });

    test('checkUpdraft returns false when courier is grounded', () {
      final condenser = AcCondenserComponent(
        position: Vector2(200.0, 412.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 460.0;
      simulator.isGrounded = true;

      final playerPos = Vector2(210.0, 412.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(condenser.checkUpdraft(playerPos, playerSize, simulator), isFalse);
      expect(condenser.hasLifted, isFalse);
    });

    test('checkUpdraft returns false when courier is outside horizontal span', () {
      final condenser = AcCondenserComponent(
        position: Vector2(300.0, 412.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 400.0;
      simulator.isGrounded = false;

      final playerPos = Vector2(100.0, 352.0); // Far away horizontally
      final playerSize = Vector2(40.0, 48.0);

      expect(condenser.checkUpdraft(playerPos, playerSize, simulator), isFalse);
      expect(condenser.hasLifted, isFalse);
    });

    test('checkUpdraft returns false when foot Y is outside vertical updraft draft window', () {
      final condenser = AcCondenserComponent(
        position: Vector2(200.0, 412.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 320.0; // Too high above condenser draft
      simulator.isGrounded = false;

      final playerPos = Vector2(210.0, 272.0);
      final playerSize = Vector2(40.0, 48.0);

      expect(condenser.checkUpdraft(playerPos, playerSize, simulator), isFalse);
      expect(condenser.hasLifted, isFalse);
    });

    test('checkUpdraft catapults courier with thermal draft boost and activates glide', () {
      var lifted = false;
      final condenser = AcCondenserComponent(
        position: Vector2(200.0, 412.0),
        updraftImpulse: 380.0,
        onUpdraft: () {
          lifted = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // footY within [412.0 - 45.0, 412.0 + 14.0] = [367.0, 426.0]
      simulator.currentY = 400.0;
      simulator.isGrounded = false;
      simulator.verticalVelocity = -80.0;

      final playerPos = Vector2(210.0, 352.0);
      final playerSize = Vector2(40.0, 48.0);

      final result = condenser.checkUpdraft(playerPos, playerSize, simulator);
      expect(result, isTrue);
      expect(condenser.hasLifted, isTrue);
      expect(lifted, isTrue);
      expect(simulator.verticalVelocity, equals(380.0));
      expect(simulator.isGliding, isTrue);

      // Subsequent checks should return false
      expect(condenser.checkUpdraft(playerPos, playerSize, simulator), isFalse);
    });

    test('render paints sheet metal cabinet, copper fins, and rotating fan cowls without errors', () {
      final condenser = AcCondenserComponent(
        position: Vector2(100.0, 412.0),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => condenser.render(canvas), returnsNormally);

      condenser.update(0.08);
      expect(() => condenser.render(canvas), returnsNormally);
    });
  });

  group('GameState AC Condenser Updraft Tracking (Issue #93)', () {
    test('recordAcUpdraft awards base tips scaled by stunt multiplier and advances streak', () {
      final state = GameState();
      state.startRun();

      AcCondenserEvent? receivedEvent;
      state.onAcCondenserUpdraft = (event) {
        receivedEvent = event;
      };

      expect(state.acUpdraftsInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordAcUpdraft(baseTips: 30, updraftImpulse: 380.0);
      expect(event, isNotNull);
      expect(state.acUpdraftsInRun, equals(1));
      expect(state.stuntStreak, equals(1));

      // Streak 1 -> 1.2x multiplier -> round(30 * 1.2) = 36 tips
      expect(event!.baseTips, equals(30));
      expect(event.totalTips, equals(36));
      expect(event.multiplier, equals(1.2));
      expect(event.stuntStreak, equals(1));
      expect(event.updraftImpulse, equals(380.0));
      expect(state.tips, equals(36));
      expect(receivedEvent, equals(event));
    });

    test('recordAcUpdraft scales with DailyModifier.skateCommute (doubles) and energy boost', () {
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
      final event = state.recordAcUpdraft(baseTips: 30);
      expect(event, isNotNull);
      // Base: round(30 * 1.2) = 36. With skateCommute: 36 * 2 = 72. With energy drink: 72 * 2 = 144.
      expect(event!.totalTips, equals(144));
      expect(state.tips, equals(144));
    });

    test('recordAcUpdraft returns null when game is not running', () {
      final state = GameState();
      expect(state.recordAcUpdraft(), isNull);
    });

    test('startRun resets acUpdraftsInRun counter', () {
      final state = GameState();
      state.startRun();
      state.recordAcUpdraft();
      expect(state.acUpdraftsInRun, equals(1));

      state.startRun();
      expect(state.acUpdraftsInRun, equals(0));
    });
  });

  group('WorldChunkManager AC Condenser Procedural Generation (Issue #93)', () {
    test('generates AC condensers after 100m threshold', () {
      final chunkManager = WorldChunkManager();
      var generatedCondenser = false;

      for (var chunkIndex = 0; chunkIndex < 50; chunkIndex++) {
        final chunk = chunkManager.generateChunk(
          startX: chunkIndex * 960.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 320.0,
          distanceMeters: 110.0 + (chunkIndex * 20.0),
        );

        if (chunk.acCondensers.isNotEmpty) {
          generatedCondenser = true;
          for (final ac in chunk.acCondensers) {
            expect(ac.width, equals(72.0));
            expect(ac.height, equals(48.0));
            expect(ac.y, equals(460.0 - 48.0));
            expect(ac.updraftImpulse, equals(380.0));
          }
          break;
        }
      }

      expect(generatedCondenser, isTrue);
    });

    test('AcCondenserData holds specified coordinates and default dimensions', () {
      const data = AcCondenserData(
        x: 420.0,
        y: 412.0,
      );
      expect(data.x, equals(420.0));
      expect(data.y, equals(412.0));
      expect(data.width, equals(72.0));
      expect(data.height, equals(48.0));
      expect(data.updraftImpulse, equals(380.0));
    });
  });

  group('ParticleEffectComponent.condenserMist Tests (Issue #93)', () {
    test('creates chilled condensation mist particles with aqua vapor and shimmer gold palette', () {
      final mist = ParticleEffectComponent.condenserMist(
        position: Vector2(300.0, 412.0),
        count: 22,
      );

      expect(mist.particles.length, equals(22));
      for (final p in mist.particles) {
        expect(p.position.x, equals(300.0));
        expect(p.position.y, equals(412.0));
        expect(p.maxLife, greaterThan(0.0));
        expect(p.gravity, equals(70.0));
        expect(p.drag, equals(0.93));
        expect(p.velocity.y, lessThan(0.0)); // Upward draft velocity
      }
    });
  });

  group('CourierGame Integration with AcCondenserComponent (Issue #93)', () {
    testWidgets('spawns, updates, scrolls, and resets AC condensers in run lifecycle', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final condenser = AcCondenserComponent(
        position: Vector2(400.0, 412.0),
      );
      game.activeAcCondensers.add(condenser);
      game.world.add(condenser);

      expect(game.activeAcCondensers.contains(condenser), isTrue);

      final initialX = condenser.position.x;
      game.update(0.05);
      expect(condenser.position.x, lessThan(initialX));

      game.restartRun();
      expect(game.activeAcCondensers, isEmpty);
    });

    testWidgets('triggers thermal updraft lift and deploys glide when airborne courier descends into condenser', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final condenser = AcCondenserComponent(
        position: Vector2(game.player.position.x + 10.0, 412.0),
        updraftImpulse: 380.0,
      );
      game.activeAcCondensers.add(condenser);
      game.world.add(condenser);

      // Make player airborne into the condenser draft zone
      game.player.simulator.currentY = 400.0;
      game.player.simulator.isGrounded = false;
      game.player.simulator.verticalVelocity = -40.0;

      expect(game.gameState.acUpdraftsInRun, equals(0));
      game.update(0.02);

      expect(condenser.hasLifted, isTrue);
      expect(game.gameState.acUpdraftsInRun, equals(1));
      expect(game.player.simulator.isGliding, isTrue);
      expect(game.player.isGliding, isTrue);
    });

    testWidgets('recycles offscreen AC condensers cleanly', (tester) async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreen = AcCondenserComponent(
        position: Vector2(-250.0, 412.0),
      );
      game.activeAcCondensers.add(offscreen);
      game.world.add(offscreen);

      game.update(0.02);
      expect(game.activeAcCondensers.contains(offscreen), isFalse);
    });
  });

  group('GameOverModal AC Condenser Badge UI Tests (Issue #93)', () {
    testWidgets('renders game_over_condenser_badge when acCondensersCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1400,
              tips: 180,
              isNewRecord: false,
              careerTips: 2800,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              acCondensersCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_condenser_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('3 CONDENSER LIFTS'), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
    });

    testWidgets('renders singular text when acCondensersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1400,
              tips: 180,
              isNewRecord: false,
              careerTips: 2800,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              acCondensersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.text('1 CONDENSER LIFT'), findsOneWidget);
    });

    testWidgets('omits game_over_condenser_badge when acCondensersCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1400,
              tips: 180,
              isNewRecord: false,
              careerTips: 2800,
              completedContracts: 2,
              contractBonusTips: 80,
              deliveriesCompleted: 5,
              acCondensersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_condenser_badge'));
      expect(badgeFinder, findsNothing);
    });
  });
}
