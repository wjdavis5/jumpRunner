import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// Abstract interface for audio playback to decouple flame_audio platform calls
/// and allow deterministic headless testing without hardware audio plugins.
abstract class AudioPlayerInterface {
  Future<void> playSfx(String file, {double volume = 1.0});
  Future<void> startBgm(String file, {double volume = 0.7});
  Future<void> stopBgm();
  Future<void> setBgmVolume(double volume);
  Future<void> setPlaybackRate(double rate);

  Future<void> startAmbience(String file, {double volume = 0.0}) async {}
  Future<void> stopAmbience() async {}
  Future<void> setAmbienceVolume(double volume) async {}
}

/// Production audio backend delegating to FlameAudio.
///
/// Swallows platform errors quietly to ensure missing hardware channels never crash the app.
class FlameAudioBackend implements AudioPlayerInterface {
  AudioPlayer? _ambiencePlayer;

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('[Audio] Sfx error ($file): $e');
    }
  }

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {
    try {
      await FlameAudio.bgm.play(file, volume: volume);
    } catch (e) {
      debugPrint('[Audio] Bgm error ($file): $e');
    }
  }

  @override
  Future<void> stopBgm() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('[Audio] Bgm stop error: $e');
    }
  }

  @override
  Future<void> setBgmVolume(double volume) async {
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(volume);
    } catch (e) {
      debugPrint('[Audio] Bgm volume error: $e');
    }
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    try {
      await FlameAudio.bgm.audioPlayer.setPlaybackRate(rate);
    } catch (e) {
      debugPrint('[Audio] Bgm playback rate error: $e');
    }
  }

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {
    try {
      if (_ambiencePlayer != null) {
        await _ambiencePlayer!.stop();
      }
      _ambiencePlayer = await FlameAudio.loopLongAudio(file, volume: volume);
    } catch (e) {
      debugPrint('[Audio] Ambience error ($file): $e');
    }
  }

  @override
  Future<void> stopAmbience() async {
    try {
      if (_ambiencePlayer != null) {
        await _ambiencePlayer!.stop();
        _ambiencePlayer = null;
      }
    } catch (e) {
      debugPrint('[Audio] Ambience stop error: $e');
    }
  }

  @override
  Future<void> setAmbienceVolume(double volume) async {
    try {
      if (_ambiencePlayer != null) {
        await _ambiencePlayer!.setVolume(volume);
      }
    } catch (e) {
      debugPrint('[Audio] Ambience volume error: $e');
    }
  }
}

/// Central audio manager for Courier Dash.
///
/// Coordinates low-latency sound effect triggers (jump, coin, fumble, milestone),
/// looping background music, asset preloading, adaptive tempo scaling,
/// milestone ducking, and user mute persistence.
class GameAudioController {
  GameAudioController({
    AudioPlayerInterface? backend,
    LocalStorageService? storageService,
  })  : _backend = backend ?? FlameAudioBackend(),
        _storage = storageService {
    if (_storage != null) {
      isMuted = _storage!.isSoundMuted;
    }
  }

  final AudioPlayerInterface _backend;
  final LocalStorageService? _storage;

  static const double defaultBgmVolume = 0.7;
  static const double duckedBgmVolume = 0.3;
  static const double milestoneDuckedBgmVolume = 0.25;

  bool isMuted = false;
  bool isMusicActive = false;
  bool isPaused = false;
  bool isMilestoneDucking = false;

  double currentBgmVolume = defaultBgmVolume;
  double currentPlaybackRate = 1.0;

  final List<String> attemptedPlays = [];

  // Asset paths relative to assets/audio/
  static const String sfxJump = 'sfx/jump.ogg';
  static const String sfxCoin = 'sfx/coin.ogg';
  static const String sfxFumble = 'sfx/fumble.ogg';
  static const String sfxMilestone = 'sfx/milestone.ogg';
  static const String sfxRainAmbience = 'sfx/rain_ambience.ogg';
  static const String musicBgm = 'music/courier_groove.ogg';

  /// Maximum volume for ambient weather rain audio (Issue #27 requirement: 0.0 to 0.4).
  static const double maxRainAmbienceVolume = 0.4;

  double currentRainIntensity = 0.0;
  double currentRainVolume = 0.0;
  bool isRainAudioActive = false;

  /// Preloads audio assets into cache for low-latency playback.
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([
        sfxJump,
        sfxCoin,
        sfxFumble,
        sfxMilestone,
        sfxRainAmbience,
        musicBgm,
      ]);
    } catch (_) {}
  }

  /// Sets the background music volume (0.0 to 1.0).
  Future<void> setBgmVolume(double volume) async {
    currentBgmVolume = volume.clamp(0.0, 1.0);
    if (!isMuted && isMusicActive) {
      await _backend.setBgmVolume(currentBgmVolume);
    }
  }

  /// Sets the background music playback rate (0.5 to 2.0).
  Future<void> setPlaybackRate(double rate) async {
    currentPlaybackRate = rate.clamp(0.5, 2.0);
    if (!isMuted && isMusicActive) {
      await _backend.setPlaybackRate(currentPlaybackRate);
    }
  }

  /// Dynamically scales background music tempo based on courier running speed.
  Future<void> updateSpeed(double gameSpeed, {double baseSpeed = 200.0}) async {
    final targetRate = (1.0 + ((gameSpeed - baseSpeed) / baseSpeed) * 0.15).clamp(1.0, 1.25);
    if ((targetRate - currentPlaybackRate).abs() >= 0.02) {
      await setPlaybackRate(targetRate);
    }
  }

  /// Ducks background music volume down to [duckedBgmVolume] during game pause.
  Future<void> pauseDucking() async {
    isPaused = true;
    await setBgmVolume(duckedBgmVolume);
  }

  /// Restores background music volume to [defaultBgmVolume] on game resume.
  Future<void> resumeDucking() async {
    isPaused = false;
    if (!isMilestoneDucking) {
      await setBgmVolume(defaultBgmVolume);
    } else {
      await setBgmVolume(milestoneDuckedBgmVolume);
    }
  }

  /// Temporarily ducks background music volume during celebratory milestone fanfares.
  Future<void> duckForMilestone({
    Duration duration = const Duration(milliseconds: 1400),
  }) async {
    if (isMuted || !isMusicActive) return;
    isMilestoneDucking = true;
    await setBgmVolume(milestoneDuckedBgmVolume);

    Future.delayed(duration, () async {
      isMilestoneDucking = false;
      if (!isPaused && isMusicActive && !isMuted) {
        await setBgmVolume(defaultBgmVolume);
      }
    });
  }

  /// Toggles mute state and saves preference to local storage.
  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _storage?.setSoundMuted(isMuted);

    if (isMuted) {
      await _backend.stopBgm();
      if (isRainAudioActive) {
        await _backend.stopAmbience();
        isRainAudioActive = false;
        currentRainVolume = 0.0;
      }
    } else {
      if (isMusicActive) {
        final vol = isPaused
            ? duckedBgmVolume
            : (isMilestoneDucking ? milestoneDuckedBgmVolume : currentBgmVolume);
        await _backend.startBgm(musicBgm, volume: vol);
        if (currentPlaybackRate != 1.0) {
          await _backend.setPlaybackRate(currentPlaybackRate);
        }
      }
      if (currentRainIntensity > 0.01) {
        final targetVolume = currentRainIntensity * maxRainAmbienceVolume;
        isRainAudioActive = true;
        currentRainVolume = targetVolume;
        await _backend.startAmbience(sfxRainAmbience, volume: targetVolume);
      }
    }
  }

  /// Updates ambient weather audio based on rain precipitation intensity (0.0 to 1.0).
  ///
  /// Dynamically scales volume between 0.0 and 0.4 with smooth interpolation,
  /// and respects user mute state.
  Future<void> updateWeather(double rainIntensity) async {
    currentRainIntensity = rainIntensity.clamp(0.0, 1.0);
    final targetVolume = currentRainIntensity * maxRainAmbienceVolume;

    if (isMuted) {
      if (isRainAudioActive) {
        await _backend.stopAmbience();
        isRainAudioActive = false;
        currentRainVolume = 0.0;
      }
      return;
    }

    if (targetVolume > 0.01) {
      if (!isRainAudioActive) {
        isRainAudioActive = true;
        currentRainVolume = targetVolume;
        await _backend.startAmbience(sfxRainAmbience, volume: targetVolume);
      } else if ((targetVolume - currentRainVolume).abs() >= 0.01) {
        currentRainVolume = targetVolume;
        await _backend.setAmbienceVolume(targetVolume);
      }
    } else {
      if (isRainAudioActive) {
        await _backend.setAmbienceVolume(0.0);
        await _backend.stopAmbience();
        isRainAudioActive = false;
        currentRainVolume = 0.0;
      }
    }
  }

  /// Stops all ambient soundscapes (e.g. on run restart or game exit).
  Future<void> stopAmbience() async {
    isRainAudioActive = false;
    currentRainVolume = 0.0;
    currentRainIntensity = 0.0;
    await _backend.stopAmbience();
  }

  /// Plays jump sound effect.
  Future<void> playJump() async {
    if (isMuted) return;
    attemptedPlays.add(sfxJump);
    await _backend.playSfx(sfxJump, volume: 0.8);
  }

  /// Plays coin collection chime.
  Future<void> playCoin() async {
    if (isMuted) return;
    attemptedPlays.add(sfxCoin);
    await _backend.playSfx(sfxCoin, volume: 0.7);
  }

  /// Plays fumble / package damage sound.
  Future<void> playFumble() async {
    if (isMuted) return;
    attemptedPlays.add(sfxFumble);
    await _backend.playSfx(sfxFumble, volume: 0.9);
  }

  /// Plays celebratory milestone completion jingle and ducks background music.
  Future<void> playMilestone({
    Duration duckDuration = const Duration(milliseconds: 1400),
  }) async {
    if (isMuted) return;
    attemptedPlays.add(sfxMilestone);
    duckForMilestone(duration: duckDuration);
    await _backend.playSfx(sfxMilestone, volume: 1.0);
  }

  /// Starts looping background music track.
  Future<void> startMusic({double? volume}) async {
    isMusicActive = true;
    currentBgmVolume = volume ?? (isPaused ? duckedBgmVolume : defaultBgmVolume);
    if (isMuted) return;
    await _backend.startBgm(musicBgm, volume: currentBgmVolume);
    if (currentPlaybackRate != 1.0) {
      await _backend.setPlaybackRate(currentPlaybackRate);
    }
  }

  /// Stops background music track and active ambient soundscapes.
  Future<void> stopMusic() async {
    isMusicActive = false;
    await _backend.stopBgm();
    await stopAmbience();
  }
}
