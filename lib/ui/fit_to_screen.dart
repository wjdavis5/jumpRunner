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

/// Lays [child] out no narrower than [minWidth] and, on a screen narrower
/// than that, scales the whole of it down to the width there is.
///
/// The HUD and the two shop cards are rows of fixed-size parts. On a phone
/// held upright (the web build lets a player choose that), or in a narrow
/// browser window, those rows ran off the right-hand edge: at 375 px the
/// pause and mute buttons were off the screen altogether, and so were the
/// Locker's buy buttons. Everything in [child] sees a screen [minWidth]
/// wide and proportionally taller, so it lays out as it does on the
/// narrowest screen it was designed for.
class NarrowScreenScale extends StatelessWidget {
  const NarrowScreenScale({super.key, required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width >= minWidth) return child;

        // Everything inside is drawn [shrink] times smaller, so the notch
        // and gesture-bar insets are given to it that much larger: a
        // SafeArea inside still clears the real ones.
        final grow = minWidth / width;
        final designSize = Size(minWidth, height * grow);
        final screen = MediaQuery.of(context);
        return FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox.fromSize(
            size: designSize,
            child: MediaQuery(
              data: screen.copyWith(
                size: designSize,
                padding: screen.padding * grow,
                viewPadding: screen.viewPadding * grow,
                viewInsets: screen.viewInsets * grow,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
