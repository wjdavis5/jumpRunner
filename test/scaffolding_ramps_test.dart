import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/ramp_component.dart';
import 'package:jump_runner/game/components/scaffolding_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JumpPhysicsSimulator Elevated Surface Tests (Issue #38)', () {
    late JumpPhysicsSimulator simulator;
    const groundY = 460.0;
    const scaffoldingY = 340.0;

    setUp(() {
      simulator = JumpPhysicsSimulator(groundY: groundY);
    });

    test('initializes with targetSurfaceY at groundY', () {
      expect(simulator.currentSurfaceY, equals(groundY));
      expect(simulator.currentY, equals(groundY));
      expect(simulator.isGrounded, isTrue);
    });

    test('launch applies upward velocity impulse', () {
      simulator.launch(520.0);
      expect(simulator.isGrounded, isFalse);
      expect(simulator.verticalVelocity, equals(520.0));

      simulator.update(0.1);
      expect(simulator.currentY, lessThan(groundY));
    });

    test('lands on elevated surface when descending', () {
      simulator.launch(520.0);
      simulator.setSurfaceY(scaffoldingY);

      // Simulate apex and descent
      for (int i = 0; i < 40; i++) {
        simulator.update(0.02);
      }

      // Should land on elevated surface at 340.0
      expect(simulator.isGrounded, isTrue);
      expect(simulator.currentY, equals(scaffoldingY));
      expect(simulator.verticalVelocity, equals(0.0));
    });

    test('stepping off elevated surface causes courier to drop under gravity', () {
      simulator.launch(520.0);
      simulator.setSurfaceY(scaffoldingY);

      // Land on scaffolding
      for (int i = 0; i < 40; i++) {
        simulator.update(0.02);
      }
      expect(simulator.isGrounded, isTrue);
      expect(simulator.currentY, equals(scaffoldingY));

      // Courier walks off edge
      simulator.resetSurfaceY();
      expect(simulator.isGrounded, isFalse);

      // Updates under gravity back down to groundY
      for (int i = 0; i < 40; i++) {
        simulator.update(0.02);
      }

      expect(simulator.isGrounded, isTrue);
      expect(simulator.currentY, equals(groundY));
    });
  });

  group('RampComponent & ScaffoldingComponent Unit Tests', () {
    test('RampComponent collision detection and launch impulse', () {
      final ramp = RampComponent(
        position: Vector2(200.0, 424.0),
        size: Vector2(74.0, 36.0),
        launchImpulse: 420.0,
      );

      final player = CourierPlayer(
        groundY: 460.0,
        initialX: 220.0,
      );

      expect(ramp.launchImpulse, equals(420.0));
      expect(ramp.hasLaunched, isFalse);
      expect(ramp.checkCollisionWith(player), isTrue);

      ramp.hasLaunched = true;
      expect(ramp.checkCollisionWith(player), isFalse);
    });

    test('ScaffoldingComponent surfaceY and canvas rendering', () {
      final scaffolding = ScaffoldingComponent(
        position: Vector2(300.0, 330.0),
        size: Vector2(400.0, 12.0),
        groundY: 460.0,
      );

      expect(scaffolding.surfaceY, equals(330.0));
      expect(scaffolding.shouldRecycle, isFalse);

      scaffolding.position.x = -600.0;
      expect(scaffolding.shouldRecycle, isTrue);

      // Procedural canvas render
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => scaffolding.render(canvas), returnsNormally);
    });

    test('RampComponent procedural canvas rendering', () {
      final ramp = RampComponent(
        position: Vector2(100.0, 424.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => ramp.render(canvas), returnsNormally);
    });
  });

  group('WorldChunkManager Aerial Route Generation', () {
    test('ChunkData includes scaffoldings and ramps lists', () {
      final manager = WorldChunkManager(random: math.Random(1));
      final chunk = manager.generateChunk(
        startX: 0.0,
        speed: 200.0,
        distanceMeters: 0.0,
      );

      expect(chunk.scaffoldings, isNotNull);
      expect(chunk.ramps, isNotNull);
    });

    test('generates aerial scaffolding with high-reward gold rush', () {
      // Create generator with seed that triggers aerial route
      WorldChunkManager? foundManager;
      ChunkData? aerialChunk;

      for (int seed = 0; seed < 50; seed++) {
        final m = WorldChunkManager(random: math.Random(seed));
        final c = m.generateChunk(
          startX: 1000.0,
          speed: 300.0,
          distanceMeters: 300.0,
        );
        if (c.scaffoldings.isNotEmpty && c.ramps.isNotEmpty) {
          foundManager = m;
          aerialChunk = c;
          break;
        }
      }

      expect(foundManager, isNotNull);
      expect(aerialChunk, isNotNull);
      expect(aerialChunk!.ramps.length, equals(1));
      expect(aerialChunk.scaffoldings.length, equals(1));

      final scaffolding = aerialChunk.scaffoldings.first;
      expect(scaffolding.y, equals(460.0 - 120.0)); // 340.0
      expect(scaffolding.width, greaterThanOrEqualTo(200.0));

      // Pickups placed along elevated scaffolding deck
      final elevatedPickups = aerialChunk.pickups.where(
        (p) => p.y < 350.0,
      );
      expect(elevatedPickups, isNotEmpty);
    });
  });

  group('CourierGame Scaffolding Traversal & Camera Juice', () {
    test('CourierGame spawns and handles ramp boost and elevated scaffolding', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final ramp = RampComponent(
        position: Vector2(game.player.position.x - 10.0, 424.0),
        size: Vector2(74.0, 36.0),
      );
      final scaffolding = ScaffoldingComponent(
        position: Vector2(game.player.position.x - 20.0, 340.0),
        size: Vector2(400.0, 12.0),
        groundY: 460.0,
      );

      game.activeRamps.add(ramp);
      game.world.add(ramp);
      game.activeScaffolding.add(scaffolding);
      game.world.add(scaffolding);

      // Trigger update frame to step onto ramp
      game.update(0.016);

      expect(ramp.hasLaunched, isTrue);
      expect(game.world.children.whereType<FloatingTextComponent>().any(
        (t) => t.text == 'RAMP BOOST!',
      ), isTrue);

      // Land on scaffolding
      for (int i = 0; i < 40; i++) {
        game.update(0.02);
      }

      expect(game.player.isElevated, isTrue);
      expect(game.cameraTargetY, lessThan(CourierGame.virtualResolution.y / 2));

      // Move past scaffolding to drop back down to sidewalk
      scaffolding.position.x = -500.0;
      for (int i = 0; i < 40; i++) {
        game.update(0.02);
      }

      expect(game.player.isElevated, isFalse);
      expect(game.player.simulator.currentY, equals(CourierGame.groundY));
    });

    test('restartRun cleans up active scaffolding and ramps', () async {
      final game = CourierGame();
      await game.onLoad();

      final ramp = RampComponent(position: Vector2(200, 424));
      final scaffolding = ScaffoldingComponent(position: Vector2(280, 330), size: Vector2(300, 12));
      game.activeRamps.add(ramp);
      game.world.add(ramp);
      game.activeScaffolding.add(scaffolding);
      game.world.add(scaffolding);

      expect(game.activeRamps.length, equals(1));
      expect(game.activeScaffolding.length, equals(1));

      game.restartRun();

      expect(game.activeRamps, isEmpty);
      expect(game.activeScaffolding, isEmpty);
      expect(game.world.children.whereType<RampComponent>(), isEmpty);
      expect(game.world.children.whereType<ScaffoldingComponent>(), isEmpty);
    });
  });
}
