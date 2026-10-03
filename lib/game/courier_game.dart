import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio_controller.dart';
import 'components/courier_player.dart';
import 'components/obstacle_component.dart';
import 'components/parallax_city.dart';
import 'components/pickup_component.dart';
import 'logic/game_state.dart';
import 'logic/world_chunk_manager.dart';

/// Main Flame game loop for Courier Dash.
///
/// Features a fixed 16:9 virtual resolution of 960x540 with letterboxing,
/// collision detection, continuous parallax city scrolling, procedural obstacle/pickup spawning,
/// low-latency audio integration, and responsive courier jumping controls.
class CourierGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  CourierGame({
    GameState? gameState,
    GameAudioController? audioController,
    WorldChunkManager? chunkManager,
  })  : gameState = gameState ?? GameState(),
        audio = audioController ?? GameAudioController(),
        chunkManager = chunkManager ?? WorldChunkManager(),
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

  final GameState gameState;
  final GameAudioController audio;
  final WorldChunkManager chunkManager;

  late final ParallaxCityComponent parallaxCity;
  late final CourierPlayer player;

  double currentSpeed = 200.0;
  double nextChunkX = 960.0;

  bool isRunning = true;

  final List<ObstacleComponent> activeObstacles = [];
  final List<PickupComponent> activePickups = [];

  VoidCallback? onRunConcluded;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    parallaxCity = ParallaxCityComponent(size: virtualResolution);
    world.add(parallaxCity);

    player = CourierPlayer(
      groundY: groundY,
      onJump: () => audio.playJump(),
      onDamage: () {
        audio.playFumble();
        gameState.applyHazardDamage();
      },
    );
    world.add(player);

    gameState.onMilestone = (event) {
      audio.playMilestone();
    };

    gameState.onGameOver = () {
      isRunning = false;
      onRunConcluded?.call();
    };

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
          _handlePickup(type);
        },
      );
      activePickups.add(pickComp);
      world.add(pickComp);
    }

    nextChunkX += 960.0;
  }

  void _handlePickup(PickupType type) {
    switch (type) {
      case PickupType.coin:
        gameState.addTip(1);
        audio.playCoin();
        break;
      case PickupType.coin5:
        gameState.addTip(5);
        audio.playCoin();
        break;
      case PickupType.energyDrink:
        gameState.activateEnergyDrink();
        audio.playCoin();
        break;
      case PickupType.packageRestore:
        gameState.restorePackage();
        audio.playMilestone();
        break;
    }
  }

  /// Resets the runner for the next shift.
  void restartRun() {
    for (final o in activeObstacles) {
      o.removeFromParent();
    }
    for (final p in activePickups) {
      p.removeFromParent();
    }
    activeObstacles.clear();
    activePickups.clear();

    chunkManager.reset();
    nextChunkX = 960.0;
    currentSpeed = 200.0;

    gameState.startRun();
    player.position = Vector2(120.0, groundY - player.size.y);
    player.simulator.currentY = groundY;
    player.simulator.verticalVelocity = 0.0;
    player.simulator.isGrounded = true;
    player.state = CourierState.running;
    player.isBoosted = false;

    isRunning = true;
    _spawnChunk();
    audio.startMusic();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning || gameState.status != GameStatus.running) return;

    // 0. Update active energy drink buff & player boosted visual state
    gameState.updateEnergyTimer(dt);
    player.isBoosted = gameState.isEnergyBoostActive;

    // 1. Calculate dynamic scroll speed based on distance (with energy boost)
    final speedMultiplier = gameState.isEnergyBoostActive ? 1.2 : 1.0;
    currentSpeed = chunkManager.calculateSpeed(gameState.distanceMeters) * speedMultiplier;

    // 2. Advance meter progress (20 px = 1 meter)
    final distanceDelta = (currentSpeed * dt) / 20.0;
    gameState.updateDistance(gameState.distanceMeters + distanceDelta);

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

    // 5. Coin Magnet Effect: attract nearby coins to the courier while energized
    if (gameState.isEnergyBoostActive) {
      final playerCenter = player.position + (player.size / 2);
      const magnetRadius = 260.0;
      const magnetSpeed = 480.0;

      for (final p in activePickups) {
        if ((p.type == PickupType.coin || p.type == PickupType.coin5) && !p.isCollected) {
          final pickupCenter = p.position + (p.size / 2);
          final diff = playerCenter - pickupCenter;
          final dist = diff.length;
          if (dist < magnetRadius && dist > 1.0) {
            final pull = diff.normalized() * (magnetSpeed * dt);
            p.position += pull;
          }
        }
      }
    }

    // 6. Clean up recycled items
    activeObstacles.removeWhere((o) => o.shouldRecycle || !o.isMounted);
    activePickups.removeWhere((p) => p.shouldRecycle || p.isCollected || !p.isMounted);

    // 7. Spawn next procedural chunk when horizon approaches
    if (nextChunkX <= virtualResolution.x + 480.0) {
      _spawnChunk();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isRunning && gameState.status == GameStatus.running) {
      player.jump();
    }
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
        if (isRunning && gameState.status == GameStatus.running) {
          player.jump();
        }
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        player.stopJump();
        return KeyEventResult.handled;
      }
    }

    return super.onKeyEvent(event, keysPressed);
  }
}
