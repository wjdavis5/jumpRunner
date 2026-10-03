import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Major environmental time-of-day phases mapped across courier distance progression.
enum TimeOfDayPhase {
  day,
  dusk,
  night,
  dawn,
}

/// Color and lighting specification for an urban environment time-of-day phase.
class TimeOfDayPalette {
  const TimeOfDayPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.skyline,
    required this.building,
    required this.windowLit,
    required this.windowUnlit,
    required this.sidewalk,
    required this.curb,
    required this.street,
    required this.lampGlow,
    required this.stars,
    required this.moonAlpha,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color skyline;
  final Color building;
  final Color windowLit;
  final Color windowUnlit;
  final Color sidewalk;
  final Color curb;
  final Color street;
  final double lampGlow;
  final double stars;
  final double moonAlpha;

  /// High-noon crisp daylight palette.
  static const TimeOfDayPalette day = TimeOfDayPalette(
    skyTop: Color(0xFF6BA3D8),
    skyBottom: Color(0xFFD4E6F1),
    skyline: Color(0xFF4A6572),
    building: Color(0xFF34495E),
    windowLit: Color(0x55B0BEC5),
    windowUnlit: Color(0x3378909C),
    sidewalk: Color(0xFF7F8C8D),
    curb: Color(0xFF5D6D7E),
    street: Color(0xFF2C3E50),
    lampGlow: 0.0,
    stars: 0.0,
    moonAlpha: 0.0,
  );

  /// Golden hour / sunset dusk palette with vibrant fiery skies and emerging lights.
  static const TimeOfDayPalette dusk = TimeOfDayPalette(
    skyTop: Color(0xFF3D235A),
    skyBottom: Color(0xFFE67E22),
    skyline: Color(0xFF2A1B3D),
    building: Color(0xFF212832),
    windowLit: Color(0xFFFFD54F),
    windowUnlit: Color(0x442C3E50),
    sidewalk: Color(0xFF5A6566),
    curb: Color(0xFF42494A),
    street: Color(0xFF1C2833),
    lampGlow: 0.7,
    stars: 0.35,
    moonAlpha: 0.5,
  );

  /// Midnight urban palette with dark navy skies, glowing windows, and radiant streetlamps.
  static const TimeOfDayPalette night = TimeOfDayPalette(
    skyTop: Color(0xFF0A0F1D),
    skyBottom: Color(0xFF1A2639),
    skyline: Color(0xFF0F1522),
    building: Color(0xFF141A26),
    windowLit: Color(0xFFF9E79F),
    windowUnlit: Color(0x22111722),
    sidewalk: Color(0xFF404646),
    curb: Color(0xFF2B3031),
    street: Color(0xFF0F141A),
    lampGlow: 1.0,
    stars: 1.0,
    moonAlpha: 1.0,
  );

  /// Early morning dawn palette transitioning back to daylight for endurance runs.
  static const TimeOfDayPalette dawn = TimeOfDayPalette(
    skyTop: Color(0xFF4A3568),
    skyBottom: Color(0xFFFFB380),
    skyline: Color(0xFF3B4152),
    building: Color(0xFF2B3746),
    windowLit: Color(0x88FFD54F),
    windowUnlit: Color(0x3337474F),
    sidewalk: Color(0xFF6B7778),
    curb: Color(0xFF4F5A5B),
    street: Color(0xFF212E3B),
    lampGlow: 0.3,
    stars: 0.15,
    moonAlpha: 0.2,
  );

  /// Smoothly interpolates between two environmental lighting palettes.
  static TimeOfDayPalette lerp(TimeOfDayPalette a, TimeOfDayPalette b, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return TimeOfDayPalette(
      skyTop: Color.lerp(a.skyTop, b.skyTop, clampedT) ?? a.skyTop,
      skyBottom: Color.lerp(a.skyBottom, b.skyBottom, clampedT) ?? a.skyBottom,
      skyline: Color.lerp(a.skyline, b.skyline, clampedT) ?? a.skyline,
      building: Color.lerp(a.building, b.building, clampedT) ?? a.building,
      windowLit: Color.lerp(a.windowLit, b.windowLit, clampedT) ?? a.windowLit,
      windowUnlit: Color.lerp(a.windowUnlit, b.windowUnlit, clampedT) ?? a.windowUnlit,
      sidewalk: Color.lerp(a.sidewalk, b.sidewalk, clampedT) ?? a.sidewalk,
      curb: Color.lerp(a.curb, b.curb, clampedT) ?? a.curb,
      street: Color.lerp(a.street, b.street, clampedT) ?? a.street,
      lampGlow: a.lampGlow + (b.lampGlow - a.lampGlow) * clampedT,
      stars: a.stars + (b.stars - a.stars) * clampedT,
      moonAlpha: a.moonAlpha + (b.moonAlpha - a.moonAlpha) * clampedT,
    );
  }
}

class _StarData {
  const _StarData(this.xRatio, this.yRatio, this.radius, this.twinkleSpeed, this.phaseOffset);
  final double xRatio;
  final double yRatio;
  final double radius;
  final double twinkleSpeed;
  final double phaseOffset;
}

/// Parallax city component rendering dynamic day/dusk/night environmental lighting:
/// 1. Skyline / distant clouds & rooftops: 20 px/s
/// 2. Midground urban storefronts & glowing windows: 60 px/s
/// 3. Foreground sidewalk, curb, and streetlamps: 200 px/s base
class ParallaxCityComponent extends PositionComponent {
  ParallaxCityComponent({Vector2? size}) {
    this.size = size ?? Vector2(960, 540);
    currentPalette = TimeOfDayPalette.day;
  }

  static const double baseSkylineSpeed = 20.0;
  static const double baseMidgroundSpeed = 60.0;
  static const double baseSidewalkSpeed = 200.0;

  double speedMultiplier = 1.0;

  double skylineOffset = 0.0;
  double midgroundOffset = 0.0;
  double sidewalkOffset = 0.0;

  double distanceMeters = 0.0;
  double elapsedTime = 0.0;

  late TimeOfDayPalette currentPalette;

  // Static color references preserved for backward compatibility
  static const Color skyTopColor = Color(0xFF6BA3D8);
  static const Color skyBottomColor = Color(0xFFD4E6F1);
  static const Color skylineColor = Color(0xFF4A6572);
  static const Color midgroundBuildingColor = Color(0xFF34495E);
  static const Color midgroundWindowColor = Color(0xFFF9E79F);
  static const Color sidewalkColor = Color(0xFF7F8C8D);
  static const Color curbColor = Color(0xFF5D6D7E);
  static const Color streetColor = Color(0xFF2C3E50);

  static const List<_StarData> _stars = [
    _StarData(0.05, 0.12, 1.5, 3.1, 0.2),
    _StarData(0.12, 0.22, 1.2, 2.4, 1.5),
    _StarData(0.18, 0.08, 2.0, 4.0, 2.8),
    _StarData(0.24, 0.28, 1.0, 2.0, 0.9),
    _StarData(0.31, 0.14, 1.8, 3.5, 3.4),
    _StarData(0.38, 0.25, 1.3, 2.7, 4.1),
    _StarData(0.45, 0.09, 2.2, 4.2, 1.2),
    _StarData(0.52, 0.32, 1.1, 1.8, 5.0),
    _StarData(0.59, 0.18, 1.6, 3.3, 2.1),
    _StarData(0.66, 0.27, 1.4, 2.9, 0.5),
    _StarData(0.72, 0.11, 2.0, 3.8, 3.9),
    _StarData(0.78, 0.30, 1.2, 2.2, 1.7),
    _StarData(0.85, 0.15, 1.7, 3.6, 4.6),
    _StarData(0.92, 0.24, 1.3, 2.5, 2.3),
    _StarData(0.08, 0.35, 1.0, 2.1, 3.0),
    _StarData(0.15, 0.17, 1.6, 3.7, 0.8),
    _StarData(0.22, 0.38, 1.2, 2.6, 5.2),
    _StarData(0.28, 0.05, 2.1, 4.1, 2.5),
    _StarData(0.35, 0.33, 1.1, 1.9, 1.1),
    _StarData(0.42, 0.19, 1.5, 3.2, 4.4),
    _StarData(0.49, 0.07, 1.9, 3.9, 0.3),
    _StarData(0.56, 0.36, 1.0, 2.3, 3.7),
    _StarData(0.63, 0.21, 1.7, 3.4, 2.0),
    _StarData(0.70, 0.34, 1.3, 2.8, 5.4),
    _StarData(0.76, 0.06, 2.3, 4.3, 1.4),
    _StarData(0.83, 0.31, 1.1, 2.0, 4.0),
    _StarData(0.89, 0.13, 1.8, 3.5, 0.7),
    _StarData(0.96, 0.29, 1.2, 2.4, 3.2),
  ];

  /// Calculates the active environmental time-of-day phase based on distance.
  TimeOfDayPhase get currentPhase => calculatePhaseForDistance(distanceMeters);

  /// Current streetlamp luminescence intensity (0.0 to 1.0).
  double get streetlampGlowIntensity => currentPalette.lampGlow;

  /// Current twinkling star visibility intensity (0.0 to 1.0).
  double get starVisibility => currentPalette.stars;

  /// Determines the active time-of-day phase from runner distance.
  static TimeOfDayPhase calculatePhaseForDistance(double distance) {
    final cycleDistance = distance % 5000.0;
    if (cycleDistance < 1250.0) {
      return TimeOfDayPhase.day;
    } else if (cycleDistance < 2500.0) {
      return TimeOfDayPhase.dusk;
    } else if (cycleDistance < 4300.0) {
      return TimeOfDayPhase.night;
    } else {
      return TimeOfDayPhase.dawn;
    }
  }

  /// Calculates the interpolated environmental palette across continuous runner distance.
  static TimeOfDayPalette calculatePaletteForDistance(double distance) {
    final cycleDistance = distance % 5000.0;

    // Phase 1: Daytime (0m to 900m)
    if (cycleDistance < 900.0) {
      return TimeOfDayPalette.day;
    }
    // Transition 1: Day -> Dusk (900m to 1600m)
    else if (cycleDistance < 1600.0) {
      final t = (cycleDistance - 900.0) / 700.0;
      return TimeOfDayPalette.lerp(TimeOfDayPalette.day, TimeOfDayPalette.dusk, t);
    }
    // Phase 2: Sunset / Dusk Peak (1600m to 2200m)
    else if (cycleDistance < 2200.0) {
      return TimeOfDayPalette.dusk;
    }
    // Transition 2: Dusk -> Midnight (2200m to 2800m)
    else if (cycleDistance < 2800.0) {
      final t = (cycleDistance - 2200.0) / 600.0;
      return TimeOfDayPalette.lerp(TimeOfDayPalette.dusk, TimeOfDayPalette.night, t);
    }
    // Phase 3: Midnight City (2800m to 4000m)
    else if (cycleDistance < 4000.0) {
      return TimeOfDayPalette.night;
    }
    // Transition 3: Midnight -> Dawn (4000m to 4600m)
    else if (cycleDistance < 4600.0) {
      final t = (cycleDistance - 4000.0) / 600.0;
      return TimeOfDayPalette.lerp(TimeOfDayPalette.night, TimeOfDayPalette.dawn, t);
    }
    // Transition 4: Dawn -> Daytime (4600m to 5000m)
    else {
      final t = (cycleDistance - 4600.0) / 400.0;
      return TimeOfDayPalette.lerp(TimeOfDayPalette.dawn, TimeOfDayPalette.day, t);
    }
  }

  /// Updates ambient lighting and sky colors according to courier distance.
  void updateLighting(double meters, [double dt = 0.0]) {
    distanceMeters = meters;
    elapsedTime += dt;
    currentPalette = calculatePaletteForDistance(meters);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final width = size.x;
    if (width <= 0) return;

    elapsedTime += dt;

    skylineOffset = (skylineOffset + baseSkylineSpeed * speedMultiplier * dt) % width;
    midgroundOffset = (midgroundOffset + baseMidgroundSpeed * speedMultiplier * dt) % width;
    sidewalkOffset = (sidewalkOffset + baseSidewalkSpeed * speedMultiplier * dt) % width;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    final groundY = h - 80;

    // 1. Dynamic Sky Gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [currentPalette.skyTop, currentPalette.skyBottom],
      ).createShader(Rect.fromLTWH(0, 0, w, groundY));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, groundY), skyPaint);

    // 2. Stars & Moon (Rendered behind distant skyline)
    if (currentPalette.stars > 0.01) {
      _renderStars(canvas, w, groundY);
    }
    if (currentPalette.moonAlpha > 0.01) {
      _renderMoon(canvas, w);
    }

    // 3. Far Skyline Layer (scrolls at skylineOffset)
    _renderSkyline(canvas, w, groundY, skylineOffset);

    // 4. Midground Storefronts Layer with lit windows (scrolls at midgroundOffset)
    _renderMidground(canvas, w, groundY, midgroundOffset);

    // 5. Foreground Sidewalk, Curb, Street, and Streetlamps (scrolls at sidewalkOffset)
    _renderSidewalk(canvas, w, h, groundY, sidewalkOffset);
  }

  void _renderStars(Canvas canvas, double w, double groundY) {
    final maxStarY = groundY - 140.0;
    for (final star in _stars) {
      final sx = star.xRatio * w;
      final sy = star.yRatio * maxStarY;
      final twinkle = 0.6 + 0.4 * math.sin(elapsedTime * star.twinkleSpeed + star.phaseOffset);
      final alpha = (currentPalette.stars * twinkle).clamp(0.0, 1.0);

      final starPaint = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), star.radius, starPaint);
    }
  }

  void _renderMoon(Canvas canvas, double w) {
    final moonCenter = Offset(w - 180.0, 75.0);
    final alpha = currentPalette.moonAlpha.clamp(0.0, 1.0);

    // Outer luminous glow
    final glowPaint = Paint()..color = const Color(0xFFFFF9C4).withValues(alpha: (0.18 * alpha).clamp(0.0, 1.0));
    canvas.drawCircle(moonCenter, 42.0, glowPaint);

    // Moon disc
    final moonPaint = Paint()..color = const Color(0xFFFFFDE7).withValues(alpha: (0.92 * alpha).clamp(0.0, 1.0));
    canvas.drawCircle(moonCenter, 22.0, moonPaint);

    // Soft crescent shadow
    final shadowPaint = Paint()..color = currentPalette.skyTop.withValues(alpha: (0.85 * alpha).clamp(0.0, 1.0));
    canvas.drawCircle(moonCenter + const Offset(8.0, -4.0), 19.0, shadowPaint);
  }

  void _renderSkyline(Canvas canvas, double w, double groundY, double offset) {
    final paint = Paint()..color = currentPalette.skyline;

    // Draw two slices side-by-side for seamless wrapping
    for (var slice = -1; slice <= 1; slice++) {
      final startX = slice * w - offset;

      for (var i = 0; i < 12; i++) {
        final bx = startX + i * 80.0;
        final bh = 140.0 + ((i * 37) % 80);
        const bw = 65.0;
        canvas.drawRect(
          Rect.fromLTWH(bx, groundY - bh, bw, bh),
          paint,
        );
      }
    }
  }

  void _renderMidground(Canvas canvas, double w, double groundY, double offset) {
    final buildingPaint = Paint()..color = currentPalette.building;
    final litWindowPaint = Paint()..color = currentPalette.windowLit;
    final unlitWindowPaint = Paint()..color = currentPalette.windowUnlit;

    for (var slice = -1; slice <= 1; slice++) {
      final startX = slice * w - offset;

      for (var i = 0; i < 8; i++) {
        final bx = startX + i * 120.0;
        final bh = 90.0 + ((i * 29) % 60);
        const bw = 100.0;

        // Building facade
        canvas.drawRect(
          Rect.fromLTWH(bx, groundY - bh, bw, bh),
          buildingPaint,
        );

        // Storefront windows / glowing residential windows
        for (var wy = groundY - bh + 15; wy < groundY - 20; wy += 25) {
          for (var wx = bx + 12; wx < bx + bw - 15; wx += 25) {
            final isLit = ((i * 5 + wy.toInt() * 7 + wx.toInt() * 11) % 5) != 0;
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, 15, 15),
              isLit ? litWindowPaint : unlitWindowPaint,
            );
          }
        }
      }
    }
  }

  void _renderSidewalk(Canvas canvas, double w, double h, double groundY, double offset) {
    // 1. Sidewalk body
    final sidewalkPaint = Paint()..color = currentPalette.sidewalk;
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, 24), sidewalkPaint);

    // 2. Curb edge
    final curbPaint = Paint()..color = currentPalette.curb;
    canvas.drawRect(Rect.fromLTWH(0, groundY + 20, w, 4), curbPaint);

    // 3. Street asphalt below curb
    final streetPaint = Paint()..color = currentPalette.street;
    canvas.drawRect(Rect.fromLTWH(0, groundY + 24, w, h - (groundY + 24)), streetPaint);

    // 4. Sidewalk slab joint lines that scroll
    final jointPaint = Paint()
      ..color = currentPalette.curb
      ..strokeWidth = 2;

    for (var slice = -1; slice <= 1; slice++) {
      final startX = slice * w - offset;
      for (var x = startX; x < startX + w; x += 60.0) {
        if (x >= -10 && x <= w + 10) {
          canvas.drawLine(Offset(x, groundY), Offset(x, groundY + 20), jointPaint);
        }
      }
    }

    // 5. Streetlamps along the sidewalk
    const lampSpacing = 240.0;
    for (var slice = -1; slice <= 1; slice++) {
      final startX = slice * w - offset;
      for (var lx = startX + 70.0; lx < startX + w; lx += lampSpacing) {
        if (lx >= -60.0 && lx <= w + 60.0) {
          _renderStreetlamp(canvas, lx, groundY, currentPalette.lampGlow);
        }
      }
    }
  }

  void _renderStreetlamp(Canvas canvas, double lx, double groundY, double glow) {
    final polePaint = Paint()..color = const Color(0xFF263238);
    final fixturePaint = Paint()..color = const Color(0xFF37474F);

    // Vertical iron lamp post
    canvas.drawRect(Rect.fromLTWH(lx - 2.0, groundY - 65.0, 4.0, 65.0), polePaint);

    // Base plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lx - 6.0, groundY - 3.0, 12.0, 3.0),
        const Radius.circular(1.5),
      ),
      polePaint,
    );

    // Curved bracket arm extending rightward toward sidewalk
    final armPath = Path()
      ..moveTo(lx, groundY - 55.0)
      ..quadraticBezierTo(lx + 2.0, groundY - 68.0, lx + 16.0, groundY - 68.0);
    canvas.drawPath(
      armPath,
      Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Lantern fixture housing
    canvas.drawRect(Rect.fromLTWH(lx + 10.0, groundY - 70.0, 12.0, 4.0), fixturePaint);

    // Luminous bulb
    final bulbRect = Rect.fromLTWH(lx + 11.5, groundY - 66.0, 9.0, 9.0);
    final bulbColor = Color.lerp(
      const Color(0xFF607D8B),
      const Color(0xFFFFF9C4),
      glow,
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bulbRect, const Radius.circular(2.0)),
      Paint()..color = bulbColor,
    );

    // Radiant streetlamp glow and sidewalk pool when active
    if (glow > 0.05) {
      final bulbCenter = Offset(lx + 16.0, groundY - 61.5);

      // Inner warm halo
      canvas.drawCircle(
        bulbCenter,
        18.0,
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: (0.32 * glow).clamp(0.0, 1.0)),
      );

      // Outer soft radial atmosphere
      canvas.drawCircle(
        bulbCenter,
        36.0,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: (0.16 * glow).clamp(0.0, 1.0)),
      );

      // Downward ground pool illumination on sidewalk
      final groundPoolRect = Rect.fromCenter(
        center: Offset(lx + 16.0, groundY + 8.0),
        width: 130.0 * glow,
        height: 20.0,
      );
      canvas.drawOval(
        groundPoolRect,
        Paint()..color = const Color(0xFFFFEE88).withValues(alpha: (0.22 * glow).clamp(0.0, 1.0)),
      );
    }
  }
}
