import 'dart:math' as math;
import 'package:flame/components.dart';

/// Manages camera screen trauma shake and dynamic high-speed framing zoom.
class CameraJuiceController {
  CameraJuiceController({
    Vector2? maxShakeOffset,
    this.maxAngleRad = 0.015,
    this.decayRate = 1.6,
    this.baseSpeed = 200.0,
    this.maxSpeed = 450.0,
    this.baseZoom = 1.0,
    this.highSpeedZoom = 0.94,
    this.zoomLerpSpeed = 2.5,
    math.Random? random,
  })  : maxShakeOffset = maxShakeOffset ?? Vector2(10.0, 7.0),
        _rng = random ?? math.Random(),
        currentZoom = baseZoom;

  /// Maximum camera position displacement during peak trauma shake.
  final Vector2 maxShakeOffset;

  /// Maximum camera angular displacement in radians during peak trauma shake.
  final double maxAngleRad;

  /// Linear decay rate of camera trauma per second.
  final double decayRate;

  /// Baseline courier speed (px/s) corresponding to default zoom (1.0x).
  final double baseSpeed;

  /// Peak courier speed (px/s) corresponding to maximum speed framing zoom (0.94x).
  final double maxSpeed;

  /// Normal rest camera zoom factor.
  final double baseZoom;

  /// Wide framing camera zoom factor at high velocity.
  final double highSpeedZoom;

  /// Interpolation rate for smooth zoom transitions.
  final double zoomLerpSpeed;

  final math.Random _rng;

  /// Current trauma level from 0.0 (still) to 1.0 (maximum impact).
  double trauma = 0.0;

  /// Non-linear shake intensity derived from current trauma (trauma^2).
  double get shakeIntensity => trauma * trauma;

  /// Current camera zoom factor.
  double currentZoom;

  /// Current camera translation shake offset.
  Vector2 shakeOffset = Vector2.zero();

  /// Current camera rotational shake in radians.
  double shakeAngle = 0.0;

  /// Adds impact trauma to the camera (e.g. 0.6 on hazard collision).
  void addTrauma(double amount) {
    trauma = (trauma + amount).clamp(0.0, 1.0);
  }

  /// Calculates target camera framing zoom for a given runner velocity.
  double calculateZoomForSpeed(double speed) {
    if (speed <= baseSpeed) return baseZoom;
    if (speed >= maxSpeed) return highSpeedZoom;
    final t = (speed - baseSpeed) / (maxSpeed - baseSpeed);
    return baseZoom - (baseZoom - highSpeedZoom) * t;
  }

  /// Advances trauma decay, calculates shake displacement, and lerps zoom.
  void update(double dt, {required double currentSpeed}) {
    updateShake(dt);

    // 3. Smoothly interpolate zoom toward velocity framing target
    final targetZoom = calculateZoomForSpeed(currentSpeed);
    currentZoom += (targetZoom - currentZoom) * (zoomLerpSpeed * dt).clamp(0.0, 1.0);
  }

  /// Advances trauma decay and the shake displacement, leaving zoom alone.
  ///
  /// The death beat drives the zoom itself but still needs the impact shake.
  void updateShake(double dt) {
    // 1. Linearly decay trauma
    if (trauma > 0.0) {
      trauma = math.max(0.0, trauma - decayRate * dt);
    }

    // 2. Calculate non-linear trauma shake
    final intensity = shakeIntensity;
    if (intensity > 0.001) {
      final rx = _rng.nextDouble() * 2.0 - 1.0;
      final ry = _rng.nextDouble() * 2.0 - 1.0;
      final ra = _rng.nextDouble() * 2.0 - 1.0;

      shakeOffset = Vector2(
        rx * maxShakeOffset.x * intensity,
        ry * maxShakeOffset.y * intensity,
      );
      shakeAngle = ra * maxAngleRad * intensity;
    } else {
      shakeOffset = Vector2.zero();
      shakeAngle = 0.0;
    }
  }

  /// Resets trauma, shake, and zoom back to default resting values.
  void reset() {
    trauma = 0.0;
    currentZoom = baseZoom;
    shakeOffset = Vector2.zero();
    shakeAngle = 0.0;
  }
}
