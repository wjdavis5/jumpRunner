import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'components/courier_player.dart';
import 'components/obstacle_component.dart';
import 'components/parallax_city.dart';
import 'components/pickup_component.dart';
import 'logic/world_chunk_manager.dart';

/// Main Flame game loop for Courier Dash.
///
/// Features a fixed 16:9 virtual resolution of 960x540 with letterboxing,
/// collision detection, continuous parallax city scrolling, procedural obstacle/pickup spawning,
/// and responsive courier jumping controls.
class CourierGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  CourierGame({
    WorldChunkManager? chunkManager,
  })  : chunkManager = chunkManager ?? WorldChunkManager(),
        super(
          camera: CameraComponent.withFixedResolution(
            width: virtualResolution.x,
            height: virtualResolution.y,
          )..viewfinder.anchor = Anchor.topLeft,
        );

  /// Fixed virtual canvas resolution (16:9 widescreen).
  static final Vector2 virtualResolution = Vector2(960, 540);

  /// Ground surface baseline Y coordinate in virtual coordinates.
  static const double groundY = 460.0;

  final WorldChunkManager chunkManager;

  late final ParallaxCityComponent parallaxCity;
  late final CourierPlayer player;

  double currentSpeed = 200.0;
  double distanceMeters = 0.0;
  double nextChunkX = 960.0;

  bool isRunning = true;

  final List<ObstacleComponent> activeObstacles = [];
  final List<PickupComponent> activePickups = [];

  ValueChanged<PickupType>? onPickupCollected;
  VoidCallback? onHazardHit;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    parallaxCity = ParallaxCityComponent(size: virtualResolution);
    world.add(parallaxCity);

    player = CourierPlayer(
      groundY: groundY,
      onDamage: () => onHazardHit?.call(),
    );
    world.add(player);

    // Seed initial terrain chunk
    _spawnChunk();
  }

  void _spawnChunk() {
    final chunk = chunkManager.generateChunk(
      startX: nextChunkX,
      speed: currentSpeed,
      groundY: groundY,
    );

    for (final o in chunk.obstacles) {
      final obsComp = ObstacleComponent(
        type: o.type,
        position: Vector2(o.x, o.y),
        size: Vector2(o.width, o.height),
      );
      activeObstacles.add(obsComp);
      world.add(obsComp);
    }

    for (final p in chunk.pickups) {
      final pickComp = PickupComponent(
        type: p.type,
        position: Vector2(p.x, p.y),
        onCollected: (type) {
          activePickups.removeWhere((item) => item.isCollected);
          onPickupCollected?.call(type);
        },
      );
      activePickups.add(pickComp);
      world.add(pickComp);
    }

    nextChunkX += 960.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    // 1. Calculate dynamic scroll speed based on distance
    currentSpeed = chunkManager.calculateSpeed(distanceMeters);

    // 2. Advance meter progress (200 px/s ≈ 10 m/s for arcade feel: 20 px = 1 meter)
    distanceMeters += (currentSpeed * dt) / 20.0;

    // 3. Update parallax city velocity
    parallaxCity.speedMultiplier = currentSpeed / 200.0;

    // 4. Scroll active hazards and pickups leftward
    final scrollDelta = currentSpeed * dt;
    nextChunkX -= scrollDelta;

    for (final o in activeObstacles) {
      o.position.x -= scrollDelta;
    }
    for (final p in activePickups) {
      p.position.x -= scrollDelta;
    }

    // 5. Clean up recycled items
    activeObstacles.removeWhere((o) => o.shouldRecycle || !o.isMounted);
    activePickups.removeWhere((p) => p.shouldRecycle || p.isCollected || !p.isMounted);

    // 6. Spawn next procedural chunk when horizon approaches
    if (nextChunkX <= virtualResolution.x + 480.0) {
      _spawnChunk();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isRunning) player.jump();
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
        if (isRunning) player.jump();
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        player.stopJump();
        return KeyEventResult.handled;
      }
    }

    return super.onKeyEvent(event, keysPressed);
  }
}
