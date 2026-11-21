import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioBackend implements AudioPlayerInterface {
  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {}

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async {}

  @override
  Future<void> stopBgm() async {}

  @override
  Future<void> setBgmVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> startAmbience(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopAmbience() async {}

  @override
  Future<void> setAmbienceVolume(double volume) async {}

  @override
  Future<bool> startLayer(String file, {double volume = 0.0}) async => true;

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}

  @override
  Future<void> setLayerPlaybackRate(double rate) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reduce Screen Shake Storage (Accessibility)', () {
    test('defaults to off and round-trips the preference', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.isReduceShake, isFalse,
          reason: 'full shake is the default experience');

      await storage.setReduceShake(true);
      expect(storage.isReduceShake, isTrue);

      // A fresh service reads the persisted preference.
      final reloaded = LocalStorageService();
      await reloaded.init();
      expect(reloaded.isReduceShake, isTrue);

      await storage.setReduceShake(false);
      expect(storage.isReduceShake, isFalse);
    });
  });

  group('Reduce Screen Shake Gating (Accessibility)', () {
    test('a full-strength shake lands at full trauma by default', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();

      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
        storageService: storage,
      );
      game.triggerScreenShake(0.8);
      expect(game.cameraJuice.trauma, closeTo(0.8, 0.001));
    });

    test('the reduced preference lands the same shake at a quarter', () async {
      SharedPreferences.setMockInitialValues({'courier_reduce_shake': true});
      final storage = LocalStorageService();
      await storage.init();

      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
        storageService: storage,
      );
      game.triggerScreenShake(0.8);
      expect(game.cameraJuice.trauma, closeTo(0.2, 0.001),
          reason: 'the impact still registers, the street stops lurching');

      // Flipping the preference mid-shift applies to the next impact.
      await storage.setReduceShake(false);
      game.triggerScreenShake(0.4);
      expect(game.cameraJuice.trauma, closeTo(0.6, 0.001),
          reason: '0.2 still decaying plus the full 0.4');
    });
  });

  group('Reduce Screen Shake Pause Menu Toggle (Accessibility)', () {
    testWidgets('the toggle renders, reports, and flips', (tester) async {
      final state = GameState()..startRun();
      state.pauseRun();

      bool? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenuModal(
              gameState: state,
              isReduceShake: false,
              onToggleReduceShake: (reduce) => reported = reduce,
              onResume: () {},
              onQuit: () {},
            ),
          ),
        ),
      );

      expect(find.text('Reduce Screen Shake'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reduce_shake_toggle')));
      expect(reported, isTrue,
          reason: 'tapping the row asks for the reduction on');

      // Re-render with the preference on: the switch reads it back.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenuModal(
              gameState: state,
              isReduceShake: true,
              onToggleReduceShake: (reduce) => reported = reduce,
              onResume: () {},
              onQuit: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('reduce_shake_toggle')));
      expect(reported, isFalse);
    });
  });
}
