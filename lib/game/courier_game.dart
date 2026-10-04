import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'audio_controller.dart';
import '../services/storage_service.dart';
import 'components/courier_player.dart';
import 'components/crane_swing_component.dart';
import 'components/crosswalk_zone_component.dart';
import 'components/cyclist_companion_component.dart';
import 'components/delivery_drone_component.dart';
import 'components/drop_zone_component.dart';
import 'components/floating_text_component.dart';
import 'components/food_cart_component.dart';
import 'components/grind_rail_component.dart';
import 'components/obstacle_component.dart';
import 'components/parallax_city.dart';
import 'components/particle_effect.dart';
import 'components/pickup_component.dart';
import 'components/pigeon_flock_component.dart';
import 'components/pr_marker_component.dart';
import 'components/rain_component.dart';
import 'components/ramp_component.dart';
import 'components/scaffolding_component.dart';
import 'components/speech_bubble_component.dart';
import 'components/steam_vent_component.dart';
import 'components/subway_station_component.dart';
import 'logic/achievement_manager.dart';
import 'logic/camera_juice_controller.dart';
import 'logic/game_state.dart';
import 'logic/weather_controller.dart';
import 'logic/world_chunk_manager.dart';
import 'models/courier_skin.dart';
import 'models/daily_shift.dart';
import 'models/run_booster.dart';

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
    AchievementManager? achievementManager,
    LocalStorageService? storageService,
    int? personalRecordDistance,
    CourierSkin? initialSkin,
    Set<RunBooster>? initialBoosters,
    this.dailyShift,
  })  : gameState = gameState ?? GameState(),
        audio = audioController ?? GameAudioController(),
        chunkManager = chunkManager ?? WorldChunkManager(),
        weatherController = weatherController ?? WeatherController(),
        cameraJuice = cameraJuiceController ?? CameraJuiceController(),
        achievementManager = achievementManager ?? AchievementManager(),
        storage = storageService,
        personalRecordDistance = personalRecordDistance ?? storageService?.highDistance ?? 0,
        activeSkin = initialSkin ?? CourierSkin.standard,
        activeBoosters = initialBoosters ?? const {},
        super(
          camera: CameraComponent.withFixedResolution(
            width: virtualResolution.x,
            height: virtualResolution.y,
          )..viewfinder.anchor = Anchor.center
           ..viewfinder.position = Vector2(virtualResolution.x / 2, virtualResolution.y / 2),
        );

  CourierSkin activeSkin;
  Set<RunBooster> activeBoosters;

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
  final AchievementManager achievementManager;
  final LocalStorageService? storage;
  DailyShift? dailyShift;

  int personalRecordDistance;
  PersonalRecordMarkerComponent? activePrMarker;
  bool hasSpawnedPrMarker = false;
  bool hasSurpassedPr = false;
  bool hasRecordedDailyShiftSuccess = false;
  DeliveryDroneComponent? deliveryDrone;

  int _wetHazardsCleared = 0;

  late final ParallaxCityComponent parallaxCity;
  late final RainComponent rainComponent;
  late final CourierPlayer player;

  double currentSpeed = 200.0;
  double nextChunkX = 960.0;

  bool isRunning = true;
  double _footstepTimer = 0.0;

  final List<ObstacleComponent> activeObstacles = [];
  final List<PickupComponent> activePickups = [];
  final List<ScaffoldingComponent> activeScaffolding = [];
  final List<RampComponent> activeRamps = [];
  final List<DropZoneComponent> activeDropZones = [];
  final List<GrindRailComponent> activeGrindRails = [];
  final List<SteamVentComponent> activeSteamVents = [];
  final List<SubwayStationComponent> activeSubwayStations = [];
  final List<CraneSwingComponent> activeCranes = [];
  final List<CyclistCompanionComponent> activeCyclists = [];
  final List<PigeonFlockComponent> activePigeonFlocks = [];
  final List<CrosswalkZoneComponent> activeCrosswalks = [];
  final List<FoodCartComponent> activeFoodCarts = [];
  ObstacleComponent? _currentVaultTarget;
  double cameraTargetY = 270.0;
  double _grindSparkTimer = 0.0;

  VoidCallback? onRunConcluded;
  VoidCallback? onPauseRequested;

  /// Triggers impact screen trauma shake.
  void triggerScreenShake([double trauma = 0.65]) {
    cameraJuice.addTrauma(trauma);
  }

  bool _isUpdatingTree = false;
  final List<Component> _pendingEffects = [];

  /// Safely adds transient visual effects and indicators to the world,
  /// queuing them if called during component tree traversal in headless environments.
  void addEffect(Component effect) {
    if (_isUpdatingTree && !world.isMounted) {
      _pendingEffects.add(effect);
    } else {
      world.add(effect);
    }
  }

  void _flushPendingEffects() {
    if (_pendingEffects.isNotEmpty) {
      final effects = _pendingEffects.toList();
      _pendingEffects.clear();
      for (final e in effects) {
        world.add(e);
      }
    }
  }

  /// Spawns footstep or landing sidewalk dust puffs.
  void spawnDust(Vector2 pos, {int count = 6}) {
    addEffect(ParticleEffectComponent.dust(position: pos, count: count));
  }

  /// Spawns footstep, landing, or jump water splashes when wet/raining.
  void spawnSplash(Vector2 pos, {int count = 8}) {
    addEffect(ParticleEffectComponent.splash(position: pos, count: count));
  }

  /// Spawns pickup collection sparkle bursts.
  void spawnSparkles(Vector2 pos, {Color color = const Color(0xFFF1C40F), int count = 12}) {
    addEffect(ParticleEffectComponent.sparkles(position: pos, color: color, count: count));
  }

  /// Spawns pigeon flock panic flutter feather bursts.
  void spawnFeathers(Vector2 pos, {int count = 12}) {
    addEffect(ParticleEffectComponent.feathers(position: pos, count: count));
  }

  /// Spawns food cart umbrella bounce spice cloud puffs (chili, paprika, turmeric, cumin).
  void spawnSpiceCloud(Vector2 pos, {int count = 16}) {
    addEffect(ParticleEffectComponent.spiceCloud(position: pos, count: count));
  }

  /// Spawns celebratory shift milestone confetti fireworks.
  void spawnConfetti(Vector2 pos, {int count = 35}) {
    addEffect(ParticleEffectComponent.confetti(position: pos, count: count));
  }

  /// Spawns hazard impact and package fumble debris.
  void spawnImpact(Vector2 pos, {int count = 14}) {
    addEffect(ParticleEffectComponent.impact(position: pos, count: count));
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
        audio.playCourierBark(CourierBarkType.damage);
        spawnImpact(player.position + (player.size / 2));
        triggerScreenShake(0.65);
        gameState.applyHazardDamage();
      },
      onRailOllie: _handleRailOllie,
      checkCanVault: _canVaultObstacleAhead,
      onVault: _handleParkourVault,
      onGlideStarted: _handleGlideStarted,
      onGlideEnded: _handleGlideEnded,
      onCraneLaunch: _handleCraneLaunch,
      onDraftSlingshot: _handleDraftSlingshot,
    );
    world.add(player);

    audio.addCourierBarkListener((type, line) {
      Color borderColor = const Color(0xFF00E5FF);
      Color textColor = const Color(0xFFFFFFFF);
      if (type == CourierBarkType.damage) {
        borderColor = const Color(0xFFFF5252);
        textColor = const Color(0xFFFFCDD2);
      } else if (type == CourierBarkType.nearMiss) {
        borderColor = const Color(0xFFFFD166);
      } else if (type == CourierBarkType.glide) {
        borderColor = const Color(0xFFFF9F43);
      }
      addEffect(
        SpeechBubbleComponent(
          text: line,
          position: Vector2(player.position.x - 10.0, player.position.y - 42.0),
          borderColor: borderColor,
          textColor: textColor,
        ),
      );
    });

    audio.addCustomerReactionListener((type, line) {
      final Color borderColor = type == CustomerReactionType.fiveStars
          ? const Color(0xFFF1C40F)
          : const Color(0xFF2ECC71);
      final Color textColor = type == CustomerReactionType.fiveStars
          ? const Color(0xFFFFF176)
          : Colors.white;
      addEffect(
        SpeechBubbleComponent(
          text: line,
          position: Vector2(player.position.x + 24.0, groundY - 76.0),
          borderColor: borderColor,
          textColor: textColor,
          tailOffsetX: 22.0,
        ),
      );
    });

    gameState.onMilestone = (event) {
      audio.playMilestone();
      spawnConfetti(Vector2(virtualResolution.x / 2, 100));
      spawnConfetti(Vector2(player.position.x + 40, groundY - 120), count: 20);
    };

    achievementManager.onAchievementUnlocked = (achievement) {
      audio.playMilestone();
      world.add(
        FloatingTextComponent(
          text: 'TROPHY: ${achievement.title}!',
          position: Vector2(player.position.x - 20, player.position.y - 40),
          color: const Color(0xFFF1C40F),
        ),
      );
    };

    gameState.onGameOver = () {
      isRunning = false;
      cameraJuice.reset();
      camera.viewfinder.position = Vector2(virtualResolution.x / 2, virtualResolution.y / 2);
      camera.viewfinder.zoom = 1.0;
      camera.viewfinder.angle = 0.0;
      onRunConcluded?.call();
    };

    gameState.onVipMissionExpired = () {
      audio.playFumble();
      triggerScreenShake(0.25);
      addEffect(
        FloatingTextComponent(
          text: 'VIP TIMER EXPIRED!',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFFE74C3C),
        ),
      );
      audio.playCourierBark(CourierBarkType.damage, line: 'Lost the VIP bonus!');
    };

    if (dailyShift != null || activeBoosters.isNotEmpty) {
      gameState.startRun(dailyShift: dailyShift, equippedBoosters: activeBoosters);
      if (dailyShift?.modifier == DailyModifier.rainyRush) {
        weatherController.rainIntensity = 0.8;
        rainComponent.rainIntensity = 0.8;
      }
      player.isBoosted = gameState.isEnergyBoostActive;
    }

    // Seed initial terrain chunk
    _spawnChunk();
  }

  void _spawnChunk() {
    final chunk = chunkManager.generateChunk(
      startX: nextChunkX,
      speed: currentSpeed,
      groundY: groundY,
      distanceMeters: gameState.distanceMeters,
      isVipActive: gameState.isVipMissionActive,
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

    for (final s in chunk.scaffoldings) {
      final scComp = ScaffoldingComponent(
        position: Vector2(s.x, s.y),
        size: Vector2(s.width, s.height),
        groundY: groundY,
      );
      activeScaffolding.add(scComp);
      world.add(scComp);
    }

    for (final r in chunk.ramps) {
      final rampComp = RampComponent(
        position: Vector2(r.x, r.y),
        size: Vector2(r.width, r.height),
        launchImpulse: r.launchImpulse,
      );
      activeRamps.add(rampComp);
      world.add(rampComp);
    }

    for (final dz in chunk.dropZones) {
      final dzComp = DropZoneComponent(
        position: Vector2(dz.x, dz.y),
        size: Vector2(dz.width, dz.height),
        groundY: groundY,
        isVip: dz.isVip,
      );
      activeDropZones.add(dzComp);
      world.add(dzComp);
    }

    for (final gr in chunk.grindRails) {
      final grComp = GrindRailComponent(
        position: Vector2(gr.x, gr.y),
        size: Vector2(gr.width, gr.height),
        groundY: groundY,
      );
      activeGrindRails.add(grComp);
      world.add(grComp);
    }

    for (final sv in chunk.steamVents) {
      final svComp = SteamVentComponent(
        position: Vector2(sv.x, sv.y),
        size: Vector2(sv.width, sv.height),
        groundY: groundY,
        updraftHeight: sv.updraftHeight,
        updraftVelocity: sv.updraftVelocity,
      );
      activeSteamVents.add(svComp);
      world.add(svComp);
    }

    for (final st in chunk.subwayStations) {
      final stComp = SubwayStationComponent(
        position: Vector2(st.x, groundY - 260.0),
        size: Vector2(st.width, 260.0),
        groundY: groundY,
        stationName: st.stationName,
      );
      activeSubwayStations.add(stComp);
      world.add(stComp);
    }

    for (final cs in chunk.craneSwings) {
      final craneComp = CraneSwingComponent(
        position: Vector2(cs.x, cs.y),
        size: Vector2(cs.width, cs.height),
        cableLength: cs.cableLength,
      );
      activeCranes.add(craneComp);
      world.add(craneComp);
    }

    for (final cy in chunk.cyclists) {
      final cyclistComp = CyclistCompanionComponent(
        position: Vector2(cy.x, cy.y),
        size: Vector2(cy.width, cy.height),
        groundY: groundY,
        relativeSpeed: cy.relativeSpeed,
      );
      activeCyclists.add(cyclistComp);
      world.add(cyclistComp);
    }

    for (final pf in chunk.pigeonFlocks) {
      final flockComp = PigeonFlockComponent(
        position: Vector2(pf.x, pf.y),
        pigeonCount: pf.pigeonCount,
        groundY: groundY,
      );
      activePigeonFlocks.add(flockComp);
      world.add(flockComp);
    }

    for (final cw in chunk.crosswalks) {
      final crosswalkComp = CrosswalkZoneComponent(
        position: Vector2(cw.x, cw.y),
        width: cw.width,
        groundY: groundY,
        signalCountdown: cw.signalCountdown,
      );
      activeCrosswalks.add(crosswalkComp);
      world.add(crosswalkComp);
    }

    for (final fc in chunk.foodCarts) {
      final cartComp = FoodCartComponent(
        position: Vector2(fc.x, fc.y),
        width: fc.width,
        height: fc.height,
        groundY: groundY,
        bounceImpulse: fc.bounceImpulse,
      );
      activeFoodCarts.add(cartComp);
      world.add(cartComp);
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
        case PickupType.drone:
          sparkColor = const Color(0xFF00E5FF);
          break;
        case PickupType.vipPackage:
          sparkColor = const Color(0xFFFFD700);
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
      case PickupType.drone:
        gameState.activateDrone();
        audio.playMilestone();
        world.add(
          FloatingTextComponent(
            text: 'DRONE DEPLOYED!',
            position: Vector2(player.position.x - 10, player.position.y - 30),
            color: const Color(0xFF00E5FF),
          ),
        );
        break;
      case PickupType.vipPackage:
        gameState.startVipMission();
        audio.playMilestone();
        audio.playCourierBark(CourierBarkType.stunt, line: 'VIP Express incoming! Time to hustle!');
        triggerScreenShake(0.2);
        spawnConfetti(Vector2(player.position.x + 30.0, player.position.y - 20.0), count: 16);
        world.add(
          FloatingTextComponent(
            text: 'VIP EXPRESS DISPATCH! 14s (3X SURGE)',
            position: Vector2(player.position.x - 20, player.position.y - 35),
            color: const Color(0xFFFFD700),
          ),
        );
        break;
    }
  }

  /// Resets the runner for the next shift.
  void restartRun({DailyShift? shift, Set<RunBooster>? equippedBoosters}) {
    if (shift != null) {
      dailyShift = shift;
    }
    if (equippedBoosters != null) {
      activeBoosters = equippedBoosters;
    }

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
    for (final sb in world.children.whereType<SpeechBubbleComponent>().toList()) {
      sb.removeFromParent();
    }
    audio.resetBarkCooldowns();
    activeObstacles.clear();
    activePickups.clear();
    for (final s in activeScaffolding.toList()) {
      s.removeFromParent();
    }
    for (final r in activeRamps.toList()) {
      r.removeFromParent();
    }
    for (final s in world.children.whereType<ScaffoldingComponent>().toList()) {
      s.removeFromParent();
    }
    for (final r in world.children.whereType<RampComponent>().toList()) {
      r.removeFromParent();
    }
    for (final dz in activeDropZones.toList()) {
      dz.removeFromParent();
    }
    for (final dz in world.children.whereType<DropZoneComponent>().toList()) {
      dz.removeFromParent();
    }
    for (final gr in activeGrindRails.toList()) {
      gr.removeFromParent();
    }
    for (final gr in world.children.whereType<GrindRailComponent>().toList()) {
      gr.removeFromParent();
    }
    for (final sv in activeSteamVents.toList()) {
      sv.removeFromParent();
    }
    for (final sv in world.children.whereType<SteamVentComponent>().toList()) {
      sv.removeFromParent();
    }
    for (final st in activeSubwayStations.toList()) {
      st.removeFromParent();
    }
    for (final st in world.children.whereType<SubwayStationComponent>().toList()) {
      st.removeFromParent();
    }
    for (final c in activeCranes.toList()) {
      c.removeFromParent();
    }
    for (final c in world.children.whereType<CraneSwingComponent>().toList()) {
      c.removeFromParent();
    }
    for (final cy in activeCyclists.toList()) {
      cy.removeFromParent();
    }
    for (final cy in world.children.whereType<CyclistCompanionComponent>().toList()) {
      cy.removeFromParent();
    }
    for (final pf in activePigeonFlocks.toList()) {
      pf.removeFromParent();
    }
    for (final pf in world.children.whereType<PigeonFlockComponent>().toList()) {
      pf.removeFromParent();
    }
    for (final cw in activeCrosswalks.toList()) {
      cw.removeFromParent();
    }
    for (final cw in world.children.whereType<CrosswalkZoneComponent>().toList()) {
      cw.removeFromParent();
    }
    for (final fc in activeFoodCarts.toList()) {
      fc.removeFromParent();
    }
    for (final fc in world.children.whereType<FoodCartComponent>().toList()) {
      fc.removeFromParent();
    }
    activeScaffolding.clear();
    activeRamps.clear();
    activeDropZones.clear();
    activeGrindRails.clear();
    activeSteamVents.clear();
    activeSubwayStations.clear();
    activeCranes.clear();
    activeCyclists.clear();
    activePigeonFlocks.clear();
    activeCrosswalks.clear();
    activeFoodCarts.clear();
    cameraTargetY = virtualResolution.y / 2;
    player.endGrinding();
    player.stopGlide();
    if (player.isSwinging) {
      player.state = CourierState.running;
      player.attachedCrane = null;
    }
    player.resetTargetSurfaceY();
    _footstepTimer = 0.0;
    _grindSparkTimer = 0.0;
    _wetHazardsCleared = 0;
    _currentVaultTarget = null;

    for (final m in world.children.whereType<PersonalRecordMarkerComponent>().toList()) {
      m.removeFromParent();
    }
    activePrMarker = null;
    hasSpawnedPrMarker = false;
    hasSurpassedPr = false;
    personalRecordDistance = storage?.highDistance ?? personalRecordDistance;

    if (deliveryDrone != null && deliveryDrone!.isMounted) {
      deliveryDrone!.removeFromParent();
    }
    deliveryDrone = null;
    for (final d in world.children.whereType<DeliveryDroneComponent>().toList()) {
      d.removeFromParent();
    }

    chunkManager.reset();
    weatherController.reset();
    rainComponent.rainIntensity = 0.0;
    audio.updateWeather(0.0);
    cameraJuice.reset();
    final baseCenter = Vector2(virtualResolution.x / 2, virtualResolution.y / 2);
    camera.viewfinder.position = baseCenter;
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.angle = 0.0;
    nextChunkX = 960.0;
    currentSpeed = 200.0;
    parallaxCity.updateLighting(0.0, 0.0, 0.0);

    hasRecordedDailyShiftSuccess = false;
    gameState.startRun(dailyShift: dailyShift, equippedBoosters: activeBoosters);
    if (dailyShift?.modifier == DailyModifier.rainyRush) {
      weatherController.rainIntensity = 0.8;
      rainComponent.rainIntensity = 0.8;
    }
    player.position = Vector2(120.0, groundY - player.size.y);
    player.simulator.currentY = groundY;
    player.simulator.verticalVelocity = 0.0;
    player.simulator.isGrounded = true;
    player.state = CourierState.running;
    player.isBoosted = gameState.isEnergyBoostActive;

    isRunning = true;
    _spawnChunk();
    audio.startMusic();
  }

  @override
  void update(double dt) {
    _isUpdatingTree = true;
    try {
      super.update(dt);
    } finally {
      _isUpdatingTree = false;
    }
    _flushPendingEffects();
    if (!isRunning || gameState.status != GameStatus.running) return;

    // 0. Update active energy drink buff, drone assist, celebration, and stunt combo timers
    gameState.updateEnergyTimer(dt);
    gameState.updateDroneTimer(dt);
    gameState.updateMilestoneTimer(dt);
    gameState.updateContractTimer(dt);
    gameState.updateStuntTimer(dt);
    gameState.updateVipTimer(dt);
    player.isBoosted = gameState.isEnergyBoostActive;

    // 0b. Spawn / mount companion delivery drone if active
    if (gameState.isDroneActive && (deliveryDrone == null || !deliveryDrone!.isMounted)) {
      deliveryDrone = DeliveryDroneComponent(
        game: this,
        position: Vector2(player.position.x + 30.0, player.position.y - 45.0),
      );
      world.add(deliveryDrone!);
    }

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

    // 1. Calculate dynamic scroll speed based on distance (with energy boost, grind surge, and parkour vault surge)
    final speedMultiplier = (gameState.isEnergyBoostActive ? 1.2 : 1.0) *
        (player.isGrinding ? 1.20 : 1.0) *
        (player.isVaulting ? 1.25 : 1.0) *
        (player.isDrafting ? 1.20 : 1.0);
    currentSpeed = chunkManager.calculateSpeed(gameState.distanceMeters) * speedMultiplier;
    audio.updateSpeed(currentSpeed);

    // 2. Advance meter progress (20 px = 1 meter)
    final distanceDelta = (currentSpeed * dt) / 20.0;
    gameState.updateDistance(gameState.distanceMeters + distanceDelta);
    if (player.isGliding) {
      player.glideDistance += distanceDelta;
    }

    // 2a. Evaluate distance achievements at key milestones
    if ((gameState.distanceMeters >= 500.0 && !achievementManager.isUnlocked('first_delivery')) ||
        (gameState.distanceMeters >= 2500.0 && !achievementManager.isUnlocked('shift_veteran'))) {
      _evaluateAchievements();
    }

    // 2c. Evaluate Personal Record (PR) Holographic Sidewalk Marker Spawning
    if (!hasSpawnedPrMarker && personalRecordDistance >= 100) {
      final remainingMeters = personalRecordDistance - gameState.distanceMeters;
      // Spawn when milestone is within 45m ahead (~900px, entering horizon)
      if (remainingMeters <= 45.0 && remainingMeters > -5.0) {
        final spawnX = player.position.x + (remainingMeters * 20.0);
        final marker = PersonalRecordMarkerComponent(
          prDistance: personalRecordDistance,
          position: Vector2(spawnX, groundY - 80.0),
        );
        activePrMarker = marker;
        hasSpawnedPrMarker = true;
        world.add(marker);
      }
    }

    // 2b. Advance dynamic weather simulation
    weatherController.update(gameState.distanceMeters);
    rainComponent.rainIntensity = weatherController.rainIntensity;
    rainComponent.horizontalScrollSpeed = currentSpeed;
    audio.updateWeather(weatherController.rainIntensity);

    // 3. Update parallax city velocity & dynamic environment lighting
    parallaxCity.speedMultiplier = currentSpeed / 200.0;
    parallaxCity.updateLighting(
      gameState.distanceMeters,
      dt,
      weatherController.rainIntensity,
    );

    // 3b. Update camera trauma shake, velocity framing zoom, and vertical aerial tracking
    cameraJuice.update(dt, currentSpeed: currentSpeed);
    final targetCameraY = (player.isElevated || player.isGrinding || player.isGliding)
        ? (virtualResolution.y / 2) - 35.0
        : (virtualResolution.y / 2);
    cameraTargetY += (targetCameraY - cameraTargetY) * (3.0 * dt).clamp(0.0, 1.0);
    camera.viewfinder.position = Vector2(
      (virtualResolution.x / 2) + cameraJuice.shakeOffset.x,
      cameraTargetY + cameraJuice.shakeOffset.y,
    );
    camera.viewfinder.zoom = cameraJuice.currentZoom;
    camera.viewfinder.angle = cameraJuice.shakeAngle;

    // 4. Scroll active hazards, pickups, scaffolding, ramps, and PR marker leftward
    final scrollDelta = currentSpeed * dt;
    nextChunkX -= scrollDelta;

    for (final o in activeObstacles) {
      o.position.x -= scrollDelta;
    }
    for (final p in activePickups) {
      p.position.x -= scrollDelta;
    }
    for (final s in activeScaffolding) {
      s.position.x -= scrollDelta;
    }
    for (final r in activeRamps) {
      r.position.x -= scrollDelta;
    }
    for (final dz in activeDropZones) {
      dz.position.x -= scrollDelta;
    }
    for (final gr in activeGrindRails) {
      gr.position.x -= scrollDelta;
    }
    for (final sv in activeSteamVents) {
      sv.position.x -= scrollDelta;
    }
    for (final c in activeCranes) {
      c.position.x -= scrollDelta;
    }
    for (final cy in activeCyclists) {
      cy.position.x -= scrollDelta;
    }
    for (final pf in activePigeonFlocks) {
      pf.position.x -= scrollDelta;
    }
    for (final cw in activeCrosswalks) {
      cw.position.x -= scrollDelta;
    }
    for (final fc in activeFoodCarts) {
      fc.position.x -= scrollDelta;
    }
    if (activePrMarker != null) {
      activePrMarker!.position.x -= scrollDelta;
    }

    // 4b. Evaluate Personal Record (PR) Surpass Celebration
    if (activePrMarker != null && !activePrMarker!.hasBeenSurpassed) {
      if (player.position.x >= activePrMarker!.position.x) {
        activePrMarker!.hasBeenSurpassed = true;
        hasSurpassedPr = true;
        _handlePersonalRecordSurpassed(activePrMarker!);
      }
    }

    // 4c. Evaluate Daily Shift Goal Celebration
    if (gameState.isDailyShiftActive &&
        gameState.hasCompletedDailyShiftInRun &&
        !hasRecordedDailyShiftSuccess) {
      hasRecordedDailyShiftSuccess = true;
      audio.playMilestone();
      triggerScreenShake(0.4);
      addEffect(
        FloatingTextComponent(
          text: 'DAILY SHIFT COMPLETED! +\$${gameState.activeDailyShift!.completionBonusTips}',
          position: Vector2(player.position.x - 20, player.position.y - 40),
          color: const Color(0xFFF1C40F),
        ),
      );
      spawnConfetti(Vector2(virtualResolution.x / 2, 80), count: 30);
      storage?.completeDailyShift(
        dateString: gameState.activeDailyShift!.dateString,
        bonusTips: gameState.activeDailyShift!.completionBonusTips,
      );
    }

    // 4d. Evaluate Ramp Launch Catapult
    for (final r in activeRamps) {
      if (!r.hasLaunched && r.checkCollisionWith(player)) {
        r.hasLaunched = true;
        player.launchFromRamp(impulse: r.launchImpulse);
        audio.playJump();
        triggerScreenShake(0.2);
        spawnSparkles(
          Vector2(r.position.x + (r.size.x / 2), r.position.y),
          color: const Color(0xFFF1C40F),
          count: 12,
        );
        addEffect(
          FloatingTextComponent(
            text: 'RAMP BOOST!',
            position: Vector2(player.position.x - 10, player.position.y - 30),
            color: const Color(0xFFFF9F43),
          ),
        );
      }
    }

    // 4e. Evaluate Elevated Scaffolding Support under Player Footprint
    final courierFootX = player.position.x + (player.size.x / 2);
    final courierFootY = player.simulator.currentY;
    ScaffoldingComponent? supportingScaffolding;
    for (final s in activeScaffolding) {
      if (courierFootX >= s.position.x && courierFootX <= s.position.x + s.size.x) {
        if (courierFootY <= s.surfaceY + 16.0) {
          supportingScaffolding = s;
          break;
        }
      }
    }

    // 4f. Evaluate Grind Rail Surface Attachment, Sparks, and Dismount
    GrindRailComponent? supportingRail;
    for (final gr in activeGrindRails) {
      if (gr.checkCollisionWith(player) ||
          (player.isGrinding && courierFootX >= gr.position.x && courierFootX <= gr.position.x + gr.size.x)) {
        supportingRail = gr;
        break;
      }
    }

    if (supportingRail != null) {
      if (!player.isGrinding) {
        player.startGrinding(supportingRail.surfaceY);
        audio.playCoin();
        triggerScreenShake(0.15);
        spawnSparkles(
          Vector2(courierFootX, supportingRail.surfaceY),
          color: const Color(0xFFF1C40F),
          count: 10,
        );
      } else {
        player.grindDistance += distanceDelta;
        _grindSparkTimer += dt;
        if (_grindSparkTimer >= 0.05) {
          _grindSparkTimer = 0.0;
          spawnSparkles(
            Vector2(player.position.x + 10.0, supportingRail.surfaceY - 2.0),
            color: const Color(0xFFFF9F43),
            count: 3,
          );
        }
      }
    } else if (player.isGrinding) {
      // Clean dismount off rail trailing edge!
      final meters = player.grindDistance;
      player.endGrinding();
      player.resetTargetSurfaceY();
      _grindSparkTimer = 0.0;

      final event = gameState.recordRailClear(grindDistanceMeters: meters);
      if (event != null) {
        audio.playCoin();
        triggerScreenShake(0.15);
        addEffect(
          FloatingTextComponent(
            text: 'RAIL CLEAR! +\$${event.bonusTips}',
            position: Vector2(player.position.x - 10.0, player.position.y - 30.0),
            color: const Color(0xFFF1C40F),
          ),
        );
        spawnSparkles(
          Vector2(courierFootX, groundY - 30.0),
          color: const Color(0xFF00E5FF),
          count: 8,
        );
      }
    } else if (supportingScaffolding != null) {
      player.setTargetSurfaceY(supportingScaffolding.surfaceY);
    } else {
      player.resetTargetSurfaceY();
    }

    // 4g. Evaluate Customer Doorstep Delivery Drop-offs
    for (final dz in activeDropZones) {
      if (!dz.hasDelivered && dz.checkCollisionWith(player)) {
        dz.hasDelivered = true;
        if (dz.isVip || gameState.isVipMissionActive) {
          final event = gameState.recordVipDelivery();
          if (event != null) {
            audio.playMilestone();
            audio.playCustomerReaction(CustomerReactionType.fiveStars);
            triggerScreenShake(0.25);
            spawnSparkles(
              Vector2(dz.position.x + (dz.size.x / 2), dz.position.y + dz.size.y - 10.0),
              color: const Color(0xFFFFD700),
              count: 24,
            );
            spawnConfetti(
              Vector2(dz.position.x + (dz.size.x / 2), dz.position.y - 20.0),
              count: 20,
            );

            final multStr = '${event.multiplier.toStringAsFixed(1)}x';
            addEffect(
              FloatingTextComponent(
                text: 'VIP EXPRESS DELIVERED! ★★★★★ ($multStr) +\$${event.totalTips}',
                position: Vector2(player.position.x - 20.0, player.position.y - 45.0),
                color: const Color(0xFFFFD700),
              ),
            );

            audio.playCourierBark(CourierBarkType.stunt, line: 'VIP delivery secured!');
            storage?.recordDeliveries(1);
          }
        } else {
          final event = gameState.recordDoorstepDelivery(
            speedMultiplier: currentSpeed / 200.0,
          );
          if (event != null) {
            audio.playCoin();
            if (event.ratingStars >= 5) {
              audio.playCustomerReaction(CustomerReactionType.fiveStars);
            } else {
              audio.playCustomerReaction(CustomerReactionType.thankYou);
            }
            triggerScreenShake(0.15);
            spawnSparkles(
              Vector2(dz.position.x + (dz.size.x / 2), dz.position.y + dz.size.y - 10.0),
              color: const Color(0xFFF1C40F),
              count: 14,
            );

            final stars = '★' * event.ratingStars;
            final streakMsg = event.streak > 1 ? '${event.streak}x STREAK ' : '';
            addEffect(
              FloatingTextComponent(
                text: '$stars $streakMsg+\$${event.totalTips}',
                position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
                color: const Color(0xFFF1C40F),
              ),
            );

            if (event.didRestockPackage) {
              audio.playMilestone();
              addEffect(
                FloatingTextComponent(
                  text: '3x STREAK RESTOCK! +1 PKG',
                  position: Vector2(player.position.x - 10.0, player.position.y - 55.0),
                  color: const Color(0xFF2ECC71),
                ),
              );
            }

            storage?.recordDeliveries(1);
          }
        }
      }
    }

    // 4h. Evaluate Thermal Steam Vent Updraft Column Contact
    for (final sv in activeSteamVents) {
      if (sv.isInUpdraft(player.position, player.size)) {
        player.simulator.applyUpdraft(sv.updraftVelocity);
        if (!sv.hasTriggeredBoost) {
          sv.hasTriggeredBoost = true;
          audio.playJump();
          audio.playCourierBark(CourierBarkType.stunt);
          triggerScreenShake(0.2);
          spawnSparkles(
            Vector2(sv.position.x + (sv.size.x / 2), sv.position.y),
            color: const Color(0xFF00E5FF),
            count: 12,
          );
          final event = gameState.recordSteamVentBoost();
          if (event != null) {
            final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
            addEffect(
              FloatingTextComponent(
                text: 'STEAM BOOST! $multStr+\$${event.totalTips}',
                position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
                color: const Color(0xFF00E5FF),
              ),
            );
          }
          _evaluateAchievements();
        }
      }
    }

    // 4i. Evaluate Subterranean Subway Tunnel Station Entry
    for (final st in activeSubwayStations) {
      if (!st.hasTriggeredTransit && player.position.x >= st.position.x) {
        st.hasTriggeredTransit = true;
        final event = gameState.recordSubwayTransit(stationName: st.stationName);
        if (event != null) {
          audio.playMilestone();
          audio.playCourierBark(CourierBarkType.stunt, line: 'Subway shortcut!');
          triggerScreenShake(0.15);
          spawnSparkles(
            Vector2(st.position.x + 40.0, groundY - 60.0),
            color: const Color(0xFF2980B9),
            count: 14,
          );
          final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
          addEffect(
            FloatingTextComponent(
              text: 'SUBWAY: ${event.stationName}! $multStr+\$${event.totalTips}',
              position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
              color: const Color(0xFF00E5FF),
            ),
          );
        }
      }
    }

    // 4j. Evaluate Industrial Construction Crane Swing Traversal
    if (!player.isSwinging) {
      if (!player.simulator.isGrounded && player.state != CourierState.hurt) {
        for (final c in activeCranes) {
          if (c.canGrabHook(player.position, player.size)) {
            player.attachToCrane(c);
            audio.playJump();
            triggerScreenShake(0.15);
            spawnSparkles(
              c.hookPosition,
              color: const Color(0xFF00E5FF),
              count: 12,
            );
            break;
          }
        }
      }
    } else if (player.attachedCrane != null) {
      final crane = player.attachedCrane!;
      // Auto-release at forward apex crest (+0.62 rad) or if swing reverses
      if (crane.swingAngle >= 0.62 || (crane.swingAngle > 0.32 && crane.angularVelocity < -0.12)) {
        player.releaseCraneSwing();
      }
    }

    // 4k. Evaluate Cyclist Companion Aerodynamic Slipstream Drafting
    CyclistCompanionComponent? draftingCyclist;
    for (final c in activeCyclists) {
      if (c.isPlayerInDraftZone(player.position, player.size)) {
        draftingCyclist = c;
        break;
      }
    }
    if (draftingCyclist != null) {
      if (!player.isDrafting) {
        player.isDrafting = true;
        audio.playCourierBark(CourierBarkType.stunt, line: 'On your wheel!');
        spawnSparkles(
          Vector2(player.position.x + 20.0, player.position.y + player.size.y - 10.0),
          color: const Color(0xFF00E5FF),
          count: 8,
        );
      }
      draftingCyclist.isPlayerDrafting = true;
      draftingCyclist.playerDraftDuration += dt;
      gameState.totalDraftDurationInRun += dt;
      gameState.setDrafting(true);
    } else {
      if (player.isDrafting) {
        player.isDrafting = false;
      }
      for (final c in activeCyclists) {
        c.isPlayerDrafting = false;
      }
      gameState.setDrafting(false);
    }

    // 4l. Evaluate Urban Pigeon Flock Scatter & Mid-Air Leap Stunt
    for (final pf in activePigeonFlocks) {
      if (!pf.isScattered) {
        pf.checkProximity(player.position, player.size);
        if (pf.isScattered) {
          audio.playCourierBark(CourierBarkType.stunt, line: 'Out of the way, pigeons!');
          spawnFeathers(
            Vector2(pf.position.x + (pf.size.x / 2), pf.position.y + 10.0),
            count: 14,
          );
        }
      }
      if (pf.checkCourierIntersection(player.position, player.size)) {
        _handlePigeonScatter(pf);
      }
    }

    // 4m. Evaluate Urban Street Crosswalk Sprint-by High-Fives
    for (final cw in activeCrosswalks) {
      if (!cw.isHighFived && cw.checkHighFiveProximity(player.position, player.size)) {
        _handleHighFive(cw);
      }
    }

    // 4n. Evaluate Street Food Cart Umbrella Bounce Cushions
    for (final fc in activeFoodCarts) {
      if (fc.checkBounce(player.position, player.size, player.simulator)) {
        _handleFoodCartBounce(fc);
      }
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
    activeScaffolding.removeWhere((s) {
      if (s.shouldRecycle || s.isRemoved) {
        if (s.isMounted) s.removeFromParent();
        return true;
      }
      return false;
    });
    activeRamps.removeWhere((r) {
      if (r.shouldRecycle || r.isRemoved) {
        if (r.isMounted) r.removeFromParent();
        return true;
      }
      return false;
    });
    activeDropZones.removeWhere((dz) {
      if (dz.shouldRecycle || dz.isRemoved) {
        if (dz.isMounted) dz.removeFromParent();
        return true;
      }
      return false;
    });
    activeGrindRails.removeWhere((gr) {
      if (gr.shouldRecycle || gr.isRemoved) {
        if (gr.isMounted) gr.removeFromParent();
        return true;
      }
      return false;
    });
    activeSteamVents.removeWhere((sv) {
      if (sv.shouldRecycle || sv.isRemoved) {
        if (sv.isMounted) sv.removeFromParent();
        return true;
      }
      return false;
    });
    activeSubwayStations.removeWhere((st) {
      if (st.shouldRecycle || st.isRemoved) {
        if (st.isMounted) st.removeFromParent();
        return true;
      }
      return false;
    });
    activeCranes.removeWhere((c) {
      if (c.shouldRecycle || c.isRemoved) {
        if (c.isMounted) c.removeFromParent();
        return true;
      }
      return false;
    });
    activeCyclists.removeWhere((c) {
      if (c.shouldRecycle || c.isRemoved) {
        if (c.isMounted) c.removeFromParent();
        return true;
      }
      return false;
    });
    activePigeonFlocks.removeWhere((pf) {
      if (pf.shouldRecycle || pf.isRemoved) {
        if (pf.isMounted) pf.removeFromParent();
        return true;
      }
      return false;
    });
    activeCrosswalks.removeWhere((cw) {
      if (cw.shouldRecycle || cw.isRemoved) {
        if (cw.isMounted) cw.removeFromParent();
        return true;
      }
      return false;
    });
    activeFoodCarts.removeWhere((fc) {
      if (fc.shouldRecycle || fc.isRemoved) {
        if (fc.isMounted) fc.removeFromParent();
        return true;
      }
      return false;
    });
    if (activePrMarker != null && activePrMarker!.shouldRecycle) {
      if (activePrMarker!.isMounted) {
        activePrMarker!.removeFromParent();
      }
      activePrMarker = null;
    }
    for (final fx in world.children.whereType<ParticleEffectComponent>().toList()) {
      if (fx.isFinished) {
        fx.removeFromParent();
      }
    }
    for (final ft in world.children.whereType<FloatingTextComponent>().toList()) {
      if (ft.isFinished) {
        ft.removeFromParent();
      }
    }
    for (final sb in world.children.whereType<SpeechBubbleComponent>().toList()) {
      if (sb.isFinished) {
        sb.removeFromParent();
      }
    }

    // 7. Spawn next procedural chunk when horizon approaches
    if (nextChunkX <= virtualResolution.x + 480.0) {
      _spawnChunk();
    }

    _flushPendingEffects();
  }

  void _handleNearMiss(ObstacleComponent obstacle, double clearance) {
    gameState.recordStunt(clearance: clearance);
    audio.playCoin();
    audio.playCourierBark(CourierBarkType.nearMiss);

    // Floating score popup above courier
    final multiplierStr = gameState.stuntMultiplier > 1.0 ? '${gameState.stuntMultiplier}x ' : '';
    addEffect(
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

    if (weatherController.isRaining) {
      _wetHazardsCleared++;
    }
    _evaluateAchievements();
  }

  void _handleRailOllie() {
    final event = gameState.recordRailOllie(
      grindDistanceMeters: player.grindDistance,
    );
    if (event != null) {
      audio.playMilestone();
      audio.playCourierBark(CourierBarkType.stunt);
      triggerScreenShake(0.3);

      spawnSparkles(
        Vector2(player.position.x + (player.size.x / 2), player.position.y + player.size.y),
        color: const Color(0xFFFF9F43),
        count: 14,
      );

      final multiplierStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'RAIL OLLIE! $multiplierStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );

      _evaluateAchievements();
    }
  }

  bool _canVaultObstacleAhead() {
    final courierFrontX = player.position.x + player.size.x;
    final courierFootY = player.simulator.currentY;

    final obstaclesToCheck = activeObstacles.isNotEmpty
        ? activeObstacles
        : world.children.whereType<ObstacleComponent>();

    for (final obs in obstaclesToCheck) {
      if (!obs.isVaultable || obs.hasBeenVaulted || obs.hasCollidedWithPlayer) {
        continue;
      }
      final dist = obs.position.x - courierFrontX;
      // Approach window: -16.0px (just reaching/overlapping) to 68.0px ahead
      if (dist >= -16.0 && dist <= 68.0) {
        final groundDiff = (courierFootY - (obs.position.y + obs.size.y)).abs();
        if (groundDiff <= 20.0) {
          _currentVaultTarget = obs;
          return true;
        }
      }
    }
    _currentVaultTarget = null;
    return false;
  }

  void _handleParkourVault() {
    final target = _currentVaultTarget;
    if (target != null) {
      target.hasBeenVaulted = true;
    }
    audio.playJump();
    audio.playCourierBark(CourierBarkType.stunt);
    triggerScreenShake(0.18);

    final plantX = target != null
        ? target.position.x + (target.size.x / 2)
        : player.position.x + player.size.x;
    final plantY = target != null ? target.position.y : player.position.y + player.size.y - 20;

    spawnSparkles(
      Vector2(plantX, plantY),
      color: const Color(0xFF00E5FF),
      count: 12,
    );

    final event = gameState.recordVault(
      obstacleType: target?.type ?? ObstacleType.hydrant,
    );

    if (event != null) {
      final multiplierStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'PARKOUR VAULT! $multiplierStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
    }

    _evaluateAchievements();
  }

  void _handleGlideStarted() {
    audio.playJump();
    audio.playCourierBark(CourierBarkType.glide);
    triggerScreenShake(0.10);
    spawnSparkles(
      Vector2(player.position.x + (player.size.x / 2), player.position.y - 8.0),
      color: const Color(0xFFFF9F43),
      count: 8,
    );
  }

  void _handleGlideEnded() {
    final meters = player.glideDistance;
    if (meters >= 5.0) {
      final event = gameState.recordGlide(glideDistanceMeters: meters);
      if (event != null) {
        audio.playCoin();
        triggerScreenShake(0.15);
        final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
        addEffect(
          FloatingTextComponent(
            text: 'GLIDE! ${meters.toStringAsFixed(0)}m $multStr+\$${event.totalTips}',
            position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
            color: const Color(0xFFFF9F43),
          ),
        );
        _evaluateAchievements();
      }
    }
  }

  void _handleCraneLaunch(double swingAngle) {
    final event = gameState.recordCraneSwing(swingAngle: swingAngle);
    if (event != null) {
      audio.playMilestone();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Catch you on the flip side!');
      triggerScreenShake(0.3);
      spawnSparkles(
        Vector2(player.position.x + (player.size.x / 2), player.position.y),
        color: const Color(0xFFF1C40F),
        count: 16,
      );

      final multiplierStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'CRANE SWING! $multiplierStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFFF1C40F),
        ),
      );

      _evaluateAchievements();
    }
  }

  void _handleDraftSlingshot() {
    final event = gameState.recordDraftSlingshot();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Slingshot launch!');
      triggerScreenShake(0.2);
      spawnSparkles(
        Vector2(player.position.x + 30.0, player.position.y),
        color: const Color(0xFF00E5FF),
        count: 14,
      );
      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'SLINGSHOT BOOST! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handlePigeonScatter(PigeonFlockComponent flock) {
    final event = gameState.recordPigeonScatter();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Scram!');
      triggerScreenShake(0.18);
      spawnFeathers(
        Vector2(player.position.x + (player.size.x / 2), player.position.y),
        count: 16,
      );
      spawnSparkles(
        Vector2(player.position.x + (player.size.x / 2), player.position.y),
        color: const Color(0xFF80CBC4),
        count: 12,
      );
      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'FLOCK SCATTER! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF80CBC4),
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleHighFive(CrosswalkZoneComponent cw) {
    final event = gameState.recordHighFive();
    if (event != null) {
      audio.playCoin();
      audio.playCustomerReaction(CustomerReactionType.fiveStars, line: 'Awesome pace!');
      triggerScreenShake(0.16);
      spawnSparkles(
        cw.handWorldPosition,
        color: const Color(0xFFFFD700),
        count: 14,
      );
      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'HIGH FIVE! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFFFFD700),
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleFoodCartBounce(FoodCartComponent fc) {
    final event = gameState.recordFoodCartBounce();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Spicy bounce!');
      triggerScreenShake(0.20);
      spawnSpiceCloud(fc.umbrellaApexWorld, count: 18);
      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'SPICY BOUNCE! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFFFF9800),
        ),
      );
      _evaluateAchievements();
    }
  }

  void _evaluateAchievements() {
    achievementManager.evaluateProgress(
      distanceMeters: gameState.distanceMeters,
      stuntCombo: gameState.stuntMultiplier.round(),
      lifetimeContracts: gameState.contractManager.completedCount,
      lifetimeCareerTips: gameState.tips + gameState.contractManager.totalBonusTips,
      wetHazardsCleared: _wetHazardsCleared,
    );
  }

  void _handlePersonalRecordSurpassed(PersonalRecordMarkerComponent marker) {
    audio.playMilestone();
    triggerScreenShake(0.35);

    // Floating celebratory banner above courier
    addEffect(
      FloatingTextComponent(
        text: 'NEW RECORD! ${marker.prDistance}m BEATEN!',
        position: Vector2(player.position.x - 10, player.position.y - 30),
        color: const Color(0xFFF1C40F),
      ),
    );

    // Gold sparkle burst at marker apex
    spawnSparkles(
      Vector2(marker.position.x + (marker.size.x / 2), marker.position.y + 10),
      color: const Color(0xFFF1C40F),
      count: 18,
    );

    // Horizon celebratory confetti shower
    spawnConfetti(Vector2(virtualResolution.x / 2, 80), count: 25);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isRunning && gameState.status == GameStatus.running) {
      if (!player.jump()) {
        player.toggleGlide();
      }
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
          if (!player.jump()) {
            player.toggleGlide();
          }
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
