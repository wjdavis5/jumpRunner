import 'package:flutter/gestures.dart';

/// Tells the game when a finger or a mouse button goes down on it and when
/// that same one comes off, and nothing in between.
///
/// Flutter's tap recognizers give up on a touch once it has moved 18 logical
/// pixels, about 3 mm on a phone, and report it as cancelled. A thumb pressed
/// hard for a long jump rolls further than that, so a held jump was let go
/// partway up and came down as the smallest hop. A press on this game has no
/// position, only a start and an end, so how far it travels does not matter.
class PressHoldGestureRecognizer extends GestureRecognizer {
  PressHoldGestureRecognizer({super.debugOwner});

  /// A pointer touched the game.
  void Function(int pointer)? onPress;

  /// That pointer lifted, or the system took it away.
  void Function(int pointer)? onRelease;

  final Set<int> _tracked = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!_tracked.add(event.pointer)) return;
    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
    onPress?.call(event.pointer);
  }

  void _handleEvent(PointerEvent event) {
    if (event is! PointerUpEvent && event is! PointerCancelEvent) return;
    if (_stopTracking(event.pointer)) onRelease?.call(event.pointer);
  }

  bool _stopTracking(int pointer) {
    if (!_tracked.remove(pointer)) return false;
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
    return true;
  }

  // This recognizer only watches. It never enters the gesture arena, so it
  // cannot take a touch from, or lose one to, anything else on screen.
  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}

  @override
  String get debugDescription => 'press and hold';

  @override
  void dispose() {
    for (final pointer in _tracked.toList()) {
      if (_stopTracking(pointer)) onRelease?.call(pointer);
    }
    super.dispose();
  }
}
