import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/drop_zone_component.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/components/speech_bubble_component.dart';
import 'package:jump_runner/game/components/steam_vent_component.dart';
import 'package:jump_runner/game/courier_game.dart';

class MockAudioBackend implements AudioPlayerInterface {
  final List<String> playedSfx = [];
  String? activeBgm;
  bool isBgmPlaying = false;
  double bgmVolume = 0.7;
  double playbackRate = 1.0;

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    playedSfx.add(file);
  }

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {
    activeBgm = file;
    isBgmPlaying = true;
    bgmVolume = volume;
  }

  @override
  Future<void> stopBgm() async {
    isBgmPlaying = false;
  }

  @override
  Future<void> setBgmVolume(double volume) async {
    bgmVolume = volume;
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    playbackRate = rate;
  }

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

  group('SpeechBubbleComponent (Issue #48)', () {
    test('drifts upward and reports isFinished when duration elapsed', () {
      final bubble = SpeechBubbleComponent(
        text: 'Woohoo!',
        position: Vector2(100.0, 200.0),
        duration: 1.0,
        driftVelocity: -20.0,
      );

      expect(bubble.position.y, equals(200.0));
      expect(bubble.isFinished, isFalse);

      bubble.update(0.5);
      expect(bubble.position.y, equals(190.0));
      expect(bubble.isFinished, isFalse);

      bubble.update(0.6);
      expect(bubble.isFinished, isTrue);
    });

    test('renders procedural speech bubble and text cleanly', () {
      final bubble = SpeechBubbleComponent(
        text: 'Five stars! ★★★★★',
        position: Vector2(50.0, 50.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => bubble.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('CourierGame Voice Barks & Customer Reactions Integration (Issue #48)', () {
    late MockAudioBackend mockBackend;
    late GameAudioController audioController;
    late CourierGame game;

    setUp(() async {
      mockBackend = MockAudioBackend();
      audioController = GameAudioController(backend: mockBackend);
      game = CourierGame(audioController: audioController);
      await game.onLoad();
      game.gameState.startRun();
    });

    test('Doorstep delivery triggers customer reaction bark and spawns speech bubble', () {
      CustomerReactionType? lastCustomerReaction;
      String? spokenReaction;

      audioController.addCustomerReactionListener((type, line) {
        lastCustomerReaction = type;
        spokenReaction = line;
      });

      final dropZone = DropZoneComponent(
        position: Vector2(game.player.position.x - 10.0, CourierGame.groundY - 70.0),
        size: Vector2(68.0, 70.0),
      );
      game.world.add(dropZone);
      game.activeDropZones.add(dropZone);

      game.update(0.016);

      expect(dropZone.hasDelivered, isTrue);
      expect(lastCustomerReaction, isNotNull);
      expect(spokenReaction, isNotNull);
      expect(
        mockBackend.playedSfx,
        anyOf(contains('sfx/customer_thank_you.ogg'), contains('sfx/customer_five_stars.ogg')),
      );

      // Verify SpeechBubbleComponent spawned in the game world
      final bubbles = game.world.children.whereType<SpeechBubbleComponent>();
      expect(bubbles, isNotEmpty);
      expect(bubbles.any((b) => b.text == spokenReaction), isTrue);
    });

    test('Near-miss hazard clearance triggers courier nearMiss voice bark', () async {
      CourierBarkType? triggeredBark;
      String? spokenLine;

      audioController.addCourierBarkListener((type, line) {
        triggeredBark = type;
        spokenLine = line;
      });

      // Place hazard under player X
      final obstacle = ObstacleComponent(
        type: ObstacleType.hydrant,
        position: Vector2(120.0, CourierGame.groundY - 44.0),
      );
      await game.world.add(obstacle);
      await game.ready();
      game.activeObstacles.add(obstacle);

      // Position courier right above obstacle within tight clearance (20px)
      // Hydrant top = 460 - 44 = 416. Player bottom = 396 -> clearance = 20px
      game.player.simulator.isGrounded = false;
      game.player.simulator.currentY = 396.0;
      game.player.position = Vector2(120.0, 396.0 - game.player.size.y);

      // Execute update loop
      game.update(0.016);

      // Trigger near-miss handler
      expect(obstacle.hasTriggeredNearMiss, isTrue);
      expect(triggeredBark, equals(CourierBarkType.nearMiss));
      expect(spokenLine, isNotNull);
      expect(mockBackend.playedSfx, contains('sfx/bark_near_miss.ogg'));

      final bubbles = game.world.children.whereType<SpeechBubbleComponent>();
      expect(bubbles.any((b) => b.text == spokenLine), isTrue);
    });

    test('Hazard damage collision triggers courier damage vocal bark', () {
      CourierBarkType? triggeredBark;
      String? spokenLine;

      audioController.addCourierBarkListener((type, line) {
        triggeredBark = type;
        spokenLine = line;
      });

      // Trigger hazard damage
      final tookDamage = game.player.takeDamage();
      expect(tookDamage, isTrue);

      expect(triggeredBark, equals(CourierBarkType.damage));
      expect(spokenLine, isNotNull);
      expect(mockBackend.playedSfx, contains('sfx/bark_damage.ogg'));

      final bubbles = game.world.children.whereType<SpeechBubbleComponent>();
      expect(bubbles.any((b) => b.text == spokenLine), isTrue);
    });

    test('Parkour vault triggers courier stunt voice bark', () {
      CourierBarkType? triggeredBark;
      String? spokenLine;

      audioController.addCourierBarkListener((type, line) {
        triggeredBark = type;
        spokenLine = line;
      });

      final courierFrontX = game.player.position.x + game.player.size.x;
      final hydrant = ObstacleComponent(
        type: ObstacleType.hydrant,
        position: Vector2(courierFrontX + 24.0, CourierGame.groundY - 44.0),
      );
      game.world.add(hydrant);
      game.activeObstacles.add(hydrant);

      // Tap jump within approach window to trigger parkour vault
      final vaulted = game.player.jump();
      expect(vaulted, isTrue);
      expect(game.player.isVaulting, isTrue);

      expect(triggeredBark, equals(CourierBarkType.stunt));
      expect(spokenLine, isNotNull);
      expect(mockBackend.playedSfx, contains('sfx/bark_stunt.ogg'));

      final bubbles = game.world.children.whereType<SpeechBubbleComponent>();
      expect(bubbles.any((b) => b.text == spokenLine), isTrue);
    });

    test('Steam vent thermal updraft contact triggers courier stunt bark', () {
      CourierBarkType? triggeredBark;
      String? spokenLine;

      audioController.addCourierBarkListener((type, line) {
        triggeredBark = type;
        spokenLine = line;
      });

      final vent = SteamVentComponent(
        position: Vector2(game.player.position.x, CourierGame.groundY - 14.0),
      );
      game.world.add(vent);
      game.activeSteamVents.add(vent);

      game.update(0.016);

      expect(vent.hasTriggeredBoost, isTrue);
      expect(triggeredBark, equals(CourierBarkType.stunt));
      expect(spokenLine, isNotNull);
      expect(mockBackend.playedSfx, contains('sfx/bark_stunt.ogg'));

      final bubbles = game.world.children.whereType<SpeechBubbleComponent>();
      expect(bubbles.any((b) => b.text == spokenLine), isTrue);
    });

    test('Glider deployment triggers courier glide voice bark', () {
      CourierBarkType? triggeredBark;
      String? spokenLine;

      audioController.addCourierBarkListener((type, line) {
        triggeredBark = type;
        spokenLine = line;
      });

      // A seasoned courier: a novice's first glide shows the coaching hint
      // in place of the speech bubble (see glide_coaching_test).
      game.personalRecordDistance = CourierGame.leapCoachUntilRecordMeters;

      // Jump into air and deploy glider
      game.player.simulator.isGrounded = false;
      final deployed = game.player.deployGlide();
      expect(deployed, isTrue);

      expect(game.player.isGliding, isTrue);
      expect(triggeredBark, equals(CourierBarkType.glide));
      expect(spokenLine, isNotNull);
      expect(mockBackend.playedSfx, contains('sfx/bark_glide.ogg'));

      final bubbles = game.world.children.whereType<SpeechBubbleComponent>();
      expect(bubbles.any((b) => b.text == spokenLine), isTrue);
    });

    test('restartRun cleans up speech bubbles and resets bark cooldowns', () {
      final bubble = SpeechBubbleComponent(
        text: 'Woohoo!',
        position: Vector2(100.0, 100.0),
      );
      game.world.add(bubble);
      expect(game.world.children.whereType<SpeechBubbleComponent>(), contains(bubble));

      audioController.playCourierBark(CourierBarkType.stunt);
      expect(audioController.canPlayCourierBark(), isFalse);

      game.restartRun();

      expect(game.world.children.whereType<SpeechBubbleComponent>(), isEmpty);
      expect(audioController.canPlayCourierBark(), isTrue);
    });

    test('Successive barks within cooldown period are throttled to prevent spam', () {
      int barkCount = 0;
      audioController.addCourierBarkListener((type, line) => barkCount++);

      // Trigger first vault stunt bark
      final hydrant1 = ObstacleComponent(
        type: ObstacleType.hydrant,
        position: Vector2(game.player.position.x + game.player.size.x + 20.0, CourierGame.groundY - 44.0),
      );
      game.world.add(hydrant1);
      game.activeObstacles.add(hydrant1);

      game.player.jump();
      expect(barkCount, equals(1));
      final sfxCountAfterFirst = mockBackend.playedSfx.where((s) => s.contains('bark')).length;
      expect(sfxCountAfterFirst, equals(1));

      // Immediate second bark trigger within cooldown is suppressed
      audioController.playCourierBark(CourierBarkType.stunt);
      expect(barkCount, equals(1));
      final sfxCountAfterSecond = mockBackend.playedSfx.where((s) => s.contains('bark')).length;
      expect(sfxCountAfterSecond, equals(1));
    });
  });
}
