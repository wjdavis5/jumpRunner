import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/courier_game.dart';

Future<CourierGame> _runningGame() async {
  final game = CourierGame();
  await game.onLoad();
  game.gameState.startRun();
  for (var i = 0; i < 30; i++) {
    game.update(1.0 / 60.0);
  }
  expect(game.parallaxCity.speedMultiplier, greaterThan(0.0));
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A paused shift is a frozen frame', () {
    test('Skyline, sidewalk and courier hold still while paused', () async {
      final game = await _runningGame();
      game.player.jump();
      game.update(1.0 / 60.0);
      game.gameState.pauseRun();

      final city = game.parallaxCity;
      final sidewalk = city.sidewalkOffset;
      final midground = city.midgroundOffset;
      final skyline = city.skylineOffset;
      final courierY = game.player.position.y;
      final distance = game.gameState.distanceMeters;

      for (var i = 0; i < 90; i++) {
        game.update(1.0 / 60.0);
      }

      expect(city.sidewalkOffset, equals(sidewalk));
      expect(city.midgroundOffset, equals(midground));
      expect(city.skylineOffset, equals(skyline));
      // Mid-jump when paused: the courier hangs in the air rather than landing.
      expect(game.player.position.y, equals(courierY));
      expect(game.gameState.distanceMeters, equals(distance));
    });

    test('Everything moves again on resume', () async {
      final game = await _runningGame();
      game.gameState.pauseRun();
      for (var i = 0; i < 30; i++) {
        game.update(1.0 / 60.0);
      }
      final sidewalk = game.parallaxCity.sidewalkOffset;
      final distance = game.gameState.distanceMeters;

      game.gameState.resumeRun();
      for (var i = 0; i < 10; i++) {
        game.update(1.0 / 60.0);
      }

      expect(game.parallaxCity.sidewalkOffset, isNot(equals(sidewalk)));
      expect(game.gameState.distanceMeters, greaterThan(distance));
    });
  });
}
