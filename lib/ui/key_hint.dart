import 'package:flutter/material.dart';

import '../game/logic/input_hints.dart';

/// A button label with a small keycap after it on devices with a keyboard,
/// so desktop players can see which key does the same thing. Touch devices
/// get the plain label.
class KeyHintLabel extends StatelessWidget {
  const KeyHintLabel({
    super.key,
    required this.label,
    required this.keyLabel,
    required this.style,
  });

  final String label;

  /// What is printed on the keycap, for example `SPACE`.
  final String keyLabel;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: style);
    if (!expectsKeyboard) return text;
    // Scaled down rather than clipped if a narrow window squeezes the button.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          text,
          const SizedBox(width: 10),
          Container(
            key: Key('key_hint_$keyLabel'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white54, width: 1),
            ),
            child: Text(
              keyLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
