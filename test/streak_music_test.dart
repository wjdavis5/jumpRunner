import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_controller_test.dart';

/// A backend that can hold the first music start of a crossfade open, so a
/// later frame can land while the swap is still in flight.
class _BlockingBgmBackend extends MockAudioBackend {
  Completer<void>? blockNextBgmStart;
  int bgmStartCalls = 0;

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {
    bgmStartCalls++;
    final blocker = blockNextBgmStart;
    if (blocker != null) {
      blockNextBgmStart = null;
      await blocker.future;
    }
    await super.startBgm(file, volume: volume);
  }
}

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

    test('a streak that returns while muted still brings the layer back', () async {
      await holdStreak();

      // The streak dies and its fade-out is under way when the player mutes.
      await audio.updateStreakIntensity(streakActive: false, dt: 0.1);
      await audio.toggleMute();
      expect(mockBackend.isLayerPlaying, isFalse);

      // The streak is re-earned while the sound is off.
      for (var i = 0; i < 6; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'nothing may play while muted');

      await audio.toggleMute();
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue,
          reason: 'a live streak must revive its layer after a mute');
      expect(
        mockBackend.layerVolume,
        closeTo(
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio,
          0.01,
        ),
      );
    });

    test('unmuting after the streak died starts no ghost layer', () async {
      await holdStreak();
      await audio.toggleMute();

      // The streak dies while the sound is off.
      for (var i = 0; i < 10; i++) {
        await audio.updateStreakIntensity(streakActive: false, dt: 0.05);
      }
      await audio.toggleMute();

      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'the layer must not come back for a streak that is gone');
      for (var i = 0; i < 12; i++) {
        await audio.updateStreakIntensity(streakActive: false, dt: 0.05);
      }
      expect(mockBackend.isLayerPlaying, isFalse);
    });

    test('the layer takes the music tempo so the two stay beat-locked', () async {
      await audio.updateSpeed(550);
      expect(audio.currentPlaybackRate, greaterThan(1.0));
      await holdStreak();
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmLayer));
      expect(
        mockBackend.layerPlaybackRate,
        closeTo(audio.currentPlaybackRate, 0.001),
        reason: 'a track sped up by running must carry the layer with it',
      );

      await audio.updateSpeed(200);
      expect(
        mockBackend.layerPlaybackRate,
        closeTo(audio.currentPlaybackRate, 0.001),
        reason: 'slowing back down must carry the layer too',
      );
    });

    test('a frame landing mid-swap does not start a second layer', () async {
      final backend = _BlockingBgmBackend();
      final controller = GameAudioController(backend: backend);
      await controller.startMusic();
      for (var i = 0; i < 12; i++) {
        await controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      expect(backend.isLayerPlaying, isTrue);
      expect(backend.layerStarts, equals(1));

      final blocker = Completer<void>();
      backend.blockNextBgmStart = blocker;
      // This frame crosses the fade threshold and suspends inside the swap's
      // music start...
      final swap = controller.updateMusicPhase(isNight: true, dt: 1.0);
      // ...and the next frame lands while the swap is still in flight.
      final nextFrame = controller.updateMusicPhase(isNight: true, dt: 0.1);
      await Future<void>.delayed(Duration.zero);

      expect(backend.bgmStartCalls, equals(2),
          reason: 'the swap must start the night track once, not once per frame');
      expect(backend.layerStarts, equals(1),
          reason: 'a frame landing mid-swap must not start a second layer');

      blocker.complete();
      await swap;
      await nextFrame;
      expect(controller.isNightTrack, isTrue);
      expect(backend.layerStarts, equals(2),
          reason: 'the swap itself still brings its one replacement layer');
      expect(backend.activeLayer, equals(GameAudioController.musicBgmNightLayer));
    });
  });
}
