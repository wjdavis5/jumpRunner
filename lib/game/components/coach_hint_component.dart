import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Persistent first-run coaching hint floating above the opening hazard.
///
/// Bobs gently and waits for the player's first jump (or a failsafe
/// timeout), then fades out — teaching the core verb without nagging.
class CoachHintComponent extends PositionComponent {
  CoachHintComponent({
    required this.text,
    required Vector2 position,
    this.failsafeDuration = 7.0,
  }) {
    this.position = position;
    _textPainter = _layoutText(text);
  }

  final String text;
  final double failsafeDuration;

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
    _elapsed += dt;
    _bobTimer += dt;
    position.y += math.sin(_bobTimer * 3.0) * 12.0 * dt;

    if (!isDismissing && _elapsed >= failsafeDuration) {
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

    final dismissProgress = isDismissing ? (_fadeElapsed / fadeDuration).clamp(0.0, 1.0) : 0.0;
    final alpha = (1.0 - dismissProgress).clamp(0.0, 1.0);

    final panelWidth = _textPainter.width + panelPaddingH * 2;
    final panelHeight = _textPainter.height + panelPaddingV * 2;
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

    // Tail pointing at the hazard below.
    final tailPath = Path()
      ..moveTo(panelWidth / 2 - 8, panelHeight)
      ..lineTo(panelWidth / 2 + 8, panelHeight)
      ..lineTo(panelWidth / 2, panelHeight + tailHeight)
      ..close();
    canvas.drawPath(
      tailPath,
      Paint()..color = const Color(0xEE1E272E).withValues(alpha: alpha),
    );

    _textPainter.paint(
      canvas,
      const Offset(panelPaddingH, panelPaddingV + 0.5),
    );
  }
}
