import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// Abstract interface for audio playback to decouple flame_audio platform calls
/// and allow deterministic headless testing without hardware audio plugins.
abstract class AudioPlayerInterface {
  Future<void> playSfx(String file, {double volume = 1.0});
  Future<void> startBgm(String file, {double volume = 0.7});
  Future<void> stopBgm();
}

/// Production audio backend delegating to FlameAudio.
///
/// Swallows platform errors quietly to ensure missing hardware channels never crash the app.
class FlameAudioBackend implements AudioPlayerInterface {
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
}

/// Central audio manager for Courier Dash.
///
/// Coordinates low-latency sound effect triggers (jump, coin, fumble, milestone),
/// looping background music, asset preloading, and user mute persistence.
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

  bool isMuted = false;
  bool isMusicActive = false;

  final List<String> attemptedPlays = [];

  // Asset paths relative to assets/audio/
  static const String sfxJump = 'sfx/jump.ogg';
  static const String sfxCoin = 'sfx/coin.ogg';
  static const String sfxFumble = 'sfx/fumble.ogg';
  static const String sfxMilestone = 'sfx/milestone.ogg';
  static const String musicBgm = 'music/courier_groove.ogg';

  /// Preloads audio assets into cache for low-latency playback.
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([
        sfxJump,
        sfxCoin,
        sfxFumble,
        sfxMilestone,
        musicBgm,
      ]);
    } catch (_) {}
  }

  /// Toggles mute state and saves preference to local storage.
  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _storage?.setSoundMuted(isMuted);

    if (isMuted) {
      await _backend.stopBgm();
    } else if (isMusicActive) {
      await _backend.startBgm(musicBgm, volume: 0.6);
    }
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

  /// Plays celebratory milestone completion jingle.
  Future<void> playMilestone() async {
    if (isMuted) return;
    attemptedPlays.add(sfxMilestone);
    await _backend.playSfx(sfxMilestone, volume: 1.0);
  }

  /// Starts looping background music track.
  Future<void> startMusic() async {
    isMusicActive = true;
    if (isMuted) return;
    await _backend.startBgm(musicBgm, volume: 0.6);
  }

  /// Stops background music track.
  Future<void> stopMusic() async {
    isMusicActive = false;
    await _backend.stopBgm();
  }
}
