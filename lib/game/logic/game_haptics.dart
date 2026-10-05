import 'dart:async';

import 'package:flutter/services.dart';

/// The phone's vibration motor, for the three moments that earn it.
///
/// A phone game is often played with the sound off, and then a hit had only
/// the screen shake to announce it. Each call is fire-and-forget: a desktop,
/// or a browser with no vibration support, simply ignores it.
class GameHaptics {
  GameHaptics({this.enabled = true});

  /// The player's choice. When false nothing is asked of the platform.
  bool enabled;

  /// A package was knocked loose and the shift goes on.
  void hit() => _buzz(HapticFeedback.mediumImpact);

  /// The last package is gone.
  void shiftOver() => _buzz(HapticFeedback.heavyImpact);

  /// A 500 m milestone.
  void milestone() => _buzz(HapticFeedback.lightImpact);

  void _buzz(Future<void> Function() request) {
    if (!enabled) return;
    unawaited(request().catchError((Object _) {}));
  }
}
