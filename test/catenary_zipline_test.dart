import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/catenary_zipline_component.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
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

  group('CatenaryZiplineComponent Unit Tests (Issue #99)', () {
    test('initializes with default dimensions, coordinates, and idle state', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(300.0, 200.0),
        spanWidth: 240.0,
        cableDrop: 24.0,
        sag: 10.0,
        groundY: 460.0,
      );

      expect(zipline.spanWidth, equals(240.0));
      expect(zipline.cableDrop, equals(24.0));
      expect(zipline.sag, equals(10.0));
      expect(zipline.isCourierAttached, isFalse);
      expect(zipline.hasDismounted, isFalse);
      expect(zipline.startX, equals(300.0));
      expect(zipline.endX, equals(540.0));
      expect(zipline.startY, equals(218.0)); // 200 + 18
      expect(zipline.endY, equals(242.0));   // 200 + 18 + 24
      expect(zipline.shouldRecycle, isFalse);
    });

    test('cableYAt and messengerYAt compute catenary curve correctly', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(100.0, 200.0),
        spanWidth: 200.0,
        cableDrop: 20.0,
        sag: 12.0,
      );

      // Start of cable: t = 0 -> startY (218.0)
      expect(zipline.cableYAt(100.0), equals(218.0));

      // Midpoint of cable: t = 0.5 -> startY + 0.5 * 20.0 + 4 * 12 * 0.25 = 218 + 10 + 12 = 240.0
      expect(zipline.cableYAt(200.0), equals(240.0));

      // End of cable: t = 1.0 -> endY (238.0)
      expect(zipline.cableYAt(300.0), equals(238.0));

      // Messenger cable is above contact wire
      expect(zipline.messengerYAt(200.0), lessThan(zipline.cableYAt(200.0)));
    });

    test('canGrabWire rejects grounded courier', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(200.0, 200.0),
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = true;

      final canGrab = zipline.canGrabWire(
        Vector2(250.0, 210.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(canGrab, isFalse);
    });

    test('canGrabWire rejects courier outside horizontal span', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(300.0, 200.0),
        spanWidth: 240.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Far left
      final farLeft = zipline.canGrabWire(
        Vector2(100.0, 210.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farLeft, isFalse);

      // Far right
      final farRight = zipline.canGrabWire(
        Vector2(600.0, 210.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(farRight, isFalse);
    });

    test('canGrabWire rejects courier outside vertical grab window', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(300.0, 200.0),
        spanWidth: 240.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      // Too high above wire (wire is around 220-230)
      final tooHigh = zipline.canGrabWire(
        Vector2(350.0, 100.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooHigh, isFalse);

      // Too low below wire
      final tooLow = zipline.canGrabWire(
        Vector2(350.0, 350.0),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(tooLow, isFalse);
    });

    test('canGrabWire allows airborne courier in grab window', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(300.0, 200.0),
        spanWidth: 240.0,
      );
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.isGrounded = false;

      final wireY = zipline.cableYAt(350.0 + 16.0); // Foot/center X
      // Place player so handY (playerY + 10.0) is near wireY
      final playerY = wireY - 10.0;

      final canGrab = zipline.canGrabWire(
        Vector2(350.0, playerY),
        Vector2(32.0, 40.0),
        sim,
      );
      expect(canGrab, isTrue);
    });

    test('attachCourier, isPastForwardEdge, and releaseCourier lifecycle', () {
      var dismountTriggered = false;
      final zipline = CatenaryZiplineComponent(
        position: Vector2(200.0, 200.0),
        spanWidth: 200.0,
        onZiplineDismount: () {
          dismountTriggered = true;
        },
      );

      zipline.attachCourier();
      expect(zipline.isCourierAttached, isTrue);

      // Check forward edge
      expect(zipline.isPastForwardEdge(300.0), isFalse);
      expect(zipline.isPastForwardEdge(390.0), isTrue); // 200 + 200 - 14 = 386

      final impulse = zipline.releaseCourier();
      expect(zipline.isCourierAttached, isFalse);
      expect(zipline.hasDismounted, isTrue);
      expect(dismountTriggered, isTrue);
      expect(impulse.x, equals(180.0));
      expect(impulse.y, equals(220.0));
    });

    test('shouldRecycle reports true when scrolled past left threshold', () {
      final zipline = CatenaryZiplineComponent(
        position: Vector2(-450.0, 200.0),
        spanWidth: 240.0,
      );
      expect(zipline.shouldRecycle, isTrue);

      zipline.position.x = 0.0;
      expect(zipline.shouldRecycle, isFalse);
    });

    test('render paints cleanly in idle state and attached state', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final zipline = CatenaryZiplineComponent(
        position: Vector2(100.0, 200.0),
      );

      // Idle render
      expect(() => zipline.render(canvas), returnsNormally);

      // Attached render with corona flash
      zipline.attachCourier();
      zipline.update(0.1);
      expect(() => zipline.render(canvas), returnsNormally);
    });
  });

  group('ParticleEffectComponent.ziplineSparks Tests (Issue #99)', () {
    test('creates requested number of living particles with electric arc properties', () {
      final sparks = ParticleEffectComponent.ziplineSparks(
        position: Vector2(300.0, 220.0),
        count: 24,
      );

      expect(sparks.particles.length, equals(24));
      expect(sparks.isFinished, isFalse);

      for (final p in sparks.particles) {
        expect(p.isAlive, isTrue);
        expect(p.gravity, equals(80.0));
        expect(p.drag, equals(0.94));
      }

      // Step until all particles expire
      sparks.update(0.6);
      expect(sparks.isFinished, isTrue);
    });
  });

  group('CourierPlayer Ziplining State Tests (Issue #99)', () {
    test('attachToZipline transitions state and locks vertical velocity', () {
      final player = CourierPlayer(groundY: 460.0);
      final zipline = CatenaryZiplineComponent(
        position: Vector2(100.0, 200.0),
      );

      player.simulator.isGrounded = false;
      player.simulator.verticalVelocity = 120.0;
      player.state = CourierState.jumping;

      player.attachToZipline(zipline);

      expect(player.state, equals(CourierState.ziplining));
      expect(player.isZiplining, isTrue);
      expect(player.attachedZipline, equals(zipline));
      expect(player.simulator.verticalVelocity, equals(0.0));
      expect(zipline.isCourierAttached, isTrue);
    });

    test('player update locks position Y to cableYAt while ziplining', () {
      final player = CourierPlayer(groundY: 460.0);
      final zipline = CatenaryZiplineComponent(
        position: Vector2(0.0, 200.0),
        spanWidth: 300.0,
      );

      player.position = Vector2(100.0, 200.0);
      player.attachToZipline(zipline);

      player.update(0.05);

      final footX = player.position.x + (player.size.x * 0.5);
      final expectedY = zipline.cableYAt(footX) - 14.0;
      expect(player.position.y, closeTo(expectedY, 0.01));
      expect(player.simulator.verticalVelocity, equals(0.0));
    });

    test('jump while ziplining releases wire early with launch impulse', () {
      final player = CourierPlayer(groundY: 460.0);
      final zipline = CatenaryZiplineComponent(
        position: Vector2(100.0, 200.0),
      );

      player.attachToZipline(zipline);
      expect(player.isZiplining, isTrue);

      final jumped = player.jump();
      expect(jumped, isTrue);
      expect(player.isZiplining, isFalse);
      expect(player.state, equals(CourierState.jumping));
      expect(player.simulator.verticalVelocity, equals(220.0)); // Wire dismount launch
      expect(zipline.hasDismounted, isTrue);
    });

    test('takeDamage is ignored while ziplining', () {
      final player = CourierPlayer(groundY: 460.0);
      final zipline = CatenaryZiplineComponent(
        position: Vector2(100.0, 200.0),
      );

      player.attachToZipline(zipline);
      final tookDamage = player.takeDamage();
      expect(tookDamage, isFalse);
      expect(player.isZiplining, isTrue);
    });
  });

  group('GameState Catenary Zipline Logic Tests (Issue #99)', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    test('recordCatenaryZipline awards tips, advances streak, and tracks ziplinesInRun', () {
      state.startRun();
      expect(state.ziplinesCompletedInRun, equals(0));

      CatenaryZiplineEvent? capturedEvent;
      state.onCatenaryZipline = (e) => capturedEvent = e;

      final event = state.recordCatenaryZipline(distanceMeters: 24.0, baseTips: 35);
      expect(event, isNotNull);
      expect(capturedEvent, equals(event));

      expect(state.ziplinesCompletedInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      // Base 35 * 1.2x (stuntStreak 1) = 42
      expect(state.tips, equals(42));
      expect(event!.ziplinesInRun, equals(1));
      expect(event.distanceMeters, equals(24.0));
    });

    test('startRun resets ziplinesCompletedInRun', () {
      state.startRun();
      state.recordCatenaryZipline();
      expect(state.ziplinesCompletedInRun, equals(1));

      state.startRun();
      expect(state.ziplinesCompletedInRun, equals(0));
    });

    test('recordCatenaryZipline returns null when game is not running', () {
      final event = state.recordCatenaryZipline();
      expect(event, isNull);
      expect(state.ziplinesCompletedInRun, equals(0));
    });
  });

  group('CourierGame Integration with CatenaryZiplineComponent (Issue #99)', () {
    test('CourierGame spawns and clears activeCatenaryZiplines across run lifecycle', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      final zipline = CatenaryZiplineComponent(
        position: Vector2(300.0, 200.0),
      );
      game.activeCatenaryZiplines.add(zipline);
      game.world.add(zipline);

      expect(game.activeCatenaryZiplines.contains(zipline), isTrue);
      expect(game.world.children.contains(zipline), isTrue);

      game.restartRun();
      expect(game.activeCatenaryZiplines.contains(zipline), isFalse);
      expect(game.world.children.contains(zipline), isFalse);
    });

    test('CourierGame scrolls activeCatenaryZiplines horizontally with scrollDelta', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final zipline = CatenaryZiplineComponent(
        position: Vector2(450.0, 200.0),
      );
      game.activeCatenaryZiplines.add(zipline);
      game.world.add(zipline);

      final initialX = zipline.position.x;
      game.update(0.1);

      expect(zipline.position.x, lessThan(initialX));
    });

    test('CourierGame attaches airborne player to zipline and handles forward dismount', () async {
      final audioBackend = MockAudioBackend();
      final game = CourierGame(
        audioController: GameAudioController(backend: audioBackend),
      );
      await game.onLoad();
      game.gameState.startRun();

      final zipline = CatenaryZiplineComponent(
        position: Vector2(game.player.position.x - 20.0, 200.0),
        spanWidth: 100.0,
      );
      game.activeCatenaryZiplines.add(zipline);
      game.world.add(zipline);

      // Make player airborne in wire grab window
      game.player.simulator.isGrounded = false;
      final wireY = zipline.cableYAt(game.player.position.x + 16.0);
      game.player.position.y = wireY - 10.0;
      game.player.simulator.currentY = game.player.position.y + game.player.size.y;

      // Update triggers attach
      game.update(0.02);
      expect(game.player.isZiplining, isTrue);

      // Fast forward zipline position so player is past forward edge
      zipline.position.x = game.player.position.x - 95.0; // puts footX past forward edge

      game.update(0.02);
      expect(game.player.isZiplining, isFalse);
      expect(game.gameState.ziplinesCompletedInRun, equals(1));

      // Floating text spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((ft) => ft.text.contains('AERIAL CATENARY ZIPLINE!')), isTrue);

      // Particles spawned
      final sparks = game.world.children.whereType<ParticleEffectComponent>();
      expect(sparks.isNotEmpty, isTrue);
    });

    test('CourierGame recycles off-screen catenary ziplines during update', () async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();
      game.gameState.startRun();

      final offscreenZipline = CatenaryZiplineComponent(
        position: Vector2(-450.0, 200.0),
        spanWidth: 200.0,
      );
      game.activeCatenaryZiplines.add(offscreenZipline);
      game.world.add(offscreenZipline);

      game.update(0.05);
      expect(game.activeCatenaryZiplines.contains(offscreenZipline), isFalse);
    });
  });

  group('GameOverModal Zipline Badge UI Tests (Issue #99)', () {
    testWidgets('renders game_over_zipline_badge with singular text when 1 slide', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 600,
              tips: 150,
              isNewRecord: false,
              careerTips: 900,
              ziplinesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_zipline_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('1 AERIAL CATENARY ZIPLINE SLIDE'), findsOneWidget);
    });

    testWidgets('renders game_over_zipline_badge with plural text when 2 slides', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 900,
              tips: 250,
              isNewRecord: false,
              careerTips: 1500,
              ziplinesCompleted: 2,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_zipline_badge'));
      expect(badge, findsOneWidget);
      expect(find.text('2 AERIAL CATENARY ZIPLINE SLIDES'), findsOneWidget);
    });

    testWidgets('hides game_over_zipline_badge when 0 slides', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 50,
              isNewRecord: false,
              careerTips: 400,
              ziplinesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badge = find.byKey(const Key('game_over_zipline_badge'));
      expect(badge, findsNothing);
    });
  });
}
