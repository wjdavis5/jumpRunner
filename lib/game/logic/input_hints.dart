import 'package:flutter/foundation.dart';

/// Whether this device is expected to have a physical keyboard.
///
/// On the web [defaultTargetPlatform] is the browser's operating system, so a
/// desktop browser counts and a phone or tablet does not.
bool get expectsKeyboard {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// On-street coaching words for the two jump inputs.
class CoachText {
  /// A quick press: enough for scooters and dogs.
  static String hop({required bool keyboard}) =>
      keyboard ? 'PRESS SPACE TO HOP!' : 'TAP TO HOP!';

  /// A held press: needed to clear a van.
  static String leap({required bool keyboard}) =>
      keyboard ? 'HOLD SPACE TO LEAP!' : 'HOLD TO LEAP!';

  /// Over a flock of pigeons on the street. They take off as the courier
  /// comes up, and the one way to be hit is to leap up into them: a courier
  /// who keeps running passes underneath. It names the birds because a
  /// bare "don't jump" could be read as being about the dog in front of
  /// them.
  static String underTheBirds() => 'RUN UNDER THE BIRDS!';

  /// Shown while the chute is open: a press in mid-air opens it, and the
  /// same press again closes it.
  static String glide({required bool keyboard}) =>
      keyboard ? 'GLIDING!  SPACE TO DROP' : 'GLIDING!  TAP TO DROP';
}
