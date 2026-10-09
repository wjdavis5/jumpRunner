import 'dart:math' as math;
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'audio_controller.dart';
import '../services/storage_service.dart';
import 'components/ac_condenser_component.dart';
import 'components/barricade_sawhorse_component.dart';
import 'components/courier_player.dart';
import 'components/coach_hint_component.dart';
import 'components/crane_swing_component.dart';
import 'components/crosswalk_zone_component.dart';
import 'components/cyclist_companion_component.dart';
import 'components/delivery_drone_component.dart';
import 'components/drone_cargo_component.dart';
import 'components/drop_zone_component.dart';
import 'components/fire_escape_ladder_component.dart';
import 'components/floating_text_component.dart';
import 'components/food_cart_component.dart';
import 'components/food_truck_slick_component.dart';
import 'components/glass_skylight_component.dart';
import 'components/flower_kiosk_component.dart';
import 'components/water_tower_component.dart';
import 'components/newsstand_component.dart';
import 'components/cafe_bistro_component.dart';
import 'components/street_busker_component.dart';
import 'components/fire_hydrant_component.dart';
import 'components/clothesline_component.dart';
import 'components/subway_exhaust_grate_component.dart';
import 'components/catenary_zipline_component.dart';
import 'components/bus_shelter_component.dart';
import 'components/security_shutter_component.dart';
import 'components/cement_mixer_component.dart';
import 'components/lightning_flash_component.dart';
import 'components/grind_rail_component.dart';
import 'components/hvac_wind_tunnel_component.dart';
import 'components/obstacle_component.dart';
import 'components/parallax_city.dart';
import 'components/particle_effect.dart';
import 'components/pickup_component.dart';
import 'components/pigeon_flock_component.dart';
import 'components/postal_mailbox_component.dart';
import 'components/pr_marker_component.dart';
import 'components/puddle_component.dart';
import 'components/rain_component.dart';
import 'components/ramp_component.dart';
import 'components/satellite_dish_component.dart';
import 'components/scaffolding_component.dart';
import 'components/speech_bubble_component.dart';
import 'components/solar_panel_component.dart';
import 'components/steam_vent_component.dart';
import 'components/storm_drain_component.dart';
import 'components/subway_station_component.dart';
import 'components/subway_turnstile_component.dart';
import 'logic/achievement_manager.dart';
import 'logic/camera_juice_controller.dart';
import 'logic/death_slowmo_controller.dart';
import 'logic/game_haptics.dart';
import 'logic/game_state.dart';
import 'logic/input_hints.dart';
import 'logic/press_hold_recognizer.dart';
import 'logic/qa_flags.dart';
import 'logic/weather_controller.dart';
import 'logic/world_chunk_manager.dart';
import 'models/courier_skin.dart';
import 'models/daily_shift.dart';
import 'models/run_booster.dart';
import '../ui/money.dart';

/// Main Flame game loop for Courier Dash.
///
/// Features a fixed 16:9 virtual resolution of 960x540 with letterboxing,
/// collision detection, continuous parallax city scrolling, procedural obstacle/pickup spawning,
/// low-latency audio integration, and responsive courier jumping controls.
class CourierGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  CourierGame({
    GameState? gameState,
    GameAudioController? audioController,
    WorldChunkManager? chunkManager,
    WeatherController? weatherController,
    CameraJuiceController? cameraJuiceController,
    DeathSlowmoController? deathSlowmoController,
    AchievementManager? achievementManager,
    LocalStorageService? storageService,
    GameHaptics? haptics,
    int? personalRecordDistance,
    CourierSkin? initialSkin,
    Set<RunBooster>? initialBoosters,
    this.dailyShift,
  })  : gameState = gameState ?? GameState(),
        audio = audioController ?? GameAudioController(),
        chunkManager = chunkManager ?? WorldChunkManager(random: QaFlags.streetRandom),
        weatherController = weatherController ?? WeatherController(),
        cameraJuice = cameraJuiceController ?? CameraJuiceController(),
        deathSlowmo = deathSlowmoController ?? DeathSlowmoController(),
        achievementManager = achievementManager ?? AchievementManager(),
        storage = storageService,
        haptics = haptics ?? GameHaptics(enabled: storageService?.isHapticsEnabled ?? true),
        personalRecordDistance = personalRecordDistance ?? storageService?.highDistance ?? 0,
        activeSkin = initialSkin ?? CourierSkin.standard,
        activeBoosters = initialBoosters ?? const {},
        super(
          camera: CameraComponent.withFixedResolution(
            width: virtualResolution.x,
            height: virtualResolution.y,
          )..viewfinder.anchor = Anchor.center
           ..viewfinder.position = Vector2(virtualResolution.x / 2, virtualResolution.y / 2),
        ) {
    // Touches reach the game as a press and a release, not as taps: see
    // [PressHoldGestureRecognizer] for why a tap recognizer will not do.
    gestureDetectors.register<PressHoldGestureRecognizer>(
      PressHoldGestureRecognizer.new,
      (PressHoldGestureRecognizer recognizer) {
        recognizer.onPress = holdJump;
        recognizer.onRelease = letGoOfJump;
      },
    );
  }

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

  /// The widest stretch of street the game will show: a 2.4:1 screen.
  static const double maxVisibleWidth = 1296.0;

  /// Width of the street in view, in the same units as [virtualResolution].
  ///
  /// 960 on a 16:9 screen. A wider phone sees further ahead rather than
  /// getting black bars at the sides; the left edge and the courier stay
  /// where they are. Screens narrower than 16:9 are letterboxed as before.
  double visibleWidth = virtualResolution.x;

  /// Street width shown on a screen of [screen] size.
  static double visibleWidthFor(Vector2 screen) {
    if (screen.x <= 0 || screen.y <= 0) return virtualResolution.x;
    final width = virtualResolution.y * screen.x / screen.y;
    return width.clamp(virtualResolution.x, maxVisibleWidth).roundToDouble();
  }

  @override
  void onGameResize(Vector2 size) {
    final width = visibleWidthFor(size);
    if (width != visibleWidth) {
      visibleWidth = width;
      camera.viewport = FixedResolutionViewport(
        resolution: Vector2(width, virtualResolution.y),
      );
      _applyVisibleWidth();
    }
    super.onGameResize(size);
  }

  bool _backdropReady = false;

  /// Fits the backdrop layers and the resting camera to [visibleWidth].
  void _applyVisibleWidth() {
    if (_backdropReady) {
      parallaxCity.viewWidth = visibleWidth;
      rainComponent.size.x = visibleWidth;
      lightningComponent.size.x = visibleWidth;
    }
    if (!deathSlowmo.isActive) {
      camera.viewfinder.position = Vector2(visibleWidth / 2, cameraTargetY);
    }
  }

  /// Ground surface baseline Y coordinate in virtual coordinates.
  static const double groundY = 460.0;

  final GameState gameState;
  final GameAudioController audio;
  final WorldChunkManager chunkManager;
  final WeatherController weatherController;
  final CameraJuiceController cameraJuice;
  final DeathSlowmoController deathSlowmo;
  final AchievementManager achievementManager;
  final LocalStorageService? storage;

  /// Vibration on hits, the end of a shift and milestones.
  final GameHaptics haptics;
  DailyShift? dailyShift;

  int personalRecordDistance;
  PersonalRecordMarkerComponent? activePrMarker;
  bool hasSpawnedPrMarker = false;
  bool hasSurpassedPr = false;
  bool hasRecordedDailyShiftSuccess = false;
  DeliveryDroneComponent? deliveryDrone;
  CoachHintComponent? firstRunCoach;

  /// The "hold to leap" hint riding above the first van of a novice's shift.
  CoachHintComponent? leapCoach;

  /// A courier whose record is under this many meters still gets the leap
  /// hint: they have barely met a van, if at all.
  static const int leapCoachUntilRecordMeters = 400;

  /// The hint floating over the courier the first time a novice's chute
  /// opens. A press in mid-air opens it, often by accident, and nothing else
  /// says what happened or how to come down.
  CoachHintComponent? glideCoach;

  /// How far above the courier's head a speech bubble starts.
  static const double speechLift = 42.0;

  /// The same while gliding: the open chute sits where the bubble would, so
  /// the bubble starts above the canopy instead of on top of it.
  static const double speechLiftGliding = 66.0;

  bool _glideCoachShownThisRun = false;

  /// The leap hint appears once its van is about to enter the screen.
  static const double leapCoachLeadPixels = 40.0;

  bool _leapCoachShownThisRun = false;

  /// The same hint over the first subway train of a novice's shift. A train
  /// needs the held leap as much as a van does, and a shift that has
  /// already met a van still gets it: nothing says a train is like a van.
  CoachHintComponent? trainCoach;
  bool _trainCoachShownThisRun = false;

  /// "Run under the birds" over the first flock of pigeons in a shift, for a
  /// courier's first [pigeonCoachShifts] shifts that meet one. Pigeons turn
  /// up from 800 m, long after a courier stops being a novice, and they
  /// are the one hazard where the habit that works everywhere else (when
  /// in doubt, hold the jump) is the only way to be hit.
  CoachHintComponent? pigeonCoach;
  bool _pigeonCoachShownThisRun = false;
  int _pigeonCoachShiftsUnsaved = 0;

  /// In how many shifts the pigeon hint is shown before it stops.
  static const int pigeonCoachShifts = 3;

  /// How far above the street the pigeon hint rides.
  static const double pigeonCoachHeight = 250.0;

  int _wetHazardsCleared = 0;

  late final ParallaxCityComponent parallaxCity;
  late final RainComponent rainComponent;
  late final LightningFlashComponent lightningComponent;
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
  final List<StormDrainComponent> activeStormDrains = [];
  final List<SolarPanelComponent> activeSolarPanels = [];
  final List<PuddleComponent> activePuddles = [];
  final List<HvacWindTunnelComponent> activeWindTunnels = [];
  final List<SubwayTurnstileComponent> activeTurnstiles = [];
  final List<DroneCargoComponent> activeDroneCargos = [];
  final List<FireEscapeLadderComponent> activeFireEscapes = [];
  final List<FoodTruckSlickComponent> activeFoodTruckSlicks = [];
  final List<BarricadeSawhorseComponent> activeBarricades = [];
  final List<SatelliteDishComponent> activeSatelliteDishes = [];
  final List<PostalMailboxComponent> activeMailboxes = [];
  final List<AcCondenserComponent> activeAcCondensers = [];
  final List<GlassSkylightComponent> activeGlassSkylights = [];
  final List<FlowerKioskComponent> activeFlowerKiosks = [];
  final List<WaterTowerComponent> activeWaterTowers = [];
  final List<NewsstandComponent> activeNewsstands = [];
  final List<CafeBistroComponent> activeCafeBistros = [];
  final List<StreetBuskerComponent> activeStreetBuskers = [];
  final List<FireHydrantComponent> activeFireHydrants = [];
  final List<ClotheslineComponent> activeClotheslines = [];
  final List<SubwayExhaustGrateComponent> activeSubwayExhaustGrates = [];
  final List<CatenaryZiplineComponent> activeCatenaryZiplines = [];
  final List<BusShelterComponent> activeBusShelters = [];
  final List<SecurityShutterComponent> activeSecurityShutters = [];

  /// Construction cement mixers currently riding the street.
  final List<CementMixerComponent> activeCementMixers = [];
  SolarPanelComponent? _activeSolarPanel;
  GrindRailComponent? _activeGrindRail;
  double _solarSparkTimer = 0.0;
  double _ziplineSparkTimer = 0.0;
  ObstacleComponent? _currentVaultTarget;
  double cameraTargetY = 270.0;
  double _grindSparkTimer = 0.0;

  /// The daily shift modifier in force for the current run, if any.
  DailyModifier? get _dailyModifier => gameState.activeDailyShift?.modifier;

  /// Rain held for the whole of a Rainy Rush shift.
  static const double rainyRushIntensity = 0.8;

  /// Rainy Rush promises "1.2x courier speed".
  static const double rainyRushSpeedMultiplier = 1.2;

  /// Point in the day cycle used to light a Neon Midnight shift: deep night.
  static const double neonMidnightLightingMeters = 3200.0;

  VoidCallback? onRunConcluded;
  VoidCallback? onPauseRequested;

  /// Fired when a keyboard player confirms on the bare title screen.
  VoidCallback? onStartRequested;

  /// Fired when a keyboard player confirms on the results screen.
  VoidCallback? onRestartRequested;

  /// Seconds the results screen ignores keyboard confirm after it appears, so
  /// jump mashing at the moment of the crash cannot skip it.
  static const double restartInputLockout = 0.6;

  double _resultsScreenSeconds = 0.0;

  /// Camera framing at the moment the death beat began. The beat eases from
  /// here, so the camera of a fast or airborne courier does not jump on the
  /// fatal hit.
  double _deathStartZoom = 1.0;
  final Vector2 _deathStartCenter = Vector2(
    virtualResolution.x / 2,
    virtualResolution.y / 2,
  );

  /// Whether Space / Enter should restart from the results screen.
  bool get canRestartFromKeyboard =>
      gameState.status == GameStatus.gameOver &&
      overlays.isActive('GameOver') &&
      _resultsScreenSeconds >= restartInputLockout;

  /// Whether Space / Enter should start a shift: only on the bare title
  /// screen, never while a modal (locker, bodega, ...) is stacked on top.
  bool get canStartFromKeyboard =>
      gameState.status == GameStatus.idle &&
      overlays.activeOverlays.length == 1 &&
      overlays.isActive('TitleScreen');

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

    // The skyline sits below everything; a subway station's wall (see
    // [SubwayStationComponent.wallPriority]) goes between it and the street.
    parallaxCity = ParallaxCityComponent(size: virtualResolution)
      ..priority = SubwayStationComponent.wallPriority - 1;
    world.add(parallaxCity);

    rainComponent = RainComponent(size: virtualResolution);
    world.add(rainComponent);

    lightningComponent = LightningFlashComponent(
      size: virtualResolution,
      reduceFlash: storage?.isReduceFlash ?? false,
      onThunderRumble: () {
        audio.playThunder();
        triggerScreenShake(0.18);
      },
    );
    _backdropReady = true;
    _applyVisibleWidth();
    world.add(lightningComponent);

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
        final wasRunning = gameState.status == GameStatus.running;
        final source = player.lastDamageSource;
        if (wasRunning && source is ObstacleType) gameState.lastHitBy = source;
        final stillRunning = gameState.applyHazardDamage();
        if (stillRunning) {
          haptics.hit();
        } else if (wasRunning) {
          haptics.shiftOver();
        }
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
      // The glide hint already says what is going on; a second bubble in the
      // same spot would only cover it.
      final glideHintIsUp = glideCoach != null && !glideCoach!.isDismissing;
      if (type == CourierBarkType.glide && glideHintIsUp) return;
      addEffect(
        SpeechBubbleComponent(
          text: line,
          position: Vector2(
            player.position.x - 10.0,
            player.position.y - (player.isGliding ? speechLiftGliding : speechLift),
          ),
          borderColor: borderColor,
          textColor: textColor,
          speaker: player,
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
      haptics.milestone();
      spawnConfetti(Vector2(visibleWidth / 2, 100));
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
      // The street stops with the courier: once the run is over nothing
      // scrolls, so the sidewalk must not keep sliding under frozen props.
      parallaxCity.speedMultiplier = 0.0;
      player.knockOut();
      // Kick off the slow-motion death beat; the game-over modal appears
      // when _updateDeathSlowmo finishes easing the camera onto the courier.
      _deathStartZoom = cameraJuice.currentZoom;
      _deathStartCenter.setValues(visibleWidth / 2, cameraTargetY);
      deathSlowmo.begin();
      triggerScreenShake(0.35);
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
        weatherController.setManualIntensity(rainyRushIntensity);
        rainComponent.rainIntensity = rainyRushIntensity;
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
      heavySkateTraffic: _dailyModifier == DailyModifier.skateCommute,
    );

    for (final o in chunk.obstacles) {
      final obsComp = ObstacleComponent(
        type: o.type,
        position: Vector2(o.x, o.y),
        size: Vector2(o.width, o.height),
      );
      activeObstacles.add(obsComp);
      world.add(obsComp);
      if (o.type == ObstacleType.van) _coachLeapOver(obsComp);
      if (o.type == ObstacleType.subwayTrain) _coachLeapOverTrain(obsComp);
      if (o.type == ObstacleType.pigeonFlock) _coachPigeons(obsComp);
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

    for (final sd in chunk.stormDrains) {
      final drainComp = StormDrainComponent(
        position: Vector2(sd.x, sd.y),
        width: sd.width,
        height: sd.height,
        groundY: groundY,
      );
      activeStormDrains.add(drainComp);
      world.add(drainComp);
    }

    for (final sp in chunk.solarPanels) {
      final spComp = SolarPanelComponent(
        position: Vector2(sp.x, sp.y),
        size: Vector2(sp.width, sp.height),
        groundY: groundY,
      );
      activeSolarPanels.add(spComp);
      world.add(spComp);
    }

    for (final pud in chunk.puddles) {
      final pudComp = PuddleComponent(
        position: Vector2(pud.x, pud.y),
        size: Vector2(pud.width, pud.height),
        groundY: groundY,
      );
      activePuddles.add(pudComp);
      world.add(pudComp);
    }

    for (final wt in chunk.windTunnels) {
      final wtComp = HvacWindTunnelComponent(
        position: Vector2(wt.x, wt.y),
        housingWidth: wt.housingWidth,
        housingHeight: wt.housingHeight,
        windLength: wt.windLength,
        groundY: groundY,
      );
      activeWindTunnels.add(wtComp);
      world.add(wtComp);
    }

    for (final t in chunk.turnstiles) {
      final tComp = SubwayTurnstileComponent(
        position: Vector2(t.x, t.y),
        width: t.width,
        height: t.height,
        groundY: groundY,
      );
      activeTurnstiles.add(tComp);
      world.add(tComp);
    }

    for (final dc in chunk.droneCargos) {
      final dcComp = DroneCargoComponent(
        position: Vector2(dc.x, dc.y),
        width: dc.width,
        height: dc.height,
        relativeSpeed: dc.relativeSpeed,
        groundY: groundY,
      );
      activeDroneCargos.add(dcComp);
      world.add(dcComp);
    }

    for (final fe in chunk.fireEscapes) {
      final feComp = FireEscapeLadderComponent(
        position: Vector2(fe.x, fe.y),
        width: fe.width,
        height: fe.height,
        groundY: groundY,
        launchImpulse: fe.launchImpulse,
      );
      activeFireEscapes.add(feComp);
      world.add(feComp);
    }

    for (final fts in chunk.foodTruckSlicks) {
      final ftsComp = FoodTruckSlickComponent(
        position: Vector2(fts.x, fts.y),
        width: fts.width,
        height: fts.height,
        groundY: groundY,
      );
      activeFoodTruckSlicks.add(ftsComp);
      world.add(ftsComp);
    }

    for (final b in chunk.barricades) {
      final bComp = BarricadeSawhorseComponent(
        position: Vector2(b.x, b.y),
        width: b.width,
        height: b.height,
        groundY: groundY,
      );
      activeBarricades.add(bComp);
      world.add(bComp);
    }

    for (final sd in chunk.satelliteDishes) {
      final sdComp = SatelliteDishComponent(
        position: Vector2(sd.x, sd.y),
        width: sd.width,
        height: sd.height,
        launchImpulse: sd.launchImpulse,
      );
      activeSatelliteDishes.add(sdComp);
      world.add(sdComp);
    }

    for (final mb in chunk.postalMailboxes) {
      final mbComp = PostalMailboxComponent(
        position: Vector2(mb.x, mb.y),
        width: mb.width,
        height: mb.height,
        groundY: groundY,
      );
      activeMailboxes.add(mbComp);
      world.add(mbComp);
    }

    for (final ac in chunk.acCondensers) {
      final acComp = AcCondenserComponent(
        position: Vector2(ac.x, ac.y),
        width: ac.width,
        height: ac.height,
        updraftImpulse: ac.updraftImpulse,
      );
      activeAcCondensers.add(acComp);
      world.add(acComp);
    }

    for (final gs in chunk.glassSkylights) {
      final gsComp = GlassSkylightComponent(
        position: Vector2(gs.x, gs.y),
        width: gs.width,
        height: gs.height,
        groundY: groundY,
      );
      activeGlassSkylights.add(gsComp);
      world.add(gsComp);
    }

    for (final fk in chunk.flowerKiosks) {
      final fkComp = FlowerKioskComponent(
        position: Vector2(fk.x, fk.y),
        width: fk.width,
        height: fk.height,
        groundY: groundY,
      );
      activeFlowerKiosks.add(fkComp);
      world.add(fkComp);
    }

    for (final wt in chunk.waterTowers) {
      final wtComp = WaterTowerComponent(
        position: Vector2(wt.x, wt.y),
        width: wt.width,
        height: wt.height,
        groundY: groundY,
      );
      activeWaterTowers.add(wtComp);
      world.add(wtComp);
    }

    for (final ns in chunk.newsstands) {
      final nsComp = NewsstandComponent(
        position: Vector2(ns.x, ns.y),
        width: ns.width,
        height: ns.height,
        groundY: groundY,
      );
      activeNewsstands.add(nsComp);
      world.add(nsComp);
    }

    for (final cb in chunk.cafeBistros) {
      final cbComp = CafeBistroComponent(
        position: Vector2(cb.x, cb.y),
        width: cb.width,
        height: cb.height,
        groundY: groundY,
      );
      activeCafeBistros.add(cbComp);
      world.add(cbComp);
    }

    for (final sb in chunk.streetBuskers) {
      final sbComp = StreetBuskerComponent(
        position: Vector2(sb.x, sb.y),
        width: sb.width,
        height: sb.height,
        groundY: groundY,
      );
      activeStreetBuskers.add(sbComp);
      world.add(sbComp);
    }

    for (final fh in chunk.fireHydrants) {
      final fhComp = FireHydrantComponent(
        position: Vector2(fh.x, fh.y),
        width: fh.width,
        height: fh.height,
        groundY: groundY,
      );
      activeFireHydrants.add(fhComp);
      world.add(fhComp);
    }

    for (final cl in chunk.clotheslines) {
      final clComp = ClotheslineComponent(
        position: Vector2(cl.x, cl.y),
        width: cl.width,
        height: cl.height,
        roofY: cl.roofY,
      );
      activeClotheslines.add(clComp);
      world.add(clComp);
    }

    for (final seg in chunk.subwayExhaustGrates) {
      final segComp = SubwayExhaustGrateComponent(
        position: Vector2(seg.x, seg.y),
        width: seg.width,
        height: seg.height,
        groundY: groundY,
      );
      activeSubwayExhaustGrates.add(segComp);
      world.add(segComp);
    }

    for (final cz in chunk.catenaryZiplines) {
      final czComp = CatenaryZiplineComponent(
        position: Vector2(cz.x, cz.y),
        spanWidth: cz.spanWidth,
        cableDrop: cz.cableDrop,
        sag: cz.sag,
        groundY: groundY,
      );
      activeCatenaryZiplines.add(czComp);
      world.add(czComp);
    }

    for (final bs in chunk.busShelters) {
      final bsComp = BusShelterComponent(
        position: Vector2(bs.x, bs.y),
        width: bs.width,
        height: bs.height,
        groundY: groundY,
      );
      activeBusShelters.add(bsComp);
      world.add(bsComp);
    }

    for (final ss in chunk.securityShutters) {
      final ssComp = SecurityShutterComponent(
        position: Vector2(ss.x, ss.y),
        width: ss.width,
        height: ss.height,
        groundY: groundY,
      );
      activeSecurityShutters.add(ssComp);
      world.add(ssComp);
    }

    for (final cm in chunk.cementMixers) {
      final cmComp = CementMixerComponent(
        position: Vector2(cm.x, cm.y),
        width: cm.width,
        height: cm.height,
        groundY: groundY,
      );
      activeCementMixers.add(cmComp);
      world.add(cmComp);
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

  /// Clears the finished or abandoned shift off the street and parks the game
  /// behind the title screen, looking as it does on first launch.
  void returnToDepot() {
    dailyShift = null;
    restartRun();
    isRunning = false;
    gameState.status = GameStatus.idle;
    firstRunCoach?.removeFromParent();
    firstRunCoach = null;
    _clearLeapCoach();
    parallaxCity.speedMultiplier = 1.0;
  }

  /// Resets the runner for the next shift.
  ///
  /// A daily [shift] carries over to quick restarts so it can be retried.
  /// Boosters do not: they are single-run supplies, so a restart starts with
  /// none unless the caller hands over a fresh set.
  void restartRun({DailyShift? shift, Set<RunBooster>? equippedBoosters}) {
    if (shift != null) {
      dailyShift = shift;
    }
    activeBoosters = equippedBoosters ?? const {};

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
    for (final sd in activeStormDrains.toList()) {
      sd.removeFromParent();
    }
    for (final sd in world.children.whereType<StormDrainComponent>().toList()) {
      sd.removeFromParent();
    }
    for (final sp in activeSolarPanels.toList()) {
      sp.removeFromParent();
    }
    for (final sp in world.children.whereType<SolarPanelComponent>().toList()) {
      sp.removeFromParent();
    }
    for (final pud in activePuddles.toList()) {
      pud.removeFromParent();
    }
    for (final pud in world.children.whereType<PuddleComponent>().toList()) {
      pud.removeFromParent();
    }
    for (final wt in activeWindTunnels.toList()) {
      wt.removeFromParent();
    }
    for (final wt in world.children.whereType<HvacWindTunnelComponent>().toList()) {
      wt.removeFromParent();
    }
    for (final t in activeTurnstiles.toList()) {
      t.removeFromParent();
    }
    for (final t in world.children.whereType<SubwayTurnstileComponent>().toList()) {
      t.removeFromParent();
    }
    for (final dc in activeDroneCargos.toList()) {
      dc.removeFromParent();
    }
    for (final dc in world.children.whereType<DroneCargoComponent>().toList()) {
      dc.removeFromParent();
    }
    for (final fe in activeFireEscapes.toList()) {
      fe.removeFromParent();
    }
    for (final fe in world.children.whereType<FireEscapeLadderComponent>().toList()) {
      fe.removeFromParent();
    }
    for (final fts in activeFoodTruckSlicks.toList()) {
      fts.removeFromParent();
    }
    for (final fts in world.children.whereType<FoodTruckSlickComponent>().toList()) {
      fts.removeFromParent();
    }
    for (final b in activeBarricades.toList()) {
      b.removeFromParent();
    }
    for (final b in world.children.whereType<BarricadeSawhorseComponent>().toList()) {
      b.removeFromParent();
    }
    for (final sd in activeSatelliteDishes.toList()) {
      sd.removeFromParent();
    }
    for (final sd in world.children.whereType<SatelliteDishComponent>().toList()) {
      sd.removeFromParent();
    }
    for (final mb in activeMailboxes.toList()) {
      mb.removeFromParent();
    }
    for (final mb in world.children.whereType<PostalMailboxComponent>().toList()) {
      mb.removeFromParent();
    }
    for (final ac in activeAcCondensers.toList()) {
      ac.removeFromParent();
    }
    for (final ac in world.children.whereType<AcCondenserComponent>().toList()) {
      ac.removeFromParent();
    }
    for (final gs in activeGlassSkylights.toList()) {
      gs.removeFromParent();
    }
    for (final gs in world.children.whereType<GlassSkylightComponent>().toList()) {
      gs.removeFromParent();
    }
    for (final fk in activeFlowerKiosks.toList()) {
      fk.removeFromParent();
    }
    for (final fk in world.children.whereType<FlowerKioskComponent>().toList()) {
      fk.removeFromParent();
    }
    for (final wt in activeWaterTowers.toList()) {
      wt.removeFromParent();
    }
    for (final wt in world.children.whereType<WaterTowerComponent>().toList()) {
      wt.removeFromParent();
    }
    for (final ns in activeNewsstands.toList()) {
      ns.removeFromParent();
    }
    for (final ns in world.children.whereType<NewsstandComponent>().toList()) {
      ns.removeFromParent();
    }
    for (final cb in activeCafeBistros.toList()) {
      cb.removeFromParent();
    }
    for (final cb in world.children.whereType<CafeBistroComponent>().toList()) {
      cb.removeFromParent();
    }
    for (final sb in activeStreetBuskers.toList()) {
      sb.removeFromParent();
    }
    for (final sb in world.children.whereType<StreetBuskerComponent>().toList()) {
      sb.removeFromParent();
    }
    for (final fh in activeFireHydrants.toList()) {
      fh.removeFromParent();
    }
    for (final fh in world.children.whereType<FireHydrantComponent>().toList()) {
      fh.removeFromParent();
    }
    for (final cl in activeClotheslines.toList()) {
      cl.removeFromParent();
    }
    for (final cl in world.children.whereType<ClotheslineComponent>().toList()) {
      cl.removeFromParent();
    }
    for (final seg in activeSubwayExhaustGrates.toList()) {
      seg.removeFromParent();
    }
    for (final seg in world.children.whereType<SubwayExhaustGrateComponent>().toList()) {
      seg.removeFromParent();
    }
    for (final cz in activeCatenaryZiplines.toList()) {
      cz.removeFromParent();
    }
    for (final cz in world.children.whereType<CatenaryZiplineComponent>().toList()) {
      cz.removeFromParent();
    }
    for (final bs in activeBusShelters.toList()) {
      bs.removeFromParent();
    }
    for (final bs in world.children.whereType<BusShelterComponent>().toList()) {
      bs.removeFromParent();
    }
    for (final ss in activeSecurityShutters.toList()) {
      ss.removeFromParent();
    }
    for (final ss in world.children.whereType<SecurityShutterComponent>().toList()) {
      ss.removeFromParent();
    }
    for (final cm in activeCementMixers.toList()) {
      cm.removeFromParent();
    }
    for (final cm in world.children.whereType<CementMixerComponent>().toList()) {
      cm.removeFromParent();
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
    activeStormDrains.clear();
    activeSolarPanels.clear();
    activePuddles.clear();
    activeWindTunnels.clear();
    activeTurnstiles.clear();
    activeDroneCargos.clear();
    activeFireEscapes.clear();
    activeFoodTruckSlicks.clear();
    activeBarricades.clear();
    activeSatelliteDishes.clear();
    activeMailboxes.clear();
    activeAcCondensers.clear();
    activeGlassSkylights.clear();
    activeFlowerKiosks.clear();
    activeWaterTowers.clear();
    activeNewsstands.clear();
    activeCafeBistros.clear();
    activeStreetBuskers.clear();
    activeFireHydrants.clear();
    activeClotheslines.clear();
    activeSubwayExhaustGrates.clear();
    activeCatenaryZiplines.clear();
    activeBusShelters.clear();
    activeSecurityShutters.clear();
    activeCementMixers.clear();
    _activeSolarPanel = null;
    _activeGrindRail = null;
    _solarSparkTimer = 0.0;
    _ziplineSparkTimer = 0.0;
    cameraTargetY = virtualResolution.y / 2;
    player.endGrinding();
    player.stopGlide();
    if (player.isSwinging) {
      player.state = CourierState.running;
      player.attachedCrane = null;
    }
    if (player.isZiplining) {
      player.state = CourierState.running;
      player.attachedZipline = null;
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
    lightningComponent.reset();
    lightningComponent.reduceFlash = storage?.isReduceFlash ?? false;
    haptics.enabled = storage?.isHapticsEnabled ?? haptics.enabled;
    audio.updateWeather(0.0);
    cameraJuice.reset();
    deathSlowmo.reset();
    final baseCenter = Vector2(visibleWidth / 2, virtualResolution.y / 2);
    camera.viewfinder.position = baseCenter;
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.angle = 0.0;
    nextChunkX = 960.0;
    currentSpeed = 200.0;
    parallaxCity.updateLighting(0.0, 0.0, 0.0);

    hasRecordedDailyShiftSuccess = false;
    gameState.startRun(dailyShift: dailyShift, equippedBoosters: activeBoosters);
    // QA builds only (see QaFlags): start part-way into the shift.
    if (QaFlags.forceSubway) chunkManager.subwayStationChance = 1.0;
    if (QaFlags.any && QaFlags.effectiveStartMeters > 0) {
      gameState.distanceMeters = QaFlags.effectiveStartMeters.toDouble();
    }
    if (dailyShift?.modifier == DailyModifier.rainyRush) {
      // Forced for the whole shift. Assigning the intensity alone lasted one
      // frame: the weather schedule set it back to dry on the next update.
      weatherController.setManualIntensity(rainyRushIntensity);
      rainComponent.rainIntensity = rainyRushIntensity;
      lightningComponent.rainIntensity = rainyRushIntensity;
      lightningComponent.isRaining = true;
    }
    player.position = Vector2(120.0, groundY - player.size.y);
    player.simulator.currentY = groundY;
    player.simulator.verticalVelocity = 0.0;
    player.simulator.isGrounded = true;
    player.state = CourierState.running;
    player.resetForRun();
    player.isBoosted = gameState.isEnergyBoostActive;

    isRunning = true;
    _clearLeapCoach();
    _spawnChunk();
    _refreshFirstRunCoach();
    audio.startMusic();
  }

  void _clearLeapCoach() {
    leapCoach?.removeFromParent();
    leapCoach = null;
    _leapCoachShownThisRun = false;
    trainCoach?.removeFromParent();
    trainCoach = null;
    _trainCoachShownThisRun = false;
    pigeonCoach?.removeFromParent();
    pigeonCoach = null;
    _pigeonCoachShownThisRun = false;
    glideCoach?.removeFromParent();
    glideCoach = null;
    _glideCoachShownThisRun = false;
  }

  /// Explains the chute the first time it opens in a novice's shift.
  void _coachGlide() {
    if (_glideCoachShownThisRun) return;
    if (personalRecordDistance >= leapCoachUntilRecordMeters) return;
    _glideCoachShownThisRun = true;

    final hint = CoachHintComponent(
      text: CoachText.glide(keyboard: expectsKeyboard),
      position: player.position.clone(),
      follow: player,
      hoverAbove: 46.0,
      maxX: visibleWidth - 16.0,
      dismissWhen: () => !player.isGliding,
    );
    glideCoach = hint;
    world.add(hint);
  }

  /// Teaches the held jump at the first van a novice courier meets. A tap
  /// only clears scooters and dogs, and nothing on the street says so.
  void _coachLeapOver(ObstacleComponent van) {
    if (_leapCoachShownThisRun) return;
    if (personalRecordDistance >= leapCoachUntilRecordMeters) return;
    _leapCoachShownThisRun = true;

    final hint = CoachHintComponent(
      text: CoachText.leap(keyboard: expectsKeyboard),
      position: Vector2(visibleWidth, groundY - 175.0),
      follow: van,
      dismissBehindX: player.position.x,
      showWithinX: visibleWidth + leapCoachLeadPixels,
      maxX: visibleWidth - 16.0,
    );
    leapCoach = hint;
    world.add(hint);
  }

  /// A hint that waits at the right edge of the screen and then rides
  /// [height] px above the street over [hazard] until it is behind the
  /// courier.
  CoachHintComponent _hintOver(ObstacleComponent hazard, String text, {double height = 175.0}) {
    final hint = CoachHintComponent(
      text: text,
      position: Vector2(visibleWidth, groundY - height),
      follow: hazard,
      dismissBehindX: player.position.x,
      showWithinX: visibleWidth + leapCoachLeadPixels,
      maxX: visibleWidth - 16.0,
    );
    world.add(hint);
    return hint;
  }

  void _coachLeapOverTrain(ObstacleComponent train) {
    if (_trainCoachShownThisRun) return;
    if (personalRecordDistance >= leapCoachUntilRecordMeters) return;
    _trainCoachShownThisRun = true;
    trainCoach = _hintOver(train, CoachText.leap(keyboard: expectsKeyboard));
  }

  void _coachPigeons(ObstacleComponent flock) {
    if (_pigeonCoachShownThisRun) return;
    final shiftsSoFar = storage?.pigeonCoachRuns ?? _pigeonCoachShiftsUnsaved;
    if (shiftsSoFar >= pigeonCoachShifts) return;
    _pigeonCoachShownThisRun = true;
    _pigeonCoachShiftsUnsaved++;
    storage?.addPigeonCoachRun();
    // Higher than the other hints: the birds climb, and at the usual
    // height they flew up behind the bubble just as the courier reached
    // them. From here they get to it after the courier has gone under.
    pigeonCoach = _hintOver(flock, CoachText.underTheBirds(), height: pigeonCoachHeight);
  }

  /// Shows the tap-to-hop coaching hint for brand-new couriers whose
  /// personal record is still zero, riding above the opening hazard. The
  /// warm-up only serves hazards a quick tap clears, so that is what it says.
  void _refreshFirstRunCoach() {
    firstRunCoach?.removeFromParent();
    firstRunCoach = null;
    if (personalRecordDistance > 0) return;

    ObstacleComponent? firstObstacle;
    for (final o in activeObstacles) {
      if (firstObstacle == null || o.position.x < firstObstacle.position.x) {
        firstObstacle = o;
      }
    }

    final hintX = firstObstacle != null
        ? firstObstacle.position.x + firstObstacle.size.x / 2 - 100.0
        : player.position.x + 280.0;
    final hint = CoachHintComponent(
      text: CoachText.hop(keyboard: expectsKeyboard),
      position: Vector2(hintX.clamp(140.0, visibleWidth - 240.0), groundY - 175.0),
      follow: firstObstacle,
      dismissBehindX: player.position.x,
      maxX: visibleWidth - 16.0,
    );
    firstRunCoach = hint;
    world.add(hint);
  }

  /// Plays the slow-motion death beat: eases the camera onto the fallen
  /// courier, then hands off to the run-concluded flow (game-over modal).
  void _updateDeathSlowmo(double dt) {
    if (!deathSlowmo.isActive) return;

    final focusX = (player.position.x + player.size.x / 2)
        .clamp(200.0, visibleWidth - 200.0)
        .toDouble();
    final focus = Vector2(focusX, player.position.y - 30.0);
    final t = deathSlowmo.progress;
    final zoom = deathSlowmo.currentZoom(_deathStartZoom);
    // Keep the zoomed view inside the street. The backdrop is only painted a
    // little past the virtual resolution, so panning freely toward a courier
    // near the left edge showed a black void beside and below the scene.
    final targetX = _centerWithinStreet(focus.x, visibleWidth, zoom);
    final targetY = _centerWithinStreet(focus.y, virtualResolution.y, zoom);
    // The impact shake rides on top of the eased path. It runs in real time
    // rather than slow motion, so the hit still lands hard.
    cameraJuice.updateShake(dt);
    camera.viewfinder.position = Vector2(
      _deathStartCenter.x +
          (targetX - _deathStartCenter.x) * t +
          cameraJuice.shakeOffset.x,
      _deathStartCenter.y +
          (targetY - _deathStartCenter.y) * t +
          cameraJuice.shakeOffset.y,
    );
    camera.viewfinder.zoom = zoom;
    camera.viewfinder.angle = cameraJuice.shakeAngle;

    if (deathSlowmo.update(dt)) {
      cameraJuice.reset();
      camera.viewfinder.position = Vector2(visibleWidth / 2, virtualResolution.y / 2);
      camera.viewfinder.zoom = 1.0;
      camera.viewfinder.angle = 0.0;
      onRunConcluded?.call();
    }
  }

  /// The camera centre closest to [center] whose view, [extent] wide at
  /// [zoom], stays on the street. A view wider than the street is centred.
  static double _centerWithinStreet(double center, double extent, double zoom) {
    final halfView = extent / (2 * zoom);
    if (halfView * 2 >= extent) return extent / 2;
    return center.clamp(halfView, extent - halfView).toDouble();
  }

  /// The most time one frame may simulate. A longer frame (a hitch while the
  /// browser decodes something, a slow phone, a stalled tab) is cut down to
  /// this: the street holds still for the rest of the stall instead of
  /// lurching forward by a distance nobody could have reacted to.
  double maxFrameStep = 0.1;

  /// The longest single simulation step: one frame at 60 frames a second,
  /// which is what the jump was tuned at. A longer frame is run as several
  /// equal steps, so hazards are checked for collision along the way rather
  /// than being moved past the courier in one jump, and a leap is the same
  /// height on a phone managing 20 or 30 frames a second as on one managing
  /// 60. (Stepped whole, a held leap at 20 frames a second peaked at 138 px
  /// against 179 px: the hold thrust is applied a frame at a time.)
  ///
  /// Measured before leaving this alone: letting steps run to 1/48 s would
  /// save one step a frame between 48 and 60 frames a second, about 5% of
  /// the frame, and widen the spread in leap height from 6% to 9%, because
  /// the hold thrust is cut off on a step boundary. Not a good trade.
  static const double maxSubStep = 1.0 / 60.0;

  @override
  // Each step below calls FlameGame.update; the lint cannot see through the
  // loop.
  // ignore: must_call_super
  void update(double dt) {
    if (dt > maxFrameStep) dt = maxFrameStep;
    final steps = dt > maxSubStep ? (dt / maxSubStep - 1e-9).ceil() : 1;
    final stepDt = dt / steps;
    for (var i = 0; i < steps; i++) {
      _step(stepDt);
    }
  }

  /// One simulation step of [dt] seconds.
  void _step(double dt) {
    // A paused shift is a frozen frame. Skipping the component tree keeps the
    // skyline and sidewalk from scrolling on under a world that has stopped.
    if (gameState.status == GameStatus.paused) return;

    final effectiveDt = deathSlowmo.isActive ? dt * deathSlowmo.timeScale : dt;
    _isUpdatingTree = true;
    try {
      super.update(effectiveDt);
    } finally {
      _isUpdatingTree = false;
    }
    _flushPendingEffects();
    _resultsScreenSeconds =
        overlays.isActive('GameOver') ? _resultsScreenSeconds + dt : 0.0;
    if (!isRunning || gameState.status != GameStatus.running) {
      _updateDeathSlowmo(dt);
      return;
    }

    // QA builds only (see QaFlags): the shift cannot be lost.
    if (QaFlags.immortal && gameState.packages < gameState.maxPackages) {
      gameState.packages = gameState.maxPackages;
    }

    // 0. Update active energy drink buff, drone assist, celebration, and stunt combo timers
    gameState.updateEnergyTimer(dt);
    gameState.updateDroneTimer(dt);
    gameState.updateMilestoneTimer(dt);
    gameState.updateContractTimer(dt);
    gameState.updateStuntTimer(dt);
    gameState.updateVipTimer(dt);
    gameState.updateFloralAromaTimer(dt);
    gameState.updateNotorietyTimer(dt);
    gameState.updateCaffeineSurgeTimer(dt);
    gameState.updateUrbanGrooveTimer(dt);
    gameState.updateHydroplaneTimer(dt);
    gameState.updateThermalUpdraftTimer(dt);
    player.isBoosted = gameState.isEnergyBoostActive;
    player.simulator.isHydroplaning = gameState.isHydroplaneActive;
    player.simulator.isThermalUpdraft = gameState.isThermalUpdraftActive;

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
        (gameState.isCaffeineSurgeActive ? 1.18 : 1.0) *
        (gameState.isHydroplaneActive ? 1.15 : 1.0) *
        (player.isGrinding ? 1.20 : 1.0) *
        (player.isVaulting ? 1.25 : 1.0) *
        (player.isDrafting ? 1.20 : 1.0) *
        (_dailyModifier == DailyModifier.rainyRush ? rainyRushSpeedMultiplier : 1.0);
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
        (gameState.distanceMeters >= AchievementManager.longHaulMeters &&
            !achievementManager.isUnlocked('long_haul')) ||
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
    lightningComponent.rainIntensity = weatherController.rainIntensity;
    lightningComponent.isRaining = weatherController.isRaining;
    audio.updateWeather(weatherController.rainIntensity);
    audio.updateMusicPhase(
      isNight: parallaxCity.currentPhase == TimeOfDayPhase.night,
      dt: dt,
    );
    audio.updateStreakIntensity(
      streakActive: gameState.stuntStreak >= GameAudioController.streakLayerThreshold,
      dt: dt,
    );

    // 3. Update parallax city velocity & dynamic environment lighting
    parallaxCity.speedMultiplier = currentSpeed / 200.0;
    parallaxCity.updateLighting(
      // Neon Midnight is night from the first metre; other shifts follow the
      // distance-driven day cycle.
      _dailyModifier == DailyModifier.nightDash
          ? neonMidnightLightingMeters
          : gameState.distanceMeters,
      dt,
      weatherController.rainIntensity,
      lightningComponent.currentSpecularBoost,
    );

    // 3b. Update camera trauma shake, velocity framing zoom, and vertical aerial tracking
    cameraJuice.update(dt, currentSpeed: currentSpeed);
    final targetCameraY = (player.isElevated || player.isGrinding || player.isGliding)
        ? (virtualResolution.y / 2) - 35.0
        : (virtualResolution.y / 2);
    cameraTargetY += (targetCameraY - cameraTargetY) * (3.0 * dt).clamp(0.0, 1.0);
    camera.viewfinder.position = Vector2(
      (visibleWidth / 2) + cameraJuice.shakeOffset.x,
      cameraTargetY + cameraJuice.shakeOffset.y,
    );
    camera.viewfinder.zoom = cameraJuice.currentZoom;
    camera.viewfinder.angle = cameraJuice.shakeAngle;

    // 4. Scroll active hazards, pickups, scaffolding, ramps, and PR marker leftward
    final scrollDelta = currentSpeed * dt;
    nextChunkX -= scrollDelta;

    for (final o in activeObstacles) {
      o.position.x -= scrollDelta;
      o.streetSpeed = currentSpeed;
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
    for (final st in activeSubwayStations) {
      st.position.x -= scrollDelta;
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
    for (final sd in activeStormDrains) {
      sd.position.x -= scrollDelta;
    }
    for (final sp in activeSolarPanels) {
      sp.position.x -= scrollDelta;
    }
    for (final pud in activePuddles) {
      pud.position.x -= scrollDelta;
      pud.isRaining = weatherController.isRaining;
    }
    for (final wt in activeWindTunnels) {
      wt.position.x -= scrollDelta;
    }
    for (final t in activeTurnstiles) {
      t.position.x -= scrollDelta;
    }
    for (final dc in activeDroneCargos) {
      dc.position.x -= scrollDelta;
    }
    for (final fe in activeFireEscapes) {
      fe.position.x -= scrollDelta;
    }
    for (final fts in activeFoodTruckSlicks) {
      fts.position.x -= scrollDelta;
    }
    for (final b in activeBarricades) {
      b.position.x -= scrollDelta;
    }
    for (final sd in activeSatelliteDishes) {
      sd.position.x -= scrollDelta;
    }
    for (final mb in activeMailboxes) {
      mb.position.x -= scrollDelta;
    }
    for (final ac in activeAcCondensers) {
      ac.position.x -= scrollDelta;
    }
    for (final gs in activeGlassSkylights) {
      gs.position.x -= scrollDelta;
    }
    for (final fk in activeFlowerKiosks) {
      fk.position.x -= scrollDelta;
    }
    for (final wt in activeWaterTowers) {
      wt.position.x -= scrollDelta;
    }
    for (final ns in activeNewsstands) {
      ns.position.x -= scrollDelta;
    }
    for (final cb in activeCafeBistros) {
      cb.position.x -= scrollDelta;
    }
    for (final sb in activeStreetBuskers) {
      sb.position.x -= scrollDelta;
    }
    for (final fh in activeFireHydrants) {
      fh.position.x -= scrollDelta;
    }
    for (final cl in activeClotheslines) {
      cl.position.x -= scrollDelta;
    }
    for (final seg in activeSubwayExhaustGrates) {
      seg.position.x -= scrollDelta;
    }
    for (final cz in activeCatenaryZiplines) {
      cz.position.x -= scrollDelta;
    }
    for (final bs in activeBusShelters) {
      bs.position.x -= scrollDelta;
    }
    for (final ss in activeSecurityShutters) {
      ss.position.x -= scrollDelta;
    }
    for (final cm in activeCementMixers) {
      cm.position.x -= scrollDelta;
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
          text: 'DAILY SHIFT COMPLETED! +${dollars(gameState.activeDailyShift!.completionBonusTips)}',
          position: Vector2(player.position.x - 20, player.position.y - 40),
          color: const Color(0xFFF1C40F),
        ),
      );
      spawnConfetti(Vector2(visibleWidth / 2, 80), count: 30);
      // Storage records the day and the star only. The bonus itself is
      // already in this shift's tips (GameState adds it at the goal line) and
      // is banked with them when the shift ends; handing it over here as well
      // paid it twice.
      storage?.completeDailyShift(
        dateString: gameState.activeDailyShift!.dateString,
        bonusTips: 0,
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
          (player.isGrinding && _activeGrindRail == gr && courierFootX >= gr.position.x && courierFootX <= gr.position.x + gr.size.x)) {
        supportingRail = gr;
        break;
      }
    }

    // 4f-2. Evaluate Rooftop Solar Panel Array Skate Slide, Sparks, and Kinetic Charge
    SolarPanelComponent? supportingSolarPanel;
    for (final sp in activeSolarPanels) {
      if (sp.checkCollisionWith(player) ||
          (player.isGrinding && _activeSolarPanel == sp && courierFootX >= sp.position.x && courierFootX <= sp.position.x + sp.size.x)) {
        supportingSolarPanel = sp;
        break;
      }
    }

    if (supportingRail != null) {
      _activeGrindRail = supportingRail;
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
    } else if (supportingSolarPanel != null) {
      _activeSolarPanel = supportingSolarPanel;
      supportingSolarPanel.isCharging = true;
      supportingSolarPanel.addCharge(dt * 2.2);

      if (!player.isGrinding) {
        player.startGrinding(supportingSolarPanel.surfaceY);
        audio.playCoin();
        triggerScreenShake(0.12);
        addEffect(
          ParticleEffectComponent.electricSparks(
            position: Vector2(courierFootX, supportingSolarPanel.surfaceY),
            count: 12,
          ),
        );
      } else {
        player.grindDistance += distanceDelta;
        _solarSparkTimer += dt;
        if (_solarSparkTimer >= 0.05) {
          _solarSparkTimer = 0.0;
          addEffect(
            ParticleEffectComponent.electricSparks(
              position: Vector2(courierFootX, supportingSolarPanel.surfaceY - 2.0),
              count: 5,
            ),
          );
        }
      }
    } else if (player.isGrinding) {
      if (_activeSolarPanel != null) {
        final panel = _activeSolarPanel!;
        _activeSolarPanel = null;
        _solarSparkTimer = 0.0;
        player.endGrinding();
        if (supportingScaffolding != null) {
          player.setTargetSurfaceY(supportingScaffolding.surfaceY);
        } else {
          player.resetTargetSurfaceY();
        }
        _handleSolarSurge(panel);
      } else {
        // Clean dismount off rail trailing edge!
        final meters = player.grindDistance;
        _activeGrindRail = null;
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
      }
    } else {
      if (_activeSolarPanel != null) {
        if (_activeSolarPanel!.chargeLevel >= 0.25 && !_activeSolarPanel!.hasDischarged) {
          _handleSolarSurge(_activeSolarPanel!);
        }
        _activeSolarPanel = null;
        _solarSparkTimer = 0.0;
      }
      _activeGrindRail = null;

      if (supportingScaffolding != null) {
        player.setTargetSurfaceY(supportingScaffolding.surfaceY);
      } else {
        player.resetTargetSurfaceY();
      }
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
            _evaluateAchievements();
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
            _evaluateAchievements();
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
          // The Straphanger trophy.
          _evaluateAchievements();
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

    // 4o. Evaluate Street Storm Drain Vault Grate Steam Geysers & Coin Eruptions
    for (final sd in activeStormDrains) {
      if (sd.checkTrigger(player.position, player.size, player.simulator)) {
        _handleStormDrainGeyser(sd);
      }
    }

    // 4p. Evaluate Dynamic Sidewalk Puddle Splashes and Skims
    for (final pud in activePuddles) {
      if (!pud.hasSplashed && pud.checkSplash(player.position, player.size, player.simulator)) {
        pud.hasSplashed = true;
        _wetHazardsCleared++;
        triggerScreenShake(0.08);
        addEffect(
          ParticleEffectComponent.waterSpray(
            position: Vector2(courierFootX, groundY - 4.0),
            count: 14,
          ),
        );
        audio.playCoin();
      } else if (!pud.hasSkimmed && !pud.hasSplashed && pud.checkSkim(player.position, player.size, player.simulator)) {
        pud.hasSkimmed = true;
        _handlePuddleSkim(pud);
      }
    }

    // 4q. Evaluate Industrial HVAC Exhaust Wind Tunnel Aerodynamic Hover Glides
    for (final wt in activeWindTunnels) {
      if (wt.isInWindStream(player.position, player.size, player.simulator)) {
        // Buoyant aerodynamic hover lift inside the slipstream cone
        if (player.simulator.verticalVelocity < 30.0) {
          player.simulator.applyUpdraft(60.0);
        }
        if (!wt.hasAwarded) {
          wt.hasAwarded = true;
          _handleWindTunnelGlide(wt);
        }
      }
    }

    // 4r. Evaluate Street Subway Entrance Turnstile Swipes & Hurdle Vaults
    for (final t in activeTurnstiles) {
      if (!t.hasVaulted && !t.hasSwiped) {
        if (t.checkVault(player.position, player.size, player.simulator)) {
          _handleTurnstilePass(t, isVault: true);
        } else if (t.checkSwipe(player.position, player.size, player.simulator)) {
          _handleTurnstilePass(t, isVault: false);
        }
      }
    }

    // 4s. Evaluate Aerial Drone Cargo Interceptions
    for (final dc in activeDroneCargos) {
      if (dc.hasCargo && !dc.hasBeenIntercepted) {
        if (dc.checkIntercept(player.position, player.size, player.simulator)) {
          _handleDroneCatch(dc);
        }
      }
    }

    // 4t. Evaluate Street Fire Escape Ladder Drop Grabs
    for (final fe in activeFireEscapes) {
      if (!fe.hasDropped) {
        if (fe.checkLadderGrab(player.position, player.size, player.simulator)) {
          _handleFireEscapeDrop(fe);
        }
      }
    }

    // 4u. Evaluate Street Food Truck Grease Slick Drift Slides
    for (final fts in activeFoodTruckSlicks) {
      if (!fts.hasDrifted) {
        if (fts.checkDrift(player.position, player.size, player.simulator)) {
          _handleFoodTruckDrift(fts);
        }
      }
    }

    // 4v. Evaluate Street Construction Barricade Sawhorse Hurdle Vaults
    for (final b in activeBarricades) {
      if (!b.hasVaulted) {
        if (b.checkVault(player.position, player.size, player.simulator)) {
          _handleBarricadeVault(b);
        }
      }
    }

    // 4w. Evaluate Rooftop Parabolic Satellite Dish Leap Pad Launches
    for (final sd in activeSatelliteDishes) {
      if (!sd.hasLaunched) {
        if (sd.checkLaunch(player.position, player.size, player.simulator)) {
          _handleSatelliteLaunch(sd);
        }
      }
    }

    // 4x. Evaluate Street Postal Collection Mailbox Hurdle Vaults
    for (final mb in activeMailboxes) {
      if (!mb.hasVaulted) {
        if (mb.checkVault(player.position, player.size, player.simulator)) {
          _handlePostalMailboxVault(mb);
        }
      }
    }

    // 4y. Evaluate Rooftop AC Condenser Fan Updraft Column Lifts
    for (final ac in activeAcCondensers) {
      if (!ac.hasLifted) {
        if (ac.checkUpdraft(player.position, player.size, player.simulator)) {
          _handleAcCondenserUpdraft(ac);
        }
      }
    }

    // 4z. Evaluate Rooftop Architectural Glass Skylight Smash-Through Leaps
    for (final gs in activeGlassSkylights) {
      if (!gs.hasShattered) {
        if (gs.checkSmashThrough(player.position, player.size, player.simulator)) {
          _handleGlassSkylightSmash(gs);
        }
      }
    }

    // 4aa. Evaluate Sidewalk Flower Vendor Kiosk Hurdle Vaults
    for (final fk in activeFlowerKiosks) {
      if (!fk.hasVaulted) {
        if (fk.checkVault(player.position, player.size, player.simulator)) {
          _handleFlowerKioskVault(fk);
        }
      }
    }

    // 4ab. Evaluate Rooftop Wooden Water Tower Platforms & Deluge Launches
    for (final wt in activeWaterTowers) {
      if (!wt.hasTriggered) {
        if (wt.checkTraverse(player.position, player.size, player.simulator)) {
          _handleWaterTowerTraverse(wt);
        }
      }
    }

    // 4ac. Evaluate Sidewalk Newspaper Kiosk Hurdle Vaults
    for (final ns in activeNewsstands) {
      if (!ns.hasVaulted) {
        if (ns.checkVault(player.position, player.size, player.simulator)) {
          _handleNewsstandVault(ns);
        }
      }
    }

    // 4ad. Evaluate Sidewalk Cafe Bistro Hurdle Vaults
    for (final cb in activeCafeBistros) {
      if (!cb.hasVaulted) {
        if (cb.checkVault(player.position, player.size, player.simulator)) {
          _handleCafeBistroVault(cb);
        }
      }
    }

    // 4ae. Evaluate Sidewalk Street Busker Jazz Stunts
    for (final sb in activeStreetBuskers) {
      if (!sb.hasEncountered) {
        if (sb.checkInteraction(player.position, player.size, player.simulator)) {
          _handleStreetBuskerEncounter(sb);
        }
      }
    }

    // 4af. Evaluate Sidewalk Fire Hydrant Spray Traverses
    for (final fh in activeFireHydrants) {
      if (!fh.hasTriggered) {
        if (fh.checkInteraction(player.position, player.size, player.simulator)) {
          _handleFireHydrantTraverse(fh);
        }
      }
    }

    // 4ag. Evaluate Rooftop Tenement Laundry Clothesline Hurdles
    for (final cl in activeClotheslines) {
      if (!cl.hasHurdled) {
        if (cl.checkHurdle(player.position, player.size, player.simulator)) {
          _handleClotheslineHurdle(cl);
        }
      }
    }

    // 4ah. Evaluate Sidewalk Subway Exhaust Grate Updrafts
    for (final seg in activeSubwayExhaustGrates) {
      if (!seg.hasTriggered) {
        if (seg.checkUpdraft(player.position, player.size, player.simulator)) {
          _handleSubwayExhaustGrateCatch(seg);
        }
      }
    }

    // 4ai. Evaluate Aerial Catenary Power Line Zipline Slides
    if (!player.isZiplining) {
      if (!player.simulator.isGrounded && player.state != CourierState.hurt && !player.isSwinging) {
        for (final cz in activeCatenaryZiplines) {
          if (cz.canGrabWire(player.position, player.size, player.simulator)) {
            player.attachToZipline(cz);
            audio.playJump();
            triggerScreenShake(0.14);
            addEffect(
              ParticleEffectComponent.ziplineSparks(
                position: Vector2(player.position.x + (player.size.x * 0.5), player.position.y + 10.0),
                count: 18,
              ),
            );
            break;
          }
        }
      }
    } else if (player.attachedZipline != null) {
      final zipline = player.attachedZipline!;
      final footX = player.position.x + (player.size.x * 0.5);

      _ziplineSparkTimer += dt;
      if (_ziplineSparkTimer >= 0.06) {
        _ziplineSparkTimer = 0.0;
        addEffect(
          ParticleEffectComponent.ziplineSparks(
            position: Vector2(footX, zipline.cableYAt(footX)),
            count: 6,
          ),
        );
      }

      if (zipline.isPastForwardEdge(footX)) {
        _handleCatenaryZiplineDismount(zipline);
      }
    }

    // 4aj. Evaluate Street Transit Bus Stop Shelter Vaults
    for (final bs in activeBusShelters) {
      if (!bs.hasVaulted) {
        if (bs.checkShelterVault(player.position, player.size, player.simulator)) {
          _handleBusShelterVault(bs);
        }
      }
    }

    // 4ak. Evaluate Industrial Roll-Up Security Shutter Rebounds
    for (final ss in activeSecurityShutters) {
      if (!ss.hasRebounded) {
        if (ss.checkShutterRebound(player.position, player.size, player.simulator)) {
          _handleSecurityShutterRebound(ss);
        }
      }
    }

    // 4al. Evaluate Construction Cement Mixer Mortar Hops
    for (final cm in activeCementMixers) {
      if (!cm.hasHopped) {
        if (cm.checkMixerHop(player.position, player.size, player.simulator)) {
          _handleCementMixerHop(cm);
        }
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
            final wasMagnetized = p.isMagnetized;
            p.isMagnetized = true;

            final pull = diff.normalized() * (magnetSpeed * dt);
            p.position += pull;

            // Snap-in glint on field capture, then periodic comet-trail glints.
            p.magnetTrailTimer -= dt;
            if (p.magnetTrailTimer <= 0.0) {
              p.magnetTrailTimer = wasMagnetized ? 0.12 : 0.0;
              addEffect(
                ParticleEffectComponent.sparkles(
                  position: pickupCenter,
                  count: wasMagnetized ? 1 : 5,
                ),
              );
            }
          } else if (p.isMagnetized) {
            p.isMagnetized = false;
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
    activeObstacles.removeWhere((o) => o.shouldRecycle || o.isRemoved);
    activePickups.removeWhere((p) => p.shouldRecycle || p.isCollected || p.isRemoved);
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
    activeStormDrains.removeWhere((sd) {
      if (sd.shouldRecycle || sd.isRemoved) {
        if (sd.isMounted) sd.removeFromParent();
        return true;
      }
      return false;
    });
    activeSolarPanels.removeWhere((sp) {
      if (sp.shouldRecycle || sp.isRemoved) {
        if (sp.isMounted) sp.removeFromParent();
        return true;
      }
      return false;
    });
    activePuddles.removeWhere((pud) {
      if (pud.shouldRecycle || pud.isRemoved) {
        if (pud.isMounted) pud.removeFromParent();
        return true;
      }
      return false;
    });
    activeWindTunnels.removeWhere((wt) {
      if (wt.shouldRecycle || wt.isRemoved) {
        if (wt.isMounted) wt.removeFromParent();
        return true;
      }
      return false;
    });
    activeTurnstiles.removeWhere((t) {
      if (t.shouldRecycle || t.isRemoved) {
        if (t.isMounted) t.removeFromParent();
        return true;
      }
      return false;
    });
    activeDroneCargos.removeWhere((dc) {
      if (dc.shouldRecycle || dc.isRemoved) {
        if (dc.isMounted) dc.removeFromParent();
        return true;
      }
      return false;
    });
    activeFireEscapes.removeWhere((fe) {
      if (fe.shouldRecycle || fe.isRemoved) {
        if (fe.isMounted) fe.removeFromParent();
        return true;
      }
      return false;
    });
    activeFoodTruckSlicks.removeWhere((fts) {
      if (fts.shouldRecycle || fts.isRemoved) {
        if (fts.isMounted) fts.removeFromParent();
        return true;
      }
      return false;
    });
    activeBarricades.removeWhere((b) {
      if (b.shouldRecycle || b.isRemoved) {
        if (b.isMounted) b.removeFromParent();
        return true;
      }
      return false;
    });
    activeSatelliteDishes.removeWhere((sd) {
      if (sd.shouldRecycle || sd.isRemoved) {
        if (sd.isMounted) sd.removeFromParent();
        return true;
      }
      return false;
    });
    activeMailboxes.removeWhere((mb) {
      if (mb.shouldRecycle || mb.isRemoved) {
        if (mb.isMounted) mb.removeFromParent();
        return true;
      }
      return false;
    });
    activeAcCondensers.removeWhere((ac) {
      if (ac.shouldRecycle || ac.isRemoved) {
        if (ac.isMounted) ac.removeFromParent();
        return true;
      }
      return false;
    });
    activeGlassSkylights.removeWhere((gs) {
      if (gs.shouldRecycle || gs.isRemoved) {
        if (gs.isMounted) gs.removeFromParent();
        return true;
      }
      return false;
    });
    activeFlowerKiosks.removeWhere((fk) {
      if (fk.shouldRecycle || fk.isRemoved) {
        if (fk.isMounted) fk.removeFromParent();
        return true;
      }
      return false;
    });
    activeWaterTowers.removeWhere((wt) {
      if (wt.shouldRecycle || wt.isRemoved) {
        if (wt.isMounted) wt.removeFromParent();
        return true;
      }
      return false;
    });
    activeNewsstands.removeWhere((ns) {
      if (ns.shouldRecycle || ns.isRemoved) {
        if (ns.isMounted) ns.removeFromParent();
        return true;
      }
      return false;
    });
    activeCafeBistros.removeWhere((cb) {
      if (cb.shouldRecycle || cb.isRemoved) {
        if (cb.isMounted) cb.removeFromParent();
        return true;
      }
      return false;
    });
    activeStreetBuskers.removeWhere((sb) {
      if (sb.shouldRecycle || sb.isRemoved) {
        if (sb.isMounted) sb.removeFromParent();
        return true;
      }
      return false;
    });
    activeFireHydrants.removeWhere((fh) {
      if (fh.shouldRecycle || fh.isRemoved) {
        if (fh.isMounted) fh.removeFromParent();
        return true;
      }
      return false;
    });
    activeClotheslines.removeWhere((cl) {
      if (cl.shouldRecycle || cl.isRemoved) {
        if (cl.isMounted) cl.removeFromParent();
        return true;
      }
      return false;
    });
    activeSubwayExhaustGrates.removeWhere((seg) {
      if (seg.shouldRecycle || seg.isRemoved) {
        if (seg.isMounted) seg.removeFromParent();
        return true;
      }
      return false;
    });
    activeCatenaryZiplines.removeWhere((cz) {
      if (cz.shouldRecycle || cz.isRemoved) {
        if (cz.isMounted) cz.removeFromParent();
        return true;
      }
      return false;
    });
    activeBusShelters.removeWhere((bs) {
      if (bs.shouldRecycle || bs.isRemoved) {
        if (bs.isMounted) bs.removeFromParent();
        return true;
      }
      return false;
    });
    activeSecurityShutters.removeWhere((ss) {
      if (ss.shouldRecycle || ss.isRemoved) {
        if (ss.isMounted) ss.removeFromParent();
        return true;
      }
      return false;
    });
    activeCementMixers.removeWhere((cm) {
      if (cm.shouldRecycle || cm.isRemoved) {
        if (cm.isMounted) cm.removeFromParent();
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
    if (nextChunkX <= math.max(virtualResolution.x + 480.0, visibleWidth + 200.0)) {
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
    _coachGlide();
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

  void _handleStormDrainGeyser(StormDrainComponent sd) {
    final event = gameState.recordDrainGeyser(coinsSpawned: 3);
    if (event != null) {
      audio.playJump();
      audio.playCoin();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Geyser launch!');
      triggerScreenShake(0.22);
      spawnSparkles(
        sd.centerWorldPosition,
        color: const Color(0xFF00E5FF),
        count: 16,
      );
      spawnDust(sd.centerWorldPosition, count: 8);

      for (var i = 0; i < event.coinsSpawned; i++) {
        final coinX = sd.position.x + 30.0 + (i * 35.0);
        final coinY = groundY - 60.0 - (math.sin((i + 1) / (event.coinsSpawned + 1) * math.pi) * 50.0);
        late final PickupComponent coinPickup;
        coinPickup = PickupComponent(
          type: PickupType.coin,
          position: Vector2(coinX, coinY),
          onCollected: (type) {
            final collectionPos = coinPickup.position + (coinPickup.size / 2);
            activePickups.removeWhere((item) => item.isCollected);
            _handlePickup(type, collectionPos);
          },
        );
        activePickups.add(coinPickup);
        world.add(coinPickup);
      }

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'DRAIN GEYSER! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleSolarSurge(SolarPanelComponent panel) {
    if (panel.hasDischarged) return;
    panel.hasDischarged = true;

    // EMP Shockwave: Vacuum all coins within 320px directly to courier
    int coinsHarvested = 0;
    final courierCenter = player.position + (player.size / 2);
    for (final p in activePickups.toList()) {
      if ((p.type == PickupType.coin || p.type == PickupType.coin5) && !p.isCollected) {
        final pCenter = p.position + (p.size / 2);
        if ((courierCenter - pCenter).length <= 320.0) {
          p.isCollected = true;
          p.onCollected?.call(p.type);
          if (p.isMounted) {
            p.removeFromParent();
          }
          coinsHarvested++;
          addEffect(
            ParticleEffectComponent.electricSparks(
              position: pCenter,
              count: 6,
            ),
          );
        }
      }
    }

    final event = gameState.recordSolarSurge(coinsHarvested: coinsHarvested);
    if (event != null) {
      audio.playMilestone();
      audio.playCoin();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Solar surge!');
      triggerScreenShake(0.24);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'SOLAR SURGE! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 12.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.electricSparks(
          position: courierCenter,
          count: 20,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handlePuddleSkim(PuddleComponent pud) {
    final event = gameState.recordPuddleSkim();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Hydro skim!');
      triggerScreenShake(0.12);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'PUDDLE SKIM! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF29B6F6),
        ),
      );
      spawnSparkles(
        Vector2(pud.position.x + pud.size.x / 2, groundY - 10.0),
        color: const Color(0xFF29B6F6),
        count: 8,
      );
      _evaluateAchievements();
    }
  }

  void _handleWindTunnelGlide(HvacWindTunnelComponent wt) {
    final event = gameState.recordWindTunnelGlide();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(CourierBarkType.stunt, line: 'Turbine slipstream!');
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      addEffect(
        FloatingTextComponent(
          text: 'WIND TUNNEL GLIDE! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.windDebris(
          position: Vector2(player.position.x + (player.size.x / 2), player.position.y + (player.size.y / 2)),
          count: 15,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleTurnstilePass(SubwayTurnstileComponent turnstile, {required bool isVault}) {
    final event = gameState.recordTurnstilePass(isVault: isVault);
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(CourierBarkType.stunt, line: isVault ? 'Turnstile vaulted!' : 'Metro pass swiped!');
      triggerScreenShake(0.12);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      final title = isVault ? 'TURNSTILE VAULT!' : 'METRO SWIPE!';
      final color = isVault ? const Color(0xFF00E676) : const Color(0xFFFFD54F);

      addEffect(
        FloatingTextComponent(
          text: '$title $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 10.0, player.position.y - 35.0),
          color: color,
        ),
      );
      addEffect(
        ParticleEffectComponent.metroSwipe(
          position: turnstile.cardReaderWorldPosition,
          count: 14,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleDroneCatch(DroneCargoComponent drone) {
    final event = gameState.recordDroneCatch();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: event.restoredPackage ? 'Cargo intercepted! Package restocked!' : 'Aerial cargo caught!',
      );
      triggerScreenShake(0.18);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      final bonusText = event.restoredPackage ? ' +1 PKG RESTOCKED!' : '';

      addEffect(
        FloatingTextComponent(
          text: 'DRONE CATCH! $multStr+\$${event.totalTips}$bonusText',
          position: Vector2(player.position.x - 20.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.droneCargo(
          position: drone.crateCenterWorld,
          count: 22,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleFireEscapeDrop(FireEscapeLadderComponent fireEscape) {
    final event = gameState.recordFireEscapeDrop();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Fire escape shortcut!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'FIRE ESCAPE DROP! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFFFFD54F),
        ),
      );
      addEffect(
        ParticleEffectComponent.fireEscapeSparks(
          position: fireEscape.ladderGrabWorldPosition,
          count: 18,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleFoodTruckDrift(FoodTruckSlickComponent foodTruck) {
    final event = gameState.recordFoodTruckDrift();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Slick grease drift!',
      );
      triggerScreenShake(0.12);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'GREASE DRIFT SLIDE! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFFFFB300),
        ),
      );
      addEffect(
        ParticleEffectComponent.greaseSpray(
          position: foodTruck.slickCenterWorldPosition,
          count: 18,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleBarricadeVault(BarricadeSawhorseComponent barricade) {
    final event = gameState.recordBarricadeVault();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Clear over the sawhorse!',
      );
      triggerScreenShake(0.10);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'BARRICADE VAULT! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFFFF6D00),
        ),
      );
      addEffect(
        ParticleEffectComponent.sawhorseSparks(
          position: barricade.flasherWorldPosition,
          count: 18,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleSatelliteLaunch(SatelliteDishComponent dish) {
    final event = gameState.recordSatelliteLaunch(launchImpulse: dish.launchImpulse);
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'High-gain launch!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'HIGH-GAIN LAUNCH! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.satellitePulse(
          position: dish.feedHornWorldPosition,
          count: 20,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handlePostalMailboxVault(PostalMailboxComponent mailbox) {
    final event = gameState.recordMailboxVault();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Priority delivery!',
      );
      triggerScreenShake(0.08);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'EXPRESS MAIL VAULT! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFF1976D2),
        ),
      );
      addEffect(
        ParticleEffectComponent.mailScatter(
          position: mailbox.chuteWorldPosition,
          count: 18,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleAcCondenserUpdraft(AcCondenserComponent condenser) {
    player.startGlide();
    final event = gameState.recordAcUpdraft(updraftImpulse: condenser.updraftImpulse);
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Thermal vortex catch!',
      );
      triggerScreenShake(0.12);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'THERMAL VORTEX LIFT! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.condenserMist(
          position: condenser.updraftWorldPosition,
          count: 22,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleGlassSkylightSmash(GlassSkylightComponent skylight) {
    final event = gameState.recordSkylightSmash();
    if (event != null) {
      audio.playMilestone();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Smashing entrance!',
      );
      triggerScreenShake(0.20);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'SKYLIGHT SMASH! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.glassShatter(
          position: skylight.shatterWorldPosition,
          count: 24,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleFlowerKioskVault(FlowerKioskComponent kiosk) {
    final event = gameState.recordFlowerKioskVault();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Fresh blooms!',
      );
      triggerScreenShake(0.12);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'FLOWER KIOSK VAULT! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFFE91E63),
        ),
      );
      addEffect(
        ParticleEffectComponent.petalBurst(
          position: kiosk.canopyApexWorld,
          count: 22,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleWaterTowerTraverse(WaterTowerComponent tower) {
    final isBreach = tower.isBreached;
    final event = gameState.recordWaterTowerTraverse(isBreachCascade: isBreach);
    if (event != null) {
      if (isBreach) {
        audio.playMilestone();
        audio.playCourierBark(
          CourierBarkType.stunt,
          line: 'Deluge unleashed!',
        );
        triggerScreenShake(0.25);
      } else {
        audio.playJump();
        audio.playCourierBark(
          CourierBarkType.stunt,
          line: 'Catwalk launch!',
        );
        triggerScreenShake(0.14);
        player.startGlide();
      }

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';
      final title = isBreach ? 'WATER TOWER BREACH!' : 'CATWALK LAUNCH!';
      final textColor = isBreach ? const Color(0xFF00E5FF) : const Color(0xFF26A69A);

      addEffect(
        FloatingTextComponent(
          text: '$title $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: textColor,
        ),
      );
      addEffect(
        ParticleEffectComponent.waterTowerDeluge(
          position: isBreach ? tower.breachWorldPosition : tower.apexWorldPosition,
          count: isBreach ? 32 : 18,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleNewsstandVault(NewsstandComponent newsstand) {
    final event = gameState.recordNewsstandVault();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Extra! Extra!',
      );
      triggerScreenShake(0.13);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'EXTRA! EXTRA! VAULT! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFFFFB300),
        ),
      );
      addEffect(
        ParticleEffectComponent.newsprintScatter(
          position: newsstand.counterApexWorld,
          count: 24,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleCafeBistroVault(CafeBistroComponent bistro) {
    final event = gameState.recordCafeBistroVault();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Espresso rush!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'CAFE BISTRO VAULT! $multStr+\$${event.totalTips}',
          position: Vector2(bistro.position.x - 10.0, bistro.tabletopWorldY - 32.0),
          color: const Color(0xFFFFB74D),
        ),
      );
      addEffect(
        ParticleEffectComponent.espressoPorcelainBurst(
          position: bistro.tabletopApexWorld,
          count: 26,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleStreetBuskerEncounter(StreetBuskerComponent busker) {
    final event = gameState.recordStreetBuskerEncounter();
    if (event != null) {
      audio.playCoin();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Urban groove!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'URBAN GROOVE! $multStr+\$${event.totalTips}',
          position: Vector2(busker.position.x - 10.0, busker.position.y - 32.0),
          color: const Color(0xFFE040FB),
        ),
      );
      addEffect(
        ParticleEffectComponent.musicalNoteFountain(
          position: busker.saxBellApexWorld,
          count: 28,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleFireHydrantTraverse(FireHydrantComponent hydrant) {
    final event = gameState.recordFireHydrantTraverse();
    if (event != null) {
      player.simulator.isHydroplaning = true;
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Fresh hydrant blast!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'HYDROPLANE! $multStr+\$${event.totalTips}',
          position: Vector2(hydrant.position.x - 10.0, hydrant.hydrantApexWorldY - 32.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.hydrantWaterPlume(
          position: hydrant.sprayApexWorld,
          count: 32,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleClotheslineHurdle(ClotheslineComponent clothesline) {
    final event = gameState.recordClotheslineHurdle();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Fresh out the wash!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'CLOTHESLINE REBOUND! $multStr+\$${event.totalTips}',
          position: Vector2(clothesline.position.x - 10.0, clothesline.ropeSagWorldY - 32.0),
          color: const Color(0xFFFF8A80),
        ),
      );
      addEffect(
        ParticleEffectComponent.clotheslineLinenScatter(
          position: clothesline.centerApexWorld,
          count: 26,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleSubwayExhaustGrateCatch(SubwayExhaustGrateComponent grate) {
    final event = gameState.recordSubwayExhaustGrateCatch();
    if (event != null) {
      player.simulator.isThermalUpdraft = true;
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Thermal catch!',
      );
      triggerScreenShake(0.14);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'THERMAL UPDRAFT! $multStr+\$${event.totalTips}',
          position: Vector2(grate.position.x - 10.0, grate.position.y - 32.0),
          color: const Color(0xFFFFB74D),
        ),
      );
      addEffect(
        ParticleEffectComponent.subwayExhaustSteam(
          position: grate.plumeApexWorld,
          count: 30,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleCatenaryZiplineDismount(CatenaryZiplineComponent zipline) {
    player.releaseZipline();
    final event = gameState.recordCatenaryZipline(distanceMeters: zipline.spanWidth / 10.0);
    if (event != null) {
      audio.playMilestone();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'High-voltage zip!',
      );
      triggerScreenShake(0.18);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'AERIAL CATENARY ZIPLINE! $multStr+\$${event.totalTips}',
          position: Vector2(player.position.x - 15.0, player.position.y - 35.0),
          color: const Color(0xFF00E5FF),
        ),
      );
      addEffect(
        ParticleEffectComponent.ziplineSparks(
          position: Vector2(player.position.x + (player.size.x * 0.5), player.position.y + 10.0),
          count: 28,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleBusShelterVault(BusShelterComponent shelter) {
    shelter.markVaulted();
    final event = gameState.recordBusShelterVault();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Express service!',
      );
      triggerScreenShake(0.13);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'TRANSIT SHELTER VAULT! $multStr+\$${event.totalTips}',
          position: Vector2(shelter.position.x - 10.0, shelter.position.y - 32.0),
          color: const Color(0xFFFFB300),
        ),
      );
      addEffect(
        ParticleEffectComponent.transitLedSparks(
          position: shelter.marqueeApexWorld,
          count: 26,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleSecurityShutterRebound(SecurityShutterComponent shutter) {
    shutter.markRebounded();
    final event = gameState.recordSecurityShutterRebound();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Off the wall!',
      );
      triggerScreenShake(0.16);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'SECURITY SHUTTER REBOUND! $multStr+\$${event.totalTips}',
          position: Vector2(shutter.position.x - 12.0, shutter.position.y - 32.0),
          color: const Color(0xFFFF007F),
        ),
      );
      addEffect(
        ParticleEffectComponent.securityShutterSparks(
          position: shutter.reboundApexWorld,
          count: 28,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _handleCementMixerHop(CementMixerComponent mixer) {
    mixer.markHopped();
    final event = gameState.recordCementMixerHop();
    if (event != null) {
      audio.playJump();
      audio.playCourierBark(
        CourierBarkType.stunt,
        line: 'Still setting!',
      );
      triggerScreenShake(0.15);

      final multStr = event.multiplier > 1.0 ? '${event.multiplier}x ' : '';

      addEffect(
        FloatingTextComponent(
          text: 'CEMENT MIXER HOP! $multStr+\$${event.totalTips}',
          position: Vector2(mixer.position.x - 12.0, mixer.position.y - 32.0),
          color: const Color(0xFFB0BEC5),
        ),
      );
      addEffect(
        ParticleEffectComponent.cementMixerSplashes(
          position: mixer.hopApexWorld,
          count: 26,
        ),
      );
      _evaluateAchievements();
    }
  }

  void _evaluateAchievements() {
    achievementManager.evaluateProgress(
      distanceMeters: gameState.distanceMeters,
      // The streak length, not the tip multiplier: the multiplier tops out at
      // 2.5x, so a "4x combo" measured on it could never be reached.
      stuntCombo: gameState.stuntStreak,
      lifetimeContracts: gameState.contractManager.completedCount,
      lifetimeCareerTips: gameState.tips + gameState.contractManager.totalBonusTips,
      wetHazardsCleared: _wetHazardsCleared,
      subwayStationsInRun: gameState.subwayStationsInRun,
      // The saved career count already includes this shift's deliveries.
      lifetimeDeliveries: storage?.lifetimeDeliveries ?? gameState.deliveriesInRun,
      dailyStars: storage?.dailyStars ?? 0,
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
    spawnConfetti(Vector2(visibleWidth / 2, 80), count: 25);
  }

  /// Routes a jump press (tap or key) to the courier while a run is live.
  /// Any press also dismisses the first-run coaching hint, keyboard included.
  void _pressJump() {
    firstRunCoach?.dismiss();
    if (!isRunning || gameState.status != GameStatus.running) return;
    final jumpMult = gameState.isCaffeineSurgeActive ? 1.10 : 1.0;
    player.pressJump(impulseMultiplier: jumpMult);
  }

  /// What made the latest jump press: a touch's pointer id or a key.
  ///
  /// The hold belongs to the latest press and to nothing else. A thumb that
  /// is still coming off the glass from the previous jump, or a palm resting
  /// on the edge of the screen, cannot let go of a jump it did not start.
  Object? _jumpHolder;

  /// A finger, mouse button or key ([source]) went down: jump, and hold the
  /// jump for as long as that same source stays down.
  void holdJump(Object source) {
    _jumpHolder = source;
    _pressJump();
  }

  /// [source] came up. Lets go of the jump only if it is the one holding it.
  void letGoOfJump(Object source) {
    if (source != _jumpHolder) return;
    _jumpHolder = null;
    player.releaseJump();
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

    // Space / Enter double as "confirm" on the title and results screens, so a
    // keyboard player never has to reach for the mouse between runs.
    final isConfirmKey = event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (isConfirmKey && event is KeyDownEvent) {
      if (canRestartFromKeyboard) {
        onRestartRequested?.call();
        return KeyEventResult.handled;
      }
      if (canStartFromKeyboard) {
        onStartRequested?.call();
        return KeyEventResult.handled;
      }
    }

    final isJumpKey = event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyW;

    if (isJumpKey) {
      if (event is KeyDownEvent) {
        holdJump(event.logicalKey);
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        letGoOfJump(event.logicalKey);
        return KeyEventResult.handled;
      }
    }

    return super.onKeyEvent(event, keysPressed);
  }
}
