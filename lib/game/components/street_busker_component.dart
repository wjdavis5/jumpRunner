import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Sidewalk street busker jazz saxophonist fixture featuring an urban musician
/// with fedora, sunglasses, velvet jacket, and gleaming golden alto saxophone,
/// playing next to an open velvet-lined instrument case on the sidewalk with tip bills and coins.
///
/// Hurdling or vaulting past the busker tosses a tip, triggering a dynamic musical note
/// fountain burst and activating the Urban Groove tempo score multiplier (+1.5x for 4.0s).
class StreetBuskerComponent extends PositionComponent {
  StreetBuskerComponent({
    required Vector2 position,
    double width = 84.0,
    double height = 68.0,
    this.groundY = 460.0,
    this.onEncounter,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onEncounter;

  bool hasEncountered = false;
  double _grooveTimer = 0.0;
  double _soloReactionTimer = 0.0;

  /// Top baseline Y of the sidewalk tip case in world coordinates.
  double get caseWorldY => groundY - 16.0;

  /// World space coordinate at the saxophone bell apex for particle note bursts.
  Vector2 get saxBellApexWorld => Vector2(position.x + (size.x * 0.68), groundY - 48.0);

  /// Center point of the busker fixture in world coordinates.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the fixture has scrolled past active camera range and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _caseOuterPaint = Paint()
    ..color = const Color(0xFF263238) // Charcoal textured case shell
    ..style = PaintingStyle.fill;

  static final Paint _caseLiningPaint = Paint()
    ..color = const Color(0xFF4A148C) // Deep royal purple velvet lining
    ..style = PaintingStyle.fill;

  static final Paint _caseRimPaint = Paint()
    ..color = const Color(0xFFB0BEC5) // Chrome edge trim
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _dollarBillPaint = Paint()
    ..color = const Color(0xFF81C784) // Paper currency green
    ..style = PaintingStyle.fill;

  static final Paint _goldCoinPaint = Paint()
    ..color = const Color(0xFFFFD700) // Polished tip coin gold
    ..style = PaintingStyle.fill;

  static final Paint _clothesDarkPaint = Paint()
    ..color = const Color(0xFF1E272C) // Charcoal slacks and shoes
    ..style = PaintingStyle.fill;

  static final Paint _jacketPaint = Paint()
    ..color = const Color(0xFF283593) // Classic jazz indigo blazer
    ..style = PaintingStyle.fill;

  static final Paint _shirtPaint = Paint()
    ..color = const Color(0xFFECEFF1) // Crisp white collared shirt
    ..style = PaintingStyle.fill;

  static final Paint _skinPaint = Paint()
    ..color = const Color(0xFF8D6E63) // Warm complexion
    ..style = PaintingStyle.fill;

  static final Paint _sunglassesPaint = Paint()
    ..color = const Color(0xFF111111) // Retro dark shades
    ..style = PaintingStyle.fill;

  static final Paint _hatPaint = Paint()
    ..color = const Color(0xFF37474F) // Fedora charcoal felt
    ..style = PaintingStyle.fill;

  static final Paint _hatBandPaint = Paint()
    ..color = const Color(0xFFD32F2F) // Crimson ribbon band
    ..style = PaintingStyle.fill;

  static final Paint _saxBrassPaint = Paint()
    ..color = const Color(0xFFFFD700) // Gleaming alto sax brass
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3.6;

  static final Paint _saxBellFillPaint = Paint()
    ..color = const Color(0xFFFFB300) // Sax flared bell interior
    ..style = PaintingStyle.fill;

  static final Paint _saxKeyPaint = Paint()
    ..color = const Color(0xFFFFF8E1) // Pearloid key cups
    ..style = PaintingStyle.fill;

  static final Paint _notePaint = Paint()
    ..color = const Color(0xFFFFD54F) // Floating music note gold
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke;

  static final Paint _noteFillPaint = Paint()
    ..color = const Color(0xFFFFD54F)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _grooveTimer += dt;

    if (_soloReactionTimer > 0) {
      _soloReactionTimer = math.max(0.0, _soloReactionTimer - dt);
    }
  }

  /// Evaluates whether an airborne courier leaps across or hurdle vaults over the busker fixture.
  bool checkInteraction(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasEncountered) return false;

    // Must be actively airborne to perform the vault / stunt encounter
    if (simulator.isGrounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= fixtureLeft + 2.0) && (courierLeft <= fixtureRight - 2.0);
    if (!horizontalOverlap) return false;

    // Vertical interaction window: from above busker down to the case vault level
    final vaultTop = groundY - 72.0;
    final vaultBottom = caseWorldY + 16.0;
    final inInteractionWindow = (footY >= vaultTop) && (footY <= vaultBottom);

    if (inInteractionWindow) {
      hasEncountered = true;
      _soloReactionTimer = 0.50; // Solo reaction flourish
      simulator.launch(210.0); // Kinetic parkour vault lift
      onEncounter?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 1. Open Saxophone Case on the sidewalk (left side of fixture)
    _renderOpenInstrumentCase(canvas, w, h);

    // 2. Jazz Musician Saxophonist (right side of fixture)
    _renderSaxophonist(canvas, w, h);

    // 3. Floating ambient musical note symbols
    _renderMusicalNotes(canvas, w, h);
  }

  void _renderOpenInstrumentCase(Canvas canvas, double w, double h) {
    const caseLeft = 4.0;
    const caseW = 34.0;
    const caseH = 14.0;
    final caseTop = h - caseH;

    // Hard outer shell
    final caseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(caseLeft, caseTop, caseW, caseH),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(caseRect, _caseOuterPaint);
    canvas.drawRRect(caseRect, _caseRimPaint);

    // Deep purple velvet plush interior
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(caseLeft + 2.0, caseTop + 2.0, caseW - 4.0, caseH - 4.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(innerRect, _caseLiningPaint);

    // Crumpled green dollar bills
    canvas.save();
    canvas.translate(caseLeft + 6.0, caseTop + 4.0);
    canvas.rotate(0.12);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 7.0, 3.8), _dollarBillPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(caseLeft + 18.0, caseTop + 5.0);
    canvas.rotate(-0.18);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 8.0, 4.0), _dollarBillPaint);
    canvas.restore();

    // Shiny tip coins
    canvas.drawCircle(Offset(caseLeft + 15.0, caseTop + 8.5), 1.6, _goldCoinPaint);
    canvas.drawCircle(Offset(caseLeft + 27.0, caseTop + 7.0), 1.8, _goldCoinPaint);
    canvas.drawCircle(Offset(caseLeft + 10.0, caseTop + 9.0), 1.4, _goldCoinPaint);

    // Extra tossed coins if already vaulted/encountered
    if (hasEncountered) {
      canvas.drawCircle(Offset(caseLeft + 22.0, caseTop + 4.5), 1.9, _goldCoinPaint);
      canvas.drawCircle(Offset(caseLeft + 13.0, caseTop + 4.0), 1.5, _goldCoinPaint);
    }
  }

  void _renderSaxophonist(Canvas canvas, double w, double h) {
    final buskerX = w * 0.62;

    // Rhythmic swaying motion along jazz tempo
    final sway = math.sin(_grooveTimer * 4.2) * 2.2;
    final soloLean = _soloReactionTimer > 0 ? -math.sin((_soloReactionTimer / 0.50) * math.pi) * 4.0 : 0.0;

    canvas.save();
    canvas.translate(buskerX + sway, soloLean);

    // Legs and shoes
    canvas.drawLine(const Offset(-4.0, 48.0), Offset(-6.0, h), _saxBrassPaint..strokeWidth = 3.0..color = const Color(0xFF1E272C));
    canvas.drawLine(const Offset(4.0, 48.0), Offset(5.0, h), _saxBrassPaint..strokeWidth = 3.0..color = const Color(0xFF1E272C));
    canvas.drawRect(Rect.fromLTWH(-9.0, h - 3.5, 6.5, 3.5), _clothesDarkPaint);
    canvas.drawRect(Rect.fromLTWH(3.0, h - 3.5, 6.5, 3.5), _clothesDarkPaint);

    // Torso / Indigo Jazz Blazer
    final torsoRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-8.0, 24.0, 16.0, 25.0),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(torsoRect, _jacketPaint);

    // White shirt collar V-neck
    final collarPath = Path()
      ..moveTo(-3.0, 24.0)
      ..lineTo(0.0, 31.0)
      ..lineTo(3.0, 24.0);
    canvas.drawPath(collarPath, _shirtPaint);

    // Head / Neck
    canvas.drawCircle(const Offset(0.0, 16.0), 6.5, _skinPaint);

    // Dark Sunglasses
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5.0, 14.0, 10.0, 3.2), const Radius.circular(1.0)),
      _sunglassesPaint,
    );

    // Fedora Hat
    final fedoraPath = Path()
      ..moveTo(-11.0, 13.0)
      ..quadraticBezierTo(0.0, 10.0, 11.0, 13.0) // Brim
      ..lineTo(7.0, 5.0)
      ..quadraticBezierTo(0.0, 3.0, -7.0, 5.0)
      ..close();
    canvas.drawPath(fedoraPath, _hatPaint);

    // Hat brim line
    canvas.drawLine(const Offset(-12.0, 13.0), const Offset(12.0, 13.0), _hatPaint..strokeWidth = 2.0..style = PaintingStyle.stroke);
    _hatPaint.style = PaintingStyle.fill;

    // Crimson ribbon
    canvas.drawRect(const Rect.fromLTWH(-7.0, 9.5, 14.0, 2.2), _hatBandPaint);

    // Alto Saxophone
    _renderSaxophone(canvas);

    canvas.restore();
  }

  void _renderSaxophone(Canvas canvas) {
    // Saxophone neck from mouth
    canvas.drawLine(const Offset(1.0, 18.0), const Offset(6.0, 24.0), _saxBrassPaint..strokeWidth = 2.0..color = const Color(0xFFFFD700));

    // Saxophone body tube curving down and outward
    final saxPath = Path()
      ..moveTo(6.0, 24.0)
      ..lineTo(8.0, 41.0)
      ..quadraticBezierTo(10.0, 48.0, 16.0, 46.0) // Bottom U-bow
      ..quadraticBezierTo(19.0, 44.0, 18.0, 37.0); // Flared bell pointing upward

    canvas.drawPath(saxPath, _saxBrassPaint..strokeWidth = 3.2);

    // Flared bell opening
    canvas.drawOval(
      const Rect.fromLTWH(15.5, 34.0, 6.0, 7.5),
      _saxBellFillPaint,
    );

    // Pearloid key cup dots along sax tube
    canvas.drawCircle(const Offset(6.8, 27.0), 1.0, _saxKeyPaint);
    canvas.drawCircle(const Offset(7.2, 31.0), 1.0, _saxKeyPaint);
    canvas.drawCircle(const Offset(7.6, 35.0), 1.0, _saxKeyPaint);
    canvas.drawCircle(const Offset(8.0, 39.0), 1.0, _saxKeyPaint);

    // Musician's hands holding saxophone
    canvas.drawCircle(const Offset(5.5, 29.0), 2.2, _skinPaint);
    canvas.drawCircle(const Offset(8.0, 37.0), 2.2, _skinPaint);
  }

  void _renderMusicalNotes(Canvas canvas, double w, double h) {
    final noteOffset1 = math.sin(_grooveTimer * 3.5) * 4.0;
    final noteOffset2 = math.cos(_grooveTimer * 3.8) * 4.0;

    // Note 1: Eighth note floating above sax bell
    final n1x = (w * 0.72) + noteOffset1;
    final n1y = 12.0 + (math.sin(_grooveTimer * 2.8) * 3.0);
    _drawMusicalNote(canvas, n1x, n1y);

    // Note 2: Smaller note floating higher
    final n2x = (w * 0.82) + noteOffset2;
    final n2y = 4.0 + (math.cos(_grooveTimer * 3.2) * 2.5);
    _drawMusicalNote(canvas, n2x, n2y, scale: 0.8);
  }

  void _drawMusicalNote(Canvas canvas, double x, double y, {double scale = 1.0}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);

    // Note head
    canvas.drawOval(
      const Rect.fromLTWH(-2.0, 3.0, 4.2, 3.0),
      _noteFillPaint,
    );

    // Stem
    canvas.drawLine(const Offset(1.8, 4.0), const Offset(1.8, -4.0), _notePaint);

    // Flag
    final flagPath = Path()
      ..moveTo(1.8, -4.0)
      ..quadraticBezierTo(4.5, -2.5, 3.5, 0.5);
    canvas.drawPath(flagPath, _notePaint);

    canvas.restore();
  }
}
