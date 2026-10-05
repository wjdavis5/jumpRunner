import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/audio_controller.dart';
import 'game/courier_game.dart';
import 'game/logic/achievement_manager.dart';
import 'game/logic/game_state.dart';
import 'game/models/courier_skin.dart';
import 'game/models/daily_shift.dart';
import 'game/models/run_booster.dart';
import 'services/storage_service.dart';
import 'ui/achievements_modal.dart';
import 'ui/bodega_modal.dart';
import 'ui/daily_shift_modal.dart';
import 'ui/game_over_modal.dart';
import 'ui/hud_overlay.dart';
import 'ui/locker_modal.dart';
import 'ui/modal_scrim.dart';
import 'ui/pause_menu_modal.dart';
import 'ui/resume_countdown.dart';
import 'ui/throttled_listenable_builder.dart';
import 'ui/title_screen.dart';

/// The orientations this app supports (landscape only).
const supportedOrientations = <DeviceOrientation>[
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Locks the app to [supportedOrientations].
Future<void> lockOrientation() {
  return SystemChrome.setPreferredOrientations(supportedOrientations);
}

/// Hides the phone's status and navigation bars while the game is up.
///
/// On Android they were drawn over the game: the clock and signal icons
/// across the top of the street, and the navigation bar down the right-hand
/// edge. "Sticky" means a swipe from an edge shows them for a moment and
/// they go away again by themselves.
Future<void> hideSystemBars() {
  return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockOrientation();
  await hideSystemBars();

  final storageService = LocalStorageService();
  await storageService.init();

  final audioController = GameAudioController(storageService: storageService);
  await audioController.preload();

  runApp(
    CourierDashApp(
      storageService: storageService,
      audioController: audioController,
    ),
  );
}

/// Root widget for the Courier Dash application.
class CourierDashApp extends StatefulWidget {
  const CourierDashApp({
    super.key,
    required this.storageService,
    required this.audioController,
  });

  final LocalStorageService storageService;
  final GameAudioController audioController;

  @override
  State<CourierDashApp> createState() => _CourierDashAppState();
}

class _CourierDashAppState extends State<CourierDashApp>
    with WidgetsBindingObserver {
  late final GameState _gameState;
  late final CourierGame _game;

  bool _isNewRecord = false;
  int _lastDistance = 0;
  int _lastTips = 0;
  Set<RunBooster> _equippedBoosters = {};
  bool _isReduceFlash = false;
  bool _isHapticsOn = true;
  bool _isStartingRun = false;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _isReduceFlash = widget.storageService.isReduceFlash;
    _isHapticsOn = widget.storageService.isHapticsEnabled;
    final equippedSkin =
        CourierSkin.findById(widget.storageService.equippedSkin);
    _game = CourierGame(
      gameState: _gameState,
      audioController: widget.audioController,
      achievementManager:
          AchievementManager(storageService: widget.storageService),
      storageService: widget.storageService,
      initialSkin: equippedSkin,
    );

    _game.onRunConcluded = _handleRunConcluded;
    _game.onPauseRequested = _togglePause;
    _game.onStartRequested = _startGame;
    _game.onRestartRequested = _restartGame;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayRevision.dispose();
    super.dispose();
  }

  /// Bumped on every `setState`.
  ///
  /// The game widget is built once and never rebuilt (see [_gameWidget]), so
  /// on their own its overlays keep showing whatever they read when they were
  /// first built: an outfit just bought still on sale, a mute button that
  /// does not change. Each overlay listens to this instead.
  final ValueNotifier<int> _overlayRevision = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _overlayRevision.value++;
  }

  /// Wraps every overlay so it rebuilds when [_overlayRevision] changes.
  Map<String, OverlayWidgetBuilder<CourierGame>> _liveOverlays(
    Map<String, OverlayWidgetBuilder<CourierGame>> builders,
  ) {
    return builders.map(
      (name, build) => MapEntry(
        name,
        (context, game) => ValueListenableBuilder<int>(
          valueListenable: _overlayRevision,
          builder: (context, _, __) => build(context, game),
        ),
      ),
    );
  }

  /// Leaving the app mid-run opens the pause menu and silences the music, so
  /// the soundtrack does not play on behind another app and the courier is
  /// not thrown straight back into traffic when the player returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.audioController.resumeFromBackground();
    } else {
      _pauseGame();
      // Leaving in the middle of the count puts the menu back up, so the
      // shift does not restart while nobody is looking.
      _cancelResumeCountdown();
      widget.audioController.suspendForBackground();
    }
  }

  void _handleToggleReduceFlash(bool reduce) async {
    setState(() {
      _isReduceFlash = reduce;
    });
    await widget.storageService.setReduceFlash(reduce);
    _game.lightningComponent.reduceFlash = reduce;
  }

  void _handleToggleHaptics(bool on) async {
    setState(() {
      _isHapticsOn = on;
    });
    _game.haptics.enabled = on;
    // Turning it on answers with one buzz, so the switch is felt to work.
    if (on) _game.haptics.hit();
    await widget.storageService.setHapticsEnabled(on);
  }

  /// Writes the current shift's distance, tips and contracts to the courier's
  /// career record. Returns whether the distance is a new personal best.
  ///
  /// Everything is read from the run state before the first await, so the
  /// caller is free to reset that state straight afterwards.
  Future<bool> _bankShift() async {
    final distance = _gameState.distanceMeters.floor();
    final tips = _gameState.tips + _gameState.contractManager.totalBonusTips;
    final contracts = _gameState.contractManager.completedCount;
    final stuntCombo = _gameState.stuntStreak;
    final stations = _gameState.subwayStationsInRun;

    final isNewRecord = await widget.storageService.recordRun(
      distance: distance,
      tips: tips,
    );

    if (contracts > 0) {
      await widget.storageService.recordCompletedContracts(contracts);
    }

    // Evaluate lifetime achievements (contract specialist, big tipper)
    await _game.achievementManager.evaluateProgress(
      distanceMeters: distance.toDouble(),
      stuntCombo: stuntCombo,
      lifetimeContracts: widget.storageService.completedContracts,
      // Lifetime earnings, not the balance: spending in the Locker must not
      // push the Big Tipper trophy further away.
      lifetimeCareerTips: widget.storageService.lifetimeTips,
      subwayStationsInRun: stations,
      lifetimeDeliveries: widget.storageService.lifetimeDeliveries,
      dailyStars: widget.storageService.dailyStars,
    );
    return isNewRecord;
  }

  Future<void> _handleRunConcluded() async {
    _lastDistance = _gameState.distanceMeters.floor();
    _lastTips = _gameState.tips;
    _isNewRecord = await _bankShift();

    if (mounted) {
      setState(() {});
      _game.overlays.add('GameOver');
    }
  }

  /// Whether the depot's own buttons count: at the depot with no card open.
  ///
  /// A button fires when the finger on it lifts. A card that opens in the
  /// meantime dims the depot and takes new touches, but a finger that was
  /// already down still belongs to the button under it. Hold START SHIFT,
  /// tap DAILY with the other thumb, let go: the shift used to begin under
  /// the open card. Hold LOCKER, tap BODEGA, let go: two cards at once.
  bool get _isDepotFree => _gameState.status == GameStatus.idle && !_isMenuCardOpen;

  void _startGame([DailyShift? dailyShift]) async {
    // Not from under a card: see [_isDepotFree]. Clocking in from the Daily
    // card closes it first.
    if (_isMenuCardOpen) return;
    // A second press while boosters are still being consumed must not start
    // (and charge for) the shift twice.
    if (_isStartingRun) return;
    _isStartingRun = true;
    try {
      final boostersToApply = Set<RunBooster>.from(_equippedBoosters);
      for (final booster in boostersToApply) {
        await widget.storageService.consumeBooster(booster.id);
      }
      _equippedBoosters = {};
      _gameState.startRun(
          dailyShift: dailyShift, equippedBoosters: boostersToApply);
      // Set outright: a regular start must not inherit an earlier daily shift.
      _game.dailyShift = dailyShift;
      _game.restartRun(shift: dailyShift, equippedBoosters: boostersToApply);
      _game.overlays.remove('TitleScreen');
      _game.overlays.add('HUD');
      if (mounted) setState(() {});
    } finally {
      _isStartingRun = false;
    }
  }

  void _openBodega() {
    if (!_isDepotFree) return;
    _game.overlays.add('BodegaModal');
  }

  void _closeBodega() {
    _game.overlays.remove('BodegaModal');
    if (mounted) setState(() {});
  }

  void _handleEquippedBoostersChanged(Set<RunBooster> boosters) {
    setState(() {
      _equippedBoosters = boosters;
    });
  }

  void _openDailyShift() {
    if (!_isDepotFree) return;
    _game.overlays.add('DailyShiftModal');
  }

  void _closeDailyShift() {
    _game.overlays.remove('DailyShiftModal');
  }

  void _startDailyShift(DailyShift shift) {
    _closeDailyShift();
    _startGame(shift);
  }

  void _restartGame() {
    _game.overlays.remove('GameOver');
    _game.restartRun();
  }

  void _pauseGame() {
    if (_gameState.status == GameStatus.running) {
      _gameState.pauseRun();
      _game.overlays.add('PauseMenu');
      widget.audioController.pauseDucking();
    }
  }

  bool get _isCountingDown => _game.overlays.isActive('ResumeCountdown');

  /// Swaps the pause menu for a short count. The shift stays on hold (and the
  /// street stays frozen) until the count is done.
  void _resumeGame() {
    if (_gameState.status != GameStatus.paused || _isCountingDown) return;
    _game.overlays.remove('PauseMenu');
    _game.overlays.add('ResumeCountdown');
  }

  void _finishResume() {
    // A count that has been called off can still report that it finished:
    // taking its overlay down only takes effect on the next frame, and its
    // animation ticks before that frame is built. After the app has been
    // in the background that next frame comes seconds late, the animation
    // jumps straight to its end, and the shift used to start running
    // behind the pause menu that had replaced the count.
    if (!_isCountingDown) return;
    _game.overlays.remove('ResumeCountdown');
    if (_gameState.status == GameStatus.paused) {
      _gameState.resumeRun();
      widget.audioController.resumeDucking();
    }
  }

  /// Abandons a count in progress and shows the pause menu again.
  void _cancelResumeCountdown() {
    if (!_isCountingDown) return;
    _game.overlays.remove('ResumeCountdown');
    if (_gameState.status == GameStatus.paused) {
      _game.overlays.add('PauseMenu');
    }
  }

  void _togglePause() {
    if (_gameState.status == GameStatus.running) {
      _pauseGame();
    } else if (_gameState.status == GameStatus.paused) {
      // P or Esc during the count means "not yet": back to the menu.
      if (_isCountingDown) {
        _cancelResumeCountdown();
      } else {
        _resumeGame();
      }
    } else {
      // At the depot the same keys (P, Esc) back out of an open menu card.
      _closeOpenMenuCard();
    }
  }

  bool get _isMenuCardOpen {
    final overlays = _game.overlays;
    return overlays.isActive('BodegaModal') ||
        overlays.isActive('DailyShiftModal') ||
        overlays.isActive('LockerModal') ||
        overlays.isActive('AchievementsModal');
  }

  /// Android's back button, or the back swipe from the edge of the screen.
  ///
  /// Left to itself it closes the app, and during a shift that is a swipe a
  /// thumb makes by accident: the shift and its tips were simply gone. It
  /// now does what Esc does on a keyboard (closes a menu card, pauses,
  /// resumes), leaves the results card for the depot, and only at the depot
  /// itself, with nothing open, leaves the app.
  void _handleSystemBack() {
    switch (_gameState.status) {
      case GameStatus.running:
      case GameStatus.paused:
        _togglePause();
      case GameStatus.gameOver:
        // Not during the crash beat, before the results card is up: there
        // is nothing on screen yet for "back" to mean.
        if (_game.overlays.isActive('GameOver')) _quitToTitle();
      case GameStatus.idle:
        if (_isMenuCardOpen) {
          _closeOpenMenuCard();
        } else if (!_isStartingRun) {
          SystemNavigator.pop();
        }
    }
  }

  void _closeOpenMenuCard() {
    final overlays = _game.overlays;
    if (overlays.isActive('BodegaModal')) {
      _closeBodega();
    } else if (overlays.isActive('DailyShiftModal')) {
      _closeDailyShift();
    } else if (overlays.isActive('LockerModal')) {
      _closeLocker();
    } else if (overlays.isActive('AchievementsModal')) {
      _closeAchievements();
    }
  }

  /// Leaves the shift for the depot (title screen), from the pause menu or
  /// from the results screen. The depot is where tips get spent, so the
  /// results screen must be able to reach it too.
  Future<void> _quitToTitle() async {
    // Quitting from the pause menu abandons a live shift. Its distance and
    // tips are banked first: the pause menu calls them "Tips Banked", and
    // they used to be thrown away. A shift that ended on the results screen
    // was already banked when it concluded.
    final abandonsLiveShift = _gameState.status == GameStatus.paused ||
        _gameState.status == GameStatus.running;
    final banking = abandonsLiveShift ? _bankShift() : null;

    _game.overlays.remove('PauseMenu');
    _game.overlays.remove('ResumeCountdown');
    _game.overlays.remove('GameOver');
    _game.overlays.remove('HUD');
    _game.returnToDepot();
    widget.audioController.resumeDucking();

    // The title screen reads the career record as it builds, so it waits for
    // the banking to land.
    await banking;
    _game.overlays.add('TitleScreen');
  }

  void _toggleMute() {
    widget.audioController.toggleMute();
    setState(() {});
  }

  void _openLocker() {
    if (!_isDepotFree) return;
    _game.overlays.add('LockerModal');
  }

  void _closeLocker() {
    _game.overlays.remove('LockerModal');
  }

  void _openAchievements() {
    if (!_isDepotFree) return;
    _game.overlays.add('AchievementsModal');
  }

  void _closeAchievements() {
    _game.overlays.remove('AchievementsModal');
  }

  Future<void> _handleEquipSkin(String skinId) async {
    await widget.storageService.equipSkin(skinId);
    _game.setPlayerSkin(CourierSkin.findById(skinId));
    if (mounted) setState(() {});
  }

  Future<void> _handleUnlockSkin(String skinId, int price) async {
    final success = await widget.storageService.unlockSkin(skinId, price);
    if (success) {
      await _handleEquipSkin(skinId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courier Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // The game draws its text at the sizes its screens were laid out for,
      // whatever the phone's text-size setting says. The cards are fixed
      // compositions that are already scaled to fit the screen as a whole;
      // with system text at 130% the title, pause, Locker, Trophies and
      // daily cards all overflowed, and at 115% three of them did.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.0,
        child: child!,
      ),
      // Android's back button or back swipe is never left to close the app
      // by itself: see [_handleSystemBack].
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleSystemBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _gameWidget,
        ),
      ),
    );
  }

  /// The [GameWidget] must be constructed exactly once.
  ///
  /// Flame's `GameWidget` constructor re-applies `initialActiveOverlays` every
  /// time it is constructed, so rebuilding this widget (any `setState` above)
  /// would resurrect the 'TitleScreen' overlay on top of live gameplay.
  late final GameWidget<CourierGame> _gameWidget = GameWidget<CourierGame>(
    game: _game,
    initialActiveOverlays: const ['TitleScreen'],
    overlayBuilderMap: _liveOverlays({
      'TitleScreen': (context, game) => TitleScreen(
            highDistance: widget.storageService.highDistance,
            careerTips: widget.storageService.careerTips,
            isMuted: widget.audioController.isMuted,
            unlockedAchievementsCount: _game.achievementManager.unlockedCount,
            totalAchievementsCount: _game.achievementManager.totalCount,
            dailyStars: widget.storageService.dailyStars,
            equippedBoosters: _equippedBoosters,
            nextOutfit: CourierSkin.nextToUnlock(widget.storageService.unlockedSkins),
            onToggleMute: _toggleMute,
            onOpenLocker: _openLocker,
            onOpenBodega: _openBodega,
            onOpenAchievements: _openAchievements,
            onOpenDailyShift: _openDailyShift,
            onStartGame: _startGame,
          ),
      'BodegaModal': (context, game) => ModalScrim(
            onDismiss: _closeBodega,
            child: BodegaModal(
              storageService: widget.storageService,
              equippedBoosters: _equippedBoosters,
              onEquippedBoostersChanged: _handleEquippedBoostersChanged,
              onClose: _closeBodega,
            ),
          ),
      'DailyShiftModal': (context, game) => ModalScrim(
            onDismiss: _closeDailyShift,
            child: DailyShiftModal(
              storageService: widget.storageService,
              onStartDailyShift: _startDailyShift,
              onClose: _closeDailyShift,
            ),
          ),
      'LockerModal': (context, game) => ModalScrim(
            onDismiss: _closeLocker,
            child: LockerModal(
              careerTips: widget.storageService.careerTips,
              unlockedSkins: widget.storageService.unlockedSkins,
              equippedSkin: widget.storageService.equippedSkin,
              onEquipSkin: _handleEquipSkin,
              onUnlockSkin: _handleUnlockSkin,
              onClose: _closeLocker,
            ),
          ),
      'AchievementsModal': (context, game) => ModalScrim(
            onDismiss: _closeAchievements,
            child: AchievementsModal(
              unlockedAchievementIds: widget.storageService.unlockedAchievements,
              onClose: _closeAchievements,
            ),
          ),
      // Not rebuilt on every frame: see [ThrottledListenableBuilder].
      'HUD': (context, game) => ThrottledListenableBuilder(
            key: const Key('hud_refresher'),
            listenable: _gameState,
            builder: (context) => HUDOverlay(
              gameState: _gameState,
              isMuted: widget.audioController.isMuted,
              onToggleMute: _toggleMute,
              onPause: _togglePause,
            ),
          ),
      'PauseMenu': (context, game) => PauseMenuModal(
            gameState: _gameState,
            isReduceFlash: _isReduceFlash,
            onToggleReduceFlash: _handleToggleReduceFlash,
            isHapticsOn: _isHapticsOn,
            onToggleHaptics: _handleToggleHaptics,
            onResume: _resumeGame,
            onQuit: _quitToTitle,
          ),
      'ResumeCountdown': (context, game) => ResumeCountdown(onDone: _finishResume),
      'GameOver': (context, game) => GameOverModal(
            distance: _lastDistance,
            tips: _lastTips,
            isNewRecord: _isNewRecord,
            personalBest: widget.storageService.highDistance,
            endedBy: _gameState.lastHitBy,
            careerTips: widget.storageService.careerTips,
            nextOutfit: CourierSkin.nextToUnlock(widget.storageService.unlockedSkins),
            completedContracts: _gameState.contractManager.completedCount,
            contractBonusTips: _gameState.contractManager.totalBonusTips,
            deliveriesCompleted: _gameState.deliveriesInRun,
            grindsCompleted: _gameState.grindsInRun,
            vaultsCompleted: _gameState.vaultsInRun,
            glidesCompleted: _gameState.glidesInRun,
            subwayStationsCompleted: _gameState.subwayStationsInRun,
            craneSwingsCompleted: _gameState.craneSwingsInRun,
            vipDeliveriesCompleted: _gameState.vipDeliveriesInRun,
            bikeDraftSlingshotsCompleted: _gameState.bikeDraftSlingshotsInRun,
            pigeonScattersCompleted: _gameState.pigeonScattersInRun,
            highFivesCompleted: _gameState.highFivesInRun,
            foodCartBouncesCompleted: _gameState.foodCartBouncesInRun,
            drainGeysersCompleted: _gameState.drainGeysersInRun,
            solarSurgesCompleted: _gameState.solarSurgesInRun,
            puddleSkimsCompleted: _gameState.puddleSkimsInRun,
            windTunnelGlidesCompleted: _gameState.windTunnelGlidesInRun,
            turnstilesCompleted: _gameState.turnstileVaultsInRun,
            droneCatchesCompleted: _gameState.droneCatchesInRun,
            fireEscapesCompleted: _gameState.fireEscapeDropsInRun,
            foodTruckDriftsCompleted: _gameState.foodTruckDriftsInRun,
            barricadesCompleted: _gameState.barricadeVaultsInRun,
            satelliteLaunchesCompleted: _gameState.satelliteLaunchesInRun,
            mailboxesCompleted: _gameState.mailboxVaultsInRun,
            acCondensersCompleted: _gameState.acUpdraftsInRun,
            skylightsCompleted: _gameState.skylightSmashesInRun,
            flowerKiosksCompleted: _gameState.flowerKioskVaultsInRun,
            waterTowersCompleted: _gameState.waterTowersTraversedInRun,
            newsstandsCompleted: _gameState.newsstandsVaultedInRun,
            cafeBistrosCompleted: _gameState.cafeBistroVaultsInRun,
            buskersCompleted: _gameState.buskersEncounteredInRun,
            hydrantsCompleted: _gameState.hydrantsTraversedInRun,
            clotheslinesCompleted: _gameState.clotheslinesHurdledInRun,
            subwayGratesCompleted: _gameState.exhaustGratesCaughtInRun,
            ziplinesCompleted: _gameState.ziplinesCompletedInRun,
            busSheltersCompleted: _gameState.busSheltersVaultedInRun,
            securityShuttersCompleted: _gameState.shuttersReboundedInRun,
            onRestart: _restartGame,
            onReturnToDepot: _quitToTitle,
          ),
    }),
  );
}
