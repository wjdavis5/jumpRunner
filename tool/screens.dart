// Pictures of every screen of the app, without a phone or a browser.
//
//   flutter test tool/screens.dart
//   flutter test tool/screens.dart --dart-define=ONLY=upright-375
//   flutter test tool/screens.dart --dart-define=ONLY=street
//
// writes PNGs to build/screens/ (or --dart-define=OUT=some/dir), in about
// half a minute:
//
// - the title card, the four depot cards, the HUD, the pause menu and the
//   results card, at each of the sizes below;
// - the street itself at 960x540 (`street-*`): each coaching hint over its
//   hazard, and a minute of a seeded street played with random presses, one
//   picture every five seconds.
//
// Text is drawn in the app's own font, as on a device. A character that
// font does not have comes out as an empty box, here and in the web build:
// see `withStars`.
//
// It is not part of the test suite: `flutter test` only runs files named
// *_test.dart under test/.
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
// ignore_for_file: invalid_use_of_internal_member
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

import '../test/support/app_harness.dart';
import '../test/support/bare_street.dart';
import '../test/support/real_fonts.dart';

const _sizes = {
  'upright-320': Size(320, 568),
  'upright-375': Size(375, 667),
  'upright-430': Size(430, 932),
  'phone-568': Size(568, 320),
  'phone-667': Size(667, 375),
  'phone-844': Size(844, 390),
  'design-960': Size(960, 540),
  'laptop-1366': Size(1366, 768),
};

const _only = String.fromEnvironment('ONLY');
const _out = String.fromEnvironment('OUT', defaultValue: 'build/screens');

Future<void> _shot(WidgetTester tester, String name) async {
  await settle(tester, frames: 3);
  final file = File('${Directory.current.path}/$_out/$name.png');
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(file.uri));
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (i % 20 == 0) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
}

const double _frame = 1 / 60;

/// The game's own canvas, as it stands, to a PNG.
Future<void> _streetShot(CourierGame game, String name) async {
  final recorder = ui.PictureRecorder();
  game.render(Canvas(recorder));
  final image = await recorder.endRecording().toImage(960, 540);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('${Directory.current.path}/$_out/street-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  image.dispose();
}

Future<CourierGame> _mounted(WorldChunkManager street, {int record = 0}) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: street,
    personalRecordDistance: record,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  return game;
}

/// A chunk holding [types] in order, [gap] px apart, and nothing else.
ChunkData _chunkOf(List<ObstacleType> types, double startX, {double gap = 400.0}) {
  var x = startX + 100.0;
  final obstacles = <ObstacleData>[];
  for (final type in types) {
    final size = ObstacleComponent.defaultSizeForType(type);
    obstacles.add(ObstacleData(type: type, x: x, y: 460.0 - size.y, width: size.x, height: size.y));
    x += size.x + gap;
  }
  return ChunkData(obstacles: obstacles, pickups: const []);
}

/// Runs the street until the first hazard of [type] is [x] px across the
/// screen or nearer.
Future<void> _until(CourierGame game, ObstacleType type, double x) async {
  for (var f = 0; f < 60 * 30; f++) {
    game.gameState.packages = game.gameState.maxPackages;
    game.update(_frame);
    if (f % 10 == 0) await Future<void>.delayed(Duration.zero);
    final seen = game.activeObstacles.where((o) => o.type == type);
    if (seen.isNotEmpty && seen.first.position.x <= x) return;
  }
  fail('no $type came within $x px');
}

void _street() {
  // A first shift, and what it is taught: one picture of each hint over the
  // hazard it is about, and one with two of them up at once.
  const lessons = {
    'hint-tap': <ObstacleType>[ObstacleType.scooter],
    'hint-leap-van': [ObstacleType.van],
    'hint-leap-train': [ObstacleType.thirdRail, ObstacleType.subwayTrain],
    'hint-birds': [ObstacleType.pigeonFlock],
    'hint-van-then-birds': [ObstacleType.van, ObstacleType.pigeonFlock],
  };
  for (final lesson in lessons.entries) {
    test('street: ${lesson.key}', () async {
      final street = ScriptedStreet();
      // Only a courier with no record at all is told to tap, and the game
      // says it over the first thing on the street whatever that is (the
      // warm-up makes sure it is something a tap clears). The other
      // lessons are shown to a courier with a short record.
      final game = await _mounted(street, record: lesson.key == 'hint-tap' ? 0 : 50);
      street.build = (startX, speed) => _chunkOf(lesson.value, startX, gap: 260.0);
      game.restartRun();
      await _until(game, lesson.value.first, 520);
      await _streetShot(game, lesson.key);
    });
  }

  // The street as generated, a station at every chance, played badly on
  // purpose: random presses land on rails, awnings and hooks, and set off
  // the floating scores.
  test('street: a minute of seed 7', () async {
    final game = await _mounted(
      WorldChunkManager(random: math.Random(7))..subwayStationChance = 1.0,
      record: 180,
    );
    final rng = math.Random(7);
    var held = false;
    var next = 0;
    for (var f = 0; f < 60 * 60; f++) {
      game.gameState.packages = game.gameState.maxPackages;
      if (f >= next) {
        held ? game.letGoOfJump('tool') : game.holdJump('tool');
        next = f + (held ? 10 + rng.nextInt(40) : 2 + rng.nextInt(30));
        held = !held;
      }
      game.update(_frame);
      if (f % 5 == 0) await Future<void>.delayed(Duration.zero);
      if (f % 300 == 299) await _streetShot(game, 'seed7-${((f + 1) ~/ 60).toString().padLeft(2, '0')}s');
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_only.isEmpty || _only == 'street') _street();

  // "Golden" files that are always rewritten: this only takes pictures.
  autoUpdateGoldenFiles = true;
  setUpAll(() async {
    await loadRealFonts();
    Directory('${Directory.current.path}/$_out').createSync(recursive: true);
  });

  for (final entry in _sizes.entries) {
    final name = entry.key;
    if (_only.isNotEmpty && _only != name) continue;

    testWidgets('screens at $name', (tester) async {
      await bootApp(
        tester,
        size: entry.value,
        prefs: {
          'courier_career_tips': 128450,
          'courier_lifetime_tips': 245300,
          'courier_high_distance': 3412,
          'courier_lifetime_deliveries': 1287,
          'courier_daily_stars': 14,
        },
      );
      await _shot(tester, '$name-1-title');

      for (final card in const ['locker', 'bodega', 'trophies', 'daily_shift']) {
        await tester.tap(find.byKey(Key('open_${card}_button')));
        await settle(tester, frames: 8);
        await _shot(tester, '$name-2-$card');
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 8);
      }

      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 8);
      final state = gameOf(tester).gameState;
      // Three seconds of street, kept alive, with a five-figure tip count.
      for (var i = 0; i < 10; i++) {
        state.packages = state.maxPackages;
        await _frames(tester, 20);
      }
      state.addTip(98765);
      await _shot(tester, '$name-3-hud');

      await tester.tap(find.byKey(const Key('pause_button')));
      await settle(tester, frames: 8);
      await _shot(tester, '$name-4-pause');

      await tester.tap(find.byKey(const Key('resume_shift_button')));
      // The resume count, then on with the shift.
      await _frames(tester, 260);
      while (state.status == GameStatus.running) {
        state.applyHazardDamage();
      }
      for (var i = 0; i < 40 && find.text('START NEXT SHIFT').evaluate().isEmpty; i++) {
        await _frames(tester, 10);
      }
      await _shot(tester, '$name-5-results');
      // The results card's own timers run out before the test ends.
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
