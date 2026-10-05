// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

bool _isStreetHazard(ObstacleData o) =>
    o.type != ObstacleType.thirdRail && o.type != ObstacleType.subwayTrain;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hazards spawn at the designed density in the real game', () {
    // The game spawns every chunk at about the same screen x, because the
    // street has scrolled one chunk's width since the last spawn. The
    // generator once assumed x kept growing, remembered the previous hazard a
    // whole chunk too far right, and left most chunks empty.
    test('Spawning at a fixed screen x yields the same hazards as growing world x', () {
      for (final meters in const [50.0, 150.0, 300.0, 1000.0, 2500.0]) {
        final world = WorldChunkManager(random: math.Random(21));
        final screen = WorldChunkManager(random: math.Random(21));
        double worldX = 1440.0;
        for (var i = 0; i < 120; i++) {
          final a = world.generateChunk(
            startX: worldX,
            speed: world.calculateSpeed(meters),
            distanceMeters: meters,
          );
          final b = screen.generateChunk(
            startX: 1440.0,
            speed: screen.calculateSpeed(meters),
            distanceMeters: meters,
          );
          expect(
            b.obstacles.map((o) => '${o.type.name}@${(o.x - 1440.0).round()}').toList(),
            equals(a.obstacles.map((o) => '${o.type.name}@${(o.x - worldX).round()}').toList()),
            reason: 'chunk $i at ${meters.round()}m',
          );
          worldX += 960.0;
        }
      }
    });

    test('No stretch of chunks goes without a street hazard', () {
      final manager = WorldChunkManager(random: math.Random(4));
      int emptyRun = 0;
      int longestEmptyRun = 0;
      int hazards = 0;
      const chunks = 300;
      for (var i = 0; i < chunks; i++) {
        final chunk = manager.generateChunk(
          startX: 1440.0,
          speed: manager.calculateSpeed(600.0),
          distanceMeters: 600.0,
        );
        final street = chunk.obstacles.where(_isStreetHazard).length;
        hazards += street;
        emptyRun = chunk.obstacles.isEmpty ? emptyRun + 1 : 0;
        longestEmptyRun = math.max(longestEmptyRun, emptyRun);
      }
      expect(hazards / chunks, greaterThan(1.0));
      expect(longestEmptyRun, lessThanOrEqualTo(2));
    });

    test('A live shift meets street hazards all the way along', () async {
      final game = CourierGame(
        audioController: GameAudioController()..isMuted = true,
        chunkManager: WorldChunkManager(random: math.Random(8)),
      );
      game.onGameResize(Vector2(960, 540));
      await game.load();
      game.mount();
      game.update(0);
      await game.ready();
      game.gameState.startRun();
      game.restartRun();

      final seen = <int>{};
      final perBand = <int, int>{};
      int frames = 0;
      while (game.gameState.distanceMeters < 1000.0 && frames < 30000) {
        if (game.gameState.packages < 3) game.gameState.packages = 3;
        game.update(1.0 / 60.0);
        frames++;
        if (frames % 3 == 0) await Future<void>.delayed(Duration.zero);
        for (final o in game.activeObstacles) {
          if (o.type == ObstacleType.thirdRail || o.type == ObstacleType.subwayTrain) continue;
          if (seen.add(identityHashCode(o))) {
            final band = game.gameState.distanceMeters ~/ 250;
            perBand[band] = (perBand[band] ?? 0) + 1;
          }
        }
      }

      // 1,000 m is about 21 chunks. Before the fix a run like this met a
      // handful of street hazards in total.
      expect(seen.length, greaterThan(20));
      for (var band = 0; band < 4; band++) {
        expect(perBand[band] ?? 0, greaterThan(1), reason: '${band * 250}-${band * 250 + 250}m');
      }
    });
  });
}
