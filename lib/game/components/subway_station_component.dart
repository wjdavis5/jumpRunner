import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_font.dart';

/// Subterranean subway transit station corridor component.
///
/// Features authentic ceramic tile masonry, colored transit line band,
/// illuminated green globe entrance kiosks, flickering fluorescent tubes,
/// tactile yellow platform edge paving, and steel track rails.
class SubwayStationComponent extends PositionComponent {
  SubwayStationComponent({
    required Vector2 position,
    Vector2? size,
    this.groundY = 460.0,
    this.stationName = '8th Ave Express',
    this.lineColor = const Color(0xFF2980B9),
  }) : super(
          position: position,
          size: size ?? Vector2(1000.0, 260.0),
          priority: wallPriority,
        );

  /// The station is a wall a whole chunk wide and it is solid. It has to be
  /// drawn behind the courier and everything else on the street, which all
  /// sit at the default priority of 0, or it paints over them.
  static const int wallPriority = -1;

  final double groundY;
  final String stationName;
  final Color lineColor;

  /// Whether the courier has entered this station and registered transit rewards.
  bool hasTriggeredTransit = false;

  /// Whether this station has scrolled completely past the screen.
  bool get shouldRecycle => position.x + size.x < -200.0;

  double _flickerTimer = 0.0;
  bool _lightsFlicker = false;

  /// Current fluorescent light flicker state.
  bool get lightsFlicker => _lightsFlicker;

  /// Elapsed time within the flicker interval.
  double get flickerTimer => _flickerTimer;

  @override
  void update(double dt) {
    super.update(dt);
    _flickerTimer += dt;
    if (_flickerTimer >= 0.7) {
      _flickerTimer = 0.0;
      _lightsFlicker = !_lightsFlicker;
    }
  }

  // The station is some 900 shapes and five text layouts, and none of it
  // moves: only the tube lights toggle. Each of its two looks is recorded
  // once and replayed, instead of being rebuilt on every frame it is alive.
  final Map<bool, ui.Picture> _recorded = {};
  final Vector2 _recordedSize = Vector2.zero();

  /// How many times the station has been painted from scratch.
  @visibleForTesting
  int paintCount = 0;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_recordedSize != size) {
      _discardRecordings();
      _recordedSize.setFrom(size);
    }
    final picture = _recorded[_lightsFlicker] ??= _record();
    canvas.drawPicture(picture);
  }

  ui.Picture _record() {
    final recorder = ui.PictureRecorder();
    paintStation(Canvas(recorder));
    return recorder.endRecording();
  }

  void _discardRecordings() {
    for (final picture in _recorded.values) {
      picture.dispose();
    }
    _recorded.clear();
  }

  @override
  void onRemove() {
    _discardRecordings();
    super.onRemove();
  }

  /// Paints the whole station as it looks right now.
  @visibleForTesting
  void paintStation(Canvas canvas) {
    paintCount++;
    final w = size.x;
    final h = size.y;

    // 1. Subterranean Dark Background & Ceramic Subway Tile Wall
    final wallBasePaint = Paint()..color = const Color(0xFF1A1D20);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), wallBasePaint);

    final tilePaint = Paint()..color = const Color(0xFFE5E8E8);
    final groutPaint = Paint()
      ..color = const Color(0xFFBDC3C7)
      ..strokeWidth = 1.0;

    const tileW = 28.0;
    const tileH = 14.0;
    final numCols = (w / tileW).ceil() + 1;
    final numRows = (h / tileH).ceil();

    // The brick-bond rows start half a tile outside the wall and run past
    // its far end; clipped so the wall has straight sides where it meets
    // the street.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    for (int r = 2; r < numRows; r++) {
      final y = r * tileH;
      final xOffset = r.isEven ? 0.0 : tileW / 2;
      for (int c = -1; c < numCols; c++) {
        final x = (c * tileW) + xOffset;
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, tileW - 2, tileH - 2), tilePaint);
      }
      canvas.drawLine(Offset(0, y), Offset(w, y), groutPaint);
    }
    canvas.restore();

    // 2. Colored Transit Line Mosaic Stripe & Station Name Band
    final bandY = h * 0.45;
    const bandHeight = 28.0;
    final stripePaint = Paint()..color = lineColor;
    canvas.drawRect(Rect.fromLTWH(0, bandY, w, bandHeight), stripePaint);

    final stripeBorder = Paint()
      ..color = const Color(0xFF1C2833)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromLTWH(0, bandY, w, bandHeight), stripeBorder);

    // Repeat station name signs every 280px along the wall
    for (double sx = 60.0; sx < w - 80.0; sx += 280.0) {
      // Station plaque background
      final plaqueRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(sx, bandY + 4, 180, 20),
        const Radius.circular(3),
      );
      canvas.drawRRect(plaqueRect, Paint()..color = const Color(0xFF1A252F));
      canvas.drawRRect(
        plaqueRect,
        Paint()
          ..color = const Color(0xFFF1C40F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final textSpan = TextSpan(
        text: '★ $stationName ★',
        style: const TextStyle(
          fontFamily: gameFontFamily,
          color: Colors.white,
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(sx + (180 - tp.width) / 2, bandY + 8));
    }

    // 3. Stylized Subterranean Graffiti Murals
    final graffitiPaint = Paint()
      ..color = const Color(0xFFE74C3C).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final graffitiCyan = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw graffiti tag on tile wall
    final tagX = w * 0.52;
    final tagY = h * 0.65;
    final tagPath = Path()
      ..moveTo(tagX, tagY)
      ..lineTo(tagX + 15, tagY - 18)
      ..lineTo(tagX + 30, tagY)
      ..moveTo(tagX + 10, tagY - 8)
      ..lineTo(tagX + 22, tagY - 8);
    canvas.drawPath(tagPath, graffitiPaint);

    final tagPath2 = Path()
      ..moveTo(tagX + 38, tagY - 16)
      ..lineTo(tagX + 38, tagY)
      ..lineTo(tagX + 54, tagY)
      ..moveTo(tagX + 38, tagY - 8)
      ..lineTo(tagX + 50, tagY - 8);
    canvas.drawPath(tagPath2, graffitiCyan);

    // 4. Ceiling Steel Girders & Fluorescent Tube Light Fixtures
    final girderPaint = Paint()..color = const Color(0xFF2C3E50);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 24), girderPaint);

    final lightFixturePaint = Paint()..color = const Color(0xFF34495E);
    final tubePaint = Paint()
      ..color = _lightsFlicker ? const Color(0xFFFFF9C4) : const Color(0xFFFFFFFF);
    final ambientGlow = Paint()
      ..color = (_lightsFlicker ? const Color(0x33FFF59D) : const Color(0x22E0F7FA))
      ..style = PaintingStyle.fill;

    for (double lx = 40.0; lx < w; lx += 140.0) {
      // Steel conduit drop
      canvas.drawLine(Offset(lx + 25, 24), Offset(lx + 25, 36), Paint()..color = const Color(0xFF7F8C8D)..strokeWidth = 2);
      // Hanging light fixture
      canvas.drawRect(Rect.fromLTWH(lx, 36, 50, 6), lightFixturePaint);
      canvas.drawRect(Rect.fromLTWH(lx + 4, 40, 42, 3), tubePaint);
      // Downward ambient conical glow
      final glowPath = Path()
        ..moveTo(lx, 42)
        ..lineTo(lx - 25, 120)
        ..lineTo(lx + 75, 120)
        ..lineTo(lx + 50, 42)
        ..close();
      canvas.drawPath(glowPath, ambientGlow);
    }

    // 5. Subway Entrance Kiosk with Twin Green Globe Lamps (at x = 20)
    final kioskIronPaint = Paint()..color = const Color(0xFF1B4F72);
    final globeLampPaint = Paint()..color = const Color(0xFF2ECC71);
    final globeGlowPaint = Paint()
      ..color = const Color(0x552ECC71)
      ..style = PaintingStyle.fill;

    // Iron archway pillars
    canvas.drawRect(Rect.fromLTWH(16, h - 80, 8, 80), kioskIronPaint);
    canvas.drawRect(Rect.fromLTWH(64, h - 80, 8, 80), kioskIronPaint);
    canvas.drawRect(Rect.fromLTWH(12, h - 84, 64, 8), kioskIronPaint);

    // Illuminated green subway globe lamps
    canvas.drawCircle(const Offset(20, 172), 6.5, globeGlowPaint);
    canvas.drawCircle(const Offset(20, 172), 4.5, globeLampPaint);
    canvas.drawCircle(const Offset(68, 172), 6.5, globeGlowPaint);
    canvas.drawCircle(const Offset(68, 172), 4.5, globeLampPaint);

    // Kiosk Header Text
    final kioskText = TextPainter(
      text: const TextSpan(
        text: 'SUBWAY',
        style: TextStyle(
          fontFamily: gameFontFamily,
          color: Colors.white,
          fontSize: 7.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    kioskText.paint(canvas, const Offset(26, 178));

    // 6. Platform Concrete Edge & Yellow Tactile Warning Paving
    final platformConcrete = Paint()..color = const Color(0xFF5D6D7E);
    final tactileYellow = Paint()..color = const Color(0xFFF1C40F);
    final platformRect = Rect.fromLTWH(0, h - 18, w, 18);
    canvas.drawRect(platformRect, platformConcrete);

    // Tactile safety bump dots along the edge
    for (double tx = 4.0; tx < w; tx += 12.0) {
      canvas.drawCircle(Offset(tx, h - 14), 2.5, tactileYellow);
      canvas.drawCircle(Offset(tx + 6, h - 10), 2.5, tactileYellow);
    }

    // 7. Track Bed Wooden Cross-ties & Parallel Steel Rails
    final tiePaint = Paint()..color = const Color(0xFF4A3525);
    final railSteelPaint = Paint()..color = const Color(0xFF95A5A6);

    for (double rx = 0.0; rx < w; rx += 24.0) {
      canvas.drawRect(Rect.fromLTWH(rx, h - 5, 14, 5), tiePaint);
    }
    // Running rails
    canvas.drawLine(Offset(0, h - 4), Offset(w, h - 4), railSteelPaint..strokeWidth = 2.0);
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), railSteelPaint..strokeWidth = 2.0);

    // 8. Moody Atmospheric Vignette Ceiling Shadow
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.75),
          Colors.black.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), shadowPaint);
  }
}
