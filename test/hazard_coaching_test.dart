// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/input_hints.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bare_street.dart';

const double _frame = 1 / 60;

/// A chunk holding [types] in order, 400 px apart, and nothing else.
ChunkData _chunkOf(List<ObstacleType> types, double startX) {
  var x = startX + 100.0;
  final obstacles = <ObstacleData>[];
  for (final type in types) {
    final size = ObstacleComponent.defaultSizeForType(type);
    obstacles.add(ObstacleData(type: type, x: x, y: 460.0 - size.y, width: size.x, height: size.y));
    x += size.x + 400.0;
  }
  return ChunkData(obstacles: obstacles, pickups: const []);
}

class _Shift {
  _Shift(this.game, this.street);

  final CourierGame game;
  final ScriptedStreet street;

  /// Puts [types] on the street and runs until they have been built.
  Future<void> meet(List<ObstacleType> types) async {
    street.build = (startX, speed) => _chunkOf(types, startX);
    for (var f = 0; f < 60 * 20 && street.build != null; f++) {
      game.gameState.packages = game.gameState.maxPackages;
      game.update(_frame);
      if (f % 20 == 0) await Future<void>.delayed(Duration.zero);
    }
    expect(street.build, isNull, reason: 'the game never asked for the next chunk');
    game.update(_frame);
    await Future<void>.delayed(Duration.zero);
  }

  void startOver() {
    game.gameState.startRun();
    game.restartRun();
  }
}

Future<_Shift> _shift({int record = 0, LocalStorageService? storage}) async {
  final street = ScriptedStreet();
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
    chunkManager: street,
    personalRecordDistance: record,
    storageService: storage,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  return _Shift(game, street);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Only vans were coached. A subway train cannot be hopped either (a tap
  // clears it at none of the timings tried, early in a shift), and a
  // station can be the first thing a new courier meets past 200 m.
  group('A novice is coached on the leap at the first subway train', () {
    test('the hint rides above the train', () async {
      final shift = await _shift();
      expect(shift.game.trainCoach, isNull);
      await shift.meet([ObstacleType.thirdRail, ObstacleType.subwayTrain]);

      final hint = shift.game.trainCoach;
      expect(hint, isNotNull);
      expect(hint!.text, equals(CoachText.leap(keyboard: expectsKeyboard)));
      expect((hint.follow! as ObstacleComponent).type, equals(ObstacleType.subwayTrain));
    });

    test('a van earlier in the shift does not use it up', () async {
      final shift = await _shift();
      await shift.meet([ObstacleType.van, ObstacleType.subwayTrain]);
      expect(shift.game.leapCoach, isNotNull);
      expect(shift.game.trainCoach, isNotNull);
      expect(shift.game.trainCoach, isNot(same(shift.game.leapCoach)));
    });

    test('only the first train of a shift gets it, and the next shift again', () async {
      final shift = await _shift();
      await shift.meet([ObstacleType.subwayTrain]);
      final first = shift.game.trainCoach;
      await shift.meet([ObstacleType.subwayTrain]);
      expect(shift.game.trainCoach, same(first));

      shift.startOver();
      expect(shift.game.trainCoach, isNull);
      await shift.meet([ObstacleType.subwayTrain]);
      expect(shift.game.trainCoach, isNotNull);
    });

    test('a seasoned courier is left alone', () async {
      final shift = await _shift(record: CourierGame.leapCoachUntilRecordMeters);
      await shift.meet([ObstacleType.van, ObstacleType.subwayTrain]);
      expect(shift.game.trainCoach, isNull);
      expect(shift.game.leapCoach, isNull);
    });
  });

  // Pigeons first turn up at 800 m, long after the novice hints have
  // stopped. Holding the jump clears every other hazard on the street and
  // is the one way to be hit by this one: a held leap was hit at most of
  // the timings tried, and a courier who kept running at none.
  group('A flock of pigeons says to run under it', () {
    test('whatever the courier\'s record', () async {
      for (final record in const [0, 400, 5000]) {
        final shift = await _shift(record: record);
        await shift.meet([ObstacleType.pigeonFlock]);
        final hint = shift.game.pigeonCoach;
        expect(hint, isNotNull, reason: 'record $record');
        expect(hint!.text, equals('RUN UNDER THE BIRDS!'));
        expect((hint.follow! as ObstacleComponent).type, equals(ObstacleType.pigeonFlock));
      }
    });

    // At the height the other hints ride, the birds flew up behind the
    // bubble just as the courier reached them.
    test('from above the birds for as long as the courier has yet to pass them', () async {
      final shift = await _shift(record: 2000);
      await shift.meet([ObstacleType.pigeonFlock]);
      final game = shift.game;
      final hint = game.pigeonCoach!;
      final flock = game.activeObstacles.firstWhere((o) => o.type == ObstacleType.pigeonFlock);
      final ground = flock.position.y;

      var tookOff = false;
      for (var f = 0; f < 60 * 20 && flock.position.x + flock.size.x > game.player.position.x; f++) {
        game.gameState.packages = game.gameState.maxPackages;
        game.update(_frame);
        if (f % 20 == 0) await Future<void>.delayed(Duration.zero);
        if (flock.position.y < ground - 1) tookOff = true;
        expect(
          hint.position.y + hint.size.y,
          lessThanOrEqualTo(flock.position.y),
          reason: 'the bubble is over the birds, flock at ${flock.position}',
        );
      }
      expect(tookOff, isTrue);
      expect(game.gameState.damageTakenCount, equals(0), reason: 'running under them is safe');
    });

    test('once a shift', () async {
      final shift = await _shift(record: 2000);
      await shift.meet([ObstacleType.pigeonFlock, ObstacleType.pigeonFlock]);
      final first = shift.game.pigeonCoach;
      await shift.meet([ObstacleType.pigeonFlock]);
      expect(shift.game.pigeonCoach, same(first));
    });

    test('for three shifts that meet one, then never again', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();
      final shift = await _shift(record: 2000, storage: storage);

      for (var n = 1; n <= CourierGame.pigeonCoachShifts; n++) {
        await shift.meet([ObstacleType.pigeonFlock]);
        expect(shift.game.pigeonCoach, isNotNull, reason: 'shift $n');
        expect(storage.pigeonCoachRuns, equals(n));
        shift.startOver();
        expect(shift.game.pigeonCoach, isNull);
      }

      await shift.meet([ObstacleType.pigeonFlock]);
      expect(shift.game.pigeonCoach, isNull);
      expect(storage.pigeonCoachRuns, equals(CourierGame.pigeonCoachShifts));
    });

    test('a shift with no pigeons does not count', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();
      final shift = await _shift(storage: storage);
      await shift.meet([ObstacleType.dog, ObstacleType.van]);
      shift.startOver();
      expect(storage.pigeonCoachRuns, equals(0));
    });

    test('and without saved progress it still stops after three', () async {
      final shift = await _shift(record: 2000);
      for (var n = 1; n <= CourierGame.pigeonCoachShifts; n++) {
        await shift.meet([ObstacleType.pigeonFlock]);
        expect(shift.game.pigeonCoach, isNotNull);
        shift.startOver();
      }
      await shift.meet([ObstacleType.pigeonFlock]);
      expect(shift.game.pigeonCoach, isNull);
    });
  });

  test('other hazards get no new hint', () async {
    final shift = await _shift(record: 2000);
    await shift.meet([ObstacleType.dog, ObstacleType.skateMessenger, ObstacleType.thirdRail]);
    expect(shift.game.trainCoach, isNull);
    expect(shift.game.pigeonCoach, isNull);
    expect(shift.game.leapCoach, isNull);
  });
}
