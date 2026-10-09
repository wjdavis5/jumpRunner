import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/security_shutter_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityShutterComponent Unit Tests (Issue #122)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final shutter = SecurityShutterComponent(
        position: Vector2(300.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );

      expect(shutter.size.x, equals(48.0));
      expect(shutter.size.y, equals(80.0));
      expect(shutter.groundY, equals(460.0));
      expect(shutter.hasRebounded, isFalse);
      expect(shutter.shutterTopY, equals(380.0));
      expect(shutter.reboundApexWorld, equals(Vector2(300.0 + 24.0, 380.0 + 36.0)));
      expect(shutter.centerWorldPosition, equals(Vector2(300.0 + 24.0, 380.0 + 40.0)));
      expect(shutter.shouldRecycle, isFalse);
    });

    test('checkShutterRebound ignores courier outside horizontal bounds', () {
      final shutter = SecurityShutterComponent(
        position: Vector2(300.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 410.0;

      // Far left
      final farLeft = shutter.checkShutterRebound(
        Vector2(100.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = shutter.checkShutterRebound(
        Vector2(500.0, 390.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
      expect(shutter.hasRebounded, isFalse);
    });

    test('checkShutterRebound ignores courier outside vertical window', () {
      final shutter = SecurityShutterComponent(
        position: Vector2(300.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Too high above drum housing (windowTop is 380 - 24 = 356.0)
      sim.currentY = 330.0;
      final tooHigh = shutter.checkShutterRebound(
        Vector2(310.0, 290.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Below sidewalk ground (windowBottom is 460 + 4 = 464.0)
      sim.currentY = 480.0;
      final tooLow = shutter.checkShutterRebound(
        Vector2(310.0, 470.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
      expect(shutter.hasRebounded, isFalse);
    });

    test('checkShutterRebound triggers rebound and applies wall-kick launch (+240 px/s)', () {
      var callbackFired = false;
      final shutter = SecurityShutterComponent(
        position: Vector2(300.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
        onRebound: () => callbackFired = true,
      );

      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;
      sim.currentY = 410.0;
      sim.verticalVelocity = -40.0;

      final triggered = shutter.checkShutterRebound(
        Vector2(310.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );

      expect(triggered, isTrue);
      expect(shutter.hasRebounded, isTrue);
      expect(callbackFired, isTrue);
      expect(sim.verticalVelocity, equals(240.0)); // Upward wall-kick launch impulse

      // Subsequent check returns false (single trigger)
      final secondCheck = shutter.checkShutterRebound(
        Vector2(310.0, 370.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(secondCheck, isFalse);
    });

    test('markRebounded sets hasRebounded flag', () {
      final shutter = SecurityShutterComponent(
        position: Vector2(300.0, 380.0),
        groundY: 460.0,
      );
      expect(shutter.hasRebounded, isFalse);
      shutter.markRebounded();
      expect(shutter.hasRebounded, isTrue);
    });

    test('shouldRecycle triggers when past left offscreen boundary', () {
      final shutter = SecurityShutterComponent(
        position: Vector2(-150.0, 380.0),
        width: 48.0,
      );
      expect(shutter.shouldRecycle, isFalse);

      shutter.position.x = -240.0; // -240 + 48 = -192 < -180
      expect(shutter.shouldRecycle, isTrue);
    });

    test('render draws graffiti mural, slats, tracks, drum, and bumper without errors', () {
      final shutter = SecurityShutterComponent(
        position: Vector2(100.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => shutter.render(canvas), returnsNormally);
      recorder.endRecording();
    });
  });

  group('ParticleEffectComponent.securityShutterSparks Tests (Issue #122)', () {
    test('creates animated graffiti aerosol and metallic friction particles', () {
      final effect = ParticleEffectComponent.securityShutterSparks(
        position: Vector2(250.0, 380.0),
        count: 28,
      );

      expect(effect.isFinished, isFalse);

      effect.update(0.1);
      expect(effect.isFinished, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => effect.render(canvas), returnsNormally);
      recorder.endRecording();

      // Fast forward past particle lifetime (~0.70s max)
      effect.update(0.85);
      expect(effect.isFinished, isTrue);
    });
  });

  group('GameState Security Shutter Logic Tests (Issue #122)', () {
    test('recordSecurityShutterRebound increases counters, tips, and fires callback', () {
      final gs = GameState();
      gs.startRun();

      SecurityShutterEvent? capturedEvent;
      gs.onSecurityShutterRebound = (event) {
        capturedEvent = event;
      };

      final initialTips = gs.tips;
      final event = gs.recordSecurityShutterRebound(baseTips: 32);

      expect(event, isNotNull);
      expect(event!.baseTips, equals(32));
      expect(event.multiplier, equals(1.2)); // Streak 1 = 1.2x
      expect(event.totalTips, equals(38)); // (32 * 1.2).round() = 38
      expect(gs.shuttersReboundedInRun, equals(1));
      expect(gs.tips, equals(initialTips + 38));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.totalTips, equals(38));
    });

    test('recordSecurityShutterRebound scales tips with stunt multiplier', () {
      final gs = GameState();
      gs.startRun();
      gs.recordStunt(clearance: 10.0); // streak 1

      final initialTips = gs.tips;
      final event = gs.recordSecurityShutterRebound(baseTips: 32); // streak 2 -> 1.5x

      expect(event, isNotNull);
      expect(event!.multiplier, equals(1.5));
      expect(event.totalTips, equals(48)); // (32 * 1.5).round() = 48
      expect(gs.tips, equals(initialTips + 48));
    });

    test('recordSecurityShutterRebound returns null when run is not active', () {
      final gs = GameState();
      // Not started
      final event = gs.recordSecurityShutterRebound();
      expect(event, isNull);
      expect(gs.shuttersReboundedInRun, equals(0));
    });

    test('startRun resets shuttersReboundedInRun counter', () {
      final gs = GameState();
      gs.startRun();
      gs.recordSecurityShutterRebound();
      gs.recordSecurityShutterRebound();
      expect(gs.shuttersReboundedInRun, equals(2));

      gs.startRun();
      expect(gs.shuttersReboundedInRun, equals(0));
    });
  });

  group('CourierGame Security Shutter Integration Tests (Issue #122)', () {
    test('CourierGame spawns and clears activeSecurityShutters across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final shutter = SecurityShutterComponent(
        position: Vector2(300.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );
      game.activeSecurityShutters.add(shutter);
      game.world.add(shutter);

      expect(game.activeSecurityShutters.contains(shutter), isTrue);
      expect(game.world.children.contains(shutter), isTrue);

      game.restartRun();
      expect(game.activeSecurityShutters.contains(shutter), isFalse);
      expect(game.world.children.contains(shutter), isFalse);
    });

    test('SecurityShutterComponent scrolls with world movement', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final shutter = SecurityShutterComponent(
        position: Vector2(500.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );
      game.activeSecurityShutters.add(shutter);
      game.world.add(shutter);

      final initialX = shutter.position.x;
      game.update(0.1);
      expect(shutter.position.x, lessThan(initialX));
    });

    test('Courier rebounding off security shutter triggers event, bark, and particles', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final shutter = SecurityShutterComponent(
        position: Vector2(game.player.position.x + 10.0, 380.0),
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );
      game.activeSecurityShutters.add(shutter);
      game.world.add(shutter);

      // Position player in the air contacting the shutter face
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 410.0;
      game.player.simulator.verticalVelocity = -30.0;

      final initialRebounds = game.gameState.shuttersReboundedInRun;
      game.update(0.016);

      expect(shutter.hasRebounded, isTrue);
      expect(game.gameState.shuttersReboundedInRun, equals(initialRebounds + 1));
      expect(game.player.simulator.verticalVelocity, equals(240.0)); // Upward wall-kick launch

      // Verify floating text
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('SECURITY SHUTTER REBOUND')), isTrue);

      // Verify particle effect
      final particles = game.world.children.whereType<ParticleEffectComponent>();
      expect(particles.isNotEmpty, isTrue);
    });

    test('Offscreen security shutter is recycled', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final shutter = SecurityShutterComponent(
        position: Vector2(-260.0, 380.0), // -260 + 48 = -212 < -180
        width: 48.0,
        height: 80.0,
        groundY: 460.0,
      );
      game.activeSecurityShutters.add(shutter);
      game.world.add(shutter);

      expect(game.activeSecurityShutters.contains(shutter), isTrue);
      game.update(0.1);
      expect(game.activeSecurityShutters.contains(shutter), isFalse);
    });
  });

  group('GameOverModal Security Shutter Badge Tests (Issue #122)', () {
    testWidgets('renders single security shutter rebound badge when securityShuttersCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              securityShuttersCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_security_shutter_badge')), findsOneWidget);
      expect(find.text('1 SECURITY SHUTTER REBOUND'), findsOneWidget);
    });

    testWidgets('renders plural security shutter rebound badge when securityShuttersCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 680,
              tips: 340,
              isNewRecord: false,
              careerTips: 1800,
              securityShuttersCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_security_shutter_badge')), findsOneWidget);
      expect(find.text('3 SECURITY SHUTTER REBOUNDS'), findsOneWidget);
    });

    testWidgets('omits security shutter badge when securityShuttersCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 200,
              tips: 40,
              isNewRecord: false,
              careerTips: 500,
              securityShuttersCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_security_shutter_badge')), findsNothing);
    });
  });
}
