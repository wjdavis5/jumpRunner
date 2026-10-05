import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_font.dart';
import '../draw_order.dart';

/// Floating comic-style speech bubble indicator that displays courier voice barks
/// and customer doorstep reactions above characters.
///
/// Features animated upward drift, smooth fade-in/fade-out, speech tail arrow,
/// and distinct color coding for stunts, near-misses, and customer reactions.
class SpeechBubbleComponent extends PositionComponent {
  SpeechBubbleComponent({
    required this.text,
    required Vector2 position,
    this.backgroundColor = const Color(0xEE1E272E),
    this.textColor = Colors.white,
    this.borderColor = const Color(0xFF00E5FF),
    this.duration = 1.25,
    this.driftVelocity = -22.0,
    this.tailOffsetX = 16.0,
    this.speaker,
  }) : super(priority: wordsPriority) {
    this.position = position;
    final who = speaker;
    if (who != null) _offsetFromSpeaker = position - who.position;
  }

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double duration;
  final double driftVelocity;
  final double tailOffsetX;

  /// Who is talking. When given, the bubble keeps its place relative to them
  /// as they jump and fall, instead of being left behind in mid-air or run
  /// into from below.
  final PositionComponent? speaker;

  Vector2 _offsetFromSpeaker = Vector2.zero();

  double _elapsed = 0.0;

  /// Whether this speech bubble has completed its display duration.
  bool get isFinished => _elapsed >= duration;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final who = speaker;
    if (who != null) {
      position.setValues(
        who.position.x + _offsetFromSpeaker.x,
        who.position.y + _offsetFromSpeaker.y + driftVelocity * _elapsed,
      );
    } else {
      position.y += driftVelocity * dt;
    }

    if (_elapsed >= duration && isMounted && (parent?.isMounted ?? false)) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Fade curve: quick pop-in over first 0.1s, stay full opacity, fade out in final 0.3s
    double alpha = 1.0;
    if (_elapsed < 0.1) {
      alpha = (_elapsed / 0.1).clamp(0.0, 1.0);
    } else if (_elapsed > duration - 0.3) {
      alpha = ((duration - _elapsed) / 0.3).clamp(0.0, 1.0);
    }

    final textSpan = withStars(
      text,
      TextStyle(
        fontFamily: gameFontFamily,
        color: textColor.withValues(alpha: alpha),
        fontSize: 13.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.85 * alpha),
            blurRadius: 3.0,
            offset: const Offset(1.0, 1.0),
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 10.0;
    const paddingV = 5.0;
    final bubbleWidth = textPainter.width + (paddingH * 2);
    final bubbleHeight = textPainter.height + (paddingV * 2);
    const radius = Radius.circular(8.0);
    const tailHeight = 6.0;

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bubbleWidth, bubbleHeight),
      radius,
    );

    // Build speech bubble outline with pointer tail pointing downwards
    final path = Path()..addRRect(bubbleRect);

    final tailCenter = math.min(tailOffsetX, bubbleWidth - 12.0);
    final tailPath = Path()
      ..moveTo(tailCenter - 5.0, bubbleHeight)
      ..lineTo(tailCenter, bubbleHeight + tailHeight)
      ..lineTo(tailCenter + 5.0, bubbleHeight)
      ..close();

    path.addPath(tailPath, Offset.zero);

    // Draw bubble background
    final bgPaint = Paint()
      ..color = backgroundColor.withValues(alpha: backgroundColor.a * alpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bgPaint);

    // Draw bubble border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: borderColor.a * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(path, borderPaint);

    // Paint text inside bubble
    textPainter.paint(canvas, const Offset(paddingH, paddingV));
  }
}
