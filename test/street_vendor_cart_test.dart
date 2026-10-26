import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/street_vendor_cart_component.dart';
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

StreetVendorCartComponent _cartAt(Vector2 position) => StreetVendorCartComponent(
      position: position,
      width: 72.0,
      height: 58.0,
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

  group('StreetVendorCartComponent Unit Tests (Issue #118)', () {
    test('initializes with default dimensions, anchors, and idle state', () {
      final cart = _cartAt(Vector2(300.0, 402.0));

      expect(cart.size.x, equals(72.0));
      expect(cart.size.y, equals(58.0));
      expect(cart.groundY, equals(460.0));
      expect(cart.hasVaulted, isFalse);
      expect(cart.shouldRecycle, isFalse);
      expect(cart.counterTopWorldY, closeTo(460.0 - 58.0 * 0.42, 0.001));
      expect(cart.centerWorldPosition, equals(Vector2(336.0, 431.0)));
      expect(cart.vaultApexWorld.y, closeTo(cart.counterTopWorldY - 26.0, 0.001));
      expect(cart.cauldronWorld.x, closeTo(300.0 + 72.0 * 0.72, 0.001));
    });

    test('checkVault ignores courier outside horizontal bounds', () {
      final cart = _cartAt(Vector2(300.0, 402.0));

      final farLeft = cart.checkVault(
        Vector2(80.0, 420.0),
        Vector2(32.0, 40.0),
        _airborneAt(430.0),
      );
      expect(farLeft, isFalse);

      final farRight = cart.checkVault(
        Vector2(420.0, 420.0),
        Vector2(32.0, 40.0),
        _airborneAt(430.0),
      );
      expect(farRight, isFalse);
      expect(cart.hasVaulted, isFalse);
    });

    test('a grounded courier running past earns nothing and leaves the cart fresh', () {
      var vaults = 0;
      final cart = StreetVendorCartComponent(
        position: Vector2(300.0, 402.0),
        width: 72.0,
        height: 58.0,
        groundY: 460.0,
        onVault: () => vaults++,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;
      sim.currentY = 460.0;

      final vaulted = cart.checkVault(
        Vector2(310.0, 430.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(vaulted, isFalse);
      expect(cart.hasVaulted, isFalse);
      expect(vaults, equals(0));
      expect(sim.verticalVelocity, equals(0.0));
    });

    test('an airborne courier vaulting the counter boosts and fires once', () {
      var vaults = 0;
      final cart = StreetVendorCartComponent(
        position: Vector2(300.0, 402.0),
        width: 72.0,
        height: 58.0,
        groundY: 460.0,
        onVault: () => vaults++,
      );
      final sim = _airborneAt(435.0);

      final first = cart.checkVault(
        Vector2(310.0, 430.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(first, isTrue);
      expect(cart.hasVaulted, isTrue);
      expect(vaults, equals(1));
      expect(sim.verticalVelocity, equals(195.0));

      final second = cart.checkVault(
        Vector2(310.0, 430.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(second, isFalse);
      expect(vaults, equals(1));
    });

    test('the canopy wobbles after a vault and settles', () {
      final cart = _cartAt(Vector2(300.0, 402.0));
      cart.checkVault(
        Vector2(310.0, 430.0),
        Vector2(32.0, 40.0),
        _airborneAt(435.0),
      );

      // The wobble runs on its own 0.40 s timer and updates nothing else:
      // half a second later the cart is settled and still vaulted-once.
      cart.update(0.5);
      expect(cart.hasVaulted, isTrue);
      expect(cart.shouldRecycle, isFalse);
    });

    test('recycles once fully past the left edge, and not before', () {
      final cart = _cartAt(Vector2(-100.0, 402.0));
      expect(cart.shouldRecycle, isFalse);

      cart.position = Vector2(-260.0, 402.0);
      expect(cart.shouldRecycle, isTrue);
    });
  });

  group('ParticleEffectComponent.pretzelRoastAroma Tests (Issue #118)', () {
    test('spawns exactly the requested particle count', () {
      final effect = ParticleEffectComponent.pretzelRoastAroma(
        position: Vector2(300, 420),
        count: 26,
        random: math.Random(9),
      );

      expect(effect.particles.length, equals(26));
    });

    test('the aroma climbs: every particle rises buoyantly', () {
      final effect = ParticleEffectComponent.pretzelRoastAroma(
        position: Vector2(300, 420),
        count: 40,
        random: math.Random(4),
      );

      for (final p in effect.particles) {
        expect(p.velocity.y, lessThan(0.0),
            reason: 'aroma must rise from the cart');
        expect(p.gravity, lessThan(0.0),
            reason: 'the aroma is buoyant, not a falling spray');
      }
    });

    test('every particle comes from the roast aroma palette', () {
      const palette = {
        0xFFFFD54F, // Golden amber aroma curl
        0xFFFFCA28, // Warm roast gold
        0xFFFFFFFF, // Steam wisp
        0xFFE0F7FA, // Cool steam highlight
        0xFFFAFAFA, // Coarse salt crystal
        0xFFFF6D00, // Charcoal ember spark
      };
      final effect = ParticleEffectComponent.pretzelRoastAroma(
        position: Vector2(300, 420),
        count: 60,
        random: math.Random(6),
      );

      for (final p in effect.particles) {
        expect(palette.contains(p.color.toARGB32()), isTrue,
            reason: '${p.color} is not a roast aroma color');
      }
    });
  });

  group('GameState Hot Snack Sprint Tests (Issue #118)', () {
    test('records a vault, pays streak-scaled tips, and fires the callback', () {
      final state = GameState()..startRun();

      StreetVendorEvent? event;
      state.onStreetVendorVault = (e) => event = e;

      final tipsBefore = state.tips;
      final returned = state.recordStreetVendorVault();

      expect(returned, isNotNull);
      expect(event, isNotNull);
      expect(returned!.baseTips, equals(34));
      expect(returned.totalTips, greaterThanOrEqualTo(34));
      expect(state.tips, greaterThan(tipsBefore));
      expect(state.streetVendorsVaultedInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(returned.vendorsInRun, equals(1));
      expect(returned.sprintDuration, equals(3.5));
    });

    test('the vault ignites the Hot Snack Sprint and it expires', () {
      final state = GameState()..startRun();
      expect(state.isHotSnackSprintActive, isFalse);

      state.recordStreetVendorVault();
      expect(state.isHotSnackSprintActive, isTrue);

      state.updateHotSnackSprintTimer(3.5);
      expect(state.isHotSnackSprintActive, isFalse);
    });

    test('counts successive vaults and resets on a new run', () {
      final state = GameState()..startRun();
      state.recordStreetVendorVault();
      state.recordStreetVendorVault();
      expect(state.streetVendorsVaultedInRun, equals(2));
      expect(state.isHotSnackSprintActive, isTrue);

      state.startRun();
      expect(state.streetVendorsVaultedInRun, equals(0));
      expect(state.isHotSnackSprintActive, isFalse);
    });

    test('no vault is recorded once the run is over', () {
      final state = GameState()..startRun();
      state.status = GameStatus.gameOver;

      expect(state.recordStreetVendorVault(), isNull);
      expect(state.streetVendorsVaultedInRun, equals(0));
    });
  });

  group('WorldChunkManager Street Vendor Spawning Tests (Issue #118)', () {
    test('no vendor cart spawns before 90 m', () {
      var anySpawned = false;
      for (var seed = 0; seed < 30 && !anySpawned; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 89.0,
        );
        anySpawned = chunk.streetVendors.isNotEmpty;
      }
      expect(anySpawned, isFalse, reason: 'the gate opens at 90 m');
    });

    test('a vendor cart is possible at 90 m and clears other fixtures', () {
      var found = false;
      for (var seed = 0; seed < 60 && !found; seed++) {
        final manager = WorldChunkManager(random: math.Random(seed));
        manager.reset();
        final chunk = manager.generateChunk(
          startX: 0.0,
          chunkWidth: 960.0,
          groundY: 460.0,
          speed: 200.0,
          distanceMeters: 90.0,
        );
        found = chunk.streetVendors.isNotEmpty;

        for (final sv in chunk.streetVendors) {
          for (final fk in chunk.flowerKiosks) {
            final gap = (sv.x + sv.width < fk.x) || (sv.x > fk.x + fk.width);
            expect(gap, isTrue, reason: 'two vendor stands must not overlap');
          }
        }
      }
      expect(found, isTrue, reason: 'a vendor cart must be possible at 90 m');
    });

    test('a station chunk never carries a vendor cart', () {
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
            expect(chunk.streetVendors, isEmpty,
                reason: 'a vendor cart must not stand on a platform');
          }
        }
      }

      expect(stations, greaterThan(0), reason: 'the street must have stations');
    });
  });

  group('CourierGame Street Vendor Integration Tests (Issue #118)', () {
    test('CourierGame spawns and clears activeStreetVendors across lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final cart = _cartAt(Vector2(300.0, 402.0));
      game.activeStreetVendors.add(cart);
      game.world.add(cart);

      expect(game.activeStreetVendors.contains(cart), isTrue);
      expect(game.world.children.contains(cart), isTrue);

      game.restartRun();
      expect(game.activeStreetVendors.contains(cart), isFalse);
      expect(game.world.children.contains(cart), isFalse);
    });

    test('StreetVendorCartComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final cart = _cartAt(Vector2(500.0, 402.0));
      game.activeStreetVendors.add(cart);
      game.world.add(cart);

      final initialX = cart.position.x;
      game.update(0.1);
      expect(cart.position.x, lessThan(initialX));
    });

    test('a vaulting courier boosts, earns tips, sprints, barks and steams', () async {
      final backend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: backend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final barkLines = <String>[];
      game.audio.addCourierBarkListener((type, line) => barkLines.add(line));

      final cart = _cartAt(
        Vector2(game.player.position.x + 10.0, 402.0),
      );
      game.activeStreetVendors.add(cart);
      game.world.add(cart);

      // Vaulting down onto the counter with the feet in the window.
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 435.0;
      game.player.simulator.verticalVelocity = -30.0;

      final initialVaults = game.gameState.streetVendorsVaultedInRun;
      game.update(0.016);

      expect(cart.hasVaulted, isTrue);
      expect(game.gameState.streetVendorsVaultedInRun, equals(initialVaults + 1));
      expect(game.player.simulator.verticalVelocity, equals(195.0));
      expect(game.gameState.isHotSnackSprintActive, isTrue);

      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(
        floatingTexts.any((ft) => ft.text.contains('PRETZEL SPRINT')),
        isTrue,
      );
      expect(backend.playedSfx, contains(GameAudioController.sfxBarkStunt));
      expect(barkLines, contains('Nothing beats fresh street pretzels!'));

      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(
        particles.any((p) => p.particles.length == 26),
        isTrue,
        reason: 'the roast aroma effect must be the one spawned',
      );
    });

    test('a grounded run-past awards nothing and leaves the cart fresh', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final cart = _cartAt(
        Vector2(game.player.position.x + 10.0, 402.0),
      );
      game.activeStreetVendors.add(cart);
      game.world.add(cart);

      final initialVaults = game.gameState.streetVendorsVaultedInRun;
      game.update(0.016);

      expect(cart.hasVaulted, isFalse);
      expect(game.gameState.streetVendorsVaultedInRun, equals(initialVaults));
      expect(game.gameState.isHotSnackSprintActive, isFalse);
    });
  });

  group('GameOverModal Pretzel Badge Tests (Issue #118)', () {
    testWidgets('hides game_over_pretzel_badge when 0 sprints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            pretzelSprintsCompleted: 0,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_pretzel_badge')), findsNothing);
    });

    testWidgets('renders the singular badge when pretzelSprintsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            pretzelSprintsCompleted: 1,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_pretzel_badge')), findsOneWidget);
      expect(find.text('1 PRETZEL SPRINT'), findsOneWidget);
    });

    testWidgets('renders the plural badge when pretzelSprintsCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverModal(
            distance: 500,
            tips: 100,
            isNewRecord: false,
            careerTips: 0,
            pretzelSprintsCompleted: 2,
            onRestart: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_pretzel_badge')), findsOneWidget);
      expect(find.text('2 PRETZEL SPRINTS'), findsOneWidget);
    });
  });
}
