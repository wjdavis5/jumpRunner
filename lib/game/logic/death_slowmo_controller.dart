import 'dart:math' as math;

/// Runs the short slow-motion death beat between the terminal package loss
/// and the game-over modal, letting the final moment land before the recap.
class DeathSlowmoController {
  DeathSlowmoController({
    this.duration = 0.55,
    this.timeScale = 0.3,
    this.zoomIn = 1.3,
  });

  /// Real-time length of the slow-motion beat in seconds.
  final double duration;

  /// Component-tree time scale while the beat is active (0.3 = 30% speed).
  final double timeScale;

  /// Camera zoom factor eased toward during the beat.
  final double zoomIn;

  bool _active = false;
  double _elapsed = 0.0;

  /// True while the beat is playing (tree updates scaled, camera focused).
  bool get isActive => _active;

  /// Eased progress from 0.0 (beat start) to 1.0 (modal handoff).
  ///
  /// Holds at 1.0 after completion so late readers see the finished beat.
  double get progress => (_elapsed / duration).clamp(0.0, 1.0);

  /// Starts the death beat from zero.
  void begin() {
    _active = true;
    _elapsed = 0.0;
  }

  /// Advances the beat in real time; returns true on the completing frame.
  bool update(double dt) {
    if (!_active) return false;
    _elapsed += dt;
    if (_elapsed >= duration) {
      _elapsed = duration;
      _active = false;
      return true;
    }
    return false;
  }

  /// Camera zoom interpolated along an ease-out curve toward [zoomIn].
  double currentZoom(double baseZoom) {
    final t = progress;
    final eased = 1.0 - math.pow(1.0 - t, 3).toDouble();
    return baseZoom + (zoomIn - baseZoom) * eased;
  }

  /// Cancels any in-flight beat and restores idle state.
  void reset() {
    _active = false;
    _elapsed = 0.0;
  }
}
