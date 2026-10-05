import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/food_cart_component.dart';
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

  group('FoodCartComponent Tests (Issue #65)', () {
    test('initializes with default dimensions, bounce impulse, and unbounced state', () {
      final cart = FoodCartComponent(
        position: Vector2(300.0, 382.0),
        groundY: 460.0,
      );

      expect(cart.size.x, equals(88.0));
      expect(cart.size.y, equals(78.0));
      expect(cart.groundY, equals(460.0));
      expect(cart.bounceImpulse, equals(400.0));
      expect(cart.hasBounced, isFalse);
      expect(cart.shouldRecycle, isFalse);
    });

    test('umbrellaApexWorld returns accurate world coordinate at center-top of canopy', () {
      final cart = FoodCartComponent(
        position: Vector2(200.0, 350.0),
      );

      expect(cart.umbrellaApexWorld.x, equals(200.0 + 44.0));
      expect(cart.umbrellaApexWorld.y, equals(350.0 + 4.0));
    });

    test('checkBounce returns false when player is grounded or ascending', () {
      final cart = FoodCartComponent(
        position: Vector2(200.0, 382.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);

      // Player is grounded
      simulator.isGrounded = true;
      expect(
        cart.checkBounce(Vector2(244.0, 390.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );

      // Player is mid-air ascending rapidly
      simulator.isGrounded = false;
      simulator.verticalVelocity = 300.0;
      expect(
        cart.checkBounce(Vector2(244.0, 390.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );
    });

    test('checkBounce returns false when player is out of canopy horizontal or vertical reach', () {
      final cart = FoodCartComponent(
        position: Vector2(200.0, 382.0),
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.isGrounded = false;
      simulator.verticalVelocity = -100.0; // Falling downward

      // Foot X far to the left
      simulator.currentY = cart.umbrellaTopWorldY;
      expect(
        cart.checkBounce(Vector2(100.0, 342.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );

      // Foot X far to the right
      expect(
        cart.checkBounce(Vector2(400.0, 342.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );

      // Foot Y far above canopy
      simulator.currentY = cart.umbrellaTopWorldY - 50.0;
      expect(
        cart.checkBounce(Vector2(228.0, 290.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );

      // Foot Y far below canopy
      simulator.currentY = cart.umbrellaTopWorldY + 60.0;
      expect(
        cart.checkBounce(Vector2(228.0, 400.0), Vector2(32.0, 48.0), simulator),
        isFalse,
      );
    });

    test('checkBounce triggers launch impulse, sets hasBounced, and invokes callback', () {
      var didTriggerCallback = false;
      final cart = FoodCartComponent(
        position: Vector2(200.0, 382.0),
        bounceImpulse: 420.0,
        onBounce: () {
          didTriggerCallback = true;
        },
      );
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.isGrounded = false;
      simulator.verticalVelocity = -150.0; // Descending
      simulator.currentY = cart.umbrellaTopWorldY + 2.0;

      // Player centered over umbrella: cart.position.x = 200, center = 244
      // Player pos x = 228, width = 32 -> footX = 244
      final result = cart.checkBounce(
        Vector2(228.0, cart.umbrellaTopWorldY - 46.0),
        Vector2(32.0, 48.0),
        simulator,
      );

      expect(result, isTrue);
      expect(cart.hasBounced, isTrue);
      expect(didTriggerCallback, isTrue);
      expect(simulator.verticalVelocity, equals(420.0));
      expect(simulator.isGrounded, isFalse);

      // Consecutive check does not re-trigger while hasBounced is true
      didTriggerCallback = false;
      final secondResult = cart.checkBounce(
        Vector2(228.0, cart.umbrellaTopWorldY - 46.0),
        Vector2(32.0, 48.0),
        simulator,
      );
      expect(secondResult, isFalse);
      expect(didTriggerCallback, isFalse);
    });

    test('shouldRecycle evaluates scroll boundary', () {
      final cart = FoodCartComponent(
        position: Vector2(50.0, 382.0),
      );
      expect(cart.shouldRecycle, isFalse);

      cart.position.x = -300.0;
      expect(cart.shouldRecycle, isTrue);
    });

    test('render executes cleanly without errors during idle and spring compression', () {
      final cart = FoodCartComponent(
        position: Vector2(100.0, 382.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Idle render
      cart.render(canvas);

      // Trigger bounce spring animation and render
      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.isGrounded = false;
      simulator.currentY = cart.umbrellaTopWorldY;
      cart.checkBounce(Vector2(128.0, 340.0), Vector2(32.0, 48.0), simulator);

      cart.update(0.1);
      cart.render(canvas);

      final pic = recorder.endRecording();
      pic.dispose();
    });
  });

  group('ParticleEffectComponent.spiceCloud Tests (Issue #65)', () {
    test('creates expected particle count with spice palette and physics', () {
      final effect = ParticleEffectComponent.spiceCloud(
        position: Vector2(250.0, 380.0),
        count: 16,
      );

      expect(effect.particles.length, equals(16));
      for (final p in effect.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(80.0));
        expect(p.drag, equals(1.4));
      }
    });
  });

  group('GameState Food Cart Bounce Tests (Issue #65)', () {
    test('foodCartBouncesInRun initializes to 0', () {
      final state = GameState();
      expect(state.foodCartBouncesInRun, equals(0));
    });

    test('recordFoodCartBounce returns null when not running', () {
      final state = GameState();
      state.status = GameStatus.idle;

      final event = state.recordFoodCartBounce();
      expect(event, isNull);
      expect(state.foodCartBouncesInRun, equals(0));
    });

    test('recordFoodCartBounce increments counters, advances streak, and fires callback', () {
      final state = GameState();
      state.startRun();

      FoodCartBounceEvent? received;
      state.onFoodCartBounce = (e) => received = e;

      // Base: 25; streak advances 0 -> 1 (multiplier 1.2x); 25 * 1.2 = 30
      final event = state.recordFoodCartBounce(baseTips: 25);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(25));
      expect(event.multiplier, equals(1.2));
      expect(event.totalTips, equals(30));
      expect(event.stuntStreak, equals(1));

      expect(state.foodCartBouncesInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(state.stuntStreakTimer, equals(GameState.stuntComboDuration));
      expect(state.tips, equals(30));
      expect(received, equals(event));
    });

    test('recordFoodCartBounce scales with high combo streak, energy boost, and skate commute', () {
      final state = GameState();
      state.startRun();
      state.stuntStreak = 4; // streak advances to 5 -> multiplier 2.5x
      state.activateEnergyDrink(8.0);

      // (25 * 2.5) = 63; doubled with energy boost to 126
      final event = state.recordFoodCartBounce(baseTips: 25);
      expect(event, isNotNull);
      expect(event!.totalTips, equals(126));
      expect(state.tips, equals(126));

      // Daily shift skate commute
      final dailyState = GameState();
      dailyState.startRun();
      dailyState.activeDailyShift = const DailyShift(
        dateString: '2026-10-04',
        modifier: DailyModifier.skateCommute,
        targetDistanceMeters: 1000,
        completionBonusTips: 100,
      );

      // Streak 1 (1.2x) -> 25 * 1.2 = 30; skate commute doubles to 60
      final dailyEvent = dailyState.recordFoodCartBounce(baseTips: 25);
      expect(dailyEvent, isNotNull);
      expect(dailyEvent!.totalTips, equals(60));
    });

    test('startRun resets foodCartBouncesInRun', () {
      final state = GameState();
      state.startRun();
      state.recordFoodCartBounce();
      expect(state.foodCartBouncesInRun, equals(1));

      state.startRun();
      expect(state.foodCartBouncesInRun, equals(0));
    });
  });

  group('WorldChunkManager Food Cart Spawning Tests (Issue #65)', () {
    test('FoodCartData model stores attributes', () {
      const data = FoodCartData(
        x: 350.0,
        y: 382.0,
        width: 88.0,
        height: 78.0,
        bounceImpulse: 420.0,
      );

      expect(data.x, equals(350.0));
      expect(data.y, equals(382.0));
      expect(data.width, equals(88.0));
      expect(data.height, equals(78.0));
      expect(data.bounceImpulse, equals(420.0));
    });

    test('ChunkData includes foodCarts list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        foodCarts: [
          FoodCartData(x: 200.0, y: 382.0),
        ],
      );

      expect(chunk.foodCarts.length, equals(1));
      expect(chunk.foodCarts.first.x, equals(200.0));
    });

    test('WorldChunkManager procedurally produces food carts at distance >= 60m', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var foundCart = false;

      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 400.0 + (i * 960.0),
          groundY: 460.0,
          speed: 240.0,
          distanceMeters: 100.0,
        );
        if (chunk.foodCarts.isNotEmpty) {
          foundCart = true;
          final fc = chunk.foodCarts.first;
          expect(fc.width, equals(88.0));
          expect(fc.height, equals(78.0));
          expect(fc.bounceImpulse, equals(400.0));
          break;
        }
      }

      expect(foundCart, isTrue);
    });
  });

  group('CourierGame Food Cart Integration Tests (Issue #65)', () {
    test('landing on umbrella cushion launches courier, awards tips, and spawns spice cloud', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final cart = FoodCartComponent(
        position: Vector2(200.0, 382.0),
        bounceImpulse: 400.0,
        groundY: 460.0,
      );
      game.activeFoodCarts.add(cart);
      game.world.add(cart);

      expect(game.activeFoodCarts.length, equals(1));
      expect(game.gameState.foodCartBouncesInRun, equals(0));

      // Position courier mid-air descending directly onto umbrella cushion
      game.player.position.x = 228.0;
      game.player.simulator.currentY = cart.umbrellaTopWorldY + 4.0;
      game.player.simulator.verticalVelocity = -120.0;
      game.player.simulator.isGrounded = false;

      game.update(0.05);

      expect(cart.hasBounced, isTrue);
      expect(game.gameState.foodCartBouncesInRun, equals(1));
      expect(game.gameState.tips, greaterThan(0));
      // Launched at the bounce impulse. A 50 ms frame is simulated as three
      // 60 Hz steps, so gravity has had up to 33 ms to act by the time we look.
      expect(game.player.simulator.verticalVelocity, closeTo(400.0, 40.0));

      // Visual floating text added
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('SPICY BOUNCE!')), isTrue);

      // Particle spice cloud added
      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(particles.isNotEmpty, isTrue);
    });

    test('recycles offscreen food carts and clears active list on restartRun', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreenCart = FoodCartComponent(
        position: Vector2(-350.0, 382.0),
      );
      game.activeFoodCarts.add(offscreenCart);
      game.world.add(offscreenCart);

      game.update(0.1);
      expect(game.activeFoodCarts, isEmpty);

      final freshCart = FoodCartComponent(
        position: Vector2(300.0, 382.0),
      );
      game.activeFoodCarts.add(freshCart);
      game.world.add(freshCart);
      expect(game.activeFoodCarts.length, equals(1));

      game.restartRun();
      expect(game.activeFoodCarts, isEmpty);
      expect(game.gameState.foodCartBouncesInRun, equals(0));
    });
  });

  group('GameOverModal Food Cart Badge UI Tests (Issue #65)', () {
    testWidgets('displays game_over_food_cart_badge with singular text when foodCartBouncesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1200,
              tips: 350,
              isNewRecord: false,
              careerTips: 1800,
              foodCartBouncesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_food_cart_badge')), findsOneWidget);
      expect(find.text('1 FOOD CART BOUNCE'), findsOneWidget);
    });

    testWidgets('displays game_over_food_cart_badge with plural text when foodCartBouncesCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 2200,
              tips: 920,
              isNewRecord: true,
              careerTips: 3100,
              foodCartBouncesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_food_cart_badge')), findsOneWidget);
      expect(find.text('3 FOOD CART BOUNCES'), findsOneWidget);
    });

    testWidgets('hides game_over_food_cart_badge when foodCartBouncesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 400,
              tips: 50,
              isNewRecord: false,
              careerTips: 250,
              foodCartBouncesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_food_cart_badge')), findsNothing);
    });
  });
}
