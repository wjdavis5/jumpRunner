import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';

Future<CourierGame> _crashedGame() async {
  final game = CourierGame();
  await game.onLoad();
  game.gameState.startRun();
  game.update(0.1);
  expect(game.parallaxCity.speedMultiplier, greaterThan(0.0));

  for (var i = 0; i < 10 && game.gameState.status != GameStatus.gameOver; i++) {
    game.gameState.applyHazardDamage();
  }
  expect(game.gameState.status, equals(GameStatus.gameOver));
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Death beat camera', () {
    test('The slow-motion zoom never shows past the edge of the street', () async {
      final game = await _crashedGame();
      final resolution = CourierGame.virtualResolution;
      double peakZoom = 1.0;
      int frames = 0;

      while (game.deathSlowmo.isActive && frames < 600) {
        game.update(1.0 / 120.0);
        frames++;
        final view = game.camera.viewfinder;
        final halfWidth = resolution.x / (2 * view.zoom);
        final halfHeight = resolution.y / (2 * view.zoom);
        peakZoom = math.max(peakZoom, view.zoom);

        // The eased path stays on the street; only the impact shake may ride
        // past it, and by no more than its own travel. The backdrop is
        // painted 60 px beyond the street to cover that (death_camera_test
        // checks the pixels).
        final slackX = game.cameraJuice.maxShakeOffset.x + 0.001;
        final slackY = game.cameraJuice.maxShakeOffset.y + 0.001;
        expect(view.position.x - halfWidth, greaterThanOrEqualTo(-slackX), reason: 'left edge, frame $frames');
        expect(view.position.x + halfWidth, lessThanOrEqualTo(resolution.x + slackX), reason: 'right edge, frame $frames');
        expect(view.position.y - halfHeight, greaterThanOrEqualTo(-slackY), reason: 'top edge, frame $frames');
        expect(view.position.y + halfHeight, lessThanOrEqualTo(resolution.y + slackY), reason: 'bottom edge, frame $frames');
      }

      expect(game.deathSlowmo.isActive, isFalse);
      // The beat still zooms in; it is only kept on the painted street.
      expect(peakZoom, greaterThan(1.2));
    });
  });

  group('Street freezes when the run ends', () {
    test('Sidewalk and skyline stop scrolling once the last package drops', () async {
      final game = await _crashedGame();
      final city = game.parallaxCity;
      final sidewalk = city.sidewalkOffset;
      final midground = city.midgroundOffset;
      final skyline = city.skylineOffset;

      // Through the death beat and well into the results screen.
      for (var i = 0; i < 120; i++) {
        game.update(1.0 / 60.0);
      }

      expect(city.sidewalkOffset, equals(sidewalk));
      expect(city.midgroundOffset, equals(midground));
      expect(city.skylineOffset, equals(skyline));
    });

    test('Restarting the shift sets the street moving again', () async {
      final game = await _crashedGame();
      for (var i = 0; i < 60; i++) {
        game.update(1.0 / 60.0);
      }

      game.restartRun();
      final sidewalk = game.parallaxCity.sidewalkOffset;
      game.update(0.1);
      game.update(0.1);

      expect(game.parallaxCity.speedMultiplier, greaterThan(0.0));
      expect(game.parallaxCity.sidewalkOffset, isNot(equals(sidewalk)));
    });
  });

  group('Courier goes down when the run ends', () {
    test('The courier tumbles onto the pavement and stays there', () async {
      final game = await _crashedGame();
      final player = game.player;
      expect(player.isKnockedOut, isTrue);

      // Well past the 1.5s hit flicker, after which the courier used to get
      // back up and jog in place behind the results screen.
      for (var i = 0; i < 240; i++) {
        game.update(1.0 / 60.0);
      }

      expect(player.isKnockedOut, isTrue);
      expect(player.state, equals(CourierState.hurt));
      expect(player.knockoutAngle, closeTo(math.pi / 2, 0.001));
      expect(player.simulator.isGrounded, isTrue);
      expect(player.position.y, equals(CourierGame.groundY - player.size.y));
    });

    test('A knocked-out courier ignores jump input', () async {
      final game = await _crashedGame();
      final player = game.player;
      for (var i = 0; i < 120; i++) {
        game.update(1.0 / 60.0);
      }
      expect(player.simulator.isGrounded, isTrue);

      player.pressJump();
      game.update(1.0 / 60.0);

      expect(player.simulator.isGrounded, isTrue);
      expect(player.hasBufferedJump, isFalse);
    });

    test('Restarting puts the courier back on their feet', () async {
      final game = await _crashedGame();
      for (var i = 0; i < 60; i++) {
        game.update(1.0 / 60.0);
      }

      game.restartRun();
      game.update(1.0 / 60.0);

      final player = game.player;
      expect(player.isKnockedOut, isFalse);
      expect(player.knockoutAngle, equals(0.0));
      expect(player.state, equals(CourierState.running));
      expect(player.isInvulnerable, isFalse);
    });
  });
}
