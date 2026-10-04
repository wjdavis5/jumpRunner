import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/hvac_wind_tunnel_component.dart';
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

  group('HvacWindTunnelComponent Unit Tests (Issue #74)', () {
    test('initializes with default dimensions, position, and un-awarded state', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(250.0, 350.0),
        housingWidth: 54.0,
        housingHeight: 54.0,
        windLength: 260.0,
        groundY: 460.0,
      );

      expect(tunnel.position.x, equals(250.0));
      expect(tunnel.position.y, equals(350.0));
      expect(tunnel.housingWidth, equals(54.0));
      expect(tunnel.housingHeight, equals(54.0));
      expect(tunnel.windLength, equals(260.0));
      expect(tunnel.size.x, equals(54.0 + 260.0));
      expect(tunnel.size.y, equals(54.0));
      expect(tunnel.groundY, equals(460.0));
      expect(tunnel.hasAwarded, isFalse);
      expect(tunnel.shouldRecycle, isFalse);
      expect(tunnel.fanCenterWorld.x, equals(250.0 + 27.0));
      expect(tunnel.fanCenterWorld.y, equals(350.0 + 27.0));
    });

    test('calculates correct windStreamWorldRect bounds', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(100.0, 300.0),
        housingWidth: 50.0,
        housingHeight: 50.0,
        windLength: 200.0,
      );

      final rect = tunnel.windStreamWorldRect;
      expect(rect.left, equals(150.0));
      expect(rect.right, equals(350.0));
      expect(rect.top, equals(288.0)); // 300 - 12
      expect(rect.bottom, equals(362.0)); // 300 + 50 + 12
    });

    test('shouldRecycle triggers when tunnel has scrolled completely offscreen', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(-450.0, 350.0),
        housingWidth: 54.0,
        windLength: 260.0,
      );

      expect(tunnel.shouldRecycle, isTrue);
    });

    test('isInWindStream detects player center inside wind stream cone', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(100.0, 300.0),
        housingWidth: 50.0,
        housingHeight: 50.0,
        windLength: 200.0,
        groundY: 460.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      // Courier foot at currentY = 340, playerSize = (40, 40) => center Y = 320 (within 288..362)
      simulator.currentY = 340.0;
      simulator.isGrounded = false;

      // Player X: position 180 + 20 = 200 (within 150..350)
      final playerPos = Vector2(180.0, 300.0);
      final playerSize = Vector2(40.0, 40.0);

      expect(tunnel.isInWindStream(playerPos, playerSize, simulator), isTrue);
    });

    test('isInWindStream returns false when player is outside stream horizontal range', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(100.0, 300.0),
        housingWidth: 50.0,
        housingHeight: 50.0,
        windLength: 200.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);
      simulator.currentY = 340.0;

      // Player before the turbine intake (x < 150)
      expect(
        tunnel.isInWindStream(Vector2(80.0, 300.0), Vector2(40.0, 40.0), simulator),
        isFalse,
      );

      // Player beyond the wind cone tail (x > 350)
      expect(
        tunnel.isInWindStream(Vector2(400.0, 300.0), Vector2(40.0, 40.0), simulator),
        isFalse,
      );
    });

    test('isInWindStream returns false when player is outside stream vertical range', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(100.0, 300.0),
        housingWidth: 50.0,
        housingHeight: 50.0,
        windLength: 200.0,
      );

      final simulator = JumpPhysicsSimulator(groundY: 460.0);

      // Player too high above wind cone
      simulator.currentY = 250.0;
      expect(
        tunnel.isInWindStream(Vector2(200.0, 210.0), Vector2(40.0, 40.0), simulator),
        isFalse,
      );

      // Player on ground beneath wind cone
      simulator.currentY = 460.0;
      expect(
        tunnel.isInWindStream(Vector2(200.0, 420.0), Vector2(40.0, 40.0), simulator),
        isFalse,
      );
    });

    test('renders turbine casing, rotating blades, streamlines, and LED without throwing', () {
      final tunnel = HvacWindTunnelComponent(
        position: Vector2(100.0, 300.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      tunnel.update(0.016);
      tunnel.render(canvas);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('ParticleEffectComponent Wind Debris Tests (Issue #74)', () {
    test('windDebris factory creates buoyant aerodynamic particles', () {
      final debris = ParticleEffectComponent.windDebris(
        position: Vector2(300.0, 320.0),
        count: 15,
      );

      expect(debris.particles.length, equals(15));
      for (final p in debris.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, inInclusiveRange(-10.0, 10.0)); // near-neutral buoyancy with gentle vortex flutter
        expect(p.velocity.x, greaterThan(100.0)); // forward wind drift
      }
    });

    test('windDebris particles update and conclude lifetime', () {
      final debris = ParticleEffectComponent.windDebris(
        position: Vector2(300.0, 320.0),
        count: 5,
      );

      debris.update(0.2);
      expect(debris.isFinished, isFalse);

      debris.update(1.5);
      expect(debris.isFinished, isTrue);
    });
  });

  group('GameState Wind Tunnel Stunt Mechanics (Issue #74)', () {
    test('recordWindTunnelGlide awards base tips and advances streak', () {
      final gameState = GameState();
      gameState.startRun();

      expect(gameState.windTunnelGlidesInRun, equals(0));
      expect(gameState.stuntStreak, equals(0));

      final event = gameState.recordWindTunnelGlide(baseTips: 25);

      expect(event, isNotNull);
      expect(gameState.windTunnelGlidesInRun, equals(1));
      expect(gameState.stuntStreak, equals(1));
      expect(gameState.stuntMultiplier, equals(1.2));
      // Base tip 25 * 1.2 = 30
      expect(event!.baseTips, equals(25));
      expect(event.totalTips, equals(30));
      expect(gameState.tips, equals(30));
    });

    test('recordWindTunnelGlide scales with higher stunt combo multiplier', () {
      final gameState = GameState();
      gameState.startRun();

      gameState.recordWindTunnelGlide(); // streak 1: 1.2x -> 30
      gameState.recordWindTunnelGlide(); // streak 2: 1.5x -> (25 * 1.5).round() = 38
      final event3 = gameState.recordWindTunnelGlide(); // streak 3: 2.0x -> 50

      expect(gameState.stuntStreak, equals(3));
      expect(event3!.multiplier, equals(2.0));
      expect(event3.totalTips, equals(50));
    });

    test('recordWindTunnelGlide doubles tips during skateCommute daily shift', () {
      final gameState = GameState();
      gameState.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      final event = gameState.recordWindTunnelGlide(baseTips: 25);
      // Base 25 * 1.2 = 30, * 2 skateCommute = 60
      expect(event!.totalTips, equals(60));
      expect(gameState.tips, equals(60));
    });

    test('recordWindTunnelGlide doubles tips when energy boost active', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.activateEnergyDrink(8.0);

      final event = gameState.recordWindTunnelGlide(baseTips: 25);
      // Base 25 * 1.2 = 30, * 2 energy = 60
      expect(event!.totalTips, equals(60));
      expect(gameState.tips, equals(60));
    });

    test('recordWindTunnelGlide dispatches onWindTunnelGlide callback', () {
      final gameState = GameState();
      gameState.startRun();

      WindTunnelGlideEvent? receivedEvent;
      gameState.onWindTunnelGlide = (e) => receivedEvent = e;

      gameState.recordWindTunnelGlide(baseTips: 25);

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.baseTips, equals(25));
      expect(receivedEvent!.stuntStreak, equals(1));
    });

    test('recordWindTunnelGlide returns null when game not running', () {
      final gameState = GameState();
      expect(gameState.recordWindTunnelGlide(), isNull);
    });

    test('startRun resets windTunnelGlidesInRun to 0', () {
      final gameState = GameState();
      gameState.startRun();
      gameState.recordWindTunnelGlide();
      expect(gameState.windTunnelGlidesInRun, equals(1));

      gameState.startRun();
      expect(gameState.windTunnelGlidesInRun, equals(0));
    });
  });

  group('WorldChunkManager HVAC Wind Tunnel Generation (Issue #74)', () {
    test('HvacWindTunnelData data model retains coordinates and dimensions', () {
      const data = HvacWindTunnelData(
        x: 450.0,
        y: 350.0,
        housingWidth: 54.0,
        housingHeight: 54.0,
        windLength: 260.0,
      );

      expect(data.x, equals(450.0));
      expect(data.y, equals(350.0));
      expect(data.housingWidth, equals(54.0));
      expect(data.housingHeight, equals(54.0));
      expect(data.windLength, equals(260.0));
    });

    test('ChunkData includes windTunnels list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        windTunnels: [
          HvacWindTunnelData(x: 200.0, y: 350.0),
        ],
      );

      expect(chunk.windTunnels.length, equals(1));
      expect(chunk.windTunnels.first.x, equals(200.0));
    });

    test('WorldChunkManager generates wind tunnels after 160m', () {
      final manager = WorldChunkManager();
      var generatedTunnel = false;

      // Seed chunks past 160m to verify generation
      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 400.0 + (i * 960.0),
          speed: 250.0,
          groundY: 460.0,
          distanceMeters: 200.0,
        );
        if (chunk.windTunnels.isNotEmpty) {
          generatedTunnel = true;
          final wt = chunk.windTunnels.first;
          expect(wt.windLength, equals(260.0));
          expect(wt.y, equals(460.0 - 110.0));
          break;
        }
      }

      expect(generatedTunnel, isTrue);
    });
  });

  group('CourierGame Wind Tunnel Integration & Physics (Issue #74)', () {
    test('spawning chunk populates activeWindTunnels and attaches to world', () async {
      final game = CourierGame();
      await game.onLoad();

      expect(game.activeWindTunnels, isNotNull);
    });

    test('restartRun cleans up activeWindTunnels', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final tunnel = HvacWindTunnelComponent(
        position: Vector2(200.0, 350.0),
      );
      game.activeWindTunnels.add(tunnel);
      game.world.add(tunnel);

      expect(game.activeWindTunnels.length, equals(1));

      game.restartRun();
      expect(game.activeWindTunnels.isEmpty, isTrue);
    });

    test('update loop scrolls activeWindTunnels to the left', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final tunnel = HvacWindTunnelComponent(
        position: Vector2(300.0, 350.0),
      );
      game.activeWindTunnels.add(tunnel);

      game.currentSpeed = 200.0;
      game.update(0.1); // scrolls 200 * 0.1 = 20 px

      expect(tunnel.position.x, closeTo(280.0, 0.01));
    });

    test('player in wind stream receives hover updraft and triggers stunt bonus', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final tunnel = HvacWindTunnelComponent(
        position: Vector2(playerInitialX, 350.0),
        housingWidth: 54.0,
        windLength: 260.0,
      );
      game.activeWindTunnels.add(tunnel);

      // Position player inside stream cone
      game.player.position = Vector2(playerInitialX + 80.0, 340.0);
      game.player.simulator.currentY = 390.0;
      game.player.simulator.isGrounded = false;
      game.player.simulator.verticalVelocity = -40.0; // falling

      expect(tunnel.hasAwarded, isFalse);

      game.update(0.016);

      // Hover updraft applied
      expect(game.player.simulator.verticalVelocity, greaterThanOrEqualTo(50.0));
      expect(tunnel.hasAwarded, isTrue);
      expect(game.gameState.windTunnelGlidesInRun, equals(1));
    });

    test('recycling removes offscreen wind tunnels', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final offscreenTunnel = HvacWindTunnelComponent(
        position: Vector2(-500.0, 350.0),
      );
      game.activeWindTunnels.add(offscreenTunnel);

      game.update(0.016);
      expect(game.activeWindTunnels.contains(offscreenTunnel), isFalse);
    });
  });

  group('GameOverModal Wind Tunnel Badge UI (Issue #74)', () {
    testWidgets('does not show wind tunnel badge when 0 glides completed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              onRestart: () {},
              windTunnelGlidesCompleted: 0,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_wind_tunnel_badge')), findsNothing);
    });

    testWidgets('shows singular wind tunnel badge when 1 glide completed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 520,
              tips: 180,
              isNewRecord: false,
              careerTips: 1300,
              onRestart: () {},
              windTunnelGlidesCompleted: 1,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_wind_tunnel_badge')), findsOneWidget);
      expect(find.text('1 WIND TUNNEL GLIDE'), findsOneWidget);
      expect(find.byIcon(Icons.air), findsOneWidget);
    });

    testWidgets('shows plural wind tunnel badge when multiple glides completed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 850,
              tips: 340,
              isNewRecord: true,
              careerTips: 1800,
              onRestart: () {},
              windTunnelGlidesCompleted: 4,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_wind_tunnel_badge')), findsOneWidget);
      expect(find.text('4 WIND TUNNEL GLIDES'), findsOneWidget);
    });
  });
}

const double playerInitialX = 80.0;
