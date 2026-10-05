import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/steam_vent_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SteamVentComponent Unit Tests (Issue #46)', () {
    test('initializes with default dimensions and updraft parameters', () {
      final vent = SteamVentComponent(position: Vector2(300.0, 444.0));
      expect(vent.size.x, equals(48.0));
      expect(vent.size.y, equals(16.0));
      expect(vent.updraftHeight, equals(220.0));
      expect(vent.updraftVelocity, equals(380.0));
      expect(vent.hasTriggeredBoost, isFalse);
      expect(vent.shouldRecycle, isFalse);

      vent.position.x = -250.0;
      expect(vent.shouldRecycle, isTrue);
    });

    test('isInUpdraft accurately detects courier footprint within thermal column', () {
      final vent = SteamVentComponent(
        position: Vector2(200.0, 444.0),
        size: Vector2(48.0, 16.0),
        updraftHeight: 220.0,
      );

      // Centered directly in updraft at mid-height (y = 350)
      expect(
        vent.isInUpdraft(Vector2(200.0, 300.0), Vector2(48.0, 50.0)),
        isTrue,
      );

      // Foot touching sidewalk grate surface
      expect(
        vent.isInUpdraft(Vector2(200.0, 394.0), Vector2(48.0, 50.0)),
        isTrue,
      );

      // Outside horizontal column to the left
      expect(
        vent.isInUpdraft(Vector2(100.0, 300.0), Vector2(48.0, 50.0)),
        isFalse,
      );

      // Outside horizontal column to the right
      expect(
        vent.isInUpdraft(Vector2(320.0, 300.0), Vector2(48.0, 50.0)),
        isFalse,
      );

      // Way above updraft ceiling (higher than 220px plume)
      expect(
        vent.isInUpdraft(Vector2(200.0, 100.0), Vector2(48.0, 50.0)),
        isFalse,
      );
    });

    test('procedural canvas rendering of grate and steam plumes executes cleanly', () {
      final vent = SteamVentComponent(position: Vector2(100.0, 444.0));
      vent.update(0.1);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => vent.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('JumpPhysicsSimulator Gliding & Updraft Physics (Issue #46)', () {
    test('applyUpdraft accelerates upward velocity up to maximum speed limit', () {
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.applyUpdraft(380.0);

      expect(sim.isGrounded, isFalse);
      expect(sim.verticalVelocity, equals(380.0));

      // Updraft with lower velocity doesn't reduce current upward momentum
      sim.applyUpdraft(200.0);
      expect(sim.verticalVelocity, equals(380.0));
    });

    test('isGliding drastically softens gravity and clamps terminal descent rate', () {
      final standardSim = JumpPhysicsSimulator(groundY: 460.0);
      final glidingSim = JumpPhysicsSimulator(groundY: 460.0);

      standardSim.currentY = 250.0;
      standardSim.isGrounded = false;
      glidingSim.currentY = 250.0;
      glidingSim.isGrounded = false;
      glidingSim.isGliding = true;

      // Update both across 1 second of freefall
      for (var i = 0; i < 60; i++) {
        standardSim.update(1.0 / 60.0);
        glidingSim.update(1.0 / 60.0);
      }

      // Standard freefall drops fast under 980 px/s²
      expect(standardSim.currentY, greaterThan(glidingSim.currentY));
      // Gliding descent is capped at gentle -55 px/s
      expect(glidingSim.verticalVelocity, equals(-55.0));
    });

    test('touching ground automatically cancels isGliding', () {
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.currentY = 455.0;
      sim.isGrounded = false;
      sim.isGliding = true;

      sim.update(0.1);
      expect(sim.isGrounded, isTrue);
      expect(sim.isGliding, isFalse);
    });
  });

  group('CourierPlayer Gliding State Machine (Issue #46)', () {
    test('deployGlide and toggleGlide transition into CourierState.gliding', () {
      var glideStarted = false;
      final player = CourierPlayer(
        groundY: 460.0,
        onGlideStarted: () => glideStarted = true,
      );
      player.simulator.isGrounded = false;

      final deployed = player.deployGlide();
      expect(deployed, isTrue);
      expect(player.state, equals(CourierState.gliding));
      expect(player.isGliding, isTrue);
      expect(player.simulator.isGliding, isTrue);
      expect(glideStarted, isTrue);

      // Toggling while gliding stows the chute
      final toggled = player.toggleGlide();
      expect(toggled, isTrue);
      expect(player.state, equals(CourierState.falling));
      expect(player.isGliding, isFalse);
      expect(player.simulator.isGliding, isFalse);
    });

    test('landing on surface automatically concludes glide and notifies onGlideEnded', () {
      var glideEnded = false;
      final player = CourierPlayer(
        groundY: 460.0,
        onGlideEnded: () => glideEnded = true,
      );

      player.simulator.currentY = 450.0;
      player.simulator.isGrounded = false;
      player.startGlide();
      expect(player.isGliding, isTrue);

      // Step physics until grounded
      for (var i = 0; i < 20; i++) {
        player.update(0.05);
      }

      expect(player.simulator.isGrounded, isTrue);
      expect(player.state, equals(CourierState.running));
      expect(player.isGliding, isFalse);
      expect(glideEnded, isTrue);
    });

    test('taking damage while gliding interrupts glide chute', () {
      var glideEnded = false;
      final player = CourierPlayer(
        groundY: 460.0,
        onGlideEnded: () => glideEnded = true,
      );

      player.simulator.isGrounded = false;
      player.startGlide();
      expect(player.isGliding, isTrue);

      player.takeDamage();
      expect(player.state, equals(CourierState.hurt));
      expect(player.isGliding, isFalse);
      expect(player.simulator.isGliding, isFalse);
      expect(glideEnded, isTrue);
    });

    test('procedural rendering in gliding state executes cleanly', () {
      final player = CourierPlayer();
      player.simulator.isGrounded = false;
      player.startGlide();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => player.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('GameState Steam Vent & Glide Scoring (Issue #46)', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState();
      gameState.startRun();
    });

    test('recordSteamVentBoost advances stunt streak and awards tips', () {
      SteamVentEvent? receivedEvent;
      gameState.onSteamVent = (event) => receivedEvent = event;

      final event = gameState.recordSteamVentBoost();
      expect(event, isNotNull);
      expect(receivedEvent, equals(event));
      expect(gameState.steamBoostsInRun, equals(1));
      expect(gameState.stuntStreak, equals(1));
      // Base tip 20 * 1.2 (streak 1) = 24
      expect(event!.totalTips, equals(24));
      expect(gameState.tips, equals(24));
    });

    test('recordGlide calculates tips based on glide distance and multiplier', () {
      GlideEvent? receivedEvent;
      gameState.onGlide = (event) => receivedEvent = event;

      // Glide for 12 meters: base tip = round(12 * 1.5) = 18. Streak 1 mult 1.2 => 22 tips
      final event = gameState.recordGlide(glideDistanceMeters: 12.0);
      expect(event, isNotNull);
      expect(receivedEvent, equals(event));
      expect(event!.glideDistanceMeters, equals(12.0));
      expect(gameState.glidesInRun, equals(1));
      expect(gameState.stuntStreak, equals(1));
      expect(event.totalTips, equals(22));
      expect(gameState.tips, equals(22));
    });

    test('recordGlide rejects trivial glides under 5 meters', () {
      final event = gameState.recordGlide(glideDistanceMeters: 3.5);
      expect(event, isNull);
      expect(gameState.glidesInRun, equals(0));
      expect(gameState.tips, equals(0));
    });

    test('startRun resets steamBoostsInRun and glidesInRun', () {
      gameState.recordSteamVentBoost();
      gameState.recordGlide(glideDistanceMeters: 10.0);
      expect(gameState.steamBoostsInRun, equals(1));
      expect(gameState.glidesInRun, equals(1));

      gameState.startRun();
      expect(gameState.steamBoostsInRun, equals(0));
      expect(gameState.glidesInRun, equals(0));
    });
  });

  group('WorldChunkManager Steam Vent Spawning (Issue #46)', () {
    test('procedurally generates steam vents after 150m with vertical trail pickups', () {
      var foundVentChunk = false;

      for (var seed = 0; seed < 100; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        final chunk = manager.generateChunk(
          startX: 1000.0,
          speed: 300.0,
          distanceMeters: 200.0,
        );

        if (chunk.steamVents.isNotEmpty) {
          foundVentChunk = true;
          final vent = chunk.steamVents.first;
          expect(vent.width, equals(48.0));
          expect(vent.height, equals(16.0));
          expect(vent.updraftHeight, equals(220.0));

          // Verifies vertical pickups hovering in the steam column
          final plumePickups = chunk.pickups.where(
            (p) => p.x >= vent.x - 5.0 && p.x <= vent.x + vent.width + 5.0,
          );
          expect(plumePickups, isNotEmpty);
          break;
        }
      }

      expect(foundVentChunk, isTrue);
    });
  });

  group('CourierGame Steam Vent & Glide Traversal Integration (Issue #46)', () {
    late CourierGame game;

    setUp(() async {
      game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
    });

    tearDown(() {
      game.gameState.status = GameStatus.idle;
    });

    test('contact with steam vent updraft imparts upward velocity and awards STEAM BOOST', () {
      final vent = SteamVentComponent(
        position: Vector2(game.player.position.x, CourierGame.groundY - 16.0),
        size: Vector2(48.0, 16.0),
        updraftHeight: 220.0,
      );
      game.activeSteamVents.add(vent);
      game.world.add(vent);

      expect(vent.hasTriggeredBoost, isFalse);

      // Advance game loop
      game.update(0.016);

      expect(vent.hasTriggeredBoost, isTrue);
      expect(game.gameState.steamBoostsInRun, equals(1));
      expect(game.player.simulator.verticalVelocity, greaterThanOrEqualTo(350.0));

      // Floating text should be spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('STEAM BOOST!')), isTrue);
    });

    test('jumping while airborne toggles glide and accumulates glide distance', () {
      // Launch player into mid-air
      game.player.simulator.launch(300.0);
      game.update(0.05);

      expect(game.player.simulator.isGrounded, isFalse);
      expect(game.player.isGliding, isFalse);

      // Mid-air jump key / tap deploys glide
      final handled = game.player.toggleGlide();
      expect(handled, isTrue);
      expect(game.player.isGliding, isTrue);

      // Advance world to accumulate glide distance
      final initialGlideDistance = game.player.glideDistance;
      game.update(0.1);
      expect(game.player.glideDistance, greaterThan(initialGlideDistance));
    });

    test('restartRun cleans up active steam vents and resets counters', () {
      final vent = SteamVentComponent(
        position: Vector2(game.player.position.x, CourierGame.groundY - 16.0),
      );
      game.activeSteamVents.add(vent);
      game.world.add(vent);

      game.gameState.recordSteamVentBoost();
      game.gameState.recordGlide(glideDistanceMeters: 8.0);
      expect(game.gameState.steamBoostsInRun, equals(1));
      expect(game.gameState.glidesInRun, equals(1));

      game.restartRun();
      expect(game.gameState.steamBoostsInRun, equals(0));
      expect(game.gameState.glidesInRun, equals(0));
      expect(game.activeSteamVents.contains(vent), isFalse);
    });
  });

  group('GameOverModal Aerial Glides Badge UI Tests (Issue #46)', () {
    testWidgets('GameOverModal displays game_over_glides_badge when glidesCompleted > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 650,
              tips: 140,
              careerTips: 800,
              isNewRecord: false,
              glidesCompleted: 4,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_glides_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('4 AERIAL GLIDES'), findsOneWidget);
    });

    testWidgets('GameOverModal formats singular glide badge correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 45,
              careerTips: 300,
              isNewRecord: false,
              glidesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_glides_badge')), findsOneWidget);
      expect(find.text('1 AERIAL GLIDE'), findsOneWidget);
    });

    testWidgets('GameOverModal hides game_over_glides_badge when glidesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 45,
              careerTips: 300,
              isNewRecord: false,
              glidesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_glides_badge')), findsNothing);
    });
  });
}
