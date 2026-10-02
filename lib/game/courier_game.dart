import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'components/courier_player.dart';
import 'components/parallax_city.dart';

/// Main Flame game loop for Courier Dash.
///
/// Features a fixed 16:9 virtual resolution of 960x540 with letterboxing,
/// collision detection, continuous parallax city scrolling, and courier jumping controls.
class CourierGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  CourierGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: virtualResolution.x,
            height: virtualResolution.y,
          )..viewfinder.anchor = Anchor.topLeft,
        );

  /// Fixed virtual canvas resolution (16:9 widescreen).
  static final Vector2 virtualResolution = Vector2(960, 540);

  /// Ground surface baseline Y coordinate in virtual coordinates.
  static const double groundY = 460.0;

  late final ParallaxCityComponent parallaxCity;
  late final CourierPlayer player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    parallaxCity = ParallaxCityComponent(size: virtualResolution);
    world.add(parallaxCity);

    player = CourierPlayer(groundY: groundY);
    world.add(player);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    player.jump();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    player.stopJump();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    player.stopJump();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isJumpKey = event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyW;

    if (isJumpKey) {
      if (event is KeyDownEvent) {
        player.jump();
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        player.stopJump();
        return KeyEventResult.handled;
      }
    }

    return super.onKeyEvent(event, keysPressed);
  }
}
