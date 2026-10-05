import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_haptics.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

const _medium = 'HapticFeedbackType.mediumImpact';
const _heavy = 'HapticFeedbackType.heavyImpact';
const _light = 'HapticFeedbackType.lightImpact';

/// Every vibration the app asks the platform for, in order.
List<String> _listenForBuzzes() {
  final buzzes = <String>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') buzzes.add(call.arguments as String);
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return buzzes;
}

Future<CourierGame> _shift({LocalStorageService? storage}) async {
  final game = CourierGame(
    storageService: storage,
    audioController: GameAudioController()..isMuted = true,
  );
  await game.onLoad();
  game.gameState.startRun();
  return game;
}

Future<void> _pauseAShift(WidgetTester tester) async {
  await tester.tap(find.text('START SHIFT'));
  await settle(tester, frames: 10);
  await tester.tap(find.byKey(const Key('pause_button')));
  await settle(tester, frames: 3);
  expect(find.text('SHIFT ON HOLD'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The game never touched the vibration motor. With the sound off, which is
  // how a phone is usually held on a bus, a hit had only the screen shake to
  // say it happened.
  group('The three buzzes', () {
    test('a hit is medium, the end of the shift heavy, a milestone light', () async {
      final buzzes = _listenForBuzzes();
      GameHaptics()
        ..hit()
        ..shiftOver()
        ..milestone();
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, equals([_medium, _heavy, _light]));
    });

    test('switched off, the platform is not asked for anything', () async {
      final buzzes = _listenForBuzzes();
      GameHaptics(enabled: false)
        ..hit()
        ..shiftOver()
        ..milestone();
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, isEmpty);
    });
  });

  group('During a shift', () {
    test('each lost package buzzes once, and the last one is the heavy buzz', () async {
      final buzzes = _listenForBuzzes();
      final game = await _shift();
      expect(game.gameState.packages, equals(3));

      game.player.onDamage!();
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, equals([_medium]));

      game.player.onDamage!();
      game.player.onDamage!();
      await Future<void>.delayed(Duration.zero);
      expect(game.gameState.status, equals(GameStatus.gameOver));
      expect(buzzes, equals([_medium, _medium, _heavy]));
    });

    test('nothing buzzes once the shift is over', () async {
      final buzzes = _listenForBuzzes();
      final game = await _shift();
      game.gameState.packages = 1;
      game.player.onDamage!();
      game.player.onDamage!();
      game.player.onDamage!();
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, equals([_heavy]));
    });

    test('a 500 m milestone is a light buzz', () async {
      final buzzes = _listenForBuzzes();
      final game = await _shift();
      game.gameState.updateDistance(499.0);
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, isEmpty);
      game.gameState.updateDistance(500.0);
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, equals([_light]));
    });

    test('a courier who turned vibration off is left alone', () async {
      SharedPreferences.setMockInitialValues({'courier_haptics': false});
      final storage = LocalStorageService();
      await storage.init();
      final buzzes = _listenForBuzzes();
      final game = await _shift(storage: storage);
      expect(game.haptics.enabled, isFalse);
      game.player.onDamage!();
      game.gameState.updateDistance(500.0);
      await Future<void>.delayed(Duration.zero);
      expect(buzzes, isEmpty);
    });

    test('the saved choice is read again at the start of every shift', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();
      expect(storage.isHapticsEnabled, isTrue, reason: 'on until switched off');
      final game = await _shift(storage: storage);
      expect(game.haptics.enabled, isTrue);

      await storage.setHapticsEnabled(false);
      game.restartRun();
      expect(game.haptics.enabled, isFalse);
    });
  });

  group('The Vibration switch in the pause menu', () {
    Widget menu({required bool on, ValueChanged<bool>? onToggle}) => MaterialApp(
          home: Scaffold(
            body: PauseMenuModal(
              gameState: GameState(),
              onResume: () {},
              onQuit: () {},
              isHapticsOn: on,
              onToggleHaptics: onToggle,
            ),
          ),
        );

    testWidgets('on a phone it is there and reports the flip', (tester) async {
      bool? asked;
      await tester.pumpWidget(menu(on: true, onToggle: (value) => asked = value));
      expect(find.byKey(const Key('haptics_toggle')), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('haptics_switch'))).value, isTrue);

      await tester.tap(find.byKey(const Key('haptics_toggle')));
      await tester.pump();
      expect(asked, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a computer there is nothing to switch', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(menu(on: true, onToggle: (_) {}));
        expect(find.byKey(const Key('haptics_toggle')), findsNothing);
        // The other switch is still there.
        expect(find.byKey(const Key('reduce_flash_toggle')), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('without a handler it is not offered', (tester) async {
      await tester.pumpWidget(menu(on: true));
      expect(find.byKey(const Key('haptics_toggle')), findsNothing);
    });
  });

  group('In the running app', () {
    testWidgets('switching it off is saved and silences the game; on again answers with a buzz',
        (tester) async {
      final harness = await bootApp(tester);
      final buzzes = _listenForBuzzes();
      await _pauseAShift(tester);
      final game = gameOf(tester);
      expect(game.haptics.enabled, isTrue);

      await tester.tap(find.byKey(const Key('haptics_switch')));
      await settle(tester, frames: 3);
      expect(harness.storage.isHapticsEnabled, isFalse);
      expect(game.haptics.enabled, isFalse);
      expect(tester.widget<Switch>(find.byKey(const Key('haptics_switch'))).value, isFalse);
      expect(buzzes, isEmpty);

      await tester.tap(find.byKey(const Key('haptics_switch')));
      await settle(tester, frames: 3);
      expect(harness.storage.isHapticsEnabled, isTrue);
      expect(game.haptics.enabled, isTrue);
      expect(buzzes, equals([_medium]));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a saved "off" is how the next launch starts', (tester) async {
      await bootApp(tester, prefs: {'courier_haptics': false});
      await _pauseAShift(tester);
      expect(gameOf(tester).haptics.enabled, isFalse);
      expect(tester.widget<Switch>(find.byKey(const Key('haptics_switch'))).value, isFalse);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the pause card still fits a small phone with both switches', (tester) async {
      const phone = Size(667, 375);
      await bootApp(tester, size: phone);
      await _pauseAShift(tester);
      expect(tester.takeException(), isNull);
      for (final key in ['reduce_flash_toggle', 'haptics_toggle', 'resume_shift_button']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.top, greaterThanOrEqualTo(0.0), reason: key);
        expect(rect.bottom, lessThanOrEqualTo(phone.height), reason: key);
      }
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
