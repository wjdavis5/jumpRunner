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

/// A backend whose layer player only lands when the blocked start is
/// cleared, the way the real one holds no player until its platform call
/// returns.
class _SlowStartBackend extends MockAudioBackend {
  Completer<void>? blockNextLayerStart;
  int layerStartCalls = 0;

  @override
  Future<void> startLayer(String file, {double volume = 0.0}) async {
    layerStartCalls++;
    final blocker = blockNextLayerStart;
    if (blocker != null) {
      blockNextLayerStart = null;
      await blocker.future;
    }
    await super.startLayer(file, volume: volume);
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

      for (var i = 0; i < 3; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      }
      const fullLayer =
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio;
      expect(mockBackend.layerVolume, closeTo(fullLayer * 0.6, 0.01),
          reason: 'three tenths into the half-second fade is three fifths up');

      for (var i = 0; i < 3; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
      }
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
      expect(audio.isNightTrack, isTrue,
          reason: 'the crossfade must complete for this claim to mean anything');
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

      // The replacement layer a night swap starts keeps the tempo too.
      var elapsed = 0.0;
      while (!audio.isNightTrack && elapsed < 5.0) {
        await audio.updateMusicPhase(isNight: true, dt: 0.1);
        await audio.updateStreakIntensity(streakActive: true, dt: 0.1);
        elapsed += 0.1;
      }
      expect(audio.isNightTrack, isTrue);
      expect(mockBackend.activeLayer, equals(GameAudioController.musicBgmNightLayer));
      expect(
        mockBackend.layerPlaybackRate,
        closeTo(audio.currentPlaybackRate, 0.001),
        reason: 'the replacement layer must start at the tempo the music holds',
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

    test('a slow crossfade still brings the music and the layer back up', () async {
      final backend = _BlockingBgmBackend();
      final controller = GameAudioController(backend: backend);
      await controller.startMusic();
      for (var i = 0; i < 12; i++) {
        await controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      }

      final blocker = Completer<void>();
      backend.blockNextBgmStart = blocker;
      final swap = controller.updateMusicPhase(isNight: true, dt: 1.0);
      // Many frames pass while the swap's platform calls are held open.
      for (var i = 0; i < 20; i++) {
        await controller.updateMusicPhase(isNight: true, dt: 0.1);
        await controller.updateStreakIntensity(streakActive: true, dt: 0.1);
      }

      blocker.complete();
      await swap;
      for (var i = 0; i < 20; i++) {
        await controller.updateMusicPhase(isNight: true, dt: 0.1);
        await controller.updateStreakIntensity(streakActive: true, dt: 0.1);
      }

      expect(controller.isNightTrack, isTrue);
      expect(backend.activeLayer, equals(GameAudioController.musicBgmNightLayer));
      expect(backend.bgmVolume, closeTo(GameAudioController.defaultBgmVolume, 0.01),
          reason: 'the night track must ride back up, not stay at silence');
      expect(
        backend.layerVolume,
        closeTo(
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio,
          0.01,
        ),
        reason: 'the replacement layer must ride back up with it',
      );
    });

    test('a player that lands late is raised to the volume the fade holds', () async {
      final backend = _SlowStartBackend();
      final controller = GameAudioController(backend: backend);
      await controller.startMusic();

      final blocker = Completer<void>();
      backend.blockNextLayerStart = blocker;
      final start = controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      // The fade runs all the way open while the player is still loading.
      for (var i = 0; i < 12; i++) {
        await controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      blocker.complete();
      await start;

      const fullLayer =
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio;
      expect(backend.layerStartCalls, equals(1));
      expect(backend.isLayerPlaying, isTrue);
      expect(backend.layerVolume, closeTo(fullLayer, 0.01),
          reason: 'the late player must be raised to the fade, not left at zero');
    });

    test('mute landing while the layer is still loading keeps it silent', () async {
      final backend = _SlowStartBackend();
      final controller = GameAudioController(backend: backend);
      await controller.startMusic();

      // A streak is live with the sound off, then the sound comes back.
      await controller.toggleMute();
      for (var i = 0; i < 6; i++) {
        await controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      await controller.toggleMute();

      final blocker = Completer<void>();
      backend.blockNextLayerStart = blocker;
      final streakFrame = controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      await Future<void>.delayed(Duration.zero);
      // The sound goes off again while the player is still loading.
      await controller.toggleMute();
      blocker.complete();
      await streakFrame;
      await Future<void>.delayed(Duration.zero);

      expect(backend.layerStartCalls, equals(1));
      expect(backend.isLayerPlaying, isFalse,
          reason: 'a player landing after the mute must be stopped, not left playing');
      for (var i = 0; i < 6; i++) {
        await controller.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      expect(backend.isLayerPlaying, isFalse);
    });

    test('a streak earned after unmute revives a layer the dead one left without a player',
        () async {
      await holdStreak();
      await audio.toggleMute();

      // The streak dies while muted, then the sound comes back...
      for (var i = 0; i < 10; i++) {
        await audio.updateStreakIntensity(streakActive: false, dt: 0.05);
      }
      await audio.toggleMute();
      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'the dead streak must not bring a ghost layer back');

      // ...and only then is a new streak earned.
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue,
          reason: 'the new streak must get its layer even though the old one left no player');
      expect(
        mockBackend.layerVolume,
        closeTo(
          GameAudioController.defaultBgmVolume * GameAudioController.streakLayerVolumeRatio,
          0.01,
        ),
      );
    });

    test('a stopped shift takes its layer and the next run starts silent', () async {
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue);

      await audio.stopMusic();
      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'music and layer stop together');

      for (var i = 0; i < 12; i++) {
        await audio.updateStreakIntensity(streakActive: true, dt: 0.05);
      }
      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'no layer may run with the music stopped');

      await audio.startMusic();
      expect(mockBackend.isLayerPlaying, isFalse,
          reason: 'a new run begins silent until a streak earns the layer');
      await holdStreak();
      expect(mockBackend.isLayerPlaying, isTrue);
    });
  });
}
