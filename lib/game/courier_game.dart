import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'components/parallax_city.dart';

/// Main Flame game loop for Courier Dash.
///
/// Features a fixed 16:9 virtual resolution of 960x540 with letterboxing,
/// collision detection, and continuous parallax city scrolling.
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    parallaxCity = ParallaxCityComponent(size: virtualResolution);
    world.add(parallaxCity);
  }
}
