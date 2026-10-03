import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Floating animated text indicator that drifts upward and fades out.
///
/// Used for arcade gameplay feedback like stunt combos ("+$7 STUNT! 1.5x"),
/// coin multipliers, and close-call near misses.
class FloatingTextComponent extends PositionComponent {
  FloatingTextComponent({
    required this.text,
    required Vector2 position,
    this.color = const Color(0xFF00E5FF),
    this.duration = 0.85,
    this.driftVelocity = -55.0,
  }) {
    this.position = position;
  }

  final String text;
  final Color color;
  final double duration;
  final double driftVelocity;
  double _elapsed = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y += driftVelocity * dt;
    if (_elapsed >= duration && isMounted) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final progress = (_elapsed / duration).clamp(0.0, 1.0);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 15.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.85 * alpha),
            blurRadius: 4.0,
            offset: const Offset(1.5, 1.5),
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset.zero);
  }
}
