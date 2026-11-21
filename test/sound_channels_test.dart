import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingBackend implements AudioPlayerInterface {
  final List<String> bgmStarts = [];
  final List<String> sfxPlays = [];
  final List<String> ambienceStarts = [];
  final List<String> layerStarts = [];
  int bgmStops = 0;
  int layerStops = 0;
  int ambienceStops = 0;

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    sfxPlays.add(file);
  }

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {
    bgmStarts.add(file);
  }

  @override
  Future<void> stopBgm() async {
    bgmStops++;
  }

  @override
  Future<void> setBgmVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {
    ambienceStarts.add(file);
  }

  @override
  Future<void> stopAmbience() async {
    ambienceStops++;
  }

  @override
  Future<void> setAmbienceVolume(double volume) async {}

  @override
  Future<bool> startLayer(String file, {double volume = 0.0}) async {
    layerStarts.add(file);
    return true;
  }

  @override
  Future<void> stopLayer() async {
    layerStops++;
  }

  @override
  Future<void> setLayerVolume(double volume) async {}

  @override
  Future<void> setLayerPlaybackRate(double rate) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Music & SFX Channel Storage', () {
    test('channels default to audible and round-trip independently', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.isMusicMuted, isFalse);
      expect(storage.isSfxMuted, isFalse);

      await storage.setMusicMuted(true);
      await storage.setSfxMuted(false);
      expect(storage.isMusicMuted, isTrue);
      expect(storage.isSfxMuted, isFalse);

      final reloaded = LocalStorageService();
      await reloaded.init();
      expect(reloaded.isMusicMuted, isTrue);
      expect(reloaded.isSfxMuted, isFalse);

      await storage.setSfxMuted(true);
      expect(storage.isMusicMuted, isTrue,
          reason: 'the channels mute independently');
      expect(storage.isSfxMuted, isTrue);
    });
  });

  group('Music & SFX Channel Gating', () {
    test('a music-muted shift starts no soundtrack but plays effects',
        () async {
      final backend = RecordingBackend();
      final audio = GameAudioController(backend: backend)
        ..isMusicMuted = true;
      await audio.startMusic();

      expect(backend.bgmStarts, isEmpty,
          reason: 'music muted means no soundtrack starts');
      expect(backend.sfxPlays, isEmpty);

      await audio.playCoin();
      expect(backend.sfxPlays, hasLength(1),
          reason: 'the effects channel still sounds');
    });

    test('an effects-muted shift keeps the soundtrack and drops one-shots',
        () async {
      final backend = RecordingBackend();
      final audio = GameAudioController(backend: backend)
        ..isSfxMuted = true;
      await audio.startMusic();

      expect(backend.bgmStarts, hasLength(1),
          reason: 'the soundtrack is unaffected by the effects channel');

      await audio.playCoin();
      await audio.playJump();
      expect(backend.sfxPlays, isEmpty,
          reason: 'effects muted means no one-shots sound');
    });

    test('master mute still gates both channels', () async {
      final backend = RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.toggleMute();

      await audio.playCoin();
      await audio.startMusic();

      expect(backend.sfxPlays, isEmpty);
      expect(backend.bgmStarts, isEmpty);
    });

    test('muting music mid-shift stops the loops, unmuting restarts them',
        () async {
      final backend = RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();
      final startsBefore = backend.bgmStarts.length;
      expect(startsBefore, greaterThan(0));

      await audio.setMusicMuted(true);
      expect(backend.bgmStops, greaterThan(0),
          reason: 'flipping music off stops the playing soundtrack');
      expect(audio.isMusicMuted, isTrue);

      final stopsBefore = backend.bgmStops;
      await audio.setMusicMuted(false);
      expect(backend.bgmStarts.length, greaterThan(startsBefore),
          reason: 'unmuting restarts the soundtrack machine');
      expect(backend.bgmStops, equals(stopsBefore));
    });

    test('muting effects mid-shift is a silent flag flip', () async {
      final backend = RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();

      await audio.setSfxMuted(true);
      expect(backend.bgmStops, equals(0),
          reason: 'the soundtrack never notices the effects channel');
      expect(backend.sfxPlays, isEmpty);

      await audio.playCoin();
      expect(backend.sfxPlays, isEmpty);
    });

    test('rain ambience rides the music channel', () async {
      final backend = RecordingBackend();
      final audio = GameAudioController(backend: backend);
      await audio.startMusic();
      expect(backend.bgmStarts, hasLength(1));

      await audio.setMusicMuted(true);
      expect(backend.ambienceStarts, isEmpty);

      await audio.updateWeather(0.8);
      expect(backend.ambienceStarts, isEmpty,
          reason: 'rain rides the music channel: music muted, rain silent');

      await audio.setMusicMuted(false);
      await audio.updateWeather(0.8);
      expect(backend.ambienceStarts, hasLength(1),
          reason: 'rain returns with the music channel');
    });
  });
}
