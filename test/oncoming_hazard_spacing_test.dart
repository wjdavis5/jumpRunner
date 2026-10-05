// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const _skaterApproach = 65.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The generator leaves three quarters of a second of street between one
  // hazard and the next. For a hazard that stands still that holds all the
  // way to the courier. A skate messenger rolls toward the courier at
  // 65 px/s on top of the street, and by the time it arrives it has made up
  // 200 to 400 px on whatever was ahead of it: measured on 16 streets,
  // skaters arrived a median 214 px behind the hazard ahead where 400 was
  // meant, and one in five within 150 px.
  group('An oncoming hazard is built further back by the ground it will make up', () {
    final manager = WorldChunkManager(random: math.Random(1));

    test('two standing hazards neither close nor drift', () {
      expect(manager.closingDistance(aheadEndOffset: 300.0, speed: 400.0, approach: 0.0), equals(0.0));
    });

    test('a skater makes up its speed times the time the hazard ahead takes to arrive', () {
      // The hazard ahead ends 300 px into the chunk, which starts 1,320 px
      // from the courier: 1,620 px at 400 px/s is 4.05 s.
      final closing =
          manager.closingDistance(aheadEndOffset: 300.0, speed: 400.0, approach: _skaterApproach);
      expect(closing, closeTo(_skaterApproach * 1620.0 / 400.0, 0.01));
    });

    test('a standing hazard behind a skater is left behind by it', () {
      final closing = manager.closingDistance(
        aheadEndOffset: 300.0,
        speed: 400.0,
        approach: 0.0,
        aheadApproach: _skaterApproach,
      );
      // The skater arrives in 1,620 px at 465 px/s, pulling away all the way.
      expect(closing, closeTo(-_skaterApproach * 1620.0 / 465.0, 0.01));
    });

    test('two skaters keep their distance', () {
      expect(
        manager.closingDistance(
          aheadEndOffset: 300.0,
          speed: 400.0,
          approach: _skaterApproach,
          aheadApproach: _skaterApproach,
        ),
        equals(0.0),
      );
    });

    test('nothing ahead, nothing to make up', () {
      // The generator's "no hazard yet" marker is far behind the courier.
      expect(manager.closingDistance(aheadEndOffset: -11000.0, speed: 400.0, approach: _skaterApproach),
          equals(0.0));
    });

    test('in built streets, a skater behind a standing hazard keeps its clearance to the door', () {
      var checked = 0;
      for (var seed = 0; seed < 120; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        for (var meters = 800.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(startX: 1440.0, speed: speed, distanceMeters: meters);
          if (chunk.subwayStations.isNotEmpty) continue;
          final hazards = [...chunk.obstacles]..sort((a, b) => a.x.compareTo(b.x));
          for (var i = 1; i < hazards.length; i++) {
            final ahead = hazards[i - 1];
            final skater = hazards[i];
            if (skater.type != ObstacleType.skateMessenger) continue;
            if (ahead.type == ObstacleType.skateMessenger) continue;
            final aheadEnd = ahead.x + ahead.width;
            // When the hazard ahead has just gone by the courier:
            final seconds = (WorldChunkManager.chunkSpawnLead + aheadEnd - 1440.0) / speed;
            final gapOnArrival = skater.x - aheadEnd - _skaterApproach * seconds;
            checked++;
            expect(gapOnArrival, greaterThanOrEqualTo(street.calculateMinClearance(speed) - 1.0),
                reason: 'seed $seed at ${meters.round()} m: ${ahead.type.name} then a skater');
          }
        }
      }
      expect(checked, greaterThan(40));
    });

    test('a standing hazard behind a skater has its clearance on arrival too', () {
      var checked = 0;
      for (var seed = 0; seed < 200; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        for (var meters = 800.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(startX: 1440.0, speed: speed, distanceMeters: meters);
          if (chunk.subwayStations.isNotEmpty) continue;
          final hazards = [...chunk.obstacles]..sort((a, b) => a.x.compareTo(b.x));
          for (var i = 1; i < hazards.length; i++) {
            final skater = hazards[i - 1];
            final behind = hazards[i];
            if (skater.type != ObstacleType.skateMessenger) continue;
            if (behind.type == ObstacleType.skateMessenger) continue;
            final skaterEnd = skater.x + skater.width;
            // When the skater has just gone by the courier, it has pulled
            // this far away from the hazard behind it:
            final seconds =
                (WorldChunkManager.chunkSpawnLead + skaterEnd - 1440.0) / (speed + _skaterApproach);
            final gapOnArrival = behind.x - skaterEnd + _skaterApproach * seconds;
            final clearance = street.calculateMinClearance(speed);
            checked++;
            expect(gapOnArrival, greaterThanOrEqualTo(clearance - 1.0),
                reason: 'seed $seed at ${meters.round()} m');
            // Never built on top of each other.
            expect(behind.x - skaterEnd, greaterThanOrEqualTo(WorldChunkManager.minBuiltGap));
          }
        }
      }
      expect(checked, greaterThan(20));
    });

    test('two skaters in a row keep the gap they were built with', () {
      // Both roll at the same speed, so neither gains on the other.
      var checked = 0;
      for (var seed = 0; seed < 300 && checked < 10; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        for (var meters = 800.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(
            startX: 1440.0,
            speed: speed,
            distanceMeters: meters,
            heavySkateTraffic: true,
          );
          final hazards = [...chunk.obstacles]..sort((a, b) => a.x.compareTo(b.x));
          for (var i = 1; i < hazards.length; i++) {
            if (hazards[i].type != ObstacleType.skateMessenger ||
                hazards[i - 1].type != ObstacleType.skateMessenger) {
              continue;
            }
            checked++;
            final gap = hazards[i].x - (hazards[i - 1].x + hazards[i - 1].width);
            expect(gap, greaterThanOrEqualTo(street.calculateMinClearance(speed)));
            // And no more than the clearance plus the generator's variety.
            expect(gap, lessThanOrEqualTo(street.calculateMinClearance(speed) + 60.0 + 121.0));
          }
        }
      }
      expect(checked, greaterThanOrEqualTo(10));
    });
  });

  group('In a running shift', () {
    test('no skater reaches the courier within 200 px of the hazard ahead of it', () async {
      var skaters = 0;
      var tightest = double.infinity;
      for (final seed in [3, 6, 9, 12, 15, 18]) {
        final game = CourierGame(
          audioController: GameAudioController()..isMuted = true,
          chunkManager: WorldChunkManager(random: math.Random(seed)),
        );
        game.onGameResize(Vector2(960, 540));
        await game.load();
        game.mount();
        game.update(0);
        await game.ready();
        game.gameState.startRun();
        game.restartRun();
        game.gameState.distanceMeters = 800;
        final player = game.player;
        final done = <ObstacleComponent>{};
        for (var f = 0; f < 60 * 120 && game.gameState.distanceMeters < 2600; f++) {
          if (game.gameState.packages < GameState.defaultMaxPackages) {
            game.gameState.packages = GameState.defaultMaxPackages;
          }
          if (f % 40 == 0) player.pressJump();
          if (f % 40 == 8) player.releaseJump();
          game.update(1 / 60);
          if (f % 4 == 0) await Future<void>.delayed(Duration.zero);
          final front = player.position.x + player.size.x;
          for (final o in game.activeObstacles) {
            if (o.type != ObstacleType.skateMessenger || done.contains(o)) continue;
            if (o.position.x > front) continue;
            done.add(o);
            skaters++;
            for (final other in game.activeObstacles) {
              if (identical(other, o) ||
                  other.type == ObstacleType.pigeonFlock ||
                  other.type == ObstacleType.skateMessenger) {
                continue;
              }
              final right = other.position.x + other.size.x;
              if (right <= o.position.x + o.size.x) {
                tightest = math.min(tightest, o.position.x - right);
              }
            }
          }
        }
      }
      expect(skaters, greaterThan(8), reason: 'not enough skaters to judge by');
      expect(tightest, greaterThanOrEqualTo(200.0));
    });
  });
}
