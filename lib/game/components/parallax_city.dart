import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Parallax city component rendering three continuous horizontal scrolling layers:
/// 1. Skyline / distant clouds & rooftops: 20 px/s
/// 2. Midground urban storefronts & brick buildings: 60 px/s
/// 3. Foreground sidewalk and curb: 200 px/s base
class ParallaxCityComponent extends PositionComponent {
  ParallaxCityComponent({Vector2? size}) {
    this.size = size ?? Vector2(960, 540);
  }

  static const double baseSkylineSpeed = 20.0;
  static const double baseMidgroundSpeed = 60.0;
  static const double baseSidewalkSpeed = 200.0;

  double speedMultiplier = 1.0;

  double skylineOffset = 0.0;
  double midgroundOffset = 0.0;
  double sidewalkOffset = 0.0;

  // Colors
  static const Color skyTopColor = Color(0xFF6BA3D8);
  static const Color skyBottomColor = Color(0xFFD4E6F1);
  static const Color skylineColor = Color(0xFF4A6572);
  static const Color midgroundBuildingColor = Color(0xFF34495E);
  static const Color midgroundWindowColor = Color(0xFFF9E79F);
  static const Color sidewalkColor = Color(0xFF7F8C8D);
  static const Color curbColor = Color(0xFF5D6D7E);
  static const Color streetColor = Color(0xFF2C3E50);

  @override
  void update(double dt) {
    super.update(dt);

    final width = size.x;
    if (width <= 0) return;

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

    // 1. Sky Gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skyTopColor, skyBottomColor],
      ).createShader(Rect.fromLTWH(0, 0, w, groundY));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, groundY), skyPaint);

    // 2. Far Skyline Layer (scrolls at skylineOffset)
    _renderSkyline(canvas, w, groundY, skylineOffset);

    // 3. Midground Storefronts Layer (scrolls at midgroundOffset)
    _renderMidground(canvas, w, groundY, midgroundOffset);

    // 4. Foreground Sidewalk & Street Layer (scrolls at sidewalkOffset)
    _renderSidewalk(canvas, w, h, groundY, sidewalkOffset);
  }

  void _renderSkyline(Canvas canvas, double w, double groundY, double offset) {
    final paint = Paint()..color = skylineColor;

    // Draw two slices side-by-side for seamless wrapping
    for (var slice = -1; slice <= 1; slice++) {
      final startX = slice * w - offset;

      // Stylized distant buildings
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
    final buildingPaint = Paint()..color = midgroundBuildingColor;
    final windowPaint = Paint()..color = midgroundWindowColor;

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

        // Storefront window / glowing windows
        for (var wy = groundY - bh + 15; wy < groundY - 20; wy += 25) {
          for (var wx = bx + 12; wx < bx + bw - 15; wx += 25) {
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, 15, 15),
              windowPaint,
            );
          }
        }
      }
    }
  }

  void _renderSidewalk(Canvas canvas, double w, double h, double groundY, double offset) {
    // Sidewalk body
    final sidewalkPaint = Paint()..color = sidewalkColor;
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, 24), sidewalkPaint);

    // Curb edge
    final curbPaint = Paint()..color = curbColor;
    canvas.drawRect(Rect.fromLTWH(0, groundY + 20, w, 4), curbPaint);

    // Street asphalt below curb
    final streetPaint = Paint()..color = streetColor;
    canvas.drawRect(Rect.fromLTWH(0, groundY + 24, w, h - (groundY + 24)), streetPaint);

    // Sidewalk slab joint lines that scroll
    final jointPaint = Paint()
      ..color = curbColor
      ..strokeWidth = 2;

    for (var slice = -1; slice <= 1; slice++) {
      final startX = slice * w - offset;
      for (var x = startX; x < startX + w; x += 60.0) {
        if (x >= -10 && x <= w + 10) {
          canvas.drawLine(Offset(x, groundY), Offset(x, groundY + 20), jointPaint);
        }
      }
    }
  }
}
