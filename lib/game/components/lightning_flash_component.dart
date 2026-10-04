import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Atmospheric dynamic thunderstorm lightning system that periodically discharges
/// electrical fork strikes during heavy rain showers.
///
/// Features:
/// - Realistic multi-phase strike flash envelope: precursor leader fork, brief dip,
///   massive return stroke burst, and exponential flicker decay.
/// - Generates stochastic procedural jagged lightning bolt paths with secondary branches.
/// - Photo-sensitivity accessibility toggle (`reduceFlash`) that dampens flash alpha and hides sharp strobes.
/// - Variable acoustic delay for rolling thunder audio rumbles.
/// - Dynamically exposes `currentSpecularBoost` to intensify wet asphalt reflections during flashes.
class LightningFlashComponent extends PositionComponent {
  LightningFlashComponent({
    Vector2? size,
    math.Random? random,
    this.reduceFlash = false,
    this.onThunderRumble,
  })  : _rng = random ?? math.Random(),
        super(
          size: size ?? Vector2(960, 540),
          priority: 6,
        ) {
    _scheduleNextStrike();
  }

  final math.Random _rng;
  final VoidCallback? onThunderRumble;

  /// Photo-sensitivity accessibility preference. When true, eliminates harsh full-white
  /// screen strobes and caps illumination at a gentle, non-jarring ambient wash.
  bool reduceFlash;

  /// Current rain intensity (0.0 to 1.0). Thunderstorms trigger during rain conditions.
  double rainIntensity = 0.0;

  /// Whether precipitation is currently active.
  bool isRaining = false;

  /// Whether a lightning flash sequence is actively illuminating the scene.
  bool isFlashing = false;

  /// Current flash illumination alpha (0.0 to 1.0).
  double currentFlashAlpha = 0.0;

  /// Additional specular reflectance multiplier (0.0 to 1.0) applied to wet surfaces during flashes.
  double currentSpecularBoost = 0.0;

  double _strikeTimer = 0.0;
  double _nextStrikeDelay = 8.0;
  double _flashElapsedTime = 0.0;
  static const double _flashDuration = 0.32; // Total duration in seconds

  double? _pendingThunderTimer;

  // Bolt geometry points
  final List<Offset> _boltPoints = [];
  final List<List<Offset>> _branchPoints = [];

  // Visual paints
  static final Paint _boltCorePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _boltCoronaPaint = Paint()
    ..color = const Color(0xFF80D8FF).withValues(alpha: 0.75)
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _branchPaint = Paint()
    ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.85)
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _scheduleNextStrike() {
    // Rain downpours feature more frequent strikes (5-9s), light rain (10-16s)
    final minDelay = rainIntensity >= 0.8 ? 5.0 : 8.0;
    final variableSpan = rainIntensity >= 0.8 ? 5.0 : 8.0;
    _nextStrikeDelay = minDelay + _rng.nextDouble() * variableSpan;
    _strikeTimer = 0.0;
  }

  /// Manually triggers a procedural lightning strike.
  void triggerStrike({double? customBoltX}) {
    isFlashing = true;
    _flashElapsedTime = 0.0;

    // Acoustic thunder delay: light travels instantaneously, sound arrives 0.15s to 0.40s later
    _pendingThunderTimer = 0.15 + _rng.nextDouble() * 0.25;

    // Generate jagged bolt points from top of sky down towards skyline/rooftops
    _generateBoltGeometry(customBoltX);
  }

  void _generateBoltGeometry(double? originX) {
    _boltPoints.clear();
    _branchPoints.clear();

    final w = size.x;
    var currentX = originX ?? (w * 0.2 + _rng.nextDouble() * (w * 0.6));
    var currentY = 0.0;
    _boltPoints.add(Offset(currentX, currentY));

    final strikeTargetY = 240.0 + _rng.nextDouble() * 120.0; // Hits distant skyline
    final segments = 7 + _rng.nextInt(5);
    final dy = strikeTargetY / segments;

    for (var i = 0; i < segments; i++) {
      currentY += dy;
      currentX += (_rng.nextDouble() - 0.5) * 36.0;
      final pt = Offset(currentX, currentY);
      _boltPoints.add(pt);

      // Occasionally spawn secondary branching tendril
      if (i > 1 && i < segments - 1 && _rng.nextDouble() < 0.4) {
        final branch = <Offset>[pt];
        var branchX = currentX;
        var branchY = currentY;
        final branchSteps = 2 + _rng.nextInt(3);
        final branchDir = _rng.nextBool() ? 1.0 : -1.0;
        for (var b = 0; b < branchSteps; b++) {
          branchX += branchDir * (12.0 + _rng.nextDouble() * 20.0);
          branchY += 10.0 + _rng.nextDouble() * 18.0;
          branch.add(Offset(branchX, branchY));
        }
        _branchPoints.add(branch);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 1. Evaluate stochastic lightning strike intervals during rain weather states
    if (rainIntensity >= 0.35 || isRaining) {
      _strikeTimer += dt;
      if (_strikeTimer >= _nextStrikeDelay && !isFlashing) {
        triggerStrike();
        _scheduleNextStrike();
      }
    }

    // 2. Evaluate thunder rumble acoustic propagation delay
    if (_pendingThunderTimer != null) {
      _pendingThunderTimer = _pendingThunderTimer! - dt;
      if (_pendingThunderTimer! <= 0.0) {
        _pendingThunderTimer = null;
        onThunderRumble?.call();
      }
    }

    // 3. Evaluate multi-phase strike illumination envelope
    if (isFlashing) {
      _flashElapsedTime += dt;

      if (_flashElapsedTime >= _flashDuration) {
        isFlashing = false;
        currentFlashAlpha = 0.0;
        currentSpecularBoost = 0.0;
        _boltPoints.clear();
        _branchPoints.clear();
      } else {
        // Multi-phase illumination curve:
        // - Phase 0 (0.00s to 0.03s): Precursor leader stroke (ramps to 0.45)
        // - Phase 1 (0.03s to 0.06s): Brief dark dip (dips to 0.15)
        // - Phase 2 (0.06s to 0.12s): Main return stroke burst (peaks to 1.0)
        // - Phase 3 (0.12s to 0.32s): Secondary flicker and exponential tail decay
        double rawAlpha;
        if (_flashElapsedTime < 0.03) {
          rawAlpha = (_flashElapsedTime / 0.03) * 0.45;
        } else if (_flashElapsedTime < 0.06) {
          final t = (_flashElapsedTime - 0.03) / 0.03;
          rawAlpha = 0.45 - (t * 0.30);
        } else if (_flashElapsedTime < 0.12) {
          final t = (_flashElapsedTime - 0.06) / 0.06;
          rawAlpha = 0.15 + (t * 0.85);
        } else {
          final t = (_flashElapsedTime - 0.12) / (_flashDuration - 0.12);
          // Exponential decay with subtle high-frequency shimmer
          final shimmer = math.sin(_flashElapsedTime * 60.0) * 0.06;
          rawAlpha = (math.pow(1.0 - t, 2.2) + shimmer).toDouble().clamp(0.0, 1.0);
        }

        // Apply photo-sensitivity attenuation when reduceFlash is active
        currentFlashAlpha = reduceFlash ? rawAlpha * 0.25 : rawAlpha;
        currentSpecularBoost = rawAlpha * (reduceFlash ? 0.4 : 0.85);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isFlashing || currentFlashAlpha <= 0.01) return;

    final w = size.x;
    final h = size.y;

    // 1. Draw procedural electric fork bolt (hidden or softened if reduceFlash is enabled)
    if (!reduceFlash && _boltPoints.length >= 2) {
      final boltPath = Path()..moveTo(_boltPoints.first.dx, _boltPoints.first.dy);
      for (var i = 1; i < _boltPoints.length; i++) {
        boltPath.lineTo(_boltPoints[i].dx, _boltPoints[i].dy);
      }

      // Outer cyan electrical aura
      canvas.drawPath(boltPath, _boltCoronaPaint);
      // Bright white incandescent core
      canvas.drawPath(boltPath, _boltCorePaint);

      // Secondary branches
      for (final branch in _branchPoints) {
        if (branch.length >= 2) {
          final branchPath = Path()..moveTo(branch.first.dx, branch.first.dy);
          for (var i = 1; i < branch.length; i++) {
            branchPath.lineTo(branch[i].dx, branch[i].dy);
          }
          canvas.drawPath(branchPath, _branchPaint);
        }
      }
    }

    // 2. High-contrast ambient skyline & foreground illumination overlay
    const bleed = 60.0;
    final overlayAlpha = (currentFlashAlpha * (reduceFlash ? 0.22 : 0.65)).clamp(0.0, 1.0);
    final flashPaint = Paint()
      ..color = const Color(0xFFE1F5FE).withValues(alpha: overlayAlpha);
    canvas.drawRect(Rect.fromLTWH(-bleed, -bleed, w + bleed * 2, h + bleed * 2), flashPaint);
  }

  /// Resets lightning state back to idle.
  void reset() {
    isFlashing = false;
    currentFlashAlpha = 0.0;
    currentSpecularBoost = 0.0;
    _flashElapsedTime = 0.0;
    _pendingThunderTimer = null;
    _boltPoints.clear();
    _branchPoints.clear();
    _scheduleNextStrike();
  }
}
