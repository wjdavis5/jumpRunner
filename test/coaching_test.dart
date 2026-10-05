// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/coach_hint_component.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/input_hints.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const double _frame = 1.0 / 60.0;

Future<CourierGame> _mountedGame({int seed = 3, int record = 0}) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: WorldChunkManager(random: math.Random(seed)),
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

/// Runs the shift, never letting it end, until [done] or the frame budget.
Future<int> _runUntil(
  CourierGame game,
  bool Function() done, {
  int maxFrames = 60 * 60,
}) async {
  var frames = 0;
  while (!done() && frames < maxFrames) {
    if (game.gameState.packages < GameState.defaultMaxPackages) {
      game.gameState.packages = GameState.defaultMaxPackages;
    }
    game.update(_frame);
    frames++;
    if (frames % 3 == 0) await Future<void>.delayed(Duration.zero);
  }
  return frames;
}

ObstacleComponent _firstHazard(CourierGame game) =>
    game.activeObstacles.reduce((a, b) => a.position.x < b.position.x ? a : b);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Coaching words match the input the device has', () {
    test('touch devices are told to tap and hold', () {
      expect(CoachText.hop(keyboard: false), equals('TAP TO HOP!'));
      expect(CoachText.leap(keyboard: false), equals('HOLD TO LEAP!'));
    });

    test('keyboards are told which key', () {
      expect(CoachText.hop(keyboard: true), equals('PRESS SPACE TO HOP!'));
      expect(CoachText.leap(keyboard: true), equals('HOLD SPACE TO LEAP!'));
    });

    test('desktop platforms expect a keyboard, phones do not', () {
      try {
        for (final platform in TargetPlatform.values) {
          debugDefaultTargetPlatformOverride = platform;
          final desktop = platform == TargetPlatform.windows ||
              platform == TargetPlatform.macOS ||
              platform == TargetPlatform.linux;
          expect(expectsKeyboard, equals(desktop), reason: '$platform');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('A hint follows the hazard it is about', () {
    PositionComponent hazardAt(double x) =>
        PositionComponent(position: Vector2(x, 400), size: Vector2(40, 30));

    test('it stays centred over the hazard as the street scrolls', () {
      final hazard = hazardAt(600);
      final hint = CoachHintComponent(
        text: 'TAP TO HOP!',
        position: Vector2(0, 200),
        follow: hazard,
        dismissBehindX: 120,
      );
      for (var i = 0; i < 30; i++) {
        hazard.position.x -= 5;
        hint.update(_frame);
        final hazardCenter = hazard.position.x + hazard.size.x / 2;
        expect(hint.position.x + hint.panelWidth / 2, closeTo(hazardCenter, 0.001));
      }
      expect(hint.isDismissing, isFalse);
    });

    test('it waits at the screen edge while the hazard is still off screen', () {
      final hazard = hazardAt(1400);
      final hint = CoachHintComponent(
        text: 'TAP TO HOP!',
        position: Vector2(0, 200),
        follow: hazard,
        maxX: 944,
      );
      hint.update(_frame);
      expect(hint.position.x + hint.panelWidth, closeTo(944, 0.001));
      expect(hint.isWaiting, isFalse, reason: 'shown straight away by default');
    });

    test('it leaves once the hazard is behind the courier', () {
      final hazard = hazardAt(200);
      final hint = CoachHintComponent(
        text: 'TAP TO HOP!',
        position: Vector2(0, 200),
        follow: hazard,
        dismissBehindX: 120,
      );
      hint.update(_frame);
      expect(hint.isDismissing, isFalse);

      hazard.position.x = 70; // right edge at 110, behind the courier at 120
      hint.update(_frame);
      expect(hint.isDismissing, isTrue);
    });

    test('a far hazard does not time the hint out before it arrives', () {
      final hazard = hazardAt(900);
      final hint = CoachHintComponent(
        text: 'TAP TO HOP!',
        position: Vector2(0, 200),
        follow: hazard,
      );
      for (var i = 0; i < 100; i++) {
        hint.update(0.1); // 10 s, past the 7 s failsafe of a free hint
      }
      expect(hint.isDismissing, isFalse);
      for (var i = 0; i < 110; i++) {
        hint.update(0.1);
      }
      expect(hint.isDismissing, isTrue, reason: 'but it does give up eventually');
    });

    test('it can hold back until the hazard is about to appear', () {
      final hazard = hazardAt(1500);
      final hint = CoachHintComponent(
        text: 'HOLD TO LEAP!',
        position: Vector2(0, 200),
        follow: hazard,
        showWithinX: 1000,
      );
      final startY = hint.position.y;
      for (var i = 0; i < 600; i++) {
        hint.update(_frame);
      }
      expect(hint.isWaiting, isTrue);
      expect(hint.isDismissing, isFalse, reason: 'the clock has not started');
      expect(hint.position.y, equals(startY));

      hazard.position.x = 990;
      hint.update(_frame);
      expect(hint.isWaiting, isFalse);
    });
  });

  group('A first shift is coached on the hop', () {
    test('the hint names the hop and rides above the opening hazard', () async {
      final game = await _mountedGame();
      final hint = game.firstRunCoach!;
      final hazard = _firstHazard(game);
      expect(hint.text, equals('TAP TO HOP!'));
      expect(hint.follow, same(hazard));
      // The warm-up only serves hazards a tap clears.
      expect(hazard.type, anyOf(ObstacleType.scooter, ObstacleType.dog));

      await _runUntil(game, () => hazard.position.x < 500);
      final hazardCenter = hazard.position.x + hazard.size.x / 2;
      expect(
        (hint.position.x + hint.panelWidth / 2 - hazardCenter).abs(),
        lessThan(12.0),
        reason: 'at most a frame of scroll behind',
      );
      expect(hint.isDismissing, isFalse);
    });

    test('it leaves when the hazard has gone by, jump or no jump', () async {
      final game = await _mountedGame();
      final hint = game.firstRunCoach!;
      final hazard = _firstHazard(game);
      await _runUntil(
        game,
        () => hazard.position.x + hazard.size.x < game.player.position.x - 10,
      );
      expect(hint.isDismissing, isTrue);
    });

    test('a desktop browser is told to press Space', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final game = await _mountedGame();
        expect(game.firstRunCoach!.text, equals('PRESS SPACE TO HOP!'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('a courier with a record is not coached on the hop', () async {
      final game = await _mountedGame(record: 120);
      expect(game.firstRunCoach, isNull);
    });
  });

  group('A novice is coached on the leap at the first van', () {
    test('the hint appears with the van and rides above it', () async {
      final game = await _mountedGame(record: 120);
      expect(game.leapCoach, isNull, reason: 'no van in the warm-up');

      await _runUntil(
        game,
        () => game.leapCoach != null && !game.leapCoach!.isWaiting,
      );
      final hint = game.leapCoach!;
      final van = hint.follow! as ObstacleComponent;
      expect(hint.text, equals('HOLD TO LEAP!'));
      expect(van.type, equals(ObstacleType.van));
      expect(game.gameState.distanceMeters,
          greaterThanOrEqualTo(WorldChunkManager.warmupEndMeters));
      // It shows up as the van is about to enter the screen, not before.
      expect(van.position.x, lessThanOrEqualTo(1000.0));
      expect(van.position.x, greaterThan(900.0));

      await _runUntil(game, () => van.position.x < 500);
      final vanCenter = van.position.x + van.size.x / 2;
      expect(
        (hint.position.x + hint.panelWidth / 2 - vanCenter).abs(),
        lessThan(12.0),
      );

      // A jump does not chase it away: only the van going by does.
      game.player.pressJump();
      game.update(_frame);
      expect(hint.isDismissing, isFalse);
      await _runUntil(
        game,
        () => van.position.x + van.size.x < game.player.position.x - 10,
      );
      expect(hint.isDismissing, isTrue);
    });

    test('only the first van of a shift gets it', () async {
      final game = await _mountedGame(record: 120);
      await _runUntil(game, () => game.leapCoach != null);
      final first = game.leapCoach!;
      // Run on well past several more vans.
      await _runUntil(game, () => game.gameState.distanceMeters > 700, maxFrames: 60 * 90);
      expect(game.leapCoach, same(first));
    });

    test('the next shift coaches it again', () async {
      final game = await _mountedGame(record: 120);
      await _runUntil(game, () => game.leapCoach != null);
      game.restartRun();
      expect(game.leapCoach, isNull);
      await _runUntil(game, () => game.leapCoach != null);
      expect(game.leapCoach, isNotNull);
    });

    test('a seasoned courier is left alone', () async {
      final game = await _mountedGame(
        record: CourierGame.leapCoachUntilRecordMeters,
      );
      var sawVan = false;
      await _runUntil(game, () {
        sawVan = sawVan ||
            game.activeObstacles.any((o) => o.type == ObstacleType.van);
        return game.gameState.distanceMeters > 400;
      }, maxFrames: 60 * 90);
      expect(sawVan, isTrue, reason: 'the shift did meet a van');
      expect(game.leapCoach, isNull);
    });

    test('returning to the depot clears it', () async {
      final game = await _mountedGame(record: 120);
      await _runUntil(game, () => game.leapCoach != null);
      game.returnToDepot();
      expect(game.leapCoach, isNull);
    });
  });
}
