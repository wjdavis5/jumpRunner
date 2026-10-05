import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'courier_player.dart';

/// Rooftop photovoltaic solar panel array that enables couriers to execute kinetic skate slides,
/// accumulating electrical charge across silicon cells and unleashing high-voltage Solar Surge EMPs.
///
/// Features brushed aluminum chassis mounting frames, dark crystalline blue photovoltaic cells
/// with conductive silver busbar grids, specular glass sheen reflections, and onboard LED capacitor gauges.
class SolarPanelComponent extends PositionComponent {
  SolarPanelComponent({
    required Vector2 position,
    required Vector2 size,
    this.groundY = 460.0,
  }) : super(position: position, size: size);

  final double groundY;

  /// Top surface Y coordinate where the courier's shoes or skateboard slide.
  double get surfaceY => position.y;

  /// Whether this solar panel array has scrolled completely offscreen.
  bool get shouldRecycle => position.x + size.x < -120.0;

  /// Kinetic electrical charge level accumulated while sliding (0.0 to 1.0).
  double chargeLevel = 0.0;

  /// Whether a courier is actively sliding/grinding across this panel array.
  bool isCharging = false;

  /// Whether this panel array has discharged its Solar Surge EMP burst upon completion.
  bool hasDischarged = false;

  double _pulseTimer = 0.0;

  // Visual styling paints
  static final Paint _framePaint = Paint()
    ..color = const Color(0xFF78909C) // Brushed aluminum chassis
    ..style = PaintingStyle.fill;

  static final Paint _frameBorderPaint = Paint()
    ..color = const Color(0xFFCFD8DC) // Frame highlight edge
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _stanchionPaint = Paint()
    ..color = const Color(0xFF455A64) // Heavy industrial support steel
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke;

  static final Paint _flangePaint = Paint()..color = const Color(0xFF263238);

  static final Paint _solarCellPaint = Paint()
    ..color = const Color(0xFF0D47A1) // Deep crystalline photovoltaic blue
    ..style = PaintingStyle.fill;

  static final Paint _solarCellBorderPaint = Paint()
    ..color = const Color(0xFF1976D2) // Cell border divide
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _busbarPaint = Paint()
    ..color = const Color(0xFF80DEEA).withValues(alpha: 0.65) // Fine silver busbar grid
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _glassGlossPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.22)
    ..style = PaintingStyle.fill;

  /// Accumulates kinetic electrical charge while sliding.
  void addCharge(double amount) {
    chargeLevel = (chargeLevel + amount).clamp(0.0, 1.0);
  }

  /// Checks if the courier's bottom footprint intersects the top landing surface of the solar array.
  bool isUnderCourierFootprint(double footX, double footY) {
    final horizontalOverlap = footX >= position.x && footX <= position.x + size.x;
    final verticalOverlap = footY >= surfaceY - 14.0 && footY <= surfaceY + 18.0;
    return horizontalOverlap && verticalOverlap;
  }

  /// Returns true if the courier has reached or passed the forward dismount edge of this array.
  bool isPastForwardEdge(double footX) {
    return footX > position.x + size.x;
  }

  /// Helper to check collision with player.
  bool checkCollisionWith(CourierPlayer player) {
    // A panel only catches a courier coming down onto it. One jumping off is
    // still within reach of it for the first few frames, and used to be
    // pulled straight back on: at anything above about 24 frames a second
    // the jump was cancelled before the courier had risen clear.
    if (player.simulator.verticalVelocity > 0) return false;
    final footX = player.position.x + (player.size.x / 2);
    final footY = player.simulator.currentY;
    return isUnderCourierFootprint(footX, footY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt * 5.0;

    // Reset charging flag each frame; game update re-asserts it if courier is still sliding
    isCharging = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final panelWidth = size.x;
    final panelHeight = size.y;

    // 1. Aluminum Support Truss Legs & Mounting Stanchions down to ground/roof
    final totalLegHeight = (groundY - position.y) - panelHeight;
    if (totalLegHeight > 0) {
      const stanchionSpacing = 70.0;
      double legX = 20.0;
      while (legX < panelWidth - 10.0) {
        // Vertical stanchion column
        canvas.drawLine(
          Offset(legX, panelHeight),
          Offset(legX, panelHeight + totalLegHeight),
          _stanchionPaint,
        );

        // Angled cross truss strut
        if (legX + stanchionSpacing < panelWidth) {
          canvas.drawLine(
            Offset(legX, panelHeight + 10.0),
            Offset(legX + stanchionSpacing, panelHeight + totalLegHeight),
            _stanchionPaint,
          );
        }

        // Base mounting flange on ground
        final flangeRect = Rect.fromCenter(
          center: Offset(legX, panelHeight + totalLegHeight - 2.0),
          width: 14.0,
          height: 6.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(flangeRect, const Radius.circular(2)),
          _flangePaint,
        );

        legX += stanchionSpacing;
      }
    }

    // 2. Brushed Aluminum Outer Chassis Frame
    final outerRect = Rect.fromLTWH(0, 0, panelWidth, panelHeight);
    final outerRRect = RRect.fromRectAndRadius(outerRect, const Radius.circular(3.0));
    canvas.drawRRect(outerRRect, _framePaint);
    canvas.drawRRect(outerRRect, _frameBorderPaint);

    // 3. Crystalline Photovoltaic Silicon Cells Grid
    const margin = 3.0;
    const cellSpacing = 2.0;
    final cellAreaWidth = panelWidth - (margin * 2);
    final cellAreaHeight = panelHeight - (margin * 2);

    final numColumns = math.max(1, (cellAreaWidth / 26.0).floor());
    final cellWidth = (cellAreaWidth - ((numColumns - 1) * cellSpacing)) / numColumns;
    final cellHeight = cellAreaHeight;

    for (int i = 0; i < numColumns; i++) {
      final cellX = margin + i * (cellWidth + cellSpacing);
      final cellRect = Rect.fromLTWH(cellX, margin, cellWidth, cellHeight);

      // Deep crystalline blue cell wafer
      canvas.drawRect(cellRect, _solarCellPaint);
      canvas.drawRect(cellRect, _solarCellBorderPaint);

      // Fine horizontal busbar conductor lines
      final busbarY1 = margin + (cellHeight * 0.33);
      final busbarY2 = margin + (cellHeight * 0.66);
      canvas.drawLine(Offset(cellX, busbarY1), Offset(cellX + cellWidth, busbarY1), _busbarPaint);
      canvas.drawLine(Offset(cellX, busbarY2), Offset(cellX + cellWidth, busbarY2), _busbarPaint);

      // Vertical busbar center line
      final busbarMidX = cellX + (cellWidth / 2);
      canvas.drawLine(Offset(busbarMidX, margin), Offset(busbarMidX, margin + cellHeight), _busbarPaint);
    }

    // 4. Specular Glass Diagonal Sheen Highlight
    final sheenPath = Path()
      ..moveTo(8.0, margin)
      ..lineTo(math.min(panelWidth - 8.0, 36.0), margin)
      ..lineTo(math.max(margin, 24.0), margin + cellHeight)
      ..lineTo(margin, margin + cellHeight)
      ..close();
    canvas.drawPath(sheenPath, _glassGlossPaint);

    // 5. Onboard Kinetic Capacitor Battery Gauge & LEDs (Right side bracket)
    final ledBaseX = panelWidth - 28.0;
    final ledY = panelHeight / 2;

    // LED 1 (Cyan - Initial contact / charge)
    final led1Active = chargeLevel > 0.05 || isCharging;
    final led1Paint = Paint()
      ..color = led1Active ? const Color(0xFF00E5FF) : const Color(0xFF004D40)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ledBaseX, ledY), 2.5, led1Paint);

    // LED 2 (Gold - Half charge capacitor)
    final led2Active = chargeLevel >= 0.45;
    final led2Paint = Paint()
      ..color = led2Active ? const Color(0xFFFFD700) : const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ledBaseX + 8.0, ledY), 2.5, led2Paint);

    // LED 3 (Lightning White - Full Solar Surge Ready!)
    final led3Active = chargeLevel >= 0.85;
    final pulse = 0.5 + 0.5 * math.sin(_pulseTimer);
    final led3Color = led3Active
        ? (pulse > 0.5 ? Colors.white : const Color(0xFF18FFFF))
        : const Color(0xFF37474F);
    final led3Paint = Paint()
      ..color = led3Color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ledBaseX + 16.0, ledY), 2.8, led3Paint);

    // 6. High-Voltage Active Charging Halo Pulse
    if (chargeLevel > 0.1 || isCharging) {
      final glowAlpha = ((chargeLevel * 0.7 + 0.3 * math.sin(_pulseTimer)) * 255)
          .clamp(0, 255)
          .toInt();
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withAlpha(glowAlpha)
        ..strokeWidth = 2.0 + chargeLevel * 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(outerRRect, glowPaint);
    }
  }
}
