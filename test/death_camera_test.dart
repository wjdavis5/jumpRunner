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

const double _frame = 1.0 / 60.0;

Future<CourierGame> _mountedGame() async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  for (var i = 0; i < 20; i++) {
    game.update(_frame);
    if (i % 3 == 0) await Future<void>.delayed(Duration.zero);
  }
  return game;
}

/// Loses the last package the way a real collision does: the hit itself
/// shakes the camera, then the game-over handler adds its own jolt.
void _fatalHit(CourierGame game) {
  while (game.gameState.packages > 1) {
    game.gameState.applyHazardDamage();
  }
  game.triggerScreenShake(0.65);
  game.gameState.applyHazardDamage();
  expect(game.gameState.status, equals(GameStatus.gameOver));
}

/// Fraction of the frame the game did not paint.
Future<double> _unpainted(CourierGame game) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // A colour nothing in the game uses: any of it left over is a hole.
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 960, 540),
    ui.Paint()..color = const ui.Color(0xFFFF00FF),
  );
  game.render(canvas);
  final image = await recorder.endRecording().toImage(960, 540);
  final ByteData data = (await image.toByteData())!;
  image.dispose();

  var holes = 0;
  const total = 960 * 540;
  for (var i = 0; i < total; i++) {
    final r = data.getUint8(i * 4);
    final g = data.getUint8(i * 4 + 1);
    final b = data.getUint8(i * 4 + 2);
    if (r > 240 && g < 15 && b > 240) holes++;
  }
  return holes / total;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('The fatal hit shakes the camera', () {
    test('Trauma plays out during the slow-motion beat', () async {
      final game = await _mountedGame();
      _fatalHit(game);
      expect(game.cameraJuice.trauma, equals(1.0));

      var peakAngle = 0.0;
      var peakOffset = 0.0;
      double? lastTrauma;
      var frames = 0;
      while (game.deathSlowmo.isActive && frames < 120) {
        game.update(_frame);
        frames++;
        if (!game.deathSlowmo.isActive) break;
        peakAngle = math.max(peakAngle, game.camera.viewfinder.angle.abs());
        peakOffset = math.max(peakOffset, game.cameraJuice.shakeOffset.length);
        // The shake fades: it never grows once the beat is under way.
        if (lastTrauma != null) {
          expect(game.cameraJuice.trauma, lessThan(lastTrauma));
        }
        lastTrauma = game.cameraJuice.trauma;
      }

      // Before the fix the trauma sat untouched until the beat reset it, so
      // the hardest hit in the game was the only one with no shake at all.
      expect(peakAngle, greaterThan(0.003));
      expect(peakOffset, greaterThan(3.0));
      expect(lastTrauma, lessThan(0.3));
    });

    test('The camera is level and centred again when the results appear',
        () async {
      final game = await _mountedGame();
      _fatalHit(game);
      for (var i = 0; i < 120 && game.deathSlowmo.isActive; i++) {
        game.update(_frame);
      }
      expect(game.deathSlowmo.isActive, isFalse);

      final view = game.camera.viewfinder;
      expect(view.angle, equals(0.0));
      expect(view.zoom, equals(1.0));
      expect(view.position.x, closeTo(480.0, 0.001));
      expect(view.position.y, closeTo(270.0, 0.001));
      expect(game.cameraJuice.trauma, equals(0.0));
    });
  });

  group('The death beat starts from the camera the run left behind', () {
    test('A courier at top speed gets no zoom jump on the hit', () async {
      final game = await _mountedGame();
      // At top speed the camera has pulled back to its widest framing.
      game.cameraJuice.currentZoom = game.cameraJuice.highSpeedZoom;
      game.camera.viewfinder.zoom = game.cameraJuice.highSpeedZoom;
      _fatalHit(game);

      var previous = game.camera.viewfinder.zoom;
      var frames = 0;
      while (game.deathSlowmo.isActive && frames < 120) {
        game.update(_frame);
        frames++;
        if (!game.deathSlowmo.isActive) break;
        final zoom = game.camera.viewfinder.zoom;
        // It only ever pushes in, and by a few percent a frame at most. It
        // used to snap from 0.94 to 1.0 on the first frame.
        expect(zoom, greaterThanOrEqualTo(previous), reason: 'frame $frames');
        expect(zoom - previous, lessThan(0.04), reason: 'frame $frames');
        previous = zoom;
      }
      expect(previous, greaterThan(1.2));
    });

    test('An airborne courier gets no vertical jump on the hit', () async {
      final game = await _mountedGame();
      // While the courier is up high the camera rides 35 px above centre.
      game.cameraTargetY = 235.0;
      game.cameraJuice.trauma = 0.0;
      while (game.gameState.status != GameStatus.gameOver) {
        game.gameState.applyHazardDamage();
      }
      game.cameraJuice.trauma = 0.0; // isolate the eased path from the shake

      game.update(_frame);
      final firstY = game.camera.viewfinder.position.y;
      expect(firstY, closeTo(235.0, 0.5));
      game.update(_frame);
      expect((game.camera.viewfinder.position.y - firstY).abs(), lessThan(6.0));
    });
  });

  group('The death beat never shows an unpainted edge', () {
    test('Every frame is fully painted, at the widest zoom and hardest shake',
        () async {
      final game = await _mountedGame();
      game.cameraJuice.currentZoom = game.cameraJuice.highSpeedZoom;
      game.camera.viewfinder.zoom = game.cameraJuice.highSpeedZoom;
      _fatalHit(game);

      var frames = 0;
      while (game.deathSlowmo.isActive && frames < 120) {
        game.update(_frame);
        frames++;
        if (!game.deathSlowmo.isActive) break;
        expect(await _unpainted(game), equals(0.0), reason: 'frame $frames');
      }
      expect(frames, greaterThan(20));
    });
  });
}
