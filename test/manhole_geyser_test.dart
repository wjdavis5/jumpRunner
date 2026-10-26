import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/manhole_geyser_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';

class MockAudioBackend implements AudioPlayerInterface {
  final List<String> playedSfx = [];

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    playedSfx.add(file);
  }

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {}

  @override
  Future<void> stopBgm() async {}

  @override
  Future<void> setBgmVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopAmbience() async {}

  @override
  Future<void> setAmbienceVolume(double volume) async {}

  @override
  Future<bool> startLayer(String file, {double volume = 0.0}) async => true;

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}

  @override
  Future<void> setLayerPlaybackRate(double rate) async {}
}

ManholeGeyserComponent _geyserAt(Vector2 position) => ManholeGeyserComponent(
      position: position,
      width: 48.0,
      height: 14.0,
      groundY: 460.0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ManholeGeyserComponent Unit Tests (Issue #84)', () {
    test('initializes with default dimensions and an idle state', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));

      expect(geyser.size.x, equals(48.0));
      expect(geyser.size.y, equals(14.0));
      expect(geyser.groundY, equals(460.0));
      expect(geyser.state, equals(ManholeGeyserState.idle));
      expect(geyser.rumbleTimer, equals(0.0));
      expect(geyser.shouldRecycle, isFalse);
      expect(geyser.centerWorldPosition, equals(Vector2(324.0, 453.0)));
      expect(geyser.rimCenterWorld, equals(Vector2(324.0, 453.0)));
    });

    test('proximity starts the rattle exactly once', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      // 148 px away: within the 180 px earshot.
      final first = geyser.checkGeyser(
        Vector2(160.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(first, equals(GeyserUpdate.rumblingStarted));
      expect(geyser.state, equals(ManholeGeyserState.rumbling));
      expect(geyser.rumbleTimer, closeTo(0.55, 0.001));

      // Still rumbling, not erupting yet (128 px away, past the trigger).
      final second = geyser.checkGeyser(
        Vector2(180.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(second, equals(GeyserUpdate.none));
      expect(geyser.state, equals(ManholeGeyserState.rumbling));
    });

    test('a courier far away never starts the rattle', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);

      final outcome = geyser.checkGeyser(
        Vector2(700.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(outcome, equals(GeyserUpdate.none));
      expect(geyser.state, equals(ManholeGeyserState.idle));
    });

    test('the rattle completes into an eruption after the countdown', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      geyser.checkGeyser(
        Vector2(160.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      // The courier stands off-column (48 px half width; 90 px away).
      var sawEruption = false;
      for (var i = 0; i < 80; i++) {
        geyser.update(0.016);
        final outcome = geyser.checkGeyser(
          Vector2(200.0, 420.0),
          Vector2(32.0, 40.0),
          sim,
        );
        if (outcome == GeyserUpdate.erupting) {
          sawEruption = true;
          break;
        }
      }

      expect(sawEruption, isTrue);
      expect(geyser.state, equals(ManholeGeyserState.erupted));
      expect(sim.verticalVelocity, equals(0.0),
          reason: 'a courier off the column is not launched');
    });

    test('a courier stepping onto the lid erupts it early and rides the blast', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      // Rumbling begins with the courier 148 px away.
      geyser.checkGeyser(
        Vector2(160.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      // The courier closes onto the lid inside the 70 px trigger range:
      // the eruption fires before the rattle finishes.
      final outcome = geyser.checkGeyser(
        Vector2(280.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(outcome, equals(GeyserUpdate.launched));
      expect(geyser.state, equals(ManholeGeyserState.erupted));
      expect(sim.verticalVelocity, equals(480.0));
      expect(sim.isGrounded, isFalse);
      expect(geyser.lidVelocityY, equals(-260.0));
    });

    test('an airborne courier in the column is caught too', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 380.0; // 80 px above ground, inside the 150 px catch.

      geyser.forceErupt();
      // forceErupt skips the courier check; drive the launch through the
      // public path instead on a fresh geyser.
      final geyser2 = _geyserAt(Vector2(300.0, 446.0));
      final outcome = geyser2.checkGeyser(
        Vector2(310.0, 360.0),
        Vector2(32.0, 40.0),
        sim,
      );

      // 10 px away starts the rumble, then step in range triggers it.
      final outcome2 = geyser2.checkGeyser(
        Vector2(305.0, 360.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(outcome2, equals(GeyserUpdate.launched));
      expect(sim.verticalVelocity, equals(480.0));
      expect(outcome, equals(GeyserUpdate.rumblingStarted));
    });

    test('a gliding courier high above the column is not yanked', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 250.0; // 210 px above ground, above the 150 px catch.

      // Proximity then in-range eruption.
      geyser.checkGeyser(
        Vector2(150.0, 240.0),
        Vector2(32.0, 40.0),
        sim,
      );
      final outcome = geyser.checkGeyser(
        Vector2(300.0, 240.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(outcome, equals(GeyserUpdate.erupting));
      expect(sim.verticalVelocity, equals(0.0));
    });

    test('an eruption never fires twice', () {
      final geyser = _geyserAt(Vector2(300.0, 446.0));
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final first = geyser.checkGeyser(
        Vector2(300.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );
      final outcome = geyser.checkGeyser(
        Vector2(300.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );
      final third = geyser.checkGeyser(
        Vector2(300.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(first, equals(GeyserUpdate.rumblingStarted));
      expect(outcome, equals(GeyserUpdate.launched));
      expect(third, equals(GeyserUpdate.none));
      expect(sim.verticalVelocity, equals(480.0),
          reason: 'the launch impulse was applied exactly once');
    });

    test('recycles once fully past the left edge, and not before', () {
      final geyser = _geyserAt(Vector2(-100.0, 446.0));
      expect(geyser.shouldRecycle, isFalse);

      geyser.position = Vector2(-260.0, 446.0);
      expect(geyser.shouldRecycle, isTrue);
    });
  });

  group('ParticleEffectComponent.geyserSteamBurst Tests (Issue #84)', () {
    test('spawns exactly the requested particle count', () {
      final effect = ParticleEffectComponent.geyserSteamBurst(
        position: Vector2(300, 450),
        count: 30,
        random: math.Random(11),
      );

      expect(effect.particles.length, equals(30));
    });

    test('the column climbs: every particle rises, none falls', () {
      final effect = ParticleEffectComponent.geyserSteamBurst(
        position: Vector2(300, 450),
        count: 40,
        random: math.Random(5),
      );

      for (final p in effect.particles) {
        expect(p.velocity.y, lessThan(0.0),
            reason: 'steam must rise from the rim');
        expect(p.gravity, lessThan(0.0),
            reason: 'the column is buoyant, not a falling spray');
      }
    });

    test('every particle comes from the geyser steam palette', () {
      const palette = {
        0xFFFFFFFF, // Steam core white
        0xFFECEFF1, // Billow grey-white
        0xFFCFD8DC, // Pressure cloud
        0xFFB0BEC5, // Deep steam shadow
        0xFF80DEEA, // Water droplet flash
        0xFFE0F7FA, // Droplet mist
      };
      final effect = ParticleEffectComponent.geyserSteamBurst(
        position: Vector2(300, 450),
        count: 60,
        random: math.Random(2),
      );

      for (final p in effect.particles) {
        expect(palette.contains(p.color.toARGB32()), isTrue,
            reason: '${p.color} is not a geyser steam color');
      }
    });
  });

  group('GameState Manhole Geyser Tests (Issue #84)', () {
    test('records a ride, pays streak-scaled tips, and fires the callback', () {
      final state = GameState()..startRun();

      ManholeGeyserEvent? event;
      state.onManholeGeyserEruption = (e) => event = e;

      final tipsBefore = state.tips;
      final returned = state.recordManholeGeyser();

      expect(returned, isNotNull);
      expect(event, isNotNull);
      expect(returned!.baseTips, equals(40));
      expect(returned.totalTips, greaterThanOrEqualTo(40));
      expect(state.tips, greaterThan(tipsBefore));
      expect(state.manholeGeysersInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(returned.stuntStreak, equals(1));
      expect(returned.geysersInRun, equals(1));
    });

    test('counts successive rides and resets on a new run', () {
      final state = GameState()..startRun();
      state.recordManholeGeyser();
      state.recordManholeGeyser();
      expect(state.manholeGeysersInRun, equals(2));

      state.startRun();
      expect(state.manholeGeysersInRun, equals(0));
    });

    test('no ride is recorded once the run is over', () {
      final state = GameState()..startRun();
      state.status = GameStatus.gameOver;

      expect(state.recordManholeGeyser(), isNull);
      expect(state.manholeGeysersInRun, equals(0));
    });
  });

  group('WorldChunkManager Manhole Spawning Tests (Issue #84)', () {
    test('no manhole spawns before 130 m', () {
      var anySpawned = false;
      for (var seed = 0; seed < 30 && !anySpawned; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 129.0,
        );
        anySpawned = chunk.manholeGeysers.isNotEmpty;
      }
      expect(anySpawned, isFalse, reason: 'the gate opens at 130 m');
    });

    test('a manhole is possible at 130 m and stays clear of storm drains', () {
      var found = false;
      for (var seed = 0; seed < 60 && !found; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 130.0,
        );
        found = chunk.manholeGeysers.isNotEmpty;

        for (final mg in chunk.manholeGeysers) {
          for (final sd in chunk.stormDrains) {
            final gap = (mg.x + mg.width < sd.x - 10.0) ||
                (mg.x > sd.x + sd.width + 10.0);
            expect(gap, isTrue,
                reason: 'two street plates must not overlap');
          }
        }
      }
      expect(found, isTrue, reason: 'a manhole must be possible at 130 m');
    });

    test('a station chunk never carries a manhole geyser', () {
      var stations = 0;

      for (var seed = 0; seed < 40 && stations < 20; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 3000.0 && stations < 20; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 1440.0,
            speed: manager.calculateSpeed(meters),
            distanceMeters: meters,
          );
          if (chunk.subwayStations.isNotEmpty) {
            stations++;
            expect(chunk.manholeGeysers, isEmpty,
                reason: 'a manhole must not sit on a station platform');
          }
        }
      }

      expect(stations, greaterThan(0), reason: 'the street must have stations');
    });
  });

  group('CourierGame Manhole Geyser Integration Tests (Issue #84)', () {
    test('CourierGame spawns and clears activeManholeGeysers across lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final geyser = _geyserAt(Vector2(300.0, 446.0));
      game.activeManholeGeysers.add(geyser);
      game.world.add(geyser);

      expect(game.activeManholeGeysers.contains(geyser), isTrue);
      expect(game.world.children.contains(geyser), isTrue);

      game.restartRun();
      expect(game.activeManholeGeysers.contains(geyser), isFalse);
      expect(game.world.children.contains(geyser), isFalse);
    });

    test('ManholeGeyserComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final geyser = _geyserAt(Vector2(500.0, 446.0));
      game.activeManholeGeysers.add(geyser);
      game.world.add(geyser);

      final initialX = geyser.position.x;
      game.update(0.1);
      expect(geyser.position.x, lessThan(initialX));
    });

    test('proximity rattles; the eruption pays a ride with coins and steam', () async {
      final backend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: backend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final barkLines = <String>[];
      game.audio.addCourierBarkListener((type, line) => barkLines.add(line));

      final geyser = _geyserAt(
        Vector2(game.player.position.x + 40.0, 446.0),
      );
      game.activeManholeGeysers.add(geyser);
      game.world.add(geyser);

      // Frame 1: proximity starts the rattle and plays the cue.
      game.update(0.016);
      expect(geyser.state, equals(ManholeGeyserState.rumbling));
      expect(backend.playedSfx, contains(GameAudioController.sfxManholeRattle));

      // The courier stands in the column: the eruption launches and pays.
      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;
      final initialRides = game.gameState.manholeGeysersInRun;
      game.update(0.016);

      expect(geyser.state, equals(ManholeGeyserState.erupted));
      expect(game.player.simulator.verticalVelocity, equals(480.0));
      expect(game.gameState.manholeGeysersInRun, equals(initialRides + 1));

      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(
        floatingTexts.any((ft) => ft.text.contains('MANHOLE GEYSER')),
        isTrue,
      );
      expect(barkLines, contains('Riding the tube!'));

      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(
        particles.any((p) => p.particles.length == 30),
        isTrue,
        reason: 'the steam column effect must be the one spawned',
      );

      // The coin ring: eight new pickups riding the blast.
      expect(game.activePickups.length, greaterThanOrEqualTo(8));
    });

    test('an eruption off-column spawns coins but pays nothing', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final geyser = _geyserAt(
        Vector2(game.player.position.x + 500.0, 446.0),
      );
      game.activeManholeGeysers.add(geyser);
      game.world.add(geyser);

      // Walk the courier near enough to rattle, but the eruption completes
      // with the courier off-column (they never close inside 70 px).
      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = 460.0;
      final initialRides = game.gameState.manholeGeysersInRun;

      for (var i = 0; i < 60 && geyser.state != ManholeGeyserState.erupted; i++) {
        game.update(0.016);
        // Hold the courier 90 px from the manhole center: inside earshot,
        // outside the trigger range, off the column.
        game.player.position = Vector2(geyser.position.x - 90.0, 420.0);
        game.player.simulator.currentY = 460.0;
      }

      expect(geyser.state, equals(ManholeGeyserState.erupted));
      expect(game.gameState.manholeGeysersInRun, equals(initialRides));
      expect(game.activePickups.length, greaterThanOrEqualTo(8),
          reason: 'the coin ring still rides the blast');
    });
  });

  group('GameOverModal Manhole Badge Tests (Issue #84)', () {
    testWidgets('hides game_over_manhole_badge when 0 rides', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            manholeGeysersCompleted: 0,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_manhole_badge')), findsNothing);
    });

    testWidgets('renders the singular badge when manholeGeysersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            manholeGeysersCompleted: 1,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_manhole_badge')), findsOneWidget);
      expect(find.text('1 GEYSER RIDE'), findsOneWidget);
    });

    testWidgets('renders the plural badge when manholeGeysersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            manholeGeysersCompleted: 2,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_manhole_badge')), findsOneWidget);
      expect(find.text('2 GEYSER RIDES'), findsOneWidget);
    });
  });
}
