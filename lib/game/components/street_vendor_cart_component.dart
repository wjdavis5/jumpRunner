import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game_font.dart';
import '../logic/jump_physics.dart';

/// Street corner hot pretzel and roasted chestnut vendor stand: a wheeled
/// steel cart under a blue-and-yellow striped canvas canopy, with a copper
/// roasting cauldron over glowing charcoals and a glass warming display of
/// twisted golden pretzels.
///
/// An airborne courier hurdle-vaulting the counter gets a crisp parkour
/// boost (+195 px/s) and a whiff of the Hot Snack Sprint.
class StreetVendorCartComponent extends PositionComponent {
  StreetVendorCartComponent({
    required Vector2 position,
    double width = 72.0,
    double height = 58.0,
    this.groundY = 460.0,
    this.onVault,
  }) : super(
          position: position,
          size: Vector2(width, height),
        );

  final double groundY;
  final VoidCallback? onVault;

  bool hasVaulted = false;

  /// Seconds left on the canopy wobble after a vault.
  double _wobbleTimer = 0.0;

  /// Counter surface in world coordinates, where the vault window sits.
  double get counterTopWorldY => groundY - size.y * 0.42;

  /// Apex above the counter for aroma particle anchors.
  Vector2 get vaultApexWorld =>
      Vector2(position.x + (size.x * 0.5), counterTopWorldY - 26.0);

  /// The copper cauldron's mouth in world coordinates, where roast steam
  /// puffs rise even when nobody is vaulting.
  Vector2 get cauldronWorld =>
      Vector2(position.x + (size.x * 0.72), groundY - size.y * 0.62);

  /// Center point of the cart in world coordinates.
  Vector2 get centerWorldPosition =>
      Vector2(position.x + (size.x * 0.5), position.y + (size.y * 0.5));

  /// Whether the fixture has scrolled past active camera view and can be recycled.
  bool get shouldRecycle => position.x + size.x < -180.0;

  @override
  void update(double dt) {
    super.update(dt);

    if (_wobbleTimer > 0) {
      _wobbleTimer = math.max(0.0, _wobbleTimer - dt);
    }
  }

  /// Evaluates whether an airborne courier hurdle-vaults across the counter.
  bool checkVault(
    Vector2 playerPos,
    Vector2 playerSize,
    JumpPhysicsSimulator simulator,
  ) {
    if (hasVaulted) return false;

    // Must be actively airborne to hurdle vault.
    if (simulator.isGrounded) return false;

    final courierLeft = playerPos.x;
    final courierRight = playerPos.x + playerSize.x;
    final footY = simulator.currentY;

    final fixtureLeft = position.x;
    final fixtureRight = position.x + size.x;

    // Horizontal overlap check.
    final horizontalOverlap =
        (courierRight >= fixtureLeft + 4.0) && (courierLeft <= fixtureRight - 4.0);
    if (!horizontalOverlap) return false;

    // Hurdle vault window around counter level.
    final vaultTop = counterTopWorldY - 14.0;
    final vaultBottom = counterTopWorldY + 18.0;
    final inVaultWindow = (footY >= vaultTop) && (footY <= vaultBottom);

    if (inVaultWindow) {
      hasVaulted = true;
      _wobbleTimer = 0.40;
      simulator.launch(195.0); // Crisp parkour vault launch.
      onVault?.call();
      return true;
    }

    return false;
  }

  /// Manually mark the cart as vaulted.
  void markVaulted() {
    hasVaulted = true;
  }

  // Visual styling paints
  static final Paint _bodyPaint = Paint()
    ..color = const Color(0xFF37474F) // Dark wheeled steel cart body
    ..style = PaintingStyle.fill;

  static final Paint _bodyShadePaint = Paint()
    ..color = const Color(0xFF263238)
    ..style = PaintingStyle.fill;

  static final Paint _counterPaint = Paint()
    ..color = const Color(0xFF78909C) // Side service counter
    ..style = PaintingStyle.fill;

  static final Paint _caseFramePaint = Paint()
    ..color = const Color(0xFFB0BEC5) // Glass warming display frame
    ..style = PaintingStyle.fill;

  static final Paint _caseGlassPaint = Paint()
    ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.55)
    ..style = PaintingStyle.fill;

  static final Paint _pretzelPaint = Paint()
    ..color = const Color(0xFFD4A017) // Twisted golden brown pretzels
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;

  static final Paint _polePaint = Paint()
    ..color = const Color(0xFFB8860B) // Polished brass poles
    ..style = PaintingStyle.fill;

  static final Paint _canopyBluePaint = Paint()
    ..color = const Color(0xFF1E88E5) // Striped canvas, blue
    ..style = PaintingStyle.fill;

  static final Paint _canopyYellowPaint = Paint()
    ..color = const Color(0xFFFDD835) // Striped canvas, yellow
    ..style = PaintingStyle.fill;

  static final Paint _cauldronPaint = Paint()
    ..color = const Color(0xFFB87333) // Copper roasting cauldron
    ..style = PaintingStyle.fill;

  static final Paint _cauldronRimPaint = Paint()
    ..color = const Color(0xFFDFA878)
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke;

  static final Paint _emberPaint = Paint()
    ..color = const Color(0xFFFF6D00) // Glowing charcoals beneath
    ..style = PaintingStyle.fill;

  static final Paint _wheelPaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    final wobble = _wobbleTimer > 0.0
        ? math.sin(_wobbleTimer * 24.0) * 2.2 * (_wobbleTimer / 0.40)
        : 0.0;

    // 1. Brass poles holding the canopy.
    for (final px in [w * 0.10, w * 0.86]) {
      canvas.drawRect(Rect.fromLTWH(px, h * 0.06, 3.0, h * 0.44), _polePaint);
    }

    // 2. Striped canvas canopy with a gentle wobble after a vault.
    canvas.save();
    canvas.translate(w * 0.5, h * 0.10);
    canvas.rotate(wobble * 0.04);
    const stripeW = 8.0;
    var i = 0;
    for (var x = -w * 0.48; x < w * 0.48; x += stripeW) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0.0, stripeW, 9.0),
        i.isEven ? _canopyBluePaint : _canopyYellowPaint,
      );
      i++;
    }
    canvas.restore();

    // 3. Cart body on wheels.
    canvas.drawRect(Rect.fromLTWH(4.0, h * 0.46, w - 8.0, h * 0.40), _bodyPaint);
    canvas.drawRect(Rect.fromLTWH(4.0, h * 0.46, w - 8.0, 3.0), _bodyShadePaint);
    canvas.drawRect(Rect.fromLTWH(4.0, h * 0.56, w - 8.0, h * 0.10), _counterPaint);
    const wheelR = 6.0;
    for (final cx in [w * 0.20, w * 0.74]) {
      canvas.drawCircle(Offset(cx, h - wheelR + 1.0), wheelR, _wheelPaint);
      canvas.drawCircle(Offset(cx, h - wheelR + 1.0), 2.0, _bodyShadePaint);
    }

    // 4. Glass warming display with twisted pretzels.
    final caseRect = Rect.fromLTWH(w * 0.08, h * 0.60, w * 0.52, h * 0.22);
    canvas.drawRect(caseRect, _caseFramePaint);
    canvas.drawRect(caseRect.deflate(2.0), _caseGlassPaint);
    for (var pi = 0; pi < 3; pi++) {
      final cx = caseRect.left + 8.0 + pi * (caseRect.width - 12.0) / 2.5;
      final cy = caseRect.center.dy;
      canvas.drawCircle(Offset(cx, cy), 3.4, _pretzelPaint);
    }

    // 5. Copper chestnut cauldron on glowing charcoals.
    final cauldron = Rect.fromCenter(
      center: Offset(w * 0.72, h * 0.52),
      width: w * 0.26,
      height: h * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cauldron, const Radius.circular(4.0)),
      _cauldronPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(cauldron.left - 1.0, cauldron.top - 1.0, cauldron.width + 2.0, 3.0),
      _cauldronRimPaint,
    );
    for (var e = 0; e < 3; e++) {
      canvas.drawCircle(
        Offset(cauldron.left + 5.0 + e * 6.0, cauldron.bottom + 3.0),
        2.0,
        _emberPaint,
      );
    }

    // 6. Stenciled serving hatch text.
    const sign = TextSpan(
      text: 'PRETZELS',
      style: TextStyle(
        fontFamily: gameFontFamily,
        color: Color(0xFFFFF8E1),
        fontSize: 7,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
    final signPainter = TextPainter(text: sign, textDirection: TextDirection.ltr)..layout();
    signPainter.paint(
      canvas,
      Offset(w * 0.08 + (w * 0.52 - signPainter.width) / 2, h * 0.30),
    );
  }
}
