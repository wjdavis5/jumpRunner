import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/pigeon_flock_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PigeonFlockComponent Tests (Issue #58)', () {
    test('initializes with expected pigeon count, roosting state, and size', () {
      final flock = PigeonFlockComponent(
        position: Vector2(300.0, 446.0),
        pigeonCount: 6,
      );

      expect(flock.count, equals(6));
      expect(flock.pigeons.length, equals(6));
      expect(flock.isScattered, isFalse);
      expect(flock.hasAwardedStunt, isFalse);
      expect(flock.size.x, equals(70.0));
      expect(flock.size.y, equals(24.0));
    });

    test('scatter launches pigeons into the air with velocities and invokes callback', () {
      var didTriggerCallback = false;
      final flock = PigeonFlockComponent(
        position: Vector2(300.0, 446.0),
        onScatterTriggered: () {
          didTriggerCallback = true;
        },
      );

      flock.scatter();

      expect(flock.isScattered, isTrue);
      expect(didTriggerCallback, isTrue);
      for (final p in flock.pigeons) {
        expect(p.isAirborne, isTrue);
        expect(p.velocity.y, lessThan(0.0)); // Upward launch
      }

      // Subsequent call does not re-trigger
      didTriggerCallback = false;
      flock.scatter();
      expect(didTriggerCallback, isFalse);
    });

    test('checkProximity triggers scatter when courier enters radius', () {
      final flock = PigeonFlockComponent(
        position: Vector2(300.0, 446.0),
      );

      // 1. Courier is far away (at x = 100)
      flock.checkProximity(Vector2(100.0, 412.0), Vector2(32.0, 48.0));
      expect(flock.isScattered, isFalse);

      // 2. Courier enters within 145px (at x = 200)
      flock.checkProximity(Vector2(200.0, 412.0), Vector2(32.0, 48.0));
      expect(flock.isScattered, isTrue);
    });

    test('checkCourierIntersection awards stunt when player overlaps airborne pigeons', () {
      final flock = PigeonFlockComponent(
        position: Vector2(300.0, 446.0),
      );

      // Not scattered yet -> cannot award stunt
      expect(flock.checkCourierIntersection(Vector2(300.0, 440.0), Vector2(32.0, 48.0)), isFalse);

      flock.scatter();

      // Ensure at least one pigeon is placed near (310, 430)
      flock.pigeons.first.localPos = const Offset(10.0, -10.0);

      final didIntersect = flock.checkCourierIntersection(
        Vector2(300.0, 420.0),
        Vector2(32.0, 48.0),
      );
      expect(didIntersect, isTrue);
      expect(flock.hasAwardedStunt, isTrue);

      // Subsequent check does not double award
      final secondCheck = flock.checkCourierIntersection(
        Vector2(300.0, 420.0),
        Vector2(32.0, 48.0),
      );
      expect(secondCheck, isFalse);
    });

    test('update advances roosting peckTimer and airborne flapPhase/position', () {
      final flock = PigeonFlockComponent(
        position: Vector2(300.0, 446.0),
      );

      // Roosting update
      flock.update(0.1);
      for (final p in flock.pigeons) {
        expect(p.peckTimer, greaterThan(0.0));
      }

      // Airborne update
      flock.scatter();
      final initialY = flock.pigeons.first.localPos.dy;
      flock.update(0.1);
      expect(flock.pigeons.first.flapPhase, greaterThan(0.0));
      expect(flock.pigeons.first.localPos.dy, lessThan(initialY)); // Flew higher
    });

    test('renders procedural roosting and flying pigeons without errors', () {
      final flock = PigeonFlockComponent(
        position: Vector2(50.0, 50.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // 1. Roosting render
      expect(() => flock.render(canvas), returnsNormally);

      // 2. Flying render
      flock.scatter();
      expect(() => flock.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('shouldRecycle triggers when scrolled offscreen or after scatter duration', () {
      final flock = PigeonFlockComponent(
        position: Vector2(100.0, 446.0),
      );
      expect(flock.shouldRecycle, isFalse);

      // Offscreen left
      flock.position.x = -260.0;
      expect(flock.shouldRecycle, isTrue);

      // After scatter elapsed time > 3.0s
      final freshFlock = PigeonFlockComponent(
        position: Vector2(100.0, 446.0),
      );
      freshFlock.scatter();
      freshFlock.update(3.5);
      expect(freshFlock.shouldRecycle, isTrue);
    });
  });

  group('ParticleEffectComponent Feathers Tests (Issue #58)', () {
    test('creates feather particles with float physics and drag', () {
      final effect = ParticleEffectComponent.feathers(
        position: Vector2(200.0, 300.0),
        count: 10,
      );

      expect(effect.particles.length, equals(10));
      for (final p in effect.particles) {
        expect(p.drag, equals(1.8));
        expect(p.gravity, equals(45.0));
        expect(p.life, greaterThan(0.0));
      }

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => effect.render(canvas), returnsNormally);
      effect.update(0.1);
    });
  });

  group('GameState Pigeon Flock Scatter Tests (Issue #58)', () {
    test('initializes with zero pigeonScattersInRun', () {
      final gameState = GameState();
      expect(gameState.pigeonScattersInRun, equals(0));
    });

    test('recordPigeonScatter increments streak, awards combo-scaled tips, and triggers callback', () {
      final gameState = GameState();
      gameState.startRun();

      // Pre-set stunt streak
      gameState.recordStunt(clearance: 15.0); // stuntStreak = 1, multiplier = 1.2
      final previousTips = gameState.tips;

      FlockScatterEvent? eventReceived;
      gameState.onPigeonScatter = (event) {
        eventReceived = event;
      };

      final event = gameState.recordPigeonScatter(baseTips: 25);
      expect(event, isNotNull);
      expect(eventReceived, equals(event));
      expect(event!.baseTips, equals(25));
      expect(event.multiplier, equals(1.5)); // Stunt streak incremented to 2
      expect(event.totalTips, equals(38)); // (25 * 1.5).round() = 38
      expect(gameState.tips, equals(previousTips + 38));
      expect(gameState.pigeonScattersInRun, equals(1));
    });

    test('startRun resets pigeonScattersInRun', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.recordPigeonScatter();
      expect(gameState.pigeonScattersInRun, equals(1));

      gameState.startRun();
      expect(gameState.pigeonScattersInRun, equals(0));
    });
  });

  group('WorldChunkManager Pigeon Flock Spawning Tests (Issue #58)', () {
    test('PigeonFlockData stores coordinates and count', () {
      const data = PigeonFlockData(x: 350.0, y: 446.0, pigeonCount: 7);
      expect(data.x, equals(350.0));
      expect(data.y, equals(446.0));
      expect(data.pigeonCount, equals(7));
    });

    test('does not spawn pigeon flocks before 80 meters', () {
      final manager = WorldChunkManager();
      final chunk0 = manager.generateChunk(startX: 0.0, speed: 200.0, distanceMeters: 0.0);
      expect(chunk0.pigeonFlocks, isEmpty);
    });

    test('can generate chunk with pigeon flocks beyond 80 meters', () {
      var spawnedPigeons = false;
      for (var i = 0; i < 20; i++) {
        final manager = WorldChunkManager();
        final chunk = manager.generateChunk(startX: 1000.0, speed: 250.0, distanceMeters: 120.0);
        if (chunk.pigeonFlocks.isNotEmpty) {
          spawnedPigeons = true;
          final pf = chunk.pigeonFlocks.first;
          expect(pf.pigeonCount, greaterThanOrEqualTo(5));
          break;
        }
      }
      expect(spawnedPigeons, isTrue);
    });
  });

  group('CourierGame Pigeon Flock Integration Tests (Issue #58)', () {
    test('approaching flock triggers scatter and spawns feather particles', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      // Position courier at ground baseline
      game.player.position = Vector2(120.0, 460.0 - game.player.size.y);
      game.player.simulator.currentY = 460.0;
      game.player.simulator.isGrounded = true;

      // Add pigeon flock ahead within proximity radius (120 + 90 = 210px)
      final flock = PigeonFlockComponent(
        position: Vector2(210.0, 446.0),
      );
      game.activePigeonFlocks.add(flock);
      game.world.add(flock);

      expect(flock.isScattered, isFalse);

      // Run game update
      game.update(0.05);

      // Flock should have panicked and scattered!
      expect(flock.isScattered, isTrue);

      // Feathers effect spawned
      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(particles.isNotEmpty, isTrue);
    });

    test('mid-air leap through scattering flock awards flock scatter stunt and tips', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      game.player.position = Vector2(200.0, 400.0);
      game.player.simulator.currentY = 400.0;

      final flock = PigeonFlockComponent(
        position: Vector2(200.0, 420.0),
      );
      flock.scatter();
      flock.pigeons.first.localPos = const Offset(5.0, -10.0);

      game.activePigeonFlocks.add(flock);
      game.world.add(flock);

      game.update(0.05);

      expect(flock.hasAwardedStunt, isTrue);
      expect(game.gameState.pigeonScattersInRun, equals(1));
      expect(game.gameState.tips, greaterThan(0));

      // Visual floating text added
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('FLOCK SCATTER!')), isTrue);
    });

    test('recycles offscreen pigeon flocks and resets on restartRun', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final flock = PigeonFlockComponent(
        position: Vector2(-300.0, 446.0),
      );
      game.activePigeonFlocks.add(flock);
      game.world.add(flock);

      game.update(0.1);
      expect(game.activePigeonFlocks, isEmpty);

      final freshFlock = PigeonFlockComponent(
        position: Vector2(300.0, 446.0),
      );
      game.activePigeonFlocks.add(freshFlock);
      game.world.add(freshFlock);
      expect(game.activePigeonFlocks.length, equals(1));

      game.restartRun();
      expect(game.activePigeonFlocks, isEmpty);
      expect(game.gameState.pigeonScattersInRun, equals(0));
    });
  });

  group('GameOverModal Pigeon Badge UI Tests (Issue #58)', () {
    testWidgets('displays game_over_pigeons_badge with singular text when pigeonScattersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 1300,
              tips: 380,
              isNewRecord: false,
              careerTips: 1900,
              pigeonScattersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_pigeons_badge')), findsOneWidget);
      expect(find.text('1 PIGEON FLOCK SCATTER'), findsOneWidget);
    });

    testWidgets('displays game_over_pigeons_badge with plural text when pigeonScattersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 2100,
              tips: 840,
              isNewRecord: true,
              careerTips: 3200,
              pigeonScattersCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_pigeons_badge')), findsOneWidget);
      expect(find.text('3 PIGEON FLOCK SCATTERS'), findsOneWidget);
    });

    testWidgets('hides game_over_pigeons_badge when pigeonScattersCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 500,
              tips: 60,
              isNewRecord: false,
              careerTips: 300,
              pigeonScattersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_pigeons_badge')), findsNothing);
    });
  });
}
