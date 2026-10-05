import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Persistent first-run coaching hint floating above the opening hazard.
///
/// Bobs gently and waits for the player's first jump (or a failsafe
/// timeout), then fades out — teaching the core verb without nagging.
///
/// Given a hazard to [follow] it rides along above that hazard as the street scrolls,
/// so its tail keeps pointing at the thing it is talking about, and it leaves
/// once the hazard is behind the courier.
class CoachHintComponent extends PositionComponent {
  CoachHintComponent({
    required this.text,
    required Vector2 position,
    this.failsafeDuration = 7.0,
    this.follow,
    this.dismissBehindX = 0.0,
    this.showWithinX = double.infinity,
    this.minX = 16.0,
    this.maxX = 944.0,
    this.hoverAbove,
    this.minY = 70.0,
    this.dismissWhen,
  }) {
    this.position = position;
    _textPainter = _layoutText(text);
  }

  final String text;

  /// Seconds a hint with no hazard to follow stays up when nobody dismisses it.
  final double failsafeDuration;

  /// The hazard this hint is about, if it should follow one.
  final PositionComponent? follow;

  /// Once the hazard's right edge is left of this x (the courier), the hint
  /// has done its job and fades.
  final double dismissBehindX;

  /// The hint stays hidden until the hazard's left edge is within this x.
  /// Infinity shows it straight away, parked at the screen edge.
  final double showWithinX;

  /// Screen bounds the panel is kept inside while it follows its hazard.
  final double minX;
  final double maxX;

  /// When set, the hint also follows vertically, floating this far above
  /// the top of what it follows. Used for a hint about the courier, who
  /// moves up and down; street hazards only need the horizontal follow.
  final double? hoverAbove;

  /// Highest the panel may float (it must stay clear of the HUD).
  final double minY;

  /// Checked every frame; once it returns true the hint fades.
  final bool Function()? dismissWhen;

  /// A following hint outlives [failsafeDuration] (a far hazard can take
  /// longer than that to arrive), but never this long.
  static const double followingFailsafeDuration = 20.0;

  static const double fadeDuration = 0.35;
  static const double panelPaddingH = 14.0;
  static const double panelPaddingV = 10.0;
  static const double tailHeight = 9.0;

  late final TextPainter _textPainter;
  double _elapsed = 0.0;
  double _bobTimer = 0.0;
  double _fadeElapsed = -1.0;

  /// Whether the hint is fading out (dismissal started).
  bool get isDismissing => _fadeElapsed >= 0.0;

  /// Whether the fade-out has completed and the hint should be gone.
  bool get isFinished => _fadeElapsed >= fadeDuration;

  /// Whether the hint is still holding back for its hazard to come close.
  bool get isWaiting {
    final target = follow;
    return target != null && !isDismissing && target.position.x > showWithinX;
  }

  double get panelWidth => _textPainter.width + panelPaddingH * 2;

  double get panelHeight => _textPainter.height + panelPaddingV * 2;

  double get _hazardCenterX {
    final target = follow!;
    return target.position.x + target.size.x / 2;
  }

  /// Begins the fade-out; safe to call repeatedly.
  void dismiss() {
    if (!isDismissing) {
      _fadeElapsed = 0.0;
    }
  }

  TextPainter _layoutText(String value) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = follow;
    if (target != null) {
      position.x = (_hazardCenterX - panelWidth / 2)
          .clamp(minX, math.max(minX, maxX - panelWidth))
          .toDouble();
      if (isWaiting) return;
      if (target.isRemoved || target.position.x + target.size.x < dismissBehindX) {
        dismiss();
      }
    }
    if (dismissWhen?.call() ?? false) dismiss();

    _elapsed += dt;
    _bobTimer += dt;
    final lift = hoverAbove;
    if (target != null && lift != null) {
      // Same gentle bob as below, written out so it can ride a moving base.
      final bob = 4.0 - 4.0 * math.cos(_bobTimer * 3.0);
      final base = target.position.y - lift - panelHeight - tailHeight;
      position.y = math.max(minY, base + bob);
    } else {
      position.y += math.sin(_bobTimer * 3.0) * 12.0 * dt;
    }

    final failsafe = target == null ? failsafeDuration : followingFailsafeDuration;
    if (!isDismissing && _elapsed >= failsafe) {
      dismiss();
    }
    if (isDismissing) {
      _fadeElapsed += dt;
      if (isFinished && isMounted && (parent?.isMounted ?? false)) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isWaiting) return;

    final dismissProgress = isDismissing ? (_fadeElapsed / fadeDuration).clamp(0.0, 1.0) : 0.0;
    final alpha = (1.0 - dismissProgress).clamp(0.0, 1.0);

    final panelWidth = this.panelWidth;
    final panelHeight = this.panelHeight;
    final panelRect = Rect.fromLTWH(0, 0, panelWidth, panelHeight);

    final panelPaint = Paint()
      ..color = const Color(0xEE1E272E).withValues(alpha: alpha);
    final borderPaint = Paint()
      ..color = const Color(0xFFF1C40F).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final rrect = RRect.fromRectAndRadius(
      panelRect,
      const Radius.circular(12.0),
    );

    canvas.drawRRect(rrect, panelPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Tail pointing at the hazard below. While the panel is held at a screen
    // edge the tail slides along it to stay over the hazard.
    final tailX = follow == null
        ? panelWidth / 2
        : (_hazardCenterX - position.x).clamp(18.0, panelWidth - 18.0).toDouble();
    final tailPath = Path()
      ..moveTo(tailX - 8, panelHeight)
      ..lineTo(tailX + 8, panelHeight)
      ..lineTo(tailX, panelHeight + tailHeight)
      ..close();
    canvas.drawPath(
      tailPath,
      Paint()..color = const Color(0xEE1E272E).withValues(alpha: alpha),
    );

    // The words fade with the panel instead of hanging in the air after it.
    final fading = alpha < 1.0;
    if (fading) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, panelWidth, panelHeight),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    _textPainter.paint(
      canvas,
      const Offset(panelPaddingH, panelPaddingV + 0.5),
    );
    if (fading) canvas.restore();
  }
}
