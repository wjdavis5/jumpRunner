import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio_controller.dart';
import 'components/courier_player.dart';
import 'components/floating_text_component.dart';
import 'components/obstacle_component.dart';
import 'components/parallax_city.dart';
import 'components/particle_effect.dart';
import 'components/pickup_component.dart';
import 'components/rain_component.dart';
import 'logic/camera_juice_controller.dart';
import 'logic/game_state.dart';
import 'logic/weather_controller.dart';
import 'logic/world_chunk_manager.dart';
import 'models/courier_skin.dart';

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
    WeatherController? weatherController,
    CameraJuiceController? cameraJuiceController,
    CourierSkin? initialSkin,
  })  : gameState = gameState ?? GameState(),
        audio = audioController ?? GameAudioController(),
        chunkManager = chunkManager ?? WorldChunkManager(),
        weatherController = weatherController ?? WeatherController(),
        cameraJuice = cameraJuiceController ?? CameraJuiceController(),
        activeSkin = initialSkin ?? CourierSkin.standard,
        super(
          camera: CameraComponent.withFixedResolution(
            width: virtualResolution.x,
            height: virtualResolution.y,
          )..viewfinder.anchor = Anchor.center
           ..viewfinder.position = Vector2(virtualResolution.x / 2, virtualResolution.y / 2),
        );

  CourierSkin activeSkin;

  /// Updates player cosmetic skin and runtime palette.
  void setPlayerSkin(CourierSkin skin) {
    activeSkin = skin;
    if (isLoaded) {
      player.setSkin(skin);
    }
  }

  /// Fixed virtual canvas resolution (16:9 widescreen).
  static final Vector2 virtualResolution = Vector2(960, 540);

  /// Ground surface baseline Y coordinate in virtual coordinates.
  static const double groundY = 460.0;

  final GameState gameState;
  final GameAudioController audio;
  final WorldChunkManager chunkManager;
  final WeatherController weatherController;
  final CameraJuiceController cameraJuice;

  late final ParallaxCityComponent parallaxCity;
  late final RainComponent rainComponent;
  late final CourierPlayer player;

  double currentSpeed = 200.0;
  double nextChunkX = 960.0;

  bool isRunning = true;
  double _footstepTimer = 0.0;

  final List<ObstacleComponent> activeObstacles = [];
  final List<PickupComponent> activePickups = [];

  VoidCallback? onRunConcluded;
  VoidCallback? onPauseRequested;

  /// Triggers impact screen trauma shake.
  void triggerScreenShake([double trauma = 0.65]) {
    cameraJuice.addTrauma(trauma);
  }

  /// Spawns footstep or landing sidewalk dust puffs.
  void spawnDust(Vector2 pos, {int count = 6}) {
    world.add(ParticleEffectComponent.dust(position: pos, count: count));
  }

  /// Spawns footstep, landing, or jump water splashes when wet/raining.
  void spawnSplash(Vector2 pos, {int count = 8}) {
    world.add(ParticleEffectComponent.splash(position: pos, count: count));
  }

  /// Spawns pickup collection sparkle bursts.
  void spawnSparkles(Vector2 pos, {Color color = const Color(0xFFF1C40F), int count = 12}) {
    world.add(ParticleEffectComponent.sparkles(position: pos, color: color, count: count));
  }

  /// Spawns celebratory shift milestone confetti fireworks.
  void spawnConfetti(Vector2 pos, {int count = 35}) {
    world.add(ParticleEffectComponent.confetti(position: pos, count: count));
  }

  /// Spawns hazard impact and package fumble debris.
  void spawnImpact(Vector2 pos, {int count = 14}) {
    world.add(ParticleEffectComponent.impact(position: pos, count: count));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    parallaxCity = ParallaxCityComponent(size: virtualResolution);
    world.add(parallaxCity);

    rainComponent = RainComponent(size: virtualResolution);
    world.add(rainComponent);

    player = CourierPlayer(
      groundY: groundY,
      skin: activeSkin,
      onJump: () {
        audio.playJump();
        if (weatherController.isRaining) {
          spawnSplash(Vector2(player.position.x + 16, groundY - 1), count: 6);
        } else {
          spawnDust(Vector2(player.position.x + 16, groundY - 2), count: 5);
        }
      },
      onLand: () {
        if (weatherController.isRaining) {
          spawnSplash(Vector2(player.position.x + 20, groundY - 1), count: 10);
        } else {
          spawnDust(Vector2(player.position.x + 20, groundY - 2), count: 8);
        }
      },
      onDamage: () {
        audio.playFumble();
        spawnImpact(player.position + (player.size / 2));
        triggerScreenShake(0.65);
        gameState.applyHazardDamage();
      },
    );
    world.add(player);

    gameState.onMilestone = (event) {
      audio.playMilestone();
      spawnConfetti(Vector2(virtualResolution.x / 2, 100));
      spawnConfetti(Vector2(player.position.x + 40, groundY - 120), count: 20);
    };

    gameState.onGameOver = () {
      isRunning = false;
      cameraJuice.reset();
      camera.viewfinder.position = Vector2(virtualResolution.x / 2, virtualResolution.y / 2);
      camera.viewfinder.zoom = 1.0;
      camera.viewfinder.angle = 0.0;
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
      distanceMeters: gameState.distanceMeters,
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
      late final PickupComponent pickComp;
      pickComp = PickupComponent(
        type: p.type,
        position: Vector2(p.x, p.y),
        onCollected: (type) {
          final collectionPos = pickComp.position + (pickComp.size / 2);
          activePickups.removeWhere((item) => item.isCollected);
          _handlePickup(type, collectionPos);
        },
      );
      activePickups.add(pickComp);
      world.add(pickComp);
    }

    nextChunkX += 960.0;
  }

  void _handlePickup(PickupType type, [Vector2? pos]) {
    if (pos != null) {
      final Color sparkColor;
      switch (type) {
        case PickupType.coin:
        case PickupType.coin5:
          sparkColor = const Color(0xFFF1C40F);
          break;
        case PickupType.energyDrink:
          sparkColor = const Color(0xFF2ECC71);
          break;
        case PickupType.packageRestore:
          sparkColor = const Color(0xFFE67E22);
          break;
      }
      spawnSparkles(pos, color: sparkColor);
    }

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
    for (final o in activeObstacles.toList()) {
      o.removeFromParent();
    }
    for (final p in activePickups.toList()) {
      p.removeFromParent();
    }
    for (final c in world.children.whereType<ParticleEffectComponent>().toList()) {
      c.removeFromParent();
    }
    for (final t in world.children.whereType<FloatingTextComponent>().toList()) {
      t.removeFromParent();
    }
    activeObstacles.clear();
    activePickups.clear();
    _footstepTimer = 0.0;

    chunkManager.reset();
    weatherController.reset();
    rainComponent.rainIntensity = 0.0;
    cameraJuice.reset();
    final baseCenter = Vector2(virtualResolution.x / 2, virtualResolution.y / 2);
    camera.viewfinder.position = baseCenter;
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.angle = 0.0;
    nextChunkX = 960.0;
    currentSpeed = 200.0;
    parallaxCity.updateLighting(0.0, 0.0, 0.0);

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

    // 0. Update active energy drink buff, celebration, and stunt combo timers
    gameState.updateEnergyTimer(dt);
    gameState.updateMilestoneTimer(dt);
    gameState.updateContractTimer(dt);
    gameState.updateStuntTimer(dt);
    player.isBoosted = gameState.isEnergyBoostActive;

    // Footstep dust or puddle splash puffs while running along sidewalk
    if (player.simulator.isGrounded && player.state == CourierState.running) {
      _footstepTimer += dt;
      if (_footstepTimer >= 0.28) {
        _footstepTimer = 0.0;
        if (weatherController.isRaining) {
          spawnSplash(Vector2(player.position.x + 8.0, groundY - 1.0), count: 4);
        } else {
          spawnDust(Vector2(player.position.x + 8.0, groundY - 2.0), count: 3);
        }
      }
    }

    // 1. Calculate dynamic scroll speed based on distance (with energy boost)
    final speedMultiplier = gameState.isEnergyBoostActive ? 1.2 : 1.0;
    currentSpeed = chunkManager.calculateSpeed(gameState.distanceMeters) * speedMultiplier;
    audio.updateSpeed(currentSpeed);

    // 2. Advance meter progress (20 px = 1 meter)
    final distanceDelta = (currentSpeed * dt) / 20.0;
    gameState.updateDistance(gameState.distanceMeters + distanceDelta);

    // 2b. Advance dynamic weather simulation
    weatherController.update(gameState.distanceMeters);
    rainComponent.rainIntensity = weatherController.rainIntensity;
    rainComponent.horizontalScrollSpeed = currentSpeed;

    // 3. Update parallax city velocity & dynamic environment lighting
    parallaxCity.speedMultiplier = currentSpeed / 200.0;
    parallaxCity.updateLighting(
      gameState.distanceMeters,
      dt,
      weatherController.rainIntensity,
    );

    // 3b. Update camera trauma shake and velocity framing zoom
    cameraJuice.update(dt, currentSpeed: currentSpeed);
    final baseCenter = Vector2(virtualResolution.x / 2, virtualResolution.y / 2);
    camera.viewfinder.position = baseCenter + cameraJuice.shakeOffset;
    camera.viewfinder.zoom = cameraJuice.currentZoom;
    camera.viewfinder.angle = cameraJuice.shakeAngle;

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

    // 5b. Stunt Near-Miss Detection: evaluate tight clearances over hazards
    final playerLeft = player.position.x;
    final playerRight = player.position.x + player.size.x;
    final playerBottom = player.position.y + player.size.y;

    for (final o in activeObstacles) {
      if (!o.hasTriggeredNearMiss && !o.hasCollidedWithPlayer) {
        final obsLeft = o.position.x;
        final obsRight = o.position.x + o.size.x;
        final obsTop = o.position.y;

        final isOverlappingHorizontally = (playerRight >= obsLeft && playerLeft <= obsRight);
        if (isOverlappingHorizontally) {
          final verticalClearance = obsTop - playerBottom;
          if (verticalClearance >= 0.0 && verticalClearance <= 40.0) {
            o.hasTriggeredNearMiss = true;
            _handleNearMiss(o, verticalClearance);
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

  void _handleNearMiss(ObstacleComponent obstacle, double clearance) {
    gameState.recordStunt(clearance: clearance);
    audio.playCoin();

    // Floating score popup above courier
    final multiplierStr = gameState.stuntMultiplier > 1.0 ? '${gameState.stuntMultiplier}x ' : '';
    world.add(
      FloatingTextComponent(
        text: 'STUNT! $multiplierStr+\$${(5 * gameState.stuntMultiplier).round()}',
        position: Vector2(player.position.x + 4.0, player.position.y - 20.0),
        color: const Color(0xFF00E5FF),
      ),
    );

    // Cyan sparkle burst at the hazard apex
    spawnSparkles(
      Vector2(obstacle.position.x + (obstacle.size.x / 2), obstacle.position.y),
      color: const Color(0xFF00E5FF),
      count: 10,
    );
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
    final isPauseKey = event.logicalKey == LogicalKeyboardKey.keyP ||
        event.logicalKey == LogicalKeyboardKey.escape;

    if (isPauseKey && event is KeyDownEvent) {
      onPauseRequested?.call();
      return KeyEventResult.handled;
    }

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
