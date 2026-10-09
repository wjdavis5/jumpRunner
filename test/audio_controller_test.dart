import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? activeAmbience;
  bool isAmbiencePlaying = false;
  double ambienceVolume = 0.0;

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {
    activeAmbience = file;
    isAmbiencePlaying = true;
    ambienceVolume = volume;
  }

  @override
  Future<void> stopAmbience() async {
    isAmbiencePlaying = false;
    ambienceVolume = 0.0;
  }

  @override
  Future<void> setAmbienceVolume(double volume) async {
    ambienceVolume = volume;
  }

  String? activeLayer;
  bool isLayerPlaying = false;
  double layerVolume = 0.0;
  double layerPlaybackRate = 1.0;
  int layerStarts = 0;

  @override
  Future<bool> startLayer(String file, {double volume = 0.0}) async {
    activeLayer = file;
    isLayerPlaying = true;
    layerVolume = volume;
    // Like a fresh audioplayers player, which starts at 1x until told
    // otherwise; this is what makes the tempo-on-start test bite.
    layerPlaybackRate = 1.0;
    layerStarts++;
    return true;
  }

  @override
  Future<void> stopLayer() async {
    isLayerPlaying = false;
    layerVolume = 0.0;
  }

  // Like the production backend, a volume or rate call with no player to act
  // on does nothing.
  @override
  Future<void> setLayerVolume(double volume) async {
    if (!isLayerPlaying) return;
    layerVolume = volume;
  }

  @override
  Future<void> setLayerPlaybackRate(double rate) async {
    if (!isLayerPlaying) return;
    layerPlaybackRate = rate;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameAudioController (U6)', () {
    late MockAudioBackend mockBackend;
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      mockBackend = MockAudioBackend();
    });

    test('Sound effect invocations play correct asset paths', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.playJump();
      expect(mockBackend.playedSfx.last, equals('sfx/jump.ogg'));

      await audio.playCoin();
      expect(mockBackend.playedSfx.last, equals('sfx/coin.ogg'));

      await audio.playFumble();
      expect(mockBackend.playedSfx.last, equals('sfx/fumble.ogg'));

      await audio.playMilestone();
      expect(mockBackend.playedSfx.last, equals('sfx/milestone.ogg'));

      expect(mockBackend.playedSfx.length, equals(4));
    });

    test('Mute toggle suppresses SFX playback and persists to storage', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      expect(audio.isMuted, isFalse);
      expect(storage.isSoundMuted, isFalse);

      // Toggle mute ON
      await audio.toggleMute();
      expect(audio.isMuted, isTrue);
      expect(storage.isSoundMuted, isTrue);

      // Attempt plays while muted
      mockBackend.playedSfx.clear();
      await audio.playJump();
      await audio.playCoin();
      expect(mockBackend.playedSfx, isEmpty, reason: 'Muted audio controller must not trigger SFX');

      // Toggle mute OFF
      await audio.toggleMute();
      expect(audio.isMuted, isFalse);
      expect(storage.isSoundMuted, isFalse);

      await audio.playJump();
      expect(mockBackend.playedSfx, contains('sfx/jump.ogg'));
    });

    test('Background music loop starts and loops courier_groove track', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      expect(mockBackend.isBgmPlaying, isTrue);
      expect(mockBackend.activeBgm, equals('music/courier_groove.ogg'));
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01));

      await audio.stopMusic();
      expect(mockBackend.isBgmPlaying, isFalse);
    });

    test('Starting music while muted is suppressed', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.toggleMute();
      await audio.startMusic();
      expect(mockBackend.isBgmPlaying, isFalse);
    });

    test('Pause ducking lowers BGM volume smoothly and restores on resume', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01));

      // Pause ducking lowers volume to duckedBgmVolume (0.3)
      await audio.pauseDucking();
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.duckedBgmVolume, 0.01));
      expect(audio.isPaused, isTrue);

      // Resuming restores volume to defaultBgmVolume (0.7)
      await audio.resumeDucking();
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01));
      expect(audio.isPaused, isFalse);
    });

    test('Milestone celebration ducks BGM volume during fanfare and restores', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01));

      await audio.playMilestone(duckDuration: const Duration(milliseconds: 30));
      expect(mockBackend.playedSfx.last, equals('sfx/milestone.ogg'));
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.milestoneDuckedBgmVolume, 0.01));

      // After fanfare duration completes, volume restores to normal
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01));
    });

    test('Pause ducking scales the streak layer by the same factor as the BGM', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      for (var i = 0; i < 12; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      const fullLayer = GameAudioController.defaultBgmVolume *
          GameAudioController.streakLayerVolumeRatio;
      expect(mockBackend.layerVolume, closeTo(fullLayer, 0.01));

      await audio.pauseDucking();
      expect(
        mockBackend.layerVolume,
        closeTo(GameAudioController.duckedBgmVolume * GameAudioController.streakLayerVolumeRatio, 0.01),
        reason: 'the layer must duck exactly like the BGM',
      );

      await audio.resumeDucking();
      expect(mockBackend.layerVolume, closeTo(fullLayer, 0.01));
    });

    test('Milestone ducking scales the streak layer by the same factor as the BGM', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      for (var i = 0; i < 12; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.05);
      }

      await audio.playMilestone(duckDuration: const Duration(milliseconds: 30));
      expect(
        mockBackend.layerVolume,
        closeTo(GameAudioController.milestoneDuckedBgmVolume * GameAudioController.streakLayerVolumeRatio, 0.01),
        reason: 'the layer must duck under the milestone fanfare too',
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        mockBackend.layerVolume,
        closeTo(GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio, 0.01),
      );
    });

    test('Adaptive tempo scales playback rate dynamically with speed progression', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      expect(mockBackend.playbackRate, closeTo(1.0, 0.01));

      // Speed increases to 350 px/s
      await audio.updateSpeed(350.0, baseSpeed: 200.0);
      expect(mockBackend.playbackRate, greaterThan(1.0));
      expect(mockBackend.playbackRate, lessThanOrEqualTo(1.25));

      // Max speed clamp test
      await audio.updateSpeed(900.0, baseSpeed: 200.0);
      expect(mockBackend.playbackRate, equals(1.25));
    });

    test('Mute persistence restores appropriate volume level when unmuting', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.startMusic();
      await audio.pauseDucking();
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.duckedBgmVolume, 0.01));

      // Mute while paused
      await audio.toggleMute();
      expect(mockBackend.isBgmPlaying, isFalse);

      // Unmute while still paused: volume should restore to ducked volume
      await audio.toggleMute();
      expect(mockBackend.isBgmPlaying, isTrue);
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.duckedBgmVolume, 0.01));
    });

    test('Weather ambience updates scale smoothly from 0.0 to 0.4 based on rain precipitation intensity', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      // Intensity 0.0: No ambience active
      await audio.updateWeather(0.0);
      expect(audio.isRainAudioActive, isFalse);
      expect(mockBackend.isAmbiencePlaying, isFalse);
      expect(audio.currentRainVolume, equals(0.0));

      // Intensity 0.5: Half precipitation -> volume 0.2
      await audio.updateWeather(0.5);
      expect(audio.isRainAudioActive, isTrue);
      expect(mockBackend.isAmbiencePlaying, isTrue);
      expect(mockBackend.activeAmbience, equals(GameAudioController.sfxRainAmbience));
      expect(audio.currentRainVolume, closeTo(0.2, 0.001));
      expect(mockBackend.ambienceVolume, closeTo(0.2, 0.001));

      // Intensity 1.0: Full precipitation -> max volume 0.4
      await audio.updateWeather(1.0);
      expect(audio.currentRainVolume, closeTo(0.4, 0.001));
      expect(mockBackend.ambienceVolume, closeTo(0.4, 0.001));

      // Intensity > 1.0 clamped at 0.4
      await audio.updateWeather(1.5);
      expect(audio.currentRainVolume, closeTo(0.4, 0.001));
      expect(mockBackend.ambienceVolume, closeTo(0.4, 0.001));

      // Back to 0.0: Ambience stopped
      await audio.updateWeather(0.0);
      expect(audio.isRainAudioActive, isFalse);
      expect(mockBackend.isAmbiencePlaying, isFalse);
      expect(audio.currentRainVolume, equals(0.0));
    });

    test('Mute toggle silences rain ambience and unmuting restores weather audio when raining', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      // Start rain at intensity 0.75 (volume 0.3)
      await audio.updateWeather(0.75);
      expect(audio.isRainAudioActive, isTrue);
      expect(mockBackend.isAmbiencePlaying, isTrue);
      expect(mockBackend.ambienceVolume, closeTo(0.3, 0.001));

      // Toggle mute: should stop ambient audio
      await audio.toggleMute();
      expect(audio.isMuted, isTrue);
      expect(audio.isRainAudioActive, isFalse);
      expect(mockBackend.isAmbiencePlaying, isFalse);

      // Updating weather while muted should not play audio
      await audio.updateWeather(0.9);
      expect(audio.isRainAudioActive, isFalse);
      expect(mockBackend.isAmbiencePlaying, isFalse);

      // Unmute: should restore ambient audio based on current rain intensity
      await audio.toggleMute();
      expect(audio.isMuted, isFalse);
      expect(audio.isRainAudioActive, isTrue);
      expect(mockBackend.isAmbiencePlaying, isTrue);
      expect(mockBackend.ambienceVolume, closeTo(0.36, 0.001));
    });

    test('stopMusic stops active rain ambience', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.updateWeather(0.6);
      expect(audio.isRainAudioActive, isTrue);
      expect(mockBackend.isAmbiencePlaying, isTrue);

      await audio.stopMusic();
      expect(audio.isRainAudioActive, isFalse);
      expect(mockBackend.isAmbiencePlaying, isFalse);
      expect(audio.currentRainVolume, equals(0.0));
    });

    test('Courier voice barks play corresponding SFX asset paths (Issue #48)', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      final stuntResult = await audio.playCourierBark(CourierBarkType.stunt);
      expect(stuntResult, isTrue);
      expect(mockBackend.playedSfx.last, equals('sfx/bark_stunt.ogg'));

      audio.resetBarkCooldowns();
      final nearMissResult = await audio.playCourierBark(CourierBarkType.nearMiss);
      expect(nearMissResult, isTrue);
      expect(mockBackend.playedSfx.last, equals('sfx/bark_near_miss.ogg'));

      audio.resetBarkCooldowns();
      final damageResult = await audio.playCourierBark(CourierBarkType.damage);
      expect(damageResult, isTrue);
      expect(mockBackend.playedSfx.last, equals('sfx/bark_damage.ogg'));

      audio.resetBarkCooldowns();
      final glideResult = await audio.playCourierBark(CourierBarkType.glide);
      expect(glideResult, isTrue);
      expect(mockBackend.playedSfx.last, equals('sfx/bark_glide.ogg'));
    });

    test('Customer doorstep reactions play corresponding SFX asset paths (Issue #48)', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      final thankYouResult = await audio.playCustomerReaction(CustomerReactionType.thankYou);
      expect(thankYouResult, isTrue);
      expect(mockBackend.playedSfx.last, equals('sfx/customer_thank_you.ogg'));

      audio.resetBarkCooldowns();
      final fiveStarsResult = await audio.playCustomerReaction(CustomerReactionType.fiveStars);
      expect(fiveStarsResult, isTrue);
      expect(mockBackend.playedSfx.last, equals('sfx/customer_five_stars.ogg'));
    });

    test('Voice bark cooldown throttling prevents spam and allows bypass (Issue #48)', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      final baseTime = DateTime(2026, 10, 4, 12, 0, 0);

      // First bark at baseTime succeeds
      final first = await audio.playCourierBark(CourierBarkType.stunt, now: baseTime);
      expect(first, isTrue);
      expect(mockBackend.playedSfx.length, equals(1));

      // Second bark 0.5s later is throttled
      final second = await audio.playCourierBark(
        CourierBarkType.stunt,
        now: baseTime.add(const Duration(milliseconds: 500)),
      );
      expect(second, isFalse);
      expect(mockBackend.playedSfx.length, equals(1), reason: 'Throttled bark must not play audio');

      // Bark with ignoreCooldown = true succeeds even within cooldown
      final bypass = await audio.playCourierBark(
        CourierBarkType.damage,
        ignoreCooldown: true,
        now: baseTime.add(const Duration(milliseconds: 600)),
      );
      expect(bypass, isTrue);
      expect(mockBackend.playedSfx.length, equals(2));

      // Bark after full cooldown (>= 2.0s) succeeds
      final afterCooldown = await audio.playCourierBark(
        CourierBarkType.nearMiss,
        now: baseTime.add(const Duration(milliseconds: 2700)),
      );
      expect(afterCooldown, isTrue);
      expect(mockBackend.playedSfx.length, equals(3));
    });

    test('Customer reaction cooldown throttling suppresses rapid repetitions (Issue #48)', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      final baseTime = DateTime(2026, 10, 4, 12, 0, 0);

      final first = await audio.playCustomerReaction(CustomerReactionType.thankYou, now: baseTime);
      expect(first, isTrue);
      expect(mockBackend.playedSfx.length, equals(1));

      // Attempt within 1.0s (less than 1.5s cooldown) is throttled
      final tooSoon = await audio.playCustomerReaction(
        CustomerReactionType.fiveStars,
        now: baseTime.add(const Duration(milliseconds: 1000)),
      );
      expect(tooSoon, isFalse);
      expect(mockBackend.playedSfx.length, equals(1));

      // Attempt after 1.6s succeeds
      final allowed = await audio.playCustomerReaction(
        CustomerReactionType.fiveStars,
        now: baseTime.add(const Duration(milliseconds: 1600)),
      );
      expect(allowed, isTrue);
      expect(mockBackend.playedSfx.length, equals(2));
    });

    test('Mute silences voice barks and customer reactions but triggers visual callbacks (Issue #48)', () async {
      final audio = GameAudioController(
        backend: mockBackend,
        storageService: storage,
      );

      await audio.toggleMute();
      expect(audio.isMuted, isTrue);

      String? spokenBark;
      CourierBarkType? barkType;
      audio.onCourierBark = (type, line) {
        barkType = type;
        spokenBark = line;
      };

      String? reactionText;
      CustomerReactionType? reactionType;
      audio.onCustomerReaction = (type, line) {
        reactionType = type;
        reactionText = line;
      };

      mockBackend.playedSfx.clear();

      await audio.playCourierBark(CourierBarkType.stunt, line: 'Custom Woohoo!');
      expect(barkType, equals(CourierBarkType.stunt));
      expect(spokenBark, equals('Custom Woohoo!'));
      expect(mockBackend.playedSfx, isEmpty, reason: 'Muted audio controller must not trigger bark SFX');

      await audio.playCustomerReaction(CustomerReactionType.fiveStars, line: 'Five stars!');
      expect(reactionType, equals(CustomerReactionType.fiveStars));
      expect(reactionText, equals('Five stars!'));
      expect(mockBackend.playedSfx, isEmpty, reason: 'Muted audio controller must not trigger reaction SFX');
    });
  });
}
