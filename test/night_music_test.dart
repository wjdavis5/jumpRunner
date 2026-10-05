import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioBackend mockBackend;
  late GameAudioController audio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    mockBackend = MockAudioBackend();
    audio = GameAudioController(backend: mockBackend, storageService: storage);
    await audio.startMusic();
    mockBackend.playedSfx.clear();
  });

  group('Adaptive night music crossfade (issue #63 slice)', () {
    test('stays on the day track while the phase holds steady', () async {
      for (var i = 0; i < 30; i++) {
        await audio.updateMusicPhase(isNight: false, dt: 0.1);
      }

      expect(audio.isNightTrack, isFalse);
      expect(mockBackend.activeBgm, equals(GameAudioController.musicBgm));
      expect(mockBackend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01));
    });

    test('night flag fades out, swaps track at silence, then fades in', () async {
      // Flip to night and step through the full crossfade.
      var elapsed = 0.0;
      while (audio.isNightTrack == false && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        elapsed += 0.1;
      }
      expect(audio.isNightTrack, isTrue);
      expect(mockBackend.activeBgm, equals(GameAudioController.musicBgmNight));

      // Volume was silent at the swap and ramps back up afterwards.
      expect(mockBackend.bgmVolume, greaterThanOrEqualTo(0.0));
      for (var i = 0; i < 20; i++) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
      }
      expect(
        mockBackend.bgmVolume,
        closeTo(GameAudioController.defaultBgmVolume, 0.01),
        reason: 'fade-in must restore the full BGM volume',
      );
    });

    test('fades back to the day track when dawn arrives', () async {
      var elapsed = 0.0;
      while (audio.isNightTrack == false && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        elapsed += 0.1;
      }
      while (mockBackend.activeBgm != GameAudioController.musicBgm && elapsed < 10.0) {
        await audio.updateMusicPhase(isNight: false, dt: 0.1);
        elapsed += 0.1;
      }

      expect(mockBackend.activeBgm, equals(GameAudioController.musicBgm));
      expect(audio.isNightTrack, isFalse);
    });

    test('faded volume never exceeds the ducked volume while paused', () async {
      await audio.pauseDucking();

      var highest = 0.0;
      var elapsed = 0.0;
      while (audio.isNightTrack == false && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        elapsed += 0.1;
        highest = highest > mockBackend.bgmVolume ? highest : mockBackend.bgmVolume;
      }

      expect(
        highest,
        lessThanOrEqualTo(GameAudioController.duckedBgmVolume + 0.01),
        reason: 'crossfade must respect pause ducking as the volume ceiling',
      );
    });

    test('starting a new run snaps back to the day track', () async {
      var elapsed = 0.0;
      while (audio.isNightTrack == false && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        elapsed += 0.1;
      }
      expect(mockBackend.activeBgm, equals(GameAudioController.musicBgmNight));

      await audio.startMusic();
      expect(audio.isNightTrack, isFalse);
      expect(mockBackend.activeBgm, equals(GameAudioController.musicBgm));
    });
  });
}
