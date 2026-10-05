import 'package:flutter/widgets.dart';

/// Centers a fixed-design card and scales it down, never up, when the screen
/// is too small to show it whole.
///
/// The menu cards are laid out for the 960x540 canvas. A phone held sideways
/// offers under 400 px of height, where they used to overflow and lose their
/// bottom row of buttons.
class FitToScreen extends StatelessWidget {
  const FitToScreen({super.key, required this.child, this.margin = 12.0});

  final Widget child;

  /// Breathing room kept between the card and the screen edge.
  final double margin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(margin),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: child,
        ),
      ),
    );
  }
}
