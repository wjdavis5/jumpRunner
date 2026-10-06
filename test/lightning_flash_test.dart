import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/lightning_flash_component.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioBackend implements AudioPlayerInterface {
  final List<String> playedSfx = [];

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {
    playedSfx.add(file);
  }

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
  Future<void> startLayer(String file, {double volume = 0.0}) async {}

  @override
  Future<void> stopLayer() async {}

  @override
  Future<void> setLayerVolume(double volume) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LightningFlashComponent Unit Tests (Issue #97)', () {
    test('initializes with default dimensions and idle state', () {
      final lightning = LightningFlashComponent(
        size: Vector2(960, 540),
      );

      expect(lightning.size.x, equals(960.0));
      expect(lightning.size.y, equals(540.0));
      expect(lightning.isFlashing, isFalse);
      expect(lightning.currentFlashAlpha, equals(0.0));
      expect(lightning.currentSpecularBoost, equals(0.0));
      expect(lightning.reduceFlash, isFalse);
      expect(lightning.priority, equals(6));
    });

    test('triggerStrike initiates multi-phase flash sequence and schedules thunder delay', () {
      var thunderPlayed = false;
      final lightning = LightningFlashComponent(
        onThunderRumble: () {
          thunderPlayed = true;
        },
      );

      lightning.triggerStrike(customBoltX: 480.0);
      expect(lightning.isFlashing, isTrue);

      // Precursor phase (0 to 30ms): flash alpha ramps up
      lightning.update(0.02);
      expect(lightning.isFlashing, isTrue);
      expect(lightning.currentFlashAlpha, greaterThan(0.0));
      expect(lightning.currentFlashAlpha, lessThanOrEqualTo(0.45));

      // Dark dip phase (30ms to 60ms): alpha dips briefly
      lightning.update(0.025); // t = 0.045s
      expect(lightning.currentFlashAlpha, lessThan(0.45));
      expect(lightning.currentFlashAlpha, greaterThan(0.10));

      // Main return stroke burst phase (60ms to 120ms): jumps towards 1.0 peak
      lightning.update(0.045); // t = 0.09s
      expect(lightning.currentFlashAlpha, greaterThan(0.50));
      expect(lightning.currentSpecularBoost, greaterThan(0.45));

      // Tail decay phase (120ms to 320ms): decays gradually
      lightning.update(0.12); // t = 0.21s
      expect(lightning.isFlashing, isTrue);
      expect(lightning.currentFlashAlpha, lessThan(0.60));

      // After flash duration (~320ms): sequence completes and resets
      lightning.update(0.20); // t > 0.40s
      expect(lightning.isFlashing, isFalse);
      expect(lightning.currentFlashAlpha, equals(0.0));
      expect(lightning.currentSpecularBoost, equals(0.0));
      expect(thunderPlayed, isTrue);
    });

    test('reduceFlash attenuates flash alpha and dampens specular boost', () {
      final normal = LightningFlashComponent(reduceFlash: false);
      final reduced = LightningFlashComponent(reduceFlash: true);

      normal.triggerStrike(customBoltX: 480.0);
      reduced.triggerStrike(customBoltX: 480.0);

      // Step to peak return stroke burst (t = 0.10s)
      normal.update(0.10);
      reduced.update(0.10);

      expect(normal.currentFlashAlpha, greaterThan(0.70));
      expect(reduced.currentFlashAlpha, lessThanOrEqualTo(0.25));
      expect(reduced.currentFlashAlpha, lessThan(normal.currentFlashAlpha));
      expect(reduced.currentSpecularBoost, lessThan(normal.currentSpecularBoost));
    });

    test('render paints without errors for both standard and photosensitive reduced modes', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final normal = LightningFlashComponent(reduceFlash: false);
      normal.triggerStrike(customBoltX: 400.0);
      normal.update(0.08); // Mid-flash with active bolt path
      expect(() => normal.render(canvas), returnsNormally);

      final reduced = LightningFlashComponent(reduceFlash: true);
      reduced.triggerStrike(customBoltX: 400.0);
      reduced.update(0.08); // Reduced flash mode
      expect(() => reduced.render(canvas), returnsNormally);
    });

    test('reset clears active flash, thunder timer, and resets to idle state', () {
      final lightning = LightningFlashComponent();
      lightning.triggerStrike();
      lightning.update(0.05);
      expect(lightning.isFlashing, isTrue);

      lightning.reset();
      expect(lightning.isFlashing, isFalse);
      expect(lightning.currentFlashAlpha, equals(0.0));
      expect(lightning.currentSpecularBoost, equals(0.0));
    });

    test('stochastic strike intervals trigger periodically during rain', () {
      final lightning = LightningFlashComponent();
      lightning.rainIntensity = 0.8;
      lightning.isRaining = true;

      // Update in simulation frames until strike triggers (max delay is 16.0s = 320 steps of 0.05)
      for (var i = 0; i < 400; i++) {
        lightning.update(0.05);
        if (lightning.isFlashing) break;
      }
      expect(lightning.isFlashing, isTrue);
    });
  });

  group('LocalStorageService Reduce Flash Accessibility Tests (Issue #97)', () {
    test('persists and loads reduce flash preference', () async {
      final storage = LocalStorageService();
      await storage.init();

      expect(storage.isReduceFlash, isFalse);
      await storage.setReduceFlash(true);
      expect(storage.isReduceFlash, isTrue);
      await storage.setReduceFlash(false);
      expect(storage.isReduceFlash, isFalse);
    });
  });

  group('GameAudioController Thunder Audio Tests (Issue #97)', () {
    test('playThunder records play in attemptedPlays and respects mute', () async {
      final backend = MockAudioBackend();
      final audio = GameAudioController(backend: backend);
      expect(audio.attemptedPlays.contains(GameAudioController.sfxThunder), isFalse);

      await audio.playThunder();
      expect(audio.attemptedPlays.contains(GameAudioController.sfxThunder), isTrue);
      expect(backend.playedSfx.contains(GameAudioController.sfxThunder), isTrue);

      audio.isMuted = true;
      final countBefore = audio.attemptedPlays.where((p) => p == GameAudioController.sfxThunder).length;
      await audio.playThunder();
      final countAfter = audio.attemptedPlays.where((p) => p == GameAudioController.sfxThunder).length;
      expect(countAfter, equals(countBefore));
    });
  });

  group('ParallaxCity Specular Reflections with Lightning Boost (Issue #97)', () {
    test('updateLighting accepts lightning specular boost and boosts wet asphalt sheen', () {
      final city = ParallaxCityComponent(size: Vector2(960, 540));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      city.updateLighting(2000.0, 0.05, 0.8, 0.0);
      expect(city.lightningSpecularBoost, equals(0.0));
      expect(() => city.render(canvas), returnsNormally);

      city.updateLighting(2000.0, 0.05, 0.8, 0.9);
      expect(city.lightningSpecularBoost, equals(0.9));
      expect(() => city.render(canvas), returnsNormally);
    });
  });

  group('CourierGame Integration with LightningFlashComponent (Issue #97)', () {
    testWidgets('mounts, updates, and syncs weather state with lightning component', (tester) async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      expect(game.lightningComponent, isNotNull);
      expect(game.world.children.whereType<LightningFlashComponent>().length, equals(1));
      game.gameState.startRun();

      // Trigger rainy weather
      game.weatherController.setManualIntensity(0.85);
      game.update(0.05);

      expect(game.lightningComponent.rainIntensity, equals(0.85));
      expect(game.lightningComponent.isRaining, isTrue);

      game.restartRun();
      expect(game.lightningComponent.isFlashing, isFalse);
    });

    testWidgets('rainy rush daily modifier activates lightning storm state on start', (tester) async {
      final game = CourierGame(
        audioController: GameAudioController(backend: MockAudioBackend()),
      );
      await game.onLoad();

      game.restartRun(
        shift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.rainyRush,
          targetDistanceMeters: 500,
          completionBonusTips: 100,
        ),
      );

      expect(game.lightningComponent.rainIntensity, equals(0.8));
      expect(game.lightningComponent.isRaining, isTrue);
    });
  });

  group('PauseMenuModal Accessibility Reduce Flash UI Tests (Issue #97)', () {
    testWidgets('renders reduce_flash_toggle switch and handles tap', (tester) async {
      var toggledValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenuModal(
              gameState: GameState(),
              isReduceFlash: false,
              onToggleReduceFlash: (val) {
                toggledValue = val;
              },
              onResume: () {},
              onQuit: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('reduce_flash_toggle')), findsOneWidget);
      expect(find.text('Reduce Lightning Flash'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on), findsOneWidget);

      await tester.tap(find.byKey(const Key('reduce_flash_toggle')));
      await tester.pumpAndSettle();

      expect(toggledValue, isTrue);
    });

    testWidgets('renders flash_off icon when isReduceFlash is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenuModal(
              gameState: GameState(),
              isReduceFlash: true,
              onResume: () {},
              onQuit: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.flash_off), findsOneWidget);
    });
  });
}
