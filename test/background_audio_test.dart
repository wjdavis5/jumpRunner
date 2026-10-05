import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';

/// Records what the controller asks the platform to do.
class _RecordingBackend implements AudioPlayerInterface {
  bool bgmPlaying = false;
  double bgmVolume = 0.0;
  double playbackRate = 1.0;
  bool ambiencePlaying = false;
  double ambienceVolume = 0.0;
  int bgmStarts = 0;
  String? bgmFile;

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {}

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {
    bgmFile = file;
    bgmPlaying = true;
    bgmVolume = volume;
    playbackRate = 1.0;
    bgmStarts++;
  }

  @override
  Future<void> stopBgm() async {
    bgmPlaying = false;
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
  Future<void> startAmbience(String file, {double volume = 0.0}) async {
    ambiencePlaying = true;
    ambienceVolume = volume;
  }

  @override
  Future<void> stopAmbience() async {
    ambiencePlaying = false;
  }

  @override
  Future<void> setAmbienceVolume(double volume) async {
    ambienceVolume = volume;
  }
}

void main() {
  group('Audio while the app is in the background', () {
    test('Music stops when the app is backgrounded and returns with it', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();
      expect(backend.bgmPlaying, isTrue);

      await audio.suspendForBackground();
      expect(backend.bgmPlaying, isFalse);
      expect(audio.isBackgrounded, isTrue);
      // The run still owns its soundtrack; only playback is held.
      expect(audio.isMusicActive, isTrue);

      await audio.resumeFromBackground();
      expect(backend.bgmPlaying, isTrue);
      expect(backend.bgmVolume, equals(GameAudioController.defaultBgmVolume));
      expect(audio.isBackgrounded, isFalse);
    });

    test('Music comes back ducked when the run was paused meanwhile', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();

      await audio.pauseDucking();
      await audio.suspendForBackground();
      await audio.resumeFromBackground();

      expect(backend.bgmPlaying, isTrue);
      expect(backend.bgmVolume, equals(GameAudioController.duckedBgmVolume));
    });

    test('Rain ambience is held and restored with its volume', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();
      await audio.updateWeather(0.8);
      expect(backend.ambiencePlaying, isTrue);
      final rainVolume = audio.currentRainVolume;

      await audio.suspendForBackground();
      expect(backend.ambiencePlaying, isFalse);

      await audio.resumeFromBackground();
      expect(backend.ambiencePlaying, isTrue);
      expect(backend.ambienceVolume, equals(rainVolume));
    });

    test('The night track, not the day track, returns after dark', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();

      // Night falls: let the crossfade to the night track run to completion.
      for (var i = 0; i < 180; i++) {
        await audio.updateMusicPhase(isNight: true, dt: 1.0 / 60.0);
      }
      expect(audio.isNightTrack, isTrue);
      expect(backend.bgmFile, equals(GameAudioController.musicBgmNight));

      await audio.suspendForBackground();
      await audio.resumeFromBackground();

      expect(backend.bgmPlaying, isTrue);
      expect(backend.bgmFile, equals(GameAudioController.musicBgmNight));
      expect(backend.bgmVolume, equals(GameAudioController.defaultBgmVolume));
    });

    test('Nothing starts on return if no music was playing', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend);

      await audio.suspendForBackground();
      await audio.resumeFromBackground();

      expect(backend.bgmPlaying, isFalse);
      expect(backend.bgmStarts, equals(0));
    });

    test('A muted game stays silent through a background round trip', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend)..isMuted = true;
      await audio.startMusic();

      await audio.suspendForBackground();
      await audio.resumeFromBackground();

      expect(backend.bgmPlaying, isFalse);
      expect(backend.bgmStarts, equals(0));
    });

    test('Repeated lifecycle events do not restart the track', () async {
      final backend = _RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();
      expect(backend.bgmStarts, equals(1));

      // inactive -> hidden -> paused arrive as three separate events.
      await audio.suspendForBackground();
      await audio.suspendForBackground();
      await audio.suspendForBackground();
      await audio.resumeFromBackground();
      await audio.resumeFromBackground();

      expect(backend.bgmStarts, equals(2));
    });
  });
}
