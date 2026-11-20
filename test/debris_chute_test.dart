import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/debris_chute_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

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

const double groundY = 460.0;
const double deckY = groundY - 120.0;

DebrisChuteComponent _chuteAt(Vector2 position) => DebrisChuteComponent(
      position: position,
      width: 170.0,
      height: 120.0,
      groundY: groundY,
    );

/// The courier's foot center x on screen: the slide geometry is sampled there.
double footXOf(CourierGame game) =>
    game.player.position.x + (game.player.size.x / 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebrisChuteComponent Unit Tests (Issue #87)', () {
    test('initializes with geometry and an unslid state', () {
      final chute = _chuteAt(Vector2(200.0, deckY));

      expect(chute.size.x, equals(170.0));
      expect(chute.size.y, equals(120.0));
      expect(chute.groundY, equals(groundY));
      expect(chute.hasSlid, isFalse);
      expect(chute.shouldRecycle, isFalse);
      expect(chute.mouthWorld, Vector2(200.0, deckY));
      expect(chute.exitWorld, Vector2(370.0, groundY));
    });

    test('the slide surface runs from the hopper mouth to the sidewalk', () {
      final chute = _chuteAt(Vector2(200.0, deckY));

      expect(chute.surfaceYAt(200.0), closeTo(deckY, 0.001),
          reason: 'the mouth hangs at deck level');
      expect(chute.surfaceYAt(370.0), closeTo(groundY, 0.001),
          reason: 'the bottom mouth meets the street');
      expect(chute.surfaceYAt(285.0), closeTo(deckY + 60.0, 0.001),
          reason: 'the tube descends linearly');
      // Outside the tube the surface clamps to the nearer mouth.
      expect(chute.surfaceYAt(100.0), closeTo(deckY, 0.001));
      expect(chute.surfaceYAt(500.0), closeTo(groundY, 0.001));
    });

    test('debris tumbles on a steady clock', () {
      final chute = _chuteAt(Vector2(200.0, deckY));
      final before = chute.debrisPhase;
      chute.update(0.5);
      expect(chute.debrisPhase, greaterThan(before));
    });

    test('recycles once fully past the left edge, and not before', () {
      final chute = _chuteAt(Vector2(-100.0, deckY));
      expect(chute.shouldRecycle, isFalse,
          reason: 'the tube at -100 still reaches into view');

      chute.position = Vector2(-360.0, deckY);
      expect(chute.shouldRecycle, isTrue);
    });
  });

  group('WorldChunkManager Debris Chute Spawning Tests (Issue #87)', () {
    /// Finds a chunk whose scaffolding carries a debris chute, within [seeds].
    (WorldChunkManager, ChunkData, DebrisChuteData)? findChuteChunk(int seeds) {
      for (var seed = 0; seed < seeds; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 4000.0; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 1440.0,
            speed: manager.calculateSpeed(meters),
            distanceMeters: meters,
          );
          if (chunk.scaffoldings.isNotEmpty && chunk.debrisChutes.isNotEmpty) {
            return (manager, chunk, chunk.debrisChutes.first);
          }
        }
      }
      return null;
    }

    test('a debris chute only ever hangs off a scaffolding deck', () {
      var orphanChutes = 0;
      for (var seed = 0; seed < 40; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 4000.0; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 1440.0,
            speed: manager.calculateSpeed(meters),
            distanceMeters: meters,
          );
          if (chunk.debrisChutes.isNotEmpty && chunk.scaffoldings.isEmpty) {
            orphanChutes++;
          }
        }
      }
      expect(orphanChutes, equals(0),
          reason: 'a chute needs a deck to hang from');
    });

    test('a chute is possible, and its geometry rides the deck edge', () {
      final found = findChuteChunk(80);
      expect(found, isNotNull, reason: 'the street must carry chutes');
      final (_, chunk, chute) = found!;

      final deck = chunk.scaffoldings.first;
      expect(chute.y, equals(deck.y),
          reason: 'the hopper mouth hangs at deck level');
      expect(chute.x, greaterThanOrEqualTo(deck.x + deck.width - 6.0),
          reason: 'the mouth sits at the deck trailing edge');
      expect(chute.y + chute.height, closeTo(groundY, 0.001),
          reason: 'the bottom mouth meets the street');
      expect(chute.width, inInclusiveRange(156.0, 170.0));
    });

    test('the slide is lined with tips collected mid-descent', () {
      final found = findChuteChunk(80);
      expect(found, isNotNull);
      final (_, _, chute) = found!;

      final slideCoins = <PickupData>[];
      for (final p in found.$2.pickups) {
        final overSlide = p.x >= chute.x - 1.0 && p.x <= chute.x + chute.width + 1.0;
        final belowDeck = p.y > deckY - 1.0;
        if (overSlide && belowDeck) slideCoins.add(p);
      }
      expect(slideCoins.length, greaterThanOrEqualTo(2),
          reason: 'reward tips line the tube for the ride down');
      for (final p in slideCoins) {
        expect(p.y, lessThan(groundY - 20.0),
            reason: 'the tips sit above the street, along the tube');
      }
    });

    test('no debris chute spawns before the scaffolding gate at 150 m', () {
      var anyChute = false;
      for (var seed = 0; seed < 40 && !anyChute; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 149.0 && !anyChute; meters += 48.0) {
          final chunk = manager.generateChunk(
            startX: 0.0,
            chunkWidth: 960.0,
            groundY: groundY,
            speed: 200.0,
            distanceMeters: meters,
          );
          anyChute = chunk.debrisChutes.isNotEmpty;
        }
      }
      expect(anyChute, isFalse, reason: 'chutes inherit the 150 m scaffold gate');
    });
  });

  group('GameState Chute Slide Tests (Issue #87)', () {
    test('recording a slide pays base tips and counts it', () {
      final state = GameState();
      state.startRun();

      final before = state.tips;
      final event = state.recordChuteSlide(slideDistanceMeters: 8.5);

      expect(event, isNotNull);
      expect(event!.bonusTips, equals(12));
      expect(event.slideDistanceMeters, closeTo(8.5, 0.001));
      expect(state.chuteSlidesInRun, equals(1));
      expect(state.tips, equals(before + 12));
    });

    test('an energy boost doubles the slide tips', () {
      final state = GameState();
      state.startRun();
      state.energyDrinkTimer = 99.0;

      final event = state.recordChuteSlide(slideDistanceMeters: 8.5);
      expect(event!.bonusTips, equals(24));
    });

    test('a slide is only recorded mid-run', () {
      final state = GameState();
      expect(state.recordChuteSlide(slideDistanceMeters: 8.5), isNull);
      expect(state.chuteSlidesInRun, equals(0));
    });
  });

  group('CourierGame Debris Chute Integration Tests (Issue #87)', () {
    test('CourierGame spawns and clears activeDebrisChutes across lifecycle',
        () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final chute = _chuteAt(Vector2(900.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      expect(game.activeDebrisChutes.contains(chute), isTrue);
      expect(game.world.children.contains(chute), isTrue);

      game.restartRun();
      expect(game.activeDebrisChutes.contains(chute), isFalse);
      expect(game.world.children.contains(chute), isFalse);
    });

    test('DebrisChuteComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final chute = _chuteAt(Vector2(900.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      final initialX = chute.position.x;
      game.update(0.1);
      expect(chute.position.x, lessThan(initialX));
    });

    test('running off the deck catches the courier into the slide', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final fx = footXOf(game);
      // The mouth has just scrolled past the courier: they are stepping off
      // the deck, still grounded and elevated.
      final chute = _chuteAt(Vector2(fx - 12.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = deckY;
      game.player.setTargetSurfaceY(deckY);

      game.update(1 / 60);

      expect(game.player.isGrinding, isTrue,
          reason: 'the deck hands the courier straight into the tube');
      expect(game.player.simulator.isGrounded, isTrue);
      expect(game.player.simulator.currentY,
          closeTo(chute.surfaceYAt(footXOf(game)), 1.0));
    });

    test('the slide rides the tube down and lands at street level', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final fx = footXOf(game);
      final chute = _chuteAt(Vector2(fx - 12.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = deckY;
      game.player.setTargetSurfaceY(deckY);
      game.update(1 / 60);

      expect(game.player.isGrinding, isTrue);
      final startY = game.player.simulator.currentY;

      // Ride the whole tube: at 200 px/s the 182 px span takes about a second.
      var descended = false;
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
        if (!game.player.isGrinding) {
          descended = game.player.simulator.currentY > startY;
          break;
        }
      }

      expect(game.player.isGrinding, isFalse,
          reason: 'the bottom mouth releases the courier');
      expect(descended, isTrue,
          reason: 'the slide carried the courier down the tube');

      // The tube releases the courier a couple of pixels above the street;
      // the remaining drop lands them on the sidewalk.
      for (var i = 0; i < 12; i++) {
        game.update(1 / 60);
      }
      expect(game.player.simulator.currentY, closeTo(groundY, 0.5));
    });

    test('a full ride pays out tips and counts the slide', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final fx = footXOf(game);
      final chute = _chuteAt(Vector2(fx - 12.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = deckY;
      game.player.setTargetSurfaceY(deckY);

      final tipsBefore = game.gameState.tips;
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
        if (!game.player.isGrinding) break;
      }

      expect(game.gameState.chuteSlidesInRun, equals(1));
      expect(game.gameState.tips, equals(tipsBefore + 12));
    });

    test('jumping bail out mid-slide earns nothing', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final fx = footXOf(game);
      final chute = _chuteAt(Vector2(fx - 12.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = deckY;
      game.player.setTargetSurfaceY(deckY);
      game.update(1 / 60);
      expect(game.player.isGrinding, isTrue);

      final tipsBefore = game.gameState.tips;
      game.player.simulator.startJump(); // Bail out.
      game.update(1 / 60);

      expect(game.player.isGrinding, isFalse,
          reason: 'bailing ends the slide');
      expect(game.gameState.chuteSlidesInRun, equals(0));
      expect(game.gameState.tips, equals(tipsBefore));
    });

    test('a courier at street level walks under the tube untouched', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final fx = footXOf(game);
      // The tube's bottom sliver is still overhead: the surface line is close
      // enough to catch, but a street-level courier is not elevated.
      final chute = _chuteAt(Vector2(fx - 150.0, deckY));
      game.activeDebrisChutes.add(chute);
      game.world.add(chute);

      expect(chute.surfaceYAt(fx), greaterThan(groundY - 20.0),
          reason: 'the test stands under the bottom sliver of the tube');

      game.player.simulator.isGrounded = true;
      game.player.simulator.currentY = groundY;
      game.player.resetTargetSurfaceY();

      game.update(1 / 60);
      game.update(1 / 60);

      expect(game.player.isGrinding, isFalse,
          reason: 'a street-level courier never snatches onto the tube');
      expect(game.player.simulator.currentY, closeTo(groundY, 0.5));
    });
  });
}
