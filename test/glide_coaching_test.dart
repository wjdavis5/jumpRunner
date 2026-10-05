// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/coach_hint_component.dart';
import 'package:jump_runner/game/components/speech_bubble_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/input_hints.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/title_screen.dart';

const double _frame = 1.0 / 60.0;

Future<CourierGame> _mountedGame({int record = 120}) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: WorldChunkManager(random: math.Random(3)),
    personalRecordDistance: record,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  // An empty street, so nothing interrupts the jumps below.
  game.nextChunkX = 1e12;
  for (final o in game.activeObstacles.toList()) {
    o.removeFromParent();
  }
  game.activeObstacles.clear();
  await _run(game, 3);
  return game;
}

Future<void> _run(CourierGame game, int frames) async {
  for (var i = 0; i < frames; i++) {
    game.update(_frame);
    if (i % 3 == 0) await Future<void>.delayed(Duration.zero);
  }
}

/// Leaps, then presses again near the top of the arc to open the chute.
Future<void> _leapAndGlide(CourierGame game) async {
  game.player.pressJump();
  await _run(game, 14);
  game.player.releaseJump();
  await _run(game, 6);
  expect(game.player.simulator.isGrounded, isFalse);
  game.player.pressJump();
  game.player.releaseJump();
  await _run(game, 2);
  expect(game.player.isGliding, isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Glide coaching words', () {
    test('they say how to come down, on either kind of device', () {
      expect(CoachText.glide(keyboard: false), equals('GLIDING!  TAP TO DROP'));
      expect(CoachText.glide(keyboard: true), equals('GLIDING!  SPACE TO DROP'));
    });

    test('the title screen mentions the glide', () {
      expect(TitleScreen.controlGuide(keyboard: false), contains('Tap again in the air = Glide'));
      expect(TitleScreen.controlGuide(keyboard: true), contains('Press again in the air = Glide'));
    });

    testWidgets('the longer control guide still fits the title card', (tester) async {
      for (final platform in const [TargetPlatform.android, TargetPlatform.windows]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          for (final size in const [Size(667, 375), Size(960, 540)]) {
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: TitleScreen(highDistance: 0, careerTips: 0, onStartGame: () {}),
                ),
              ),
            );
            expect(tester.takeException(), isNull, reason: '$platform at $size');
            final guide = tester.getRect(find.byKey(const Key('control_guide')));
            expect(guide.top, greaterThanOrEqualTo(0.0));
            expect(guide.bottom, lessThanOrEqualTo(size.height));
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });
  });

  group('A hint can float above something that moves up and down', () {
    test('it keeps its distance above the thing it follows', () {
      final courier = PositionComponent(position: Vector2(120, 300), size: Vector2(56, 64));
      final hint = CoachHintComponent(
        text: 'GLIDING!  TAP TO DROP',
        position: Vector2.zero(),
        follow: courier,
        hoverAbove: 46,
      );
      for (var i = 0; i < 120; i++) {
        courier.position.y += 0.9; // drifting down
        hint.update(_frame);
        final tailTip = hint.position.y + hint.panelHeight + CoachHintComponent.tailHeight;
        // Between 38 and 46 px above the courier's head, bob included.
        expect(courier.position.y - tailTip, inInclusiveRange(37.9, 46.1));
      }
    });

    test('it never floats up into the HUD', () {
      final courier = PositionComponent(position: Vector2(120, 90), size: Vector2(56, 64));
      final hint = CoachHintComponent(
        text: 'GLIDING!  TAP TO DROP',
        position: Vector2.zero(),
        follow: courier,
        hoverAbove: 46,
        minY: 70,
      );
      hint.update(_frame);
      expect(hint.position.y, greaterThanOrEqualTo(70.0));
    });

    test('it fades when told its moment is over', () {
      var done = false;
      final courier = PositionComponent(position: Vector2(120, 300), size: Vector2(56, 64));
      final hint = CoachHintComponent(
        text: 'GLIDING!  TAP TO DROP',
        position: Vector2.zero(),
        follow: courier,
        hoverAbove: 46,
        dismissWhen: () => done,
      );
      hint.update(_frame);
      expect(hint.isDismissing, isFalse);
      done = true;
      hint.update(_frame);
      expect(hint.isDismissing, isTrue);
    });
  });

  group('A novice is told about the chute the first time it opens', () {
    test('the hint appears over the gliding courier', () async {
      final game = await _mountedGame();
      expect(game.glideCoach, isNull);

      await _leapAndGlide(game);
      final hint = game.glideCoach!;
      expect(hint.text, equals('GLIDING!  TAP TO DROP'));
      expect(hint.follow, same(game.player));

      await _run(game, 10);
      final player = game.player;
      final hintCenter = hint.position.x + hint.panelWidth / 2;
      expect((hintCenter - (player.position.x + player.size.x / 2)).abs(), lessThan(60.0));
      expect(hint.position.y + hint.panelHeight, lessThan(player.position.y));
      expect(hint.position.x, greaterThanOrEqualTo(16.0));
      expect(hint.isDismissing, isFalse);
    });

    test('pressing again drops the courier and the hint goes', () async {
      final game = await _mountedGame();
      await _leapAndGlide(game);
      final hint = game.glideCoach!;

      game.player.pressJump();
      game.player.releaseJump();
      await _run(game, 2);
      expect(game.player.isGliding, isFalse);
      expect(hint.isDismissing, isTrue);
    });

    test('riding the chute to the ground also ends it', () async {
      final game = await _mountedGame();
      await _leapAndGlide(game);
      final hint = game.glideCoach!;

      await _run(game, 60 * 6);
      expect(game.player.simulator.isGrounded, isTrue);
      expect(hint.isDismissing, isTrue);
    });

    test('only the first glide of a shift is explained', () async {
      final game = await _mountedGame();
      await _leapAndGlide(game);
      final first = game.glideCoach!;
      await _run(game, 60 * 6);

      await _leapAndGlide(game);
      expect(game.glideCoach, same(first));
      expect(first.isDismissing, isTrue, reason: 'no second hint was raised');
    });

    test('the next shift explains it again', () async {
      final game = await _mountedGame();
      await _leapAndGlide(game);
      game.restartRun();
      expect(game.glideCoach, isNull);
    });

    test('a desktop browser is told to press Space', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final game = await _mountedGame();
        await _leapAndGlide(game);
        expect(game.glideCoach!.text, equals('GLIDING!  SPACE TO DROP'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('a seasoned courier is left alone', () async {
      final game = await _mountedGame(record: CourierGame.leapCoachUntilRecordMeters);
      await _leapAndGlide(game);
      expect(game.glideCoach, isNull);
    });
  });

  group('Speech bubbles keep clear of the open chute', () {
    Iterable<SpeechBubbleComponent> bubbles(CourierGame game) =>
        game.world.children.whereType<SpeechBubbleComponent>();

    test('while the glide hint is up, there is no second bubble under it', () async {
      final game = await _mountedGame();
      await _leapAndGlide(game);
      expect(game.glideCoach, isNotNull);
      expect(bubbles(game), isEmpty);
    });

    test('without the hint, the glide bubble starts above the canopy', () async {
      final game = await _mountedGame(record: CourierGame.leapCoachUntilRecordMeters);
      await _leapAndGlide(game);
      final bubble = bubbles(game).single;
      // The canopy's top edge is 18 px above the courier's head, and the
      // bubble with its tail is about 32 px tall.
      expect(CourierGame.speechLiftGliding, greaterThanOrEqualTo(18.0 + 32.0 + 8.0));
      // It travels with the courier, so it stays above the canopy for as
      // long as it is on screen, whether the courier is rising or sinking.
      for (var i = 0; i < 40 && bubble.isMounted; i++) {
        expect(
          game.player.position.y - bubble.position.y,
          greaterThanOrEqualTo(CourierGame.speechLiftGliding - 0.5),
          reason: 'frame $i',
        );
        await _run(game, 1);
      }
    });

    test('on the ground the bubble sits where it always did', () async {
      final game = await _mountedGame(record: CourierGame.leapCoachUntilRecordMeters);
      final headY = game.player.position.y;
      game.audio.resetBarkCooldowns();
      await game.audio.playCourierBark(CourierBarkType.stunt, ignoreCooldown: true);
      await _run(game, 1);
      final bubble = bubbles(game).single;
      expect(headY - bubble.position.y, closeTo(CourierGame.speechLift, 2.0));

      // And it goes up with the courier on a jump rather than being run into.
      game.player.pressJump();
      await _run(game, 8);
      expect(game.player.position.y, lessThan(headY - 20.0));
      expect(
        game.player.position.y - bubble.position.y,
        greaterThanOrEqualTo(CourierGame.speechLift - 0.5),
      );
    });
  });
}
