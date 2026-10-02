import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/audio_controller.dart';
import 'game/courier_game.dart';
import 'game/logic/game_state.dart';
import 'services/storage_service.dart';
import 'ui/game_over_modal.dart';
import 'ui/hud_overlay.dart';
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

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _game = CourierGame(
      gameState: _gameState,
      audioController: widget.audioController,
    );

    _game.onRunConcluded = _handleRunConcluded;
  }

  Future<void> _handleRunConcluded() async {
    _lastDistance = _gameState.distanceMeters.floor();
    _lastTips = _gameState.tips;

    _isNewRecord = await widget.storageService.recordRun(
      distance: _lastDistance,
      tips: _lastTips,
    );

    if (mounted) {
      setState(() {});
      _game.overlays.add('GameOver');
    }
  }

  void _startGame() {
    _gameState.startRun();
    _game.restartRun();
    _game.overlays.remove('TitleScreen');
    _game.overlays.add('HUD');
  }

  void _restartGame() {
    _game.overlays.remove('GameOver');
    _game.restartRun();
  }

  void _toggleMute() {
    widget.audioController.toggleMute();
    setState(() {});
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
                  onToggleMute: _toggleMute,
                  onStartGame: _startGame,
                ),
            'HUD': (context, game) => AnimatedBuilder(
                  animation: _gameState,
                  builder: (context, _) => HUDOverlay(
                    gameState: _gameState,
                    isMuted: widget.audioController.isMuted,
                    onToggleMute: _toggleMute,
                  ),
                ),
            'GameOver': (context, game) => GameOverModal(
                  distance: _lastDistance,
                  tips: _lastTips,
                  isNewRecord: _isNewRecord,
                  careerTips: widget.storageService.careerTips,
                  onRestart: _restartGame,
                ),
          },
        ),
      ),
    );
  }
}
