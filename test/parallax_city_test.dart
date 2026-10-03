import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/parallax_city.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParallaxCityComponent & Environmental Lighting (Issue #13)', () {
    late ParallaxCityComponent parallax;

    setUp(() {
      parallax = ParallaxCityComponent(size: Vector2(960, 540));
    });

    test('Initializes with daytime lighting at 0m distance', () {
      expect(parallax.currentPhase, equals(TimeOfDayPhase.day));
      expect(parallax.currentPalette.lampGlow, equals(0.0));
      expect(parallax.currentPalette.stars, equals(0.0));
      expect(parallax.currentPalette.moonAlpha, equals(0.0));
      expect(parallax.currentPalette.skyTop, equals(TimeOfDayPalette.day.skyTop));
      expect(parallax.currentPalette.skyBottom, equals(TimeOfDayPalette.day.skyBottom));
      expect(parallax.streetlampGlowIntensity, equals(0.0));
      expect(parallax.starVisibility, equals(0.0));
    });

    test('Distance progression shifts through Day -> Dusk -> Night -> Dawn phases', () {
      // Daytime (0 - 1000m)
      expect(ParallaxCityComponent.calculatePhaseForDistance(0.0), equals(TimeOfDayPhase.day));
      expect(ParallaxCityComponent.calculatePhaseForDistance(500.0), equals(TimeOfDayPhase.day));
      expect(ParallaxCityComponent.calculatePhaseForDistance(1000.0), equals(TimeOfDayPhase.day));

      // Golden Hour / Dusk (1250 - 2500m)
      expect(ParallaxCityComponent.calculatePhaseForDistance(1300.0), equals(TimeOfDayPhase.dusk));
      expect(ParallaxCityComponent.calculatePhaseForDistance(1800.0), equals(TimeOfDayPhase.dusk));
      expect(ParallaxCityComponent.calculatePhaseForDistance(2400.0), equals(TimeOfDayPhase.dusk));

      // Midnight City (2500 - 4300m)
      expect(ParallaxCityComponent.calculatePhaseForDistance(2500.0), equals(TimeOfDayPhase.night));
      expect(ParallaxCityComponent.calculatePhaseForDistance(3000.0), equals(TimeOfDayPhase.night));
      expect(ParallaxCityComponent.calculatePhaseForDistance(4000.0), equals(TimeOfDayPhase.night));

      // Dawn / Sunrise cycle (4300 - 5000m)
      expect(ParallaxCityComponent.calculatePhaseForDistance(4400.0), equals(TimeOfDayPhase.dawn));
      expect(ParallaxCityComponent.calculatePhaseForDistance(4800.0), equals(TimeOfDayPhase.dawn));

      // Loops back to Day for endurance runs past 5000m
      expect(ParallaxCityComponent.calculatePhaseForDistance(5100.0), equals(TimeOfDayPhase.day));
      expect(ParallaxCityComponent.calculatePhaseForDistance(7500.0), equals(TimeOfDayPhase.night));
    });

    test('Smooth color lerping interpolates palettes without discrete jumps', () {
      // Midway between Day (900m) and Dusk (1600m) at 1250m: t = 0.5
      final midwayPalette = ParallaxCityComponent.calculatePaletteForDistance(1250.0);

      // Lamp glow should be midway between day (0.0) and dusk (0.7) -> ~0.35
      expect(midwayPalette.lampGlow, closeTo(0.35, 0.05));
      expect(midwayPalette.stars, closeTo(0.175, 0.05));

      // Sky colors should be interpolated between day and dusk
      final expectedSkyTop = Color.lerp(TimeOfDayPalette.day.skyTop, TimeOfDayPalette.dusk.skyTop, 0.5)!;
      expect(midwayPalette.skyTop.toARGB32(), equals(expectedSkyTop.toARGB32()));

      // Midnight peak (3000m)
      final nightPalette = ParallaxCityComponent.calculatePaletteForDistance(3000.0);
      expect(nightPalette.lampGlow, equals(1.0));
      expect(nightPalette.stars, equals(1.0));
      expect(nightPalette.moonAlpha, equals(1.0));
      expect(nightPalette.skyTop, equals(TimeOfDayPalette.night.skyTop));
      expect(nightPalette.building, equals(TimeOfDayPalette.night.building));
    });

    test('updateLighting updates distance, elapsed time, and palette', () {
      parallax.updateLighting(2000.0, 0.5);

      expect(parallax.distanceMeters, equals(2000.0));
      expect(parallax.elapsedTime, equals(0.5));
      expect(parallax.currentPhase, equals(TimeOfDayPhase.dusk));
      expect(parallax.streetlampGlowIntensity, closeTo(0.7, 0.01));
      expect(parallax.starVisibility, closeTo(0.35, 0.01));

      // Transition to midnight
      parallax.updateLighting(3200.0, 1.0);
      expect(parallax.currentPhase, equals(TimeOfDayPhase.night));
      expect(parallax.streetlampGlowIntensity, equals(1.0));
      expect(parallax.starVisibility, equals(1.0));
    });

    test('TimeOfDayPalette.lerp clamps parameter t safely within [0, 1]', () {
      final under = TimeOfDayPalette.lerp(TimeOfDayPalette.day, TimeOfDayPalette.night, -0.5);
      expect(under.lampGlow, equals(TimeOfDayPalette.day.lampGlow));

      final over = TimeOfDayPalette.lerp(TimeOfDayPalette.day, TimeOfDayPalette.night, 1.5);
      expect(over.lampGlow, equals(TimeOfDayPalette.night.lampGlow));
    });

    test('Layer offsets update properly with parallax city speed multipliers', () {
      parallax.speedMultiplier = 1.5;
      parallax.update(1.0);

      expect(parallax.skylineOffset, closeTo(30.0, 0.01));
      expect(parallax.midgroundOffset, closeTo(90.0, 0.01));
      expect(parallax.sidewalkOffset, closeTo(300.0, 0.01));
    });
  });
}
