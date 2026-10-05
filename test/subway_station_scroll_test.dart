// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/components/parallax_city.dart';
import 'package:jump_runner/game/components/subway_station_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

/// A mounted game 600 m into a shift on a street where every chunk that can
/// be a subway station is one.
Future<CourierGame> _subwayStreet({int seed = 4}) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: WorldChunkManager(random: math.Random(seed)),
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.chunkManager.subwayStationChance = 1.0;
  game.gameState.startRun();
  game.restartRun();
  game.gameState.distanceMeters = 600;
  return game;
}

/// Runs [seconds] of play at 60 fps with a courier who hops on a timer and
/// cannot lose the shift. [eachFrame] sees the game after every frame.
Future<void> _play(
  CourierGame game,
  double seconds, {
  void Function(int frame)? eachFrame,
}) async {
  final frames = (seconds * 60).round();
  for (var f = 0; f < frames; f++) {
    if (game.gameState.packages < GameState.defaultMaxPackages) {
      game.gameState.packages = GameState.defaultMaxPackages;
    }
    if (f % 45 == 0) game.player.pressJump();
    if (f % 45 == 6) game.player.releaseJump();
    game.update(1 / 60);
    if (f % 3 == 0) await Future<void>.delayed(Duration.zero);
    eachFrame?.call(f);
  }
}

Iterable<SubwayStationComponent> _stations(CourierGame game) =>
    game.world.children.whereType<SubwayStationComponent>();

/// Plays until the street builds a station, and returns it. Stations give
/// way to scaffolding, rails, vents and drop zones, so even at full odds the
/// first one can be half a kilometre off.
///
/// It is looked for in the game's own list, which it joins the moment it is
/// built. It appears among the world's children only once it has finished
/// loading behind whatever was queued before it, and under a full parallel
/// test run that can be a second of street later.
Future<SubwayStationComponent> _nextStation(CourierGame game) async {
  for (var frame = 0; frame < 60 * 90; frame++) {
    final live = game.activeSubwayStations.where((s) => !s.hasTriggeredTransit);
    if (live.isNotEmpty) return live.first;
    await _play(game, 1 / 60);
  }
  fail('no subway station in 90 seconds of street');
}

/// Plays until [station] is in the world, so it can be found among its
/// children.
Future<void> _untilMounted(CourierGame game, SubwayStationComponent station) async {
  for (var tenth = 0; tenth < 50 && !station.isMounted; tenth++) {
    await _play(game, 0.1);
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(station.isMounted, isTrue, reason: 'the station never joined the world');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every other thing on the street is moved left each frame by the scroll
  // section of the game loop. Subway stations were left out of it. A station
  // was built where its chunk starts, off the right edge of the screen, and
  // stayed there: never seen, never reached (so the transit tip and "Subway
  // shortcut!" never happened), and never recycled, while its third rail and
  // train rolled down an ordinary street.
  group('A subway station comes down the street like everything else', () {
    test('it is built off the right edge of the screen', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);
      expect(station.position.x, greaterThan(game.visibleWidth - 60.0));
      expect(station.hasTriggeredTransit, isFalse);
    });

    test('it moves left every frame, at the street\'s speed', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);

      final before = station.position.x;
      var expected = 0.0;
      await _play(game, 0.5, eachFrame: (_) => expected += game.currentSpeed / 60);
      final moved = before - station.position.x;
      expect(moved, greaterThan(100.0), reason: 'the station is standing still');
      expect(moved, closeTo(expected, 0.5));
    });

    test('it stays level with the hazards that were built in it', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);
      final rail = game.activeObstacles.firstWhere((o) => o.type == ObstacleType.thirdRail);
      final gap = rail.position.x - station.position.x;
      expect(gap, inInclusiveRange(220.0, 300.0));
      await _play(game, 1.0);
      expect(rail.position.x - station.position.x, closeTo(gap, 0.5));
    });

    test('the courier reaches it, and is tipped for the shortcut', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);
      expect(game.gameState.subwayStationsInRun, equals(0));

      var tipsOnEntry = -1;
      var tipsJustBefore = game.gameState.tips;
      for (var second = 0; second < 10 && tipsOnEntry < 0; second++) {
        await _play(game, 1.0, eachFrame: (_) {
          if (tipsOnEntry >= 0) return;
          if (station.hasTriggeredTransit) {
            tipsOnEntry = game.gameState.tips;
          } else {
            tipsJustBefore = game.gameState.tips;
          }
        });
      }
      expect(station.hasTriggeredTransit, isTrue, reason: 'the courier never got to the station');
      expect(game.gameState.subwayStationsInRun, equals(1));
      // $25, times whatever combo and boost were running.
      expect(tipsOnEntry - tipsJustBefore, greaterThanOrEqualTo(25));
    });

    test('the courier spends a chunk\'s worth of running inside it', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);
      var framesInside = 0;
      var pixelsInside = 0.0;
      await _play(game, 10.0, eachFrame: (_) {
        final courier = game.player.position.x;
        if (station.position.x <= courier && courier <= station.position.x + station.size.x) {
          framesInside++;
          pixelsInside += game.currentSpeed / 60;
        }
      });
      expect(framesInside, greaterThan(60));
      expect(pixelsInside, closeTo(station.size.x, 20.0));
    });

    test('once it is well behind the courier it is cleared away', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);
      expect(game.activeSubwayStations, contains(station));

      var lastSeenRightEdge = double.infinity;
      for (var second = 0; second < 15 && game.activeSubwayStations.contains(station); second++) {
        await _play(game, 1.0, eachFrame: (_) {
          if (game.activeSubwayStations.contains(station)) {
            lastSeenRightEdge = station.position.x + station.size.x;
          }
          expect(_stations(game).length, lessThanOrEqualTo(3));
        });
      }
      expect(game.activeSubwayStations, isNot(contains(station)));
      // It was kept until it was fully off the left of the screen, not before.
      expect(lastSeenRightEdge, inInclusiveRange(-215.0, -180.0));
      await _play(game, 0.1);
      expect(station.isMounted, isFalse);
      expect(_stations(game), isNot(contains(station)));
    });
  });

  // The station's wall is solid and a whole chunk wide. Things in the world
  // are painted in the order they were added unless told otherwise, and the
  // courier is added first of all, so the wall would have covered them.
  group('The station wall is behind the street, in front of the skyline', () {
    test('painting order: skyline, station, then courier and hazards', () async {
      final game = await _subwayStreet();
      final station = await _nextStation(game);
      await _untilMounted(game, station);
      final order = game.world.children.toList();
      final stationAt = order.indexOf(station);
      expect(stationAt, greaterThanOrEqualTo(0));
      expect(order.indexOf(game.world.children.whereType<ParallaxCityComponent>().single),
          lessThan(stationAt));
      expect(order.indexOf(game.player), greaterThan(stationAt));
      final hazards = game.world.children.whereType<ObstacleComponent>().toList();
      expect(hazards, isNotEmpty);
      for (final hazard in hazards) {
        expect(order.indexOf(hazard), greaterThan(stationAt),
            reason: '${hazard.type} is painted under the station wall');
      }
    });

    test('only the skyline is painted below the station', () async {
      final game = await _subwayStreet();
      await _untilMounted(game, await _nextStation(game));
      await _play(game, 1.0);
      final below = game.world.children
          .where((c) => c.priority < SubwayStationComponent.wallPriority)
          .toList();
      expect(below, hasLength(1));
      expect(below.single, isA<ParallaxCityComponent>());
    });
  });

  group('The station wall has straight sides', () {
    // The tile rows are laid brick-bond, so every other row starts half a
    // tile to the left of the wall. Those tiles used to stick out of it.
    test('no tile is painted to the left of the wall', () async {
      const margin = 40;
      final station = SubwayStationComponent(
        position: Vector2.zero(),
        size: Vector2(960.0, 260.0),
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..translate(margin.toDouble(), 0);
      station.paintStation(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(margin + 200, 260);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      picture.dispose();
      image.dispose();

      var paintedOutside = 0;
      var paintedInside = 0;
      for (var y = 0; y < 260; y++) {
        for (var x = 0; x < margin + 200; x++) {
          final alpha = bytes.getUint8((y * (margin + 200) + x) * 4 + 3);
          if (alpha == 0) continue;
          // The kiosk lamp's glow is a circle centred 20 px in with a 6.5 px
          // radius, so nothing legitimate comes within a pixel of the edge.
          if (x < margin - 1) {
            paintedOutside++;
          } else if (x >= margin) {
            paintedInside++;
          }
        }
      }
      expect(paintedOutside, equals(0));
      expect(paintedInside, equals(200 * 260));
    });
  });
}
