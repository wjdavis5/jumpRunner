import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/main.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audio backend that plays nothing and remembers whether music is "on".
class SilentAudioBackend implements AudioPlayerInterface {
  bool bgmPlaying = false;

  @override
  Future<void> playSfx(String file, {double volume = 1.0}) async {}

  @override
  Future<void> startBgm(String file, {double volume = 0.7}) async => bgmPlaying = true;

  @override
  Future<void> stopBgm() async => bgmPlaying = false;

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

  @override
  Future<void> setLayerPlaybackRate(double rate) async {}
}

/// What a whole-app test needs to poke at once the app is running.
class AppHarness {
  AppHarness(this.storage, this.audioBackend);

  final LocalStorageService storage;
  final SilentAudioBackend audioBackend;
}

/// Boots the real [CourierDashApp] and waits for the title screen.
///
/// The game loads its assets with real async work, so the wait alternates
/// real time with pumped frames. [prefs] seeds the saved career.
Future<AppHarness> bootApp(
  WidgetTester tester, {
  Size size = const Size(960, 540),
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final storage = LocalStorageService();
  await storage.init();
  final backend = SilentAudioBackend();
  final audio = GameAudioController(backend: backend, storageService: storage);

  await tester.pumpWidget(CourierDashApp(storageService: storage, audioController: audio));
  for (var i = 0; i < 20 && find.text('START SHIFT').evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.text('START SHIFT'), findsOneWidget, reason: 'the title screen never appeared');
  return AppHarness(storage, backend);
}

/// Lets pending async work land and pumps [frames] frames.
Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The live game behind the app's [GameWidget].
CourierGame gameOf(WidgetTester tester) =>
    tester.widget<GameWidget<CourierGame>>(find.byType(GameWidget<CourierGame>)).game!;
