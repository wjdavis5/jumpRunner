import 'package:flutter/material.dart';

/// Dims everything behind a menu card, and closes the card when the dimmed
/// area is tapped.
///
/// The depot's cards (Locker, Bodega, Trophies, Daily Shift) open on top of
/// the title card. Without this the title showed around and faintly through
/// them, and the only way out was the small close button.
class ModalScrim extends StatelessWidget {
  const ModalScrim({super.key, required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  /// How dark the backdrop gets. The street stays just visible.
  static const double opacity = 0.62;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('modal_scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
          ),
        ),
        child,
      ],
    );
  }
}
