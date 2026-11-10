import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/dumpster_component.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
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

DumpsterComponent _dumpsterAt(Vector2 position) => DumpsterComponent(
      position: position,
      width: 76.0,
      height: 50.0,
      groundY: 460.0,
    );

JumpPhysicsSimulator _airborneAt(double footY) {
  final sim = JumpPhysicsSimulator(groundY: 460.0);
  sim.isGrounded = false;
  sim.currentY = footY;
  sim.verticalVelocity = -30.0;
  return sim;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DumpsterComponent Unit Tests (Issue #124)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final dumpster = _dumpsterAt(Vector2(300.0, 410.0));

      expect(dumpster.size.x, equals(76.0));
      expect(dumpster.size.y, equals(50.0));
      expect(dumpster.groundY, equals(460.0));
      expect(dumpster.hasBounced, isFalse);
      expect(dumpster.lidSnapTimer, equals(0.0));
      expect(dumpster.shouldRecycle, isFalse);
      expect(dumpster.lidTopY, equals(410.0));
      expect(dumpster.currentLidAngle, closeTo(DumpsterComponent.lidRestAngle, 0.0001));
      expect(dumpster.centerWorldPosition, equals(Vector2(338.0, 435.0)));
      expect(dumpster.lidHingeWorld, equals(Vector2(338.0, 413.0)));
      expect(dumpster.bounceApexWorld, equals(Vector2(338.0, 396.0)));
    });

    test('the lids swing wide on a bounce and settle back to rest', () {
      final dumpster = _dumpsterAt(Vector2(300.0, 410.0));
      expect(dumpster.currentLidAngle, closeTo(0.26, 0.0001));

      dumpster.markBounced();
      dumpster.lidSnapTimer = DumpsterComponent.lidSnapDuration;
      expect(
        dumpster.currentLidAngle,
        closeTo(
          DumpsterComponent.lidRestAngle + DumpsterComponent.lidSnapAngle,
          0.0001,
        ),
        reason: 'the lids are flung widest the moment the spring snaps',
      );

      dumpster.update(DumpsterComponent.lidSnapDuration);
      expect(dumpster.lidSnapTimer, equals(0.0));
      expect(dumpster.currentLidAngle, closeTo(DumpsterComponent.lidRestAngle, 0.0001));
    });

    test('checkLidBounce ignores courier outside horizontal bounds', () {
      final dumpster = _dumpsterAt(Vector2(300.0, 410.0));

      final farLeft = dumpster.checkLidBounce(
        Vector2(100.0, 400.0),
        Vector2(32.0, 40.0),
        _airborneAt(400.0),
      );
      expect(farLeft, isFalse);

      final farRight = dumpster.checkLidBounce(
        Vector2(420.0, 400.0),
        Vector2(32.0, 40.0),
        _airborneAt(400.0),
      );
      expect(farRight, isFalse);
      expect(dumpster.hasBounced, isFalse);
    });

    test('checkLidBounce ignores courier outside the lid window', () {
      final dumpster = _dumpsterAt(Vector2(300.0, 410.0));

      // Well above the lid line.
      final tooHigh = dumpster.checkLidBounce(
        Vector2(310.0, 300.0),
        Vector2(32.0, 40.0),
        _airborneAt(350.0),
      );
      expect(tooHigh, isFalse);
      expect(dumpster.hasBounced, isFalse);
    });

    test('a grounded courier running past earns nothing and leaves the bin fresh', () {
      var bounces = 0;
      final dumpster = DumpsterComponent(
        position: Vector2(300.0, 410.0),
        width: 76.0,
        height: 50.0,
        groundY: 460.0,
        onBounce: () => bounces++,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final bounced = dumpster.checkLidBounce(
        Vector2(310.0, 420.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(bounced, isFalse);
      expect(dumpster.hasBounced, isFalse);
      expect(bounces, equals(0));
      expect(sim.verticalVelocity, equals(0.0));
    });

    test('an airborne courier on the lids launches and fires the callback once', () {
      var bounces = 0;
      final dumpster = DumpsterComponent(
        position: Vector2(300.0, 410.0),
        width: 76.0,
        height: 50.0,
        groundY: 460.0,
        onBounce: () => bounces++,
      );
      final sim = _airborneAt(400.0);

      final first = dumpster.checkLidBounce(
        Vector2(310.0, 380.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(first, isTrue);
      expect(dumpster.hasBounced, isTrue);
      expect(bounces, equals(1));
      expect(sim.verticalVelocity, equals(240.0));
      expect(dumpster.lidSnapTimer, equals(DumpsterComponent.lidSnapDuration));

      // A second contact on the same bin is ignored.
      final second = dumpster.checkLidBounce(
        Vector2(310.0, 380.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(second, isFalse);
      expect(bounces, equals(1));
    });

    test('recycles once fully past the left edge, and not before', () {
      final dumpster = _dumpsterAt(Vector2(-100.0, 410.0));
      expect(dumpster.shouldRecycle, isFalse,
          reason: 'a bin at -100 still reaches into view from the near side');

      dumpster.position = Vector2(-260.0, 410.0);
      expect(dumpster.shouldRecycle, isTrue);
    });
  });

  group('ParticleEffectComponent.dumpsterSparks Tests (Issue #124)', () {
    test('spawns exactly the requested particle count', () {
      final effect = ParticleEffectComponent.dumpsterSparks(
        position: Vector2(300, 400),
        count: 24,
        random: math.Random(7),
      );

      expect(effect.particles.length, equals(24));
      for (final p in effect.particles) {
        expect(p.radius, greaterThan(0.0));
        expect(p.maxLife, greaterThan(0.0));
      }
    });

    test('every particle comes from the dumpster palette', () {
      const palette = {
        0xFFB0BEC5, // Aluminum lid flake
        0xFFCFD8DC, // Bright steel sliver
        0xFF76FF03, // Lime recycled-bottle glint
        0xFFAEEA00, // Lime sparkle highlight
        0xFF4E342E, // Rubber hinge dust
        0xFF616161, // Grease fleck
      };
      final effect = ParticleEffectComponent.dumpsterSparks(
        position: Vector2(300, 400),
        count: 60,
        random: math.Random(3),
      );

      for (final p in effect.particles) {
        expect(palette.contains(p.color.toARGB32()), isTrue,
            reason: '${p.color} is not a dumpster spark color');
      }
    });
  });

  group('GameState Dumpster Bounce Tests (Issue #124)', () {
    test('records a bounce, pays streak-scaled tips, and fires the callback', () {
      final state = GameState()..startRun();

      DumpsterEvent? event;
      state.onDumpsterBounce = (e) => event = e;

      final tipsBefore = state.tips;
      final returned = state.recordDumpsterBounce();

      expect(returned, isNotNull);
      expect(event, isNotNull);
      expect(returned!.baseTips, equals(35));
      expect(returned.totalTips, greaterThanOrEqualTo(35));
      expect(state.tips, greaterThan(tipsBefore));
      expect(state.dumpsterBouncesInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(returned.stuntStreak, equals(1));
      expect(returned.bouncesInRun, equals(1));
    });

    test('counts successive bounces and resets on a new run', () {
      final state = GameState()..startRun();
      state.recordDumpsterBounce();
      state.recordDumpsterBounce();
      expect(state.dumpsterBouncesInRun, equals(2));

      state.startRun();
      expect(state.dumpsterBouncesInRun, equals(0));
    });

    test('no bounce is recorded once the run is over', () {
      final state = GameState()..startRun();
      state.status = GameStatus.gameOver;

      expect(state.recordDumpsterBounce(), isNull);
      expect(state.dumpsterBouncesInRun, equals(0));
    });
  });

  group('WorldChunkManager Dumpster Spawning Tests (Issue #124)', () {
    test('no dumpster spawns before 70 m', () {
      var anySpawned = false;
      for (var seed = 0; seed < 30 && !anySpawned; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 69.0,
        );
        anySpawned = chunk.dumpsters.isNotEmpty;
      }
      expect(anySpawned, isFalse, reason: 'the gate opens at 70 m');
    });

    test('a dumpster is possible at 70 m and always clears other street pieces', () {
      var found = false;
      for (var seed = 0; seed < 40 && !found; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 70.0,
        );
        found = chunk.dumpsters.isNotEmpty;

        for (final d in chunk.dumpsters) {
          for (final o in chunk.obstacles) {
            final gap = (d.x + d.width < o.x) || (d.x > o.x + o.width);
            expect(gap, isTrue,
                reason: 'a dumpster must not share a hazard footprint');
          }
        }
      }
      expect(found, isTrue, reason: 'a dumpster must be possible at 70 m');
    });

    test('a station chunk never carries a dumpster', () {
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
            expect(chunk.dumpsters, isEmpty,
                reason: 'a dumpster must not sit on a station platform');
          }
        }
      }

      expect(stations, greaterThan(0), reason: 'the street must have stations');
    });
  });

  group('CourierGame Dumpster Integration Tests (Issue #124)', () {
    test('CourierGame spawns and clears activeDumpsters across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final dumpster = _dumpsterAt(Vector2(300.0, 410.0));
      game.activeDumpsters.add(dumpster);
      game.world.add(dumpster);

      expect(game.activeDumpsters.contains(dumpster), isTrue);
      expect(game.world.children.contains(dumpster), isTrue);

      game.restartRun();
      expect(game.activeDumpsters.contains(dumpster), isFalse);
      expect(game.world.children.contains(dumpster), isFalse);
    });

    test('DumpsterComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final dumpster = _dumpsterAt(Vector2(500.0, 410.0));
      game.activeDumpsters.add(dumpster);
      game.world.add(dumpster);

      final initialX = dumpster.position.x;
      game.update(0.1);
      expect(dumpster.position.x, lessThan(initialX));
    });

    test('a courier springing off the lids launches, earns tips, barks and sparks', () async {
      final backend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: backend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final barkLines = <String>[];
      game.audio.addCourierBarkListener((type, line) => barkLines.add(line));

      final dumpster = _dumpsterAt(
        Vector2(game.player.position.x + 10.0, 410.0),
      );
      game.activeDumpsters.add(dumpster);
      game.world.add(dumpster);

      // Coming down onto the lids with the feet inside the bounce window.
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 405.0;
      game.player.simulator.verticalVelocity = -30.0;

      final initialBounces = game.gameState.dumpsterBouncesInRun;
      game.update(0.016);

      expect(dumpster.hasBounced, isTrue);
      expect(game.gameState.dumpsterBouncesInRun, equals(initialBounces + 1));
      expect(game.player.simulator.verticalVelocity, equals(240.0));

      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(
        floatingTexts.any((ft) => ft.text.contains('DUMPSTER LID LAUNCH')),
        isTrue,
      );
      expect(backend.playedSfx, contains(GameAudioController.sfxBarkStunt));
      expect(barkLines, contains('Trash to treasure!'));

      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(
        particles.any((p) => p.particles.length == 24),
        isTrue,
        reason: 'the dumpster sparks effect must be the one spawned',
      );
    });

    test('a grounded run-past awards nothing and leaves the bin fresh', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final dumpster = _dumpsterAt(
        Vector2(game.player.position.x + 10.0, 410.0),
      );
      game.activeDumpsters.add(dumpster);
      game.world.add(dumpster);

      final initialBounces = game.gameState.dumpsterBouncesInRun;
      game.update(0.016);

      expect(dumpster.hasBounced, isFalse);
      expect(game.gameState.dumpsterBouncesInRun, equals(initialBounces));
    });
  });

  group('GameOverModal Dumpster Badge Tests (Issue #124)', () {
    testWidgets('hides game_over_dumpster_badge when 0 bounces', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            dumpstersCompleted: 0,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_dumpster_badge')), findsNothing);
    });

    testWidgets('renders the singular badge when dumpstersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            dumpstersCompleted: 1,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_dumpster_badge')), findsOneWidget);
      expect(find.text('1 DUMPSTER LAUNCH'), findsOneWidget);
    });

    testWidgets('renders the plural badge when dumpstersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            dumpstersCompleted: 3,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_dumpster_badge')), findsOneWidget);
      expect(find.text('3 DUMPSTER LAUNCHES'), findsOneWidget);
    });
  });
}
