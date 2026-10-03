import 'dart:math' as math;

/// Major weather conditions during a courier's shift.
enum WeatherCondition {
  clear,
  rain,
}

/// Manages dynamic weather state, rain intensity curves, and transitions across distance progression.
class WeatherController {
  WeatherController({
    this.cycleDistance = 5000.0,
  });

  /// Total distance in meters before weather pattern repeats.
  final double cycleDistance;

  /// Current rain intensity from 0.0 (completely dry) to 1.0 (heavy downpour).
  double rainIntensity = 0.0;

  /// Current active weather condition classification.
  WeatherCondition get condition =>
      rainIntensity > 0.08 ? WeatherCondition.rain : WeatherCondition.clear;

  /// True when active precipitation is falling.
  bool get isRaining => rainIntensity > 0.05;

  /// Overridden manual intensity for testing or scripted scenarios.
  double? _forcedIntensity;

  /// Forces a fixed rain intensity, bypassing distance-based calculations.
  void setManualIntensity(double? intensity) {
    _forcedIntensity = intensity?.clamp(0.0, 1.0);
    if (_forcedIntensity != null) {
      rainIntensity = _forcedIntensity!;
    }
  }

  /// Calculates rain intensity according to courier shift distance.
  ///
  /// Distance mapping across 5000m shift cycle:
  /// - 0m to 1400m: Clear daylight (0.0)
  /// - 1400m to 1700m: Dusk rain shower rolling in (0.0 -> 1.0)
  /// - 1700m to 2300m: Peak evening rain shower (1.0)
  /// - 2300m to 2600m: Rain clearing up (1.0 -> 0.0)
  /// - 2600m to 3400m: Clear midnight city sky (0.0)
  /// - 3400m to 3600m: Night drizzle starting (0.0 -> 0.75)
  /// - 3600m to 4000m: Steady midnight drizzle (0.75)
  /// - 4000m to 4200m: Drizzle clearing (0.75 -> 0.0)
  /// - 4200m to 5000m: Clear sunrise / dawn (0.0)
  static double calculateRainIntensity(double distance, {double cycle = 5000.0}) {
    final d = distance % cycle;

    // Shower 1: Evening rain storm during dusk
    if (d >= 1400.0 && d < 1700.0) {
      final t = (d - 1400.0) / 300.0;
      return 0.5 - 0.5 * math.cos(t * math.pi); // smooth S-curve ramp up
    } else if (d >= 1700.0 && d < 2300.0) {
      return 1.0;
    } else if (d >= 2300.0 && d < 2600.0) {
      final t = (d - 2300.0) / 300.0;
      return 0.5 + 0.5 * math.cos(t * math.pi); // smooth S-curve ramp down
    }
    // Shower 2: Midnight drizzle
    else if (d >= 3400.0 && d < 3600.0) {
      final t = (d - 3400.0) / 200.0;
      return (0.5 - 0.5 * math.cos(t * math.pi)) * 0.75;
    } else if (d >= 3600.0 && d < 4000.0) {
      return 0.75;
    } else if (d >= 4000.0 && d < 4200.0) {
      final t = (d - 4000.0) / 200.0;
      return (0.5 + 0.5 * math.cos(t * math.pi)) * 0.75;
    }

    return 0.0;
  }

  /// Updates current weather conditions according to runner distance.
  void update(double distanceMeters) {
    if (_forcedIntensity != null) {
      rainIntensity = _forcedIntensity!;
      return;
    }
    rainIntensity = calculateRainIntensity(distanceMeters, cycle: cycleDistance);
  }

  /// Resets weather state back to clear.
  void reset() {
    _forcedIntensity = null;
    rainIntensity = 0.0;
  }
}
