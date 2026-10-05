import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/game/models/daily_shift.dart';

DailyShift _shift(DailyModifier modifier) => DailyShift(
      dateString: '2026-10-04',
      modifier: modifier,
      targetDistanceMeters: 1000,
      completionBonusTips: 100,
    );

Future<CourierGame> _gameOn(DailyModifier modifier) async {
  final game = CourierGame();
  await game.onLoad();
  game.restartRun(shift: _shift(modifier));
  for (var i = 0; i < 120; i++) {
    game.update(1.0 / 60.0);
  }
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Each daily shift's card makes two promises: a change to the street and a
  // change to the payout. These hold the game to the first half.
  group('Daily shifts deliver what their cards describe', () {
    test('Rainy Rush: it keeps raining, and the courier runs 1.2x faster', () async {
      final game = await _gameOn(DailyModifier.rainyRush);

      expect(game.weatherController.isRaining, isTrue);
      expect(game.weatherController.rainIntensity, greaterThanOrEqualTo(0.8));

      final base = game.chunkManager.calculateSpeed(game.gameState.distanceMeters);
      expect(game.currentSpeed, closeTo(base * 1.2, 0.5));
    });

    test('Neon Midnight: the city is dark from the first metre', () async {
      final game = await _gameOn(DailyModifier.nightDash);

      expect(game.gameState.distanceMeters, lessThan(100.0));
      expect(game.parallaxCity.currentPhase, equals(TimeOfDayPhase.night));
    });

    test('Skate Commute: the street is full of oncoming skaters', () async {
      final game = await _gameOn(DailyModifier.skateCommute);
      // Skaters normally do not appear before 800 m; on a skate day they are
      // on the street as soon as the warm-up ends.
      int framesWithSkaters = 0;
      while (game.gameState.distanceMeters < 600.0) {
        if (game.gameState.packages < 3) game.gameState.packages = 3;
        game.update(1.0 / 60.0);
        if (game.activeObstacles.any((o) => o.type == ObstacleType.skateMessenger)) {
          framesWithSkaters++;
        }
      }
      expect(framesWithSkaters, greaterThan(0));
    });

    test('A regular shift afterwards is dry, daylit and at normal speed', () async {
      for (final modifier in DailyModifier.values) {
        final game = await _gameOn(modifier);
        game.returnToDepot();
        game.restartRun();
        for (var i = 0; i < 60; i++) {
          game.update(1.0 / 60.0);
        }

        expect(game.weatherController.isRaining, isFalse, reason: modifier.name);
        expect(game.parallaxCity.currentPhase, equals(TimeOfDayPhase.day), reason: modifier.name);
        final base = game.chunkManager.calculateSpeed(game.gameState.distanceMeters);
        expect(game.currentSpeed, closeTo(base, 0.5), reason: modifier.name);
      }
    });
  });

  group('Heavy skate traffic in chunk generation', () {
    int skaters(WorldChunkManager manager, {required bool heavy, required double meters}) {
      int count = 0;
      double x = 960.0;
      for (var i = 0; i < 200; i++) {
        final chunk = manager.generateChunk(
          startX: x,
          speed: manager.calculateSpeed(meters),
          distanceMeters: meters,
          heavySkateTraffic: heavy,
        );
        count += chunk.obstacles.where((o) => o.type == ObstacleType.skateMessenger).length;
        x += 960.0;
      }
      return count;
    }

    test('A large share of the hazards past the warm-up are skaters', () {
      final manager = WorldChunkManager(random: math.Random(5));
      int total = 0;
      int skate = 0;
      double x = 960.0;
      for (var i = 0; i < 300; i++) {
        final chunk = manager.generateChunk(
          startX: x,
          speed: manager.calculateSpeed(300.0),
          distanceMeters: 300.0,
          heavySkateTraffic: true,
        );
        // Subway stations bring their own fixed hazards; count street ones.
        total += chunk.obstacles
            .where((o) => o.type != ObstacleType.thirdRail && o.type != ObstacleType.subwayTrain)
            .length;
        skate += chunk.obstacles.where((o) => o.type == ObstacleType.skateMessenger).length;
        x += 960.0;
      }
      // Half of the regular picks become skaters; fixed set-piece hazards
      // bring the overall share down. Normally there are none at this distance.
      expect(skate / total, inInclusiveRange(0.25, 0.65));
    });

    test('The warm-up stretch stays skater-free even on a skate day', () {
      final manager = WorldChunkManager(random: math.Random(5));
      expect(skaters(manager, heavy: true, meters: 40.0), equals(0));
    });

    test('Without the flag, generation is unchanged', () {
      final plain = WorldChunkManager(random: math.Random(9));
      final flagged = WorldChunkManager(random: math.Random(9));
      double x = 960.0;
      for (var i = 0; i < 50; i++) {
        final a = plain.generateChunk(startX: x, speed: 250.0, distanceMeters: 300.0);
        final b = flagged.generateChunk(
          startX: x,
          speed: 250.0,
          distanceMeters: 300.0,
          heavySkateTraffic: false,
        );
        expect(
          a.obstacles.map((o) => '${o.type}@${o.x}').toList(),
          equals(b.obstacles.map((o) => '${o.type}@${o.x}').toList()),
        );
        x += 960.0;
      }
    });
  });
}
