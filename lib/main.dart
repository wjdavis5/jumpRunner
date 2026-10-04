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
import 'ui/pause_menu_modal.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockOrientation();

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

class _CourierDashAppState extends State<CourierDashApp> {
  late final GameState _gameState;
  late final CourierGame _game;

  bool _isNewRecord = false;
  int _lastDistance = 0;
  int _lastTips = 0;
  Set<RunBooster> _equippedBoosters = {};

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    final equippedSkin = CourierSkin.findById(widget.storageService.equippedSkin);
    _game = CourierGame(
      gameState: _gameState,
      audioController: widget.audioController,
      achievementManager: AchievementManager(storageService: widget.storageService),
      storageService: widget.storageService,
      initialSkin: equippedSkin,
    );

    _game.onRunConcluded = _handleRunConcluded;
    _game.onPauseRequested = _togglePause;
  }

  Future<void> _handleRunConcluded() async {
    _lastDistance = _gameState.distanceMeters.floor();
    _lastTips = _gameState.tips;
    final bonusTips = _gameState.contractManager.totalBonusTips;

    _isNewRecord = await widget.storageService.recordRun(
      distance: _lastDistance,
      tips: _lastTips + bonusTips,
    );

    final completed = _gameState.contractManager.completedCount;
    if (completed > 0) {
      await widget.storageService.recordCompletedContracts(completed);
    }

    // Evaluate lifetime achievements (contract specialist, big tipper)
    await _game.achievementManager.evaluateProgress(
      distanceMeters: _lastDistance.toDouble(),
      stuntCombo: _gameState.stuntMultiplier.round(),
      lifetimeContracts: widget.storageService.completedContracts,
      lifetimeCareerTips: widget.storageService.careerTips,
    );

    if (mounted) {
      setState(() {});
      _game.overlays.add('GameOver');
    }
  }

  void _startGame([DailyShift? dailyShift]) async {
    final boostersToApply = Set<RunBooster>.from(_equippedBoosters);
    for (final booster in boostersToApply) {
      await widget.storageService.consumeBooster(booster.id);
    }
    _equippedBoosters = {};
    _gameState.startRun(dailyShift: dailyShift, equippedBoosters: boostersToApply);
    _game.restartRun(shift: dailyShift, equippedBoosters: boostersToApply);
    _game.overlays.remove('TitleScreen');
    _game.overlays.add('HUD');
    if (mounted) setState(() {});
  }

  void _openBodega() {
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

  void _resumeGame() {
    if (_gameState.status == GameStatus.paused) {
      _gameState.resumeRun();
      _game.overlays.remove('PauseMenu');
      widget.audioController.resumeDucking();
    }
  }

  void _togglePause() {
    if (_gameState.status == GameStatus.running) {
      _pauseGame();
    } else if (_gameState.status == GameStatus.paused) {
      _resumeGame();
    }
  }

  void _quitToTitle() {
    _game.overlays.remove('PauseMenu');
    _game.overlays.remove('HUD');
    _gameState.status = GameStatus.idle;
    _game.isRunning = false;
    widget.audioController.resumeDucking();
    _game.overlays.add('TitleScreen');
  }

  void _toggleMute() {
    widget.audioController.toggleMute();
    setState(() {});
  }

  void _openLocker() {
    _game.overlays.add('LockerModal');
  }

  void _closeLocker() {
    _game.overlays.remove('LockerModal');
  }

  void _openAchievements() {
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
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GameWidget<CourierGame>(
          game: _game,
          initialActiveOverlays: const ['TitleScreen'],
          overlayBuilderMap: {
            'TitleScreen': (context, game) => TitleScreen(
                  highDistance: widget.storageService.highDistance,
                  careerTips: widget.storageService.careerTips,
                  isMuted: widget.audioController.isMuted,
                  unlockedAchievementsCount: _game.achievementManager.unlockedCount,
                  totalAchievementsCount: _game.achievementManager.totalCount,
                  dailyStars: widget.storageService.dailyStars,
                  equippedBoosters: _equippedBoosters,
                  onToggleMute: _toggleMute,
                  onOpenLocker: _openLocker,
                  onOpenBodega: _openBodega,
                  onOpenAchievements: _openAchievements,
                  onOpenDailyShift: _openDailyShift,
                  onStartGame: _startGame,
                ),
            'BodegaModal': (context, game) => BodegaModal(
                  storageService: widget.storageService,
                  equippedBoosters: _equippedBoosters,
                  onEquippedBoostersChanged: _handleEquippedBoostersChanged,
                  onClose: _closeBodega,
                ),
            'DailyShiftModal': (context, game) => DailyShiftModal(
                  storageService: widget.storageService,
                  onStartDailyShift: _startDailyShift,
                ),
            'LockerModal': (context, game) => LockerModal(
                  careerTips: widget.storageService.careerTips,
                  unlockedSkins: widget.storageService.unlockedSkins,
                  equippedSkin: widget.storageService.equippedSkin,
                  onEquipSkin: _handleEquipSkin,
                  onUnlockSkin: _handleUnlockSkin,
                  onClose: _closeLocker,
                ),
            'AchievementsModal': (context, game) => AchievementsModal(
                  unlockedAchievementIds: widget.storageService.unlockedAchievements,
                  onClose: _closeAchievements,
                ),
            'HUD': (context, game) => AnimatedBuilder(
                  animation: _gameState,
                  builder: (context, _) => HUDOverlay(
                    gameState: _gameState,
                    isMuted: widget.audioController.isMuted,
                    onToggleMute: _toggleMute,
                    onPause: _togglePause,
                  ),
                ),
            'PauseMenu': (context, game) => PauseMenuModal(
                  gameState: _gameState,
                  onResume: _resumeGame,
                  onQuit: _quitToTitle,
                ),
            'GameOver': (context, game) => GameOverModal(
                  distance: _lastDistance,
                  tips: _lastTips,
                  isNewRecord: _isNewRecord,
                  careerTips: widget.storageService.careerTips,
                  completedContracts: _gameState.contractManager.completedCount,
                  contractBonusTips: _gameState.contractManager.totalBonusTips,
                  deliveriesCompleted: _gameState.deliveriesInRun,
                  grindsCompleted: _gameState.grindsInRun,
                  vaultsCompleted: _gameState.vaultsInRun,
                  onRestart: _restartGame,
                ),
          },
        ),
      ),
    );
  }
}
