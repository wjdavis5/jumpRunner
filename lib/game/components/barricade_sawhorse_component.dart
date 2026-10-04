import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../logic/jump_physics.dart';

/// Street-level A-frame construction sawhorse barricade featuring reflective orange/white
/// chevron planks, a flashing amber warning lantern, and weighted traffic cones.
class BarricadeSawhorseComponent extends PositionComponent {
  BarricadeSawhorseComponent({
    required Vector2 position,
    double width = 68.0,
    double height = 44.0,
    this.groundY = 460.0,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onVault;

  bool hasVaulted = false;
  double _flashTimer = 0.0;
  bool _isLightOn = true;
  double _coneTumbleAngle = 0.0;

  /// Top surface baseline Y of the barricade plank in world coordinates.
  double get hurdleTopWorldY => groundY - 36.0;

  /// World coordinate at the amber warning lantern for particle alignment.
  Vector2 get flasherWorldPosition => Vector2(position.x + (size.x / 2), position.y + 4.0);

  /// Center point of the sawhorse barricade in world space.
  Vector2 get centerWorldPosition => Vector2(position.x + (size.x / 2), groundY - (size.y / 2));

  /// Whether the barricade has scrolled offscreen.
  bool get shouldRecycle => position.x + size.x < -140.0;

  // Visual styling paints
  static final Paint _legPaint = Paint()
    ..color = const Color(0xFF4E342E) // Dark lumber timber
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _hingePaint = Paint()
    ..color = const Color(0xFF78909C)
    ..style = PaintingStyle.fill;

  static final Paint _plankBasePaint = Paint()
    ..color = const Color(0xFFFF6D00) // Safety orange base
    ..style = PaintingStyle.fill;

  static final Paint _chevronWhitePaint = Paint()
    ..color = const Color(0xFFFFFFFF) // Reflective vinyl white
    ..style = PaintingStyle.fill;

  static final Paint _lanternBoxPaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _conePaint = Paint()
    ..color = const Color(0xFFFF5722) // Traffic cone safety orange
    ..style = PaintingStyle.fill;

  static final Paint _coneStripePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill;

  static final Paint _coneBasePaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _flashTimer += dt;
    if (_flashTimer >= 0.35) {
      _flashTimer = 0.0;
      _isLightOn = !_isLightOn;
    }

    if (hasVaulted && _coneTumbleAngle < math.pi / 2.2) {
      _coneTumbleAngle += dt * 8.0;
    }
  }

  /// Evaluates whether an airborne courier vaults cleanly over the sawhorse barricade.
  bool checkVault(Vector2 playerPos, Vector2 playerSize, JumpPhysicsSimulator simulator) {
    if (hasVaulted) return false;

    // Must be actively airborne to hurdle-vault over barricade
    if (simulator.isGrounded) return false;

    final playerLeft = playerPos.x;
    final playerRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    // Barricade horizontal span
    final inHorizontalSpan = playerRight >= position.x + 8.0 && playerLeft <= position.x + size.x - 8.0;

    // Foot must clear top of barricade
    final clearsTop = footY <= hurdleTopWorldY + 12.0 && footY >= hurdleTopWorldY - 54.0;

    if (inHorizontalSpan && clearsTop) {
      hasVaulted = true;
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
    final baselineY = h;

    // 1. A-frame Timber Legs (Left and Right pairs)
    const legTopY = 12.0;

    // Left A-frame
    canvas.drawLine(const Offset(12.0, legTopY), Offset(4.0, baselineY), _legPaint);
    canvas.drawLine(const Offset(12.0, legTopY), Offset(20.0, baselineY), _legPaint);
    canvas.drawCircle(const Offset(12.0, legTopY), 2.5, _hingePaint);

    // Right A-frame
    canvas.drawLine(Offset(w - 12.0, legTopY), Offset(w - 20.0, baselineY), _legPaint);
    canvas.drawLine(Offset(w - 12.0, legTopY), Offset(w - 4.0, baselineY), _legPaint);
    canvas.drawCircle(Offset(w - 12.0, legTopY), 2.5, _hingePaint);

    // Lower cross-brace horizontal ties
    final tiePaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(7.0, 32.0), const Offset(17.0, 32.0), tiePaint);
    canvas.drawLine(Offset(w - 17.0, 32.0), Offset(w - 7.0, 32.0), tiePaint);

    // 2. Reflective Chevron Cross-Plank
    const plankHeight = 14.0;
    const plankTopY = 10.0;
    final plankRect = Rect.fromLTWH(0.0, plankTopY, w, plankHeight);
    final plankRRect = RRect.fromRectAndRadius(plankRect, const Radius.circular(2.0));
    canvas.drawRRect(plankRRect, _plankBasePaint);

    // Alternating white reflective diagonal chevron stripes
    canvas.save();
    canvas.clipRRect(plankRRect);
    for (var cx = -plankHeight; cx < w + plankHeight; cx += 16.0) {
      final path = Path()
        ..moveTo(cx, plankTopY)
        ..lineTo(cx + 8.0, plankTopY)
        ..lineTo(cx + 8.0 - plankHeight, plankTopY + plankHeight)
        ..lineTo(cx - plankHeight, plankTopY + plankHeight)
        ..close();
      canvas.drawPath(path, _chevronWhitePaint);
    }
    canvas.restore();

    // 3. Amber Flasher Warning Lantern on Top Center
    const lanternBoxWidth = 10.0;
    const lanternBoxHeight = 8.0;
    final lanternBoxX = (w - lanternBoxWidth) / 2;
    const lanternBoxY = plankTopY - lanternBoxHeight;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lanternBoxX, lanternBoxY, lanternBoxWidth, lanternBoxHeight),
        const Radius.circular(1.5),
      ),
      _lanternBoxPaint,
    );

    // Circular Fresnel Lens
    final lensCenter = Offset(w / 2, lanternBoxY - 4.0);
    final lensPaint = Paint()
      ..color = _isLightOn ? const Color(0xFFFFD600) : const Color(0xFF7F6000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lensCenter, 4.0, lensPaint);

    // Glowing halo if active
    if (_isLightOn) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFAB00).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(lensCenter, 8.0, glowPaint);
    }

    // 4. Flanking Safety Traffic Cones with Tumble Physics
    _renderSafetyCone(canvas, Offset(6.0, baselineY), -_coneTumbleAngle);
    _renderSafetyCone(canvas, Offset(w - 6.0, baselineY), _coneTumbleAngle);
  }

  void _renderSafetyCone(Canvas canvas, Offset baseCenter, double tumbleAngle) {
    canvas.save();
    canvas.translate(baseCenter.dx, baseCenter.dy);
    if (tumbleAngle != 0) {
      canvas.rotate(tumbleAngle);
    }

    // Heavy black square base
    canvas.drawRect(const Rect.fromLTWH(-6.0, -3.0, 12.0, 3.0), _coneBasePaint);

    // Orange cone body
    final conePath = Path()
      ..moveTo(-4.5, -3.0)
      ..lineTo(4.5, -3.0)
      ..lineTo(1.2, -18.0)
      ..lineTo(-1.2, -18.0)
      ..close();
    canvas.drawPath(conePath, _conePaint);

    // Reflective white center stripe
    final stripePath = Path()
      ..moveTo(-3.0, -8.0)
      ..lineTo(3.0, -8.0)
      ..lineTo(2.0, -13.0)
      ..lineTo(-2.0, -13.0)
      ..close();
    canvas.drawPath(stripePath, _coneStripePaint);

    canvas.restore();
  }
}
