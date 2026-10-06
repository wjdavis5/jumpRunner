import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioBackend mockBackend;
  late GameAudioController audio;

  /// Fades the layer fully in: ten steps of 0.05 s clear the 0.5 s fade.
  Future<void> holdStreak() async {
    for (var i = 0; i < 12; i++) {
      await audio.updateStreakIntensity(streakActive: true, dt: 0.05);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    mockBackend = MockAudioBackend();
    audio = GameAudioController(backend: mockBackend, storageService: storage);
    await audio.startMusic();
    mockBackend.playedSfx.clear();
  });

  group('Streak-driven intensity layer (issue #63 slice)', () {
    test('stays silent while no streak is live', () async {
      for (var i = 0; i < 30; i++) {
        await audio.updateStreakIntensity(streakActive: false, dt: 0.1);
      }

      expect(mockBackend.isLayerPlaying, isFalse);
      expect(mockBackend.layerStarts, equals(0));
    });

    test('fades in over about half a second once the streak goes live', () async {
      await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      expect(mockBackend.isLayerPlaying, isTrue);
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmLayer));
      expect(mockBackend.layerVolume, closeTo(0.0, 0.01),
          reason: 'the fade must start from silence');

      for (var i = 0; i < 6; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      }
      const fullLayer =
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio;
      expect(mockBackend.layerVolume, closeTo(fullLayer, 0.01));

      // Held at full, the volume stops moving.
      final settled = mockBackend.layerVolume;
      for (var i = 0; i < 10; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      }
      expect(mockBackend.layerVolume, closeTo(settled, 0.001));
    });

    test('fades back out and stops at silence when the streak ends', () async {
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue);

      for (var i = 0; i < 12; i++) {
        await audio.updateStreakIntensity(streakActive: false, dt: 0.05);
      }
      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'a fully faded-out layer must stop, not idle at zero');

      for (var i = 0; i < 10; i++) {
        await audio.updateStreakIntensity(streakActive: false, dt: 0.1);
      }
      expect(mockBackend.isLayerPlaying, isFalse);
    });

    test('a restarted streak rides the same loop instead of starting over', () async {
      await holdStreak();
      expect(mockBackend.layerStarts, equals(1));

      // The streak dies but is re-earned halfway through the fade-out.
      await audio.updateStreakIntensity(streakActive: false, dt: 0.1);
      await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      await holdStreak();

      expect(mockBackend.layerStarts, equals(1),
          reason: 'restarting a streak must not restart the layer loop');
      expect(mockBackend.isLayerPlaying, isTrue);
      expect(
        mockBackend.layerVolume,
        closeTo(
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio,
          0.01,
        ),
      );
    });

    test('mid-streak day-to-night crossfade swaps the layer at silence and it comes back',
        () async {
      await holdStreak();
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmLayer));

      var elapsed = 0.0;
      while (audio.isNightTrack == false && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
        elapsed += 0.1;
      }
      expect(audio.isNightTrack, isTrue);
      expect(mockBackend.activeBgm, equals(GameAudioController.musicBgmNight));
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmNightLayer),
          reason: 'the layer must swap to the matching track at the silence point');
      expect(mockBackend.isLayerPlaying, isTrue,
          reason: 'the streak is still live, so the layer comes back');

      for (var i = 0; i < 20; i++) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      }
      expect(
        mockBackend.layerVolume,
        closeTo(
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio,
          0.01,
        ),
        reason: 'the layer must ride back up on the night track',
      );
    });

    test('a crossfade with no streak live leaves no layer behind', () async {
      await holdStreak();
      // The streak dies just as night falls.
      await audio.updateStreakIntensity(streakActive: false, dt: 0.05);

      var elapsed = 0.0;
      while (audio.isNightTrack == false && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        await audio.updateStreakIntensity(streakActive: false, dt: 0.1);
        elapsed += 0.1;
      }
      for (var i = 0; i < 20; i++) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        await audio.updateStreakIntensity(streakActive: false, dt: 0.1);
      }

      expect(mockBackend.isLayerPlaying, isFalse);
      expect(mockBackend.activeLayer, isNot(equals(GameAudioController.musicBgmNightLayer)),
          reason: 'no orphaned night layer may outlive the streak');
    });

    test('starting a new run silences the layer until the next streak', () async {
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue);

      await audio.startMusic();
      expect(mockBackend.isLayerPlaying, isFalse);
      expect(mockBackend.layerStarts, equals(1),
          reason: 'the run restart is a hard cut, not another layer start');

      await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmLayer));
      expect(mockBackend.layerStarts, equals(2));
    });

    test('muting holds the layer and unmuting brings it back with the streak', () async {
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue);

      await audio.toggleMute();
      expect(mockBackend.isLayerPlaying, isFalse);

      for (var i = 0; i < 5; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      expect(mockBackend.layerStarts, equals(1),
          reason: 'nothing may start while muted');

      await audio.toggleMute();
      expect(mockBackend.isLayerPlaying, isTrue);
      expect(mockBackend.layerStarts, equals(2));
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmLayer));
    });

    test('backgrounding holds the layer and the foreground brings it back', () async {
      await holdStreak();

      await audio.suspendForBackground();
      expect(mockBackend.isLayerPlaying, isFalse);

      await audio.resumeFromBackground();
      expect(mockBackend.isLayerPlaying, isTrue);
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmLayer));
    });
  });
}
