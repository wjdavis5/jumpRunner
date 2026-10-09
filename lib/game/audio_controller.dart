import 'dart:math' as math;
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// Enumerates courier personality voice bark categories.
enum CourierBarkType {
  /// Energetic vocal pop for stunts (rail ollie, parkour vault, steam boost).
  stunt,

  /// Tight reflex gasp for near-miss hazard clearances.
  nearMiss,

  /// Dismayed vocal grunt when stumbling or suffering hazard collision.
  damage,

  /// Airborne floating shout when deploying backpack glider.
  glide,
}

/// Enumerates customer doorstep reaction vocal categories.
enum CustomerReactionType {
  /// Cheerful thank you upon successful package drop-off.
  thankYou,

  /// Enthusiastic 5-star rating shout for pristine deliveries.
  fiveStars,
}

/// Crossfade lifecycle between the day and night background tracks.
enum _MusicSwapState {
  idle,

  /// The old track fades out before the swap.
  fadingOut,

  /// The swap's platform calls are in flight; fades wait for them to land so
  /// a slow start cannot be overtaken by a fade that already finished.
  swapping,

  /// The new track fades in.
  fadingIn,
}

/// Fade lifecycle of the stunt-streak intensity layer.
enum _LayerFadeState { silent, fadingIn, audible, fadingOut }

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

  /// The streak layer is an extra loop riding on top of the music; a backend
  /// without layer support simply ignores it. Returns whether a layer player
  /// is now playing: a start that could not produce one (missing asset,
  /// platform error) reports false so the controller can retry.
  Future<bool> startLayer(String file, {double volume = 0.0}) async => true;
  Future<void> stopLayer() async {}
  Future<void> setLayerVolume(double volume) async {}

  /// Keeps the layer at the music's tempo. Without it a scaled-up track and
  /// the un-scaled layer drift apart while a streak rides them.
  Future<void> setLayerPlaybackRate(double rate) async {}
}

/// Production audio backend delegating to FlameAudio.
///
/// Swallows platform errors quietly to ensure missing hardware channels never crash the app.
class FlameAudioBackend implements AudioPlayerInterface {
  AudioPlayer? _ambiencePlayer;
  AudioPlayer? _layerPlayer;

  /// Bumped by every layer stop and start. A start whose platform call is
  /// still in flight compares its own request against this when the player
  /// finally lands: if it was superseded, it stops the player it just made
  /// instead of leaking an orphan loop the controller can never reach.
  int _layerRequest = 0;

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

  @override
  Future<bool> startLayer(String file, {double volume = 0.0}) async {
    final request = ++_layerRequest;
    try {
      // One layer at a time: swapping tracks replaces the player instead of
      // stacking a second loop over the first. The slot is cleared before the
      // load so a stop landing meanwhile does not miss the loading player.
      final previous = _layerPlayer;
      _layerPlayer = null;
      if (previous != null) {
        await _disposePlayer(previous);
      }
      final player = await FlameAudio.loopLongAudio(file, volume: volume);
      if (request != _layerRequest) {
        // Stopped, or superseded by a newer start, while this one loaded.
        await _disposePlayer(player);
        return false;
      }
      _layerPlayer = player;
      return true;
    } catch (e) {
      debugPrint('[Audio] Layer error ($file): $e');
      return false;
    }
  }

  @override
  Future<void> stopLayer() async {
    _layerRequest++;
    final player = _layerPlayer;
    _layerPlayer = null;
    if (player != null) {
      await _disposePlayer(player);
    }
  }

  /// Stops and releases a layer player, never throwing: a player whose stop
  /// fails is still dropped so it cannot block the next start.
  Future<void> _disposePlayer(AudioPlayer player) async {
    try {
      await player.stop();
      await player.dispose();
    } catch (e) {
      debugPrint('[Audio] Layer stop error: $e');
    }
  }

  @override
  Future<void> setLayerVolume(double volume) async {
    try {
      if (_layerPlayer != null) {
        await _layerPlayer!.setVolume(volume);
      }
    } catch (e) {
      debugPrint('[Audio] Layer volume error: $e');
    }
  }

  @override
  Future<void> setLayerPlaybackRate(double rate) async {
    try {
      if (_layerPlayer != null) {
        await _layerPlayer!.setPlaybackRate(rate);
      }
    } catch (e) {
      debugPrint('[Audio] Layer playback rate error: $e');
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

  /// Whether the mellow night track is currently the music target.
  bool isNightTrack = false;

  /// Fade progress multiplier applied on top of the target BGM volume
  /// while crossfading between day and night tracks (1.0 = full).
  double _trackFadeMultiplier = 1.0;
  _MusicSwapState _swapState = _MusicSwapState.idle;
  bool _swapTargetIsNight = false;
  double _fadeTimer = 0.0;
  String _activeTrack = musicBgm;

  // Streak layer state. [_streakRequested] remembers the last flag the game
  // fed so mute/backgrounding can bring the layer back with the music;
  // [_layerAudible] says the backend actually holds a layer player.
  _LayerFadeState _layerState = _LayerFadeState.silent;
  bool _streakRequested = false;
  bool _layerAudible = false;
  double _layerFade = 0.0;

  /// Seconds until a failed layer start may be tried again.
  double _layerRetryCooldown = 0.0;

  final List<String> attemptedPlays = [];

  // Asset paths relative to assets/audio/
  static const String sfxJump = 'sfx/jump.ogg';
  static const String sfxCoin = 'sfx/coin.ogg';
  static const String sfxFumble = 'sfx/fumble.ogg';
  static const String sfxMilestone = 'sfx/milestone.ogg';
  static const String sfxRainAmbience = 'sfx/rain_ambience.ogg';
  static const String sfxThunder = 'sfx/thunder.ogg';
  static const String sfxBarkStunt = 'sfx/bark_stunt.ogg';
  static const String sfxBarkNearMiss = 'sfx/bark_near_miss.ogg';
  static const String sfxBarkDamage = 'sfx/bark_damage.ogg';
  static const String sfxBarkGlide = 'sfx/bark_glide.ogg';
  static const String sfxCustomerThankYou = 'sfx/customer_thank_you.ogg';
  static const String sfxCustomerFiveStars = 'sfx/customer_five_stars.ogg';
  static const String musicBgm = 'music/courier_groove.ogg';

  /// Mellow midnight-city loop that crossfades in during the night phase.
  static const String musicBgmNight = 'music/courier_night.ogg';

  /// High-tempo arpeggio layer riding on the day track while a stunt streak
  /// of [streakLayerThreshold] or more is live (issue #63). Sample-matched to
  /// [musicBgm] so the two stay locked when started together.
  static const String musicBgmLayer = 'music/courier_groove_layer.ogg';

  /// Night counterpart of the streak layer, sample-matched to [musicBgmNight].
  static const String musicBgmNightLayer = 'music/courier_night_layer.ogg';

  /// Streak length at which the intensity layer enters (issue #63: >= 3).
  static const int streakLayerThreshold = 3;

  /// How long the streak layer takes to fade in or out, in seconds.
  static const double streakLayerFadeDuration = 0.5;

  /// The streak layer rides at this fraction of the music's audible volume,
  /// so pause/milestone ducking and track fades scale it exactly like the BGM.
  static const double streakLayerVolumeRatio = 0.5;

  /// How long to wait before retrying a layer start the backend could not
  /// make (missing asset, platform error).
  static const double layerRetryCooldownSeconds = 1.0;

  /// Crossfade duration in seconds for day <-> night track swaps.
  static const double trackFadeDuration = 0.8;

  /// Volume the BGM should hold right now, ignoring any track fade.
  double get _effectiveBgmVolume => isPaused
      ? duckedBgmVolume
      : (isMilestoneDucking ? milestoneDuckedBgmVolume : currentBgmVolume);

  /// Advances the day <-> night music crossfade; call once per frame.
  ///
  /// When the night flag flips, the current track fades out over
  /// [trackFadeDuration], swaps at silence, and the new track fades in.
  /// Ducking (pause/milestone) remains authoritative: fades multiply the
  /// effective ducked volume and never overwrite the base.
  Future<void> updateMusicPhase({required bool isNight, required double dt}) async {
    if (!isMusicActive || isMuted) return;

    if (_swapState == _MusicSwapState.idle && isNight != isNightTrack) {
      _swapState = _MusicSwapState.fadingOut;
      _swapTargetIsNight = isNight;
      _fadeTimer = 0.0;
    }

    switch (_swapState) {
      case _MusicSwapState.idle:
        return;

      case _MusicSwapState.fadingOut:
        _fadeTimer += dt;
        final t = (_fadeTimer / trackFadeDuration).clamp(0.0, 1.0);
        _trackFadeMultiplier = 1.0 - t;
        await _backend.setBgmVolume(_effectiveBgmVolume * _trackFadeMultiplier);
        await _pushLayerVolume();
        if (t >= 1.0 && _swapState == _MusicSwapState.fadingOut) {
          // Claim the swap before any await: frames landing while the
          // platform calls are still in flight wait for them instead of
          // re-running the block or starting a second layer over the first.
          _swapState = _MusicSwapState.swapping;
          isNightTrack = _swapTargetIsNight;
          _activeTrack = isNightTrack ? musicBgmNight : musicBgm;
          await _backend.startBgm(_activeTrack, volume: 0.0);
          if (currentPlaybackRate != 1.0) {
            await _backend.setPlaybackRate(currentPlaybackRate);
          }
          // The layer swaps with the track at silence so the two restart in
          // step; with no streak live nothing may survive the swap.
          if (_layerAudible) {
            await _startLayer(volume: 0.0);
          } else {
            await _backend.stopLayer();
          }
          // The swap may have been superseded while its platform calls were
          // in flight (a run restart is a hard cut, not a fade); only the
          // swap that still owns the state may arm the fade in.
          if (_swapState == _MusicSwapState.swapping) {
            _swapState = _MusicSwapState.fadingIn;
            _fadeTimer = 0.0;
          }
        }
        return;

      case _MusicSwapState.swapping:
        // A swap is in flight; fades wait for the platform calls to land.
        return;

      case _MusicSwapState.fadingIn:
        _fadeTimer += dt;
        final t = (_fadeTimer / trackFadeDuration).clamp(0.0, 1.0);
        _trackFadeMultiplier = t;
        await _backend.setBgmVolume(_effectiveBgmVolume * t);
        await _pushLayerVolume();
        if (t >= 1.0 && _swapState == _MusicSwapState.fadingIn) {
          _trackFadeMultiplier = 1.0;
          _swapState = _MusicSwapState.idle;
          await setBgmVolume(_effectiveBgmVolume);
        }
        return;
    }
  }

  /// Advances the stunt-streak intensity layer; call once per frame, right
  /// after [updateMusicPhase].
  ///
  /// While the streak flag is live ([streakLayerThreshold] or more stunts,
  /// issue #63) the layer fades in over [streakLayerFadeDuration]; when the
  /// streak dies it fades back out and stops at silence. A streak restarting
  /// while the layer is still up never restarts the loop: only its volume
  /// moves, so the arp stays in step with the music it rides.
  ///
  /// The flag is remembered even while muted so a mute/unmute pair cannot
  /// bring back the layer for a streak that is already gone; a state the
  /// machine still wants audible but whose backend player was held (mute,
  /// backgrounding) is started again instead of staying silent for a shift.
  Future<void> updateStreakIntensity({
    required bool streakActive,
    required double dt,
  }) async {
    _streakRequested = streakActive;
    if (!isMusicActive || isMuted) return;
    if (_layerRetryCooldown > 0) {
      _layerRetryCooldown =
          (_layerRetryCooldown - dt).clamp(0.0, layerRetryCooldownSeconds);
    }

    switch (_layerState) {
      case _LayerFadeState.silent:
        if (!streakActive) return;
        _layerFade = 0.0;
        _layerState = _LayerFadeState.fadingIn;
        await _startLayer(volume: 0.0);
        return;

      case _LayerFadeState.fadingIn:
        if (!streakActive) {
          _layerState = _LayerFadeState.fadingOut;
          return;
        }
        await _startLayerIfMissing();
        _layerFade = (_layerFade + dt / streakLayerFadeDuration).clamp(0.0, 1.0);
        await _pushLayerVolume();
        if (_layerFade >= 1.0) {
          _layerState = _LayerFadeState.audible;
        }
        return;

      case _LayerFadeState.audible:
        if (!streakActive) {
          _layerState = _LayerFadeState.fadingOut;
          return;
        }
        await _startLayerIfMissing();
        return;

      case _LayerFadeState.fadingOut:
        if (streakActive) {
          // The streak came back before the fade-out finished: ride the
          // existing loop back up instead of starting it from the top.
          _layerState = _LayerFadeState.fadingIn;
          await _startLayerIfMissing();
          return;
        }
        _layerFade = (_layerFade - dt / streakLayerFadeDuration).clamp(0.0, 1.0);
        if (_layerFade <= 0.0) {
          _layerState = _LayerFadeState.silent;
          _layerAudible = false;
          await _backend.stopLayer();
          return;
        }
        await _pushLayerVolume();
        return;
    }
  }

  /// The streak layer file matching the track that is playing right now.
  String get _activeLayerTrack => isNightTrack ? musicBgmNightLayer : musicBgmLayer;

  /// Volume the streak layer should hold right now: the music's own audible
  /// volume scaled by the layer ratio and the layer's fade progress. Ducking
  /// and track fades therefore multiply the layer exactly as they multiply
  /// the BGM.
  double get _effectiveLayerVolume =>
      _effectiveBgmVolume * streakLayerVolumeRatio * _layerFade * _trackFadeMultiplier;

  Future<void> _pushLayerVolume() async {
    if (_layerAudible && isMusicActive && !isMuted) {
      await _backend.setLayerVolume(_effectiveLayerVolume);
    }
  }

  /// Starts the layer loop at its current fade volume (or at [volume]) and
  /// takes the music's tempo with it.
  ///
  /// The player only exists once the backend call returns. A start the
  /// backend could not make (missing asset, platform error) reports false:
  /// the flag is cleared and the next streak frames retry after
  /// [layerRetryCooldownSeconds] instead of leaving the layer silently dead
  /// for the rest of the shift. If the layer was stopped (mute,
  /// backgrounding, run restart) while the player loaded, the player that
  /// just landed is stopped again; otherwise it is raised to the volume the
  /// fade holds *now*, which may have moved on while the start was slow.
  Future<void> _startLayer({double? volume}) async {
    _layerAudible = true;
    final started = await _backend.startLayer(
      _activeLayerTrack,
      volume: volume ?? _effectiveLayerVolume,
    );
    if (!started) {
      _layerAudible = false;
      _layerRetryCooldown = layerRetryCooldownSeconds;
      return;
    }
    if (isMuted || !isMusicActive || isBackgrounded || _layerState == _LayerFadeState.silent) {
      // The layer was stopped while the player was loading; a player that
      // lands after its stop must not keep playing.
      await _backend.stopLayer();
      return;
    }
    await _applyLayerPlaybackRate();
    await _pushLayerVolume();
  }

  /// Starts the layer loop when the state machine says it should be playing
  /// but the backend no longer holds a player: mute and backgrounding stop
  /// the player without touching the fade state, so a streak that outlives
  /// them has to bring its layer back, not leave it silent.
  Future<void> _startLayerIfMissing() async {
    if (_layerAudible || _layerRetryCooldown > 0) return;
    await _startLayer();
  }

  /// Keeps the layer on the music's current tempo.
  Future<void> _applyLayerPlaybackRate() async {
    if (currentPlaybackRate != 1.0) {
      await _backend.setLayerPlaybackRate(currentPlaybackRate);
    }
  }

  /// Brings the streak layer back with the music after both were held
  /// (mute, backgrounding): both restart from the top of the loop.
  Future<void> _restartLayerWithMusic() async {
    if (_layerState == _LayerFadeState.silent || !_streakRequested) return;
    await _startLayer();
  }

  /// Voice bark text line variations by courier bark category.
  static const Map<CourierBarkType, List<String>> courierBarkLines = {
    CourierBarkType.stunt: [
      'Woohoo!',
      'Slick!',
      'Easy money!',
      'Nailed it!',
    ],
    CourierBarkType.nearMiss: [
      'Whoa!',
      'Close one!',
      'Too close!',
    ],
    CourierBarkType.damage: [
      'Oof! My packages!',
      'Ouch!',
      'Watch the boxes!',
    ],
    CourierBarkType.glide: [
      'Floating!',
      'Catching air!',
      'Hang time!',
    ],
  };

  /// Customer doorstep reaction line variations by reaction category.
  static const Map<CustomerReactionType, List<String>> customerReactionLines = {
    CustomerReactionType.thankYou: [
      'Thank you!',
      'Right on time!',
      'Awesome delivery!',
    ],
    CustomerReactionType.fiveStars: [
      'Five stars! ★★★★★',
      'Best courier ever!',
      'Flawless delivery!',
    ],
  };

  /// Cooldown throttle between courier voice barks in seconds.
  double courierBarkCooldownSeconds = 2.0;

  /// Cooldown throttle between customer doorstep reactions in seconds.
  double customerReactionCooldownSeconds = 1.5;

  DateTime? _lastCourierBarkTime;
  DateTime? _lastCustomerReactionTime;

  final math.Random random = math.Random();

  final List<void Function(CourierBarkType type, String line)> _courierBarkListeners = [];
  final List<void Function(CustomerReactionType type, String line)> _customerReactionListeners = [];

  /// Registers an additional listener for courier voice barks.
  void addCourierBarkListener(void Function(CourierBarkType type, String line) listener) {
    _courierBarkListeners.add(listener);
  }

  /// Removes a previously registered courier voice bark listener.
  void removeCourierBarkListener(void Function(CourierBarkType type, String line) listener) {
    _courierBarkListeners.remove(listener);
  }

  /// Registers an additional listener for customer doorstep reactions.
  void addCustomerReactionListener(void Function(CustomerReactionType type, String line) listener) {
    _customerReactionListeners.add(listener);
  }

  /// Removes a previously registered customer reaction listener.
  void removeCustomerReactionListener(void Function(CustomerReactionType type, String line) listener) {
    _customerReactionListeners.remove(listener);
  }

  /// Primary callback invoked when barks or customer reactions are triggered.
  void Function(CourierBarkType type, String line)? onCourierBark;
  void Function(CustomerReactionType type, String line)? onCustomerReaction;

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
        sfxThunder,
        sfxBarkStunt,
        sfxBarkNearMiss,
        sfxBarkDamage,
        sfxBarkGlide,
        sfxCustomerThankYou,
        sfxCustomerFiveStars,
        musicBgm,
        musicBgmNight,
        musicBgmLayer,
        musicBgmNightLayer,
      ]);
    } catch (_) {}
  }

  /// Sets the background music volume (0.0 to 1.0).
  Future<void> setBgmVolume(double volume) async {
    currentBgmVolume = volume.clamp(0.0, 1.0);
    if (!isMuted && isMusicActive) {
      await _backend.setBgmVolume(currentBgmVolume);
      // Ducking goes through here, so the layer rides along: it scales by
      // the same factor the BGM just received.
      await _pushLayerVolume();
    }
  }

  /// Sets the background music playback rate (0.5 to 2.0).
  Future<void> setPlaybackRate(double rate) async {
    currentPlaybackRate = rate.clamp(0.5, 2.0);
    if (!isMuted && isMusicActive) {
      await _backend.setPlaybackRate(currentPlaybackRate);
      // The layer rides the same tempo; without this the running track scales
      // up while the arp does not, and the two drift apart within a loop.
      await _backend.setLayerPlaybackRate(currentPlaybackRate);
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
      await _backend.stopLayer();
      _layerAudible = false;
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
        await _backend.startBgm(_activeTrack, volume: vol);
        if (currentPlaybackRate != 1.0) {
          await _backend.setPlaybackRate(currentPlaybackRate);
        }
        await _restartLayerWithMusic();
      }
      if (currentRainIntensity > 0.01) {
        final targetVolume = currentRainIntensity * maxRainAmbienceVolume;
        isRainAudioActive = true;
        currentRainVolume = targetVolume;
        await _backend.startAmbience(sfxRainAmbience, volume: targetVolume);
      }
    }
  }

  /// True while the app is in the background and all looping audio is held.
  bool isBackgrounded = false;

  /// Silences music and ambience when the app leaves the foreground.
  ///
  /// Nothing else stops them: without this the soundtrack keeps playing
  /// behind a phone call or another app.
  Future<void> suspendForBackground() async {
    if (isBackgrounded) return;
    isBackgrounded = true;
    if (isMuted) return;
    await _backend.stopBgm();
    await _backend.stopLayer();
    _layerAudible = false;
    if (isRainAudioActive) {
      await _backend.stopAmbience();
    }
  }

  /// Restores whatever was playing when the app returns to the foreground.
  Future<void> resumeFromBackground() async {
    if (!isBackgrounded) return;
    isBackgrounded = false;
    if (isMuted) return;
    if (isMusicActive) {
      // Whichever of the day and night tracks was playing comes back.
      await _backend.startBgm(_activeTrack, volume: _effectiveBgmVolume);
      if (currentPlaybackRate != 1.0) {
        await _backend.setPlaybackRate(currentPlaybackRate);
      }
      await _restartLayerWithMusic();
    }
    if (isRainAudioActive) {
      await _backend.startAmbience(sfxRainAmbience, volume: currentRainVolume);
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

  /// Plays rolling thunderstorm rumble audio.
  Future<void> playThunder({double volume = 0.85}) async {
    if (isMuted) return;
    attemptedPlays.add(sfxThunder);
    await _backend.playSfx(sfxThunder, volume: volume);
  }

  /// Starts looping background music track.
  Future<void> startMusic({double? volume}) async {
    isMusicActive = true;
    // Runs begin in daylight; snap back to the day track without a fade
    // (a run restart is already a hard scene cut).
    isNightTrack = false;
    _swapState = _MusicSwapState.idle;
    _trackFadeMultiplier = 1.0;
    _activeTrack = musicBgm;
    // A new shift starts silent until the next streak earns the layer back.
    _layerState = _LayerFadeState.silent;
    _streakRequested = false;
    _layerFade = 0.0;
    if (_layerAudible) {
      await _backend.stopLayer();
      _layerAudible = false;
    }
    currentBgmVolume = volume ?? (isPaused ? duckedBgmVolume : defaultBgmVolume);
    if (isMuted) return;
    await _backend.startBgm(_activeTrack, volume: currentBgmVolume);
    if (currentPlaybackRate != 1.0) {
      await _backend.setPlaybackRate(currentPlaybackRate);
    }
  }

  /// Stops background music track and active ambient soundscapes.
  Future<void> stopMusic() async {
    isMusicActive = false;
    await _backend.stopBgm();
    await _backend.stopLayer();
    _layerAudible = false;
    _layerState = _LayerFadeState.silent;
    _streakRequested = false;
    _layerFade = 0.0;
    await stopAmbience();
  }

  /// Whether a courier voice bark can be triggered according to cooldown.
  bool canPlayCourierBark({DateTime? now}) {
    if (_lastCourierBarkTime == null) return true;
    final current = now ?? DateTime.now();
    final elapsed = current.difference(_lastCourierBarkTime!).inMilliseconds / 1000.0;
    return elapsed >= courierBarkCooldownSeconds;
  }

  /// Whether a customer doorstep reaction can be triggered according to cooldown.
  bool canPlayCustomerReaction({DateTime? now}) {
    if (_lastCustomerReactionTime == null) return true;
    final current = now ?? DateTime.now();
    final elapsed = current.difference(_lastCustomerReactionTime!).inMilliseconds / 1000.0;
    return elapsed >= customerReactionCooldownSeconds;
  }

  /// Resets voice bark and customer reaction cooldown timers.
  void resetBarkCooldowns() {
    _lastCourierBarkTime = null;
    _lastCustomerReactionTime = null;
  }

  /// Plays an expressive courier voice bark if cooldown permits.
  ///
  /// Returns `true` if the bark was triggered, or `false` if throttled by cooldown.
  Future<bool> playCourierBark(
    CourierBarkType type, {
    bool ignoreCooldown = false,
    String? line,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    if (!ignoreCooldown && !canPlayCourierBark(now: current)) {
      return false;
    }
    _lastCourierBarkTime = current;

    final availableLines = courierBarkLines[type] ?? ['Woohoo!'];
    final selectedLine = line ?? availableLines[random.nextInt(availableLines.length)];

    onCourierBark?.call(type, selectedLine);
    for (final l in List.of(_courierBarkListeners)) {
      l(type, selectedLine);
    }

    if (isMuted) return true;

    final sfxPath = _courierBarkSfx(type);
    attemptedPlays.add(sfxPath);
    await _backend.playSfx(sfxPath, volume: 0.85);
    return true;
  }

  /// Plays a cheerful customer doorstep reaction if cooldown permits.
  ///
  /// Returns `true` if the reaction was triggered, or `false` if throttled by cooldown.
  Future<bool> playCustomerReaction(
    CustomerReactionType type, {
    bool ignoreCooldown = false,
    String? line,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    if (!ignoreCooldown && !canPlayCustomerReaction(now: current)) {
      return false;
    }
    _lastCustomerReactionTime = current;

    final availableLines = customerReactionLines[type] ?? ['Thank you!'];
    final selectedLine = line ?? availableLines[random.nextInt(availableLines.length)];

    onCustomerReaction?.call(type, selectedLine);
    for (final l in List.of(_customerReactionListeners)) {
      l(type, selectedLine);
    }

    if (isMuted) return true;

    final sfxPath = _customerReactionSfx(type);
    attemptedPlays.add(sfxPath);
    await _backend.playSfx(sfxPath, volume: 0.9);
    return true;
  }

  String _courierBarkSfx(CourierBarkType type) {
    switch (type) {
      case CourierBarkType.stunt:
        return sfxBarkStunt;
      case CourierBarkType.nearMiss:
        return sfxBarkNearMiss;
      case CourierBarkType.damage:
        return sfxBarkDamage;
      case CourierBarkType.glide:
        return sfxBarkGlide;
    }
  }

  String _customerReactionSfx(CustomerReactionType type) {
    switch (type) {
      case CustomerReactionType.thankYou:
        return sfxCustomerThankYou;
      case CustomerReactionType.fiveStars:
        return sfxCustomerFiveStars;
    }
  }
}
