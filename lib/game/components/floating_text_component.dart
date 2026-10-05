import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_font.dart';
import '../draw_order.dart';

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
  }) : super(priority: wordsPriority) {
    this.position = position;
  }

  final String text;
  final Color color;
  final double duration;
  final double driftVelocity;
  double _elapsed = 0.0;

  /// Whether this floating indicator has completed its display duration.
  bool get isFinished => _elapsed >= duration;

  /// Vertical room one line of feedback needs to stay legible.
  static const double lineHeight = 18.0;

  /// Indicators whose left edges are closer than this are treated as sharing
  /// a column and are stacked rather than drawn over each other.
  static const double columnWidth = 260.0;

  @override
  void onMount() {
    super.onMount();
    _stackAboveLiveSiblings();
  }

  /// Lifts this indicator clear of any live one it would be drawn over.
  ///
  /// Rewards often land on the same frame (a near miss, a vault and a trophy)
  /// and every indicator spawns beside the courier, so without this they
  /// print on top of each other and none can be read.
  void _stackAboveLiveSiblings() {
    final siblings = parent?.children
        .whereType<FloatingTextComponent>()
        .where((other) => !identical(other, this) && !other.isFinished)
        .toList();
    if (siblings == null || siblings.isEmpty) return;

    // Walk from the lowest indicator upward so each lift is final.
    siblings.sort((a, b) => b.position.y.compareTo(a.position.y));
    for (final other in siblings) {
      final sameColumn = (position.x - other.position.x).abs() < columnWidth;
      if (sameColumn && (position.y - other.position.y).abs() < lineHeight) {
        position.y = other.position.y - lineHeight;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y += driftVelocity * dt;
    if (_elapsed >= duration && isMounted && (parent?.isMounted ?? false)) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final progress = (_elapsed / duration).clamp(0.0, 1.0);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    final textSpan = withStars(
      text,
      TextStyle(
        fontFamily: gameFontFamily,
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
