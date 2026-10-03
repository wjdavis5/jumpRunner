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
  });
}
