import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Sidewalk newspaper kiosk (newsstand) featuring a corrugated metal chassis,
/// roll-up security shutter header, illuminated "NEWS" signage, wooden magazine shelves,
/// stacked twine-tied newspaper bundles, and a rotating wire postcard carousel rack.
///
/// Hurdle vaulting across the newsstand counter triggers a fluttering burst of printed
/// headlines and glossy magazine pages, and activates an Extra! Extra! notoriety score buff.
class NewsstandComponent extends PositionComponent {
  NewsstandComponent({
    required Vector2 position,
    double width = 82.0,
    double height = 62.0,
    this.groundY = 460.0,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onVault;

  bool hasVaulted = false;
  double _wobbleTimer = 0.0;
  double _postcardSpin = 0.0;
  double _postcardSpinSpeed = 0.0;

  /// Top baseline Y of the wooden newspaper counter in world coordinates.
  double get counterWorldY => groundY - 32.0;

  /// World space coordinate at the newspaper counter apex for particle bursts.
  Vector2 get counterApexWorld => Vector2(position.x + (size.x / 2), counterWorldY);

  /// Center point of the newsstand in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), position.y + (size.y / 2));

  /// Whether the newsstand has scrolled past the active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  // Visual styling paints
  static final Paint _kioskBodyPaint = Paint()
    ..color = const Color(0xFF1B3B2B) // Vintage metropolitan dark hunter green
    ..style = PaintingStyle.fill;

  static final Paint _kioskTrimPaint = Paint()
    ..color = const Color(0xFF10261B)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _shutterBoxPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _shutterLinePaint = Paint()
    ..color = const Color(0xFF37474F)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _signBackgroundPaint = Paint()
    ..color = const Color(0xFF1A1A1A)
    ..style = PaintingStyle.fill;

  static final Paint _neonSignPaint = Paint()
    ..color = const Color(0xFFFFB300) // Glowing amber neon
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _counterWoodPaint = Paint()
    ..color = const Color(0xFF4E342E) // Weathered dark mahogany wood
    ..style = PaintingStyle.fill;

  static final Paint _newspaperPaperPaint = Paint()
    ..color = const Color(0xFFF5F5DC) // Newsprint parchment off-white
    ..style = PaintingStyle.fill;

  static final Paint _newspaperInkPaint = Paint()
    ..color = const Color(0xFF455A64)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _twinePaint = Paint()
    ..color = const Color(0xFF8D6E63) // Hemp packaging twine
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _wireRackPaint = Paint()
    ..color = const Color(0xFF90A4AE)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final List<Paint> _magazinePaints = [
    Paint()..color = const Color(0xFFE91E63), // Vibrant magenta
    Paint()..color = const Color(0xFF00E5FF), // Electric cyan
    Paint()..color = const Color(0xFFFF9100), // Amber orange
    Paint()..color = const Color(0xFF76FF03), // Lime green
    Paint()..color = const Color(0xFFFFEB3B), // Sunshine yellow
  ];

  @override
  void update(double dt) {
    super.update(dt);

    if (_wobbleTimer > 0) {
      _wobbleTimer = math.max(0.0, _wobbleTimer - dt);
    }

    if (_postcardSpinSpeed > 0) {
      _postcardSpin += _postcardSpinSpeed * dt;
      _postcardSpinSpeed = math.max(0.0, _postcardSpinSpeed - dt * 9.0);
    } else {
      // Gentle ambient drift spin
      _postcardSpin += dt * 0.8;
    }
  }

  /// Evaluates whether an airborne courier vaults across the newsstand counter.
  bool checkVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted) return false;

    // Must be actively airborne to hurdle vault
    if (simulator.isGrounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final kioskLeft = position.x;
    final kioskRight = position.x + size.x;

    // Horizontal overlap check
    final horizontalOverlap = (courierRight >= kioskLeft + 6.0) && (courierLeft <= kioskRight - 6.0);
    if (!horizontalOverlap) return false;

    // Hurdle vault window around counter rim
    final vaultTop = counterWorldY - 16.0;
    final vaultBottom = counterWorldY + 18.0;
    final inVaultWindow = (footY >= vaultTop) && (footY <= vaultBottom);

    if (inVaultWindow) {
      hasVaulted = true;
      _wobbleTimer = 0.40;
      _postcardSpinSpeed = 16.0;
      simulator.launch(200.0); // Crisp parkour vault launch
      onVault?.call();
      return true;
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    canvas.save();
    if (_wobbleTimer > 0) {
      final wobbleAngle = math.sin(_wobbleTimer * 28.0) * (_wobbleTimer / 0.40) * 0.05;
      canvas.translate(w / 2, h);
      canvas.rotate(wobbleAngle);
      canvas.translate(-w / 2, -h);
    }

    // 1. Kiosk main structure
    _renderKioskStructure(canvas, w, h);

    // 2. Roll-up shutter box header & illuminated "NEWS" sign
    _renderHeaderAndSign(canvas, w, h);

    // 3. Wooden counter shelf
    _renderCounterShelf(canvas, w, h);

    // 4. Tiered magazine racks
    _renderMagazineRacks(canvas, w, h);

    // 5. Stacked newspaper bundles
    _renderNewspaperBundles(canvas, w, h);

    // 6. Wire spinning postcard carousel
    _renderPostcardRack(canvas, w, h);

    canvas.restore();
  }

  void _renderKioskStructure(Canvas canvas, double w, double h) {
    // Base kiosk booth
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.0, 14.0, w - 18.0, h - 14.0),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(bodyRect, _kioskBodyPaint);
    canvas.drawRRect(bodyRect, _kioskTrimPaint);

    // Base footing trim
    final footingRect = Rect.fromLTWH(0.0, h - 5.0, w - 18.0, 5.0);
    canvas.drawRect(footingRect, _kioskTrimPaint);
  }

  void _renderHeaderAndSign(Canvas canvas, double w, double h) {
    const kioskMainW = 62.0;

    // Roll-up shutter box
    const shutterRect = Rect.fromLTWH(2.0, 14.0, kioskMainW, 10.0);
    canvas.drawRect(shutterRect, _shutterBoxPaint);

    for (var sy = 16.0; sy <= 22.0; sy += 3.0) {
      canvas.drawLine(Offset(2.0, sy), Offset(2.0 + kioskMainW, sy), _shutterLinePaint);
    }

    // Overhead neon sign backing
    final signRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6.0, 3.0, kioskMainW - 8.0, 11.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(signRect, _signBackgroundPaint);

    // Neon "NEWS" stylized lettering strokes
    const sx = 14.0;
    const sy = 6.0;

    // 'N'
    canvas.drawLine(const Offset(sx, sy + 6.0), const Offset(sx, sy), _neonSignPaint);
    canvas.drawLine(const Offset(sx, sy), const Offset(sx + 5.0, sy + 6.0), _neonSignPaint);
    canvas.drawLine(const Offset(sx + 5.0, sy + 6.0), const Offset(sx + 5.0, sy), _neonSignPaint);

    // 'E'
    const ex = sx + 9.0;
    canvas.drawLine(const Offset(ex + 4.5, sy), const Offset(ex, sy), _neonSignPaint);
    canvas.drawLine(const Offset(ex, sy), const Offset(ex, sy + 6.0), _neonSignPaint);
    canvas.drawLine(const Offset(ex, sy + 6.0), const Offset(ex + 4.5, sy + 6.0), _neonSignPaint);
    canvas.drawLine(const Offset(ex, sy + 3.0), const Offset(ex + 3.5, sy + 3.0), _neonSignPaint);

    // 'W'
    const wx = ex + 8.5;
    canvas.drawLine(const Offset(wx, sy), const Offset(wx + 1.5, sy + 6.0), _neonSignPaint);
    canvas.drawLine(const Offset(wx + 1.5, sy + 6.0), const Offset(wx + 3.5, sy + 2.0), _neonSignPaint);
    canvas.drawLine(const Offset(wx + 3.5, sy + 2.0), const Offset(wx + 5.5, sy + 6.0), _neonSignPaint);
    canvas.drawLine(const Offset(wx + 5.5, sy + 6.0), const Offset(wx + 7.0, sy), _neonSignPaint);

    // 'S'
    const ssx = wx + 11.0;
    canvas.drawLine(const Offset(ssx + 4.5, sy), const Offset(ssx, sy), _neonSignPaint);
    canvas.drawLine(const Offset(ssx, sy), const Offset(ssx, sy + 3.0), _neonSignPaint);
    canvas.drawLine(const Offset(ssx, sy + 3.0), const Offset(ssx + 4.5, sy + 3.0), _neonSignPaint);
    canvas.drawLine(const Offset(ssx + 4.5, sy + 3.0), const Offset(ssx + 4.5, sy + 6.0), _neonSignPaint);
    canvas.drawLine(const Offset(ssx + 4.5, sy + 6.0), const Offset(ssx, sy + 6.0), _neonSignPaint);
  }

  void _renderCounterShelf(Canvas canvas, double w, double h) {
    const kioskMainW = 62.0;

    // Heavy mahogany service counter
    final counterRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0.0, 29.0, kioskMainW + 4.0, 4.0),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(counterRect, _counterWoodPaint);
  }

  void _renderMagazineRacks(Canvas canvas, double w, double h) {
    // 2 Tiered display rows below the counter displaying magazines
    const startY1 = 36.0;
    const startY2 = 47.0;

    for (var i = 0; i < 5; i++) {
      final mx = 4.0 + (i * 11.0);
      final paint1 = _magazinePaints[i % _magazinePaints.length];
      final paint2 = _magazinePaints[(i + 2) % _magazinePaints.length];

      // Top tier
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(mx, startY1, 9.0, 8.0), const Radius.circular(1.0)),
        paint1,
      );

      // Bottom tier
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(mx, startY2, 9.0, 8.0), const Radius.circular(1.0)),
        paint2,
      );
    }
  }

  void _renderNewspaperBundles(Canvas canvas, double w, double h) {
    // Stack of morning newspapers resting on the counter
    const bundleX = 14.0;
    const bundleY = 22.0;
    const bundleW = 22.0;
    const bundleH = 7.0;

    final bundleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(bundleX, bundleY, bundleW, bundleH),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(bundleRect, _newspaperPaperPaint);

    // Headline sketch lines
    canvas.drawLine(
      const Offset(bundleX + 3.0, bundleY + 2.2),
      const Offset(bundleX + bundleW - 3.0, bundleY + 2.2),
      _newspaperInkPaint,
    );
    canvas.drawLine(
      const Offset(bundleX + 3.0, bundleY + 4.5),
      const Offset(bundleX + bundleW - 6.0, bundleY + 4.5),
      _newspaperInkPaint,
    );

    // Hemp twine binding
    canvas.drawLine(
      const Offset(bundleX + (bundleW / 2), bundleY),
      const Offset(bundleX + (bundleW / 2), bundleY + bundleH),
      _twinePaint,
    );
    canvas.drawLine(
      const Offset(bundleX, bundleY + (bundleH / 2)),
      const Offset(bundleX + bundleW, bundleY + (bundleH / 2)),
      _twinePaint,
    );
  }

  void _renderPostcardRack(Canvas canvas, double w, double h) {
    // Wire carousel stand on the right side of the booth
    final rackCenterX = w - 9.0;
    const rackTopY = 16.0;
    final rackBottomY = h - 1.0;

    // Center spindle pole
    canvas.drawLine(Offset(rackCenterX, rackTopY), Offset(rackCenterX, rackBottomY), _wireRackPaint);

    // Circular base
    canvas.drawLine(
      Offset(rackCenterX - 6.0, rackBottomY),
      Offset(rackCenterX + 6.0, rackBottomY),
      _wireRackPaint,
    );

    // Rotating postcard slots: 3 card tiers that rotate with _postcardSpin
    const tierOffsets = [19.0, 29.0, 39.0];
    final cardColors = [
      const Color(0xFF00E5FF),
      const Color(0xFFFF5252),
      const Color(0xFFFFD54F),
      const Color(0xFF81C784),
    ];

    for (var t = 0; t < tierOffsets.length; t++) {
      final ty = tierOffsets[t];
      // 4 wings / cards per tier
      for (var wing = 0; wing < 4; wing++) {
        final angle = _postcardSpin + (wing * (math.pi / 2));
        final cosAngle = math.cos(angle);
        // Only render cards facing forward (cosAngle > -0.3)
        if (cosAngle > -0.3) {
          final cardWidth = 7.0 * cosAngle.abs();
          final cardX = rackCenterX + math.sin(angle) * 7.0 - (cardWidth / 2);
          final cardPaint = Paint()..color = cardColors[(t + wing) % cardColors.length];

          canvas.drawRect(
            Rect.fromLTWH(cardX, ty, cardWidth.clamp(1.5, 7.0), 6.5),
            cardPaint,
          );
        }
      }
    }
  }
}
