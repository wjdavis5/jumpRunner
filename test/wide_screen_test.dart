// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const double _frame = 1.0 / 60.0;

Future<CourierGame> _mountedGame(double width, double height) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: WorldChunkManager(random: math.Random(3)),
    personalRecordDistance: 500,
  );
  game.onGameResize(Vector2(width, height));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  return game;
}

Future<void> _run(CourierGame game, int frames) async {
  for (var i = 0; i < frames; i++) {
    if (game.gameState.packages < GameState.defaultMaxPackages) {
      game.gameState.packages = GameState.defaultMaxPackages;
    }
    game.update(_frame);
    if (i % 3 == 0) await Future<void>.delayed(Duration.zero);
  }
}

/// Fraction of a [width] x [height] screen the game left unpainted.
Future<double> _unpainted(CourierGame game, int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // A colour nothing in the game uses: any of it left over is a bar or hole.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF00FF),
  );
  game.render(canvas);
  final image = await recorder.endRecording().toImage(width, height);
  final ByteData data = (await image.toByteData())!;
  image.dispose();

  var holes = 0;
  final total = width * height;
  for (var i = 0; i < total; i++) {
    if (data.getUint8(i * 4) > 240 &&
        data.getUint8(i * 4 + 1) < 15 &&
        data.getUint8(i * 4 + 2) > 240) {
      holes++;
    }
  }
  return holes / total;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('How much street a screen shows', () {
    test('a 16:9 screen shows the classic 960', () {
      expect(CourierGame.visibleWidthFor(Vector2(960, 540)), equals(960.0));
      expect(CourierGame.visibleWidthFor(Vector2(1920, 1080)), equals(960.0));
    });

    test('a phone held sideways shows more, in proportion', () {
      expect(CourierGame.visibleWidthFor(Vector2(844, 390)), equals(1169.0));
      expect(CourierGame.visibleWidthFor(Vector2(2400, 1080)), equals(1200.0));
    });

    test('it stops widening at 2.4:1', () {
      expect(CourierGame.visibleWidthFor(Vector2(1296, 540)), equals(1296.0));
      expect(CourierGame.visibleWidthFor(Vector2(3440, 1080)),
          equals(CourierGame.maxVisibleWidth));
    });

    test('squarer screens keep the full 960', () {
      expect(CourierGame.visibleWidthFor(Vector2(800, 600)), equals(960.0));
      expect(CourierGame.visibleWidthFor(Vector2(390, 844)), equals(960.0));
    });

    test('a screen with no size yet is treated as 16:9', () {
      expect(CourierGame.visibleWidthFor(Vector2.zero()), equals(960.0));
    });
  });

  group('A 16:9 screen is unchanged', () {
    test('camera, courier and viewport sit where they always did', () async {
      final game = await _mountedGame(960, 540);
      await _run(game, 30);
      expect(game.visibleWidth, equals(960.0));
      expect(game.camera.viewport.virtualSize, equals(Vector2(960, 540)));
      expect(game.camera.viewfinder.position.x, closeTo(480.0, 12.0));
      expect(game.player.position.x, equals(120.0));
      expect(await _unpainted(game, 960, 540), equals(0.0));
    });
  });

  group('A wide phone is filled edge to edge', () {
    test('no bars: every pixel of an 844x390 screen is painted', () async {
      final game = await _mountedGame(844, 390);
      expect(game.visibleWidth, equals(1169.0));
      expect(game.camera.viewport.virtualSize, equals(Vector2(1169, 540)));

      for (var i = 0; i < 8; i++) {
        await _run(game, 45);
        expect(await _unpainted(game, 844, 390), equals(0.0), reason: 'pass $i');
      }
    });

    test('the courier and the left edge stay put; the extra is road ahead',
        () async {
      final game = await _mountedGame(844, 390);
      await _run(game, 30);
      expect(game.player.position.x, equals(120.0));
      final view = game.camera.viewfinder;
      // Left edge of the view is still world x = 0 (give or take shake).
      expect(view.position.x - game.visibleWidth / 2, closeTo(0.0, 12.0));
    });

    test('still filled when the camera pulls back at top speed', () async {
      final game = await _mountedGame(1296, 540);
      await _run(game, 60);
      game.cameraJuice.currentZoom = game.cameraJuice.highSpeedZoom;
      game.camera.viewfinder.zoom = game.cameraJuice.highSpeedZoom;
      expect(await _unpainted(game, 1296, 540), equals(0.0));
    });

    test('hazards arrive from beyond the right edge, never pop in', () async {
      final game = await _mountedGame(1296, 540);
      final known = <int>{for (final o in game.activeObstacles) identityHashCode(o)};
      var nearest = double.infinity;
      for (var i = 0; i < 60 * 25; i++) {
        if (game.gameState.packages < GameState.defaultMaxPackages) {
          game.gameState.packages = GameState.defaultMaxPackages;
        }
        game.update(_frame);
        if (i % 3 == 0) await Future<void>.delayed(Duration.zero);
        for (final o in game.activeObstacles) {
          if (known.add(identityHashCode(o))) {
            nearest = math.min(nearest, o.position.x);
          }
        }
      }
      expect(nearest, lessThan(double.infinity), reason: 'hazards did spawn');
      expect(nearest, greaterThan(game.visibleWidth + 60.0));
    });

    test('the crash beat stays painted at the widest view', () async {
      final game = await _mountedGame(1296, 540);
      await _run(game, 40);
      game.triggerScreenShake(0.65);
      while (game.gameState.status != GameStatus.gameOver) {
        game.gameState.applyHazardDamage();
      }
      var frames = 0;
      while (game.deathSlowmo.isActive && frames < 120) {
        game.update(_frame);
        frames++;
        if (!game.deathSlowmo.isActive) break;
        expect(await _unpainted(game, 1296, 540), equals(0.0), reason: 'frame $frames');
      }
      expect(frames, greaterThan(20));
      // Back to rest, centred on the wide view.
      expect(game.camera.viewfinder.position.x, closeTo(648.0, 0.001));
    });
  });

  group('Screens that cannot be filled keep tidy bars', () {
    test('a 4:3 tablet is letterboxed around the full 960', () async {
      final game = await _mountedGame(800, 600);
      await _run(game, 30);
      expect(game.visibleWidth, equals(960.0));
      // 800 wide shows 960 x 540 at 800 x 450: a quarter of the height is bars.
      expect(await _unpainted(game, 800, 600), closeTo(0.25, 0.005));
    });

    test('an ultrawide monitor keeps side bars past 2.4:1', () async {
      final game = await _mountedGame(1600, 540);
      await _run(game, 30);
      expect(game.visibleWidth, equals(1296.0));
      expect(await _unpainted(game, 1600, 540), closeTo(304 / 1600, 0.005));
    });
  });

  group('Turning the phone or resizing the window mid-shift', () {
    test('the view widens and narrows without leaving holes', () async {
      final game = await _mountedGame(960, 540);
      await _run(game, 60);
      final distance = game.gameState.distanceMeters;

      game.onGameResize(Vector2(1296, 540));
      await _run(game, 2);
      expect(game.visibleWidth, equals(1296.0));
      expect(game.parallaxCity.viewWidth, equals(1296.0));
      expect(game.camera.viewfinder.position.x, closeTo(648.0, 12.0));
      expect(await _unpainted(game, 1296, 540), equals(0.0));

      game.onGameResize(Vector2(960, 540));
      await _run(game, 2);
      expect(game.visibleWidth, equals(960.0));
      expect(game.camera.viewfinder.position.x, closeTo(480.0, 12.0));
      expect(await _unpainted(game, 960, 540), equals(0.0));

      // The shift carried on through both changes.
      expect(game.gameState.status, equals(GameStatus.running));
      expect(game.gameState.distanceMeters, greaterThan(distance));
    });

    test('a paused shift is re-framed too', () async {
      final game = await _mountedGame(960, 540);
      await _run(game, 30);
      game.gameState.pauseRun();
      game.onGameResize(Vector2(844, 390));
      game.update(_frame);
      await Future<void>.delayed(Duration.zero);
      game.update(_frame);
      expect(game.camera.viewfinder.position.x, closeTo(584.5, 0.001));
      expect(await _unpainted(game, 844, 390), equals(0.0));
    });
  });
}
