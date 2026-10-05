// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

/// A street generator that builds nothing, so the only things on the street
/// are the ones a test puts there.
///
/// Clearing the hazards off a generated street is not enough: the coins and
/// boosters stay, and a courier who jumps into an energy drink finishes the
/// test a fifth faster than the test thinks. About one run in twelve did.
class BareStreet extends WorldChunkManager {
  @override
  ChunkData generateChunk({
    required double startX,
    double chunkWidth = 960.0,
    required double speed,
    double groundY = 460.0,
    double distanceMeters = 0.0,
    bool isVipActive = false,
    bool heavySkateTraffic = false,
  }) =>
      const ChunkData(obstacles: [], pickups: []);
}

/// A mounted, silent game on a street with nothing on it, [meters] into a
/// shift, optionally with both speed buffs running for the whole test.
Future<CourierGame> bareStreetGame(double meters, {bool boosted = false}) async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: BareStreet(),
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  game.gameState.distanceMeters = meters;
  if (boosted) {
    game.gameState
      ..energyDrinkTimer = 99.0
      ..caffeineSurgeTimer = 99.0;
  }
  game.update(0);
  await Future<void>.delayed(Duration.zero);
  game.update(1 / 60);
  return game;
}

/// A hazard of [type] standing on the street with its left edge at [x].
ObstacleComponent hazardAt(ObstacleType type, double x) {
  final size = ObstacleComponent.defaultSizeForType(type);
  return ObstacleComponent(type: type, position: Vector2(x, CourierGame.groundY - size.y), size: size);
}

/// A street that is empty except for one chunk, built by [build] the next
/// time the game asks for one.
class ScriptedStreet extends WorldChunkManager {
  ChunkData Function(double startX, double speed)? build;

  @override
  ChunkData generateChunk({
    required double startX,
    double chunkWidth = 960.0,
    required double speed,
    double groundY = 460.0,
    double distanceMeters = 0.0,
    bool isVipActive = false,
    bool heavySkateTraffic = false,
  }) {
    final next = build;
    if (next == null) return const ChunkData(obstacles: [], pickups: []);
    build = null;
    return next(startX, speed);
  }
}

/// A mounted, silent game [meters] into a shift on a street with nothing on
/// it but the one chunk [build] describes, which arrives within a screen.
Future<CourierGame> scriptedStreetGame(
  double meters,
  ChunkData Function(double startX, double speed) build,
) async {
  final street = ScriptedStreet();
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: street,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  game.gameState.distanceMeters = meters;
  game.update(0);
  await Future<void>.delayed(Duration.zero);
  game.update(1 / 60);
  street.build = build;
  return game;
}
