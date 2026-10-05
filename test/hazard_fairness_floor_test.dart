import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

import 'support/bare_street.dart';

const double _frame = 1 / 60;

/// A tap, and a press kept down until the courier is back on the ground.
const double _tap = 0.05;
const double _held = double.infinity;

/// Press timings are tried 50 ms apart, from on top of a hazard to a second
/// ahead of it. Room for error is counted in these steps.
const double _step = 0.05;
const int _steps = 20;

/// One press: made [secondsAhead] of reaching a hazard, kept down for [hold].
class _Press {
  const _Press(this.secondsAhead, this.hold);

  final double secondsAhead;
  final double hold;
}

double _rolls(ObstacleType type) => ObstacleComponent.defaultRelativeVelocityForType(type);

/// Sends [hazards] down an otherwise empty street, the first 900 px ahead of
/// the courier and each of the rest [gaps] px behind the one before.
/// `presses[i]` is the press made for hazard i (null: none), and a press is
/// never made before the one for the hazard before has been let go.
/// Returns whether the courier was hit.
Future<bool> _isHit(
  List<ObstacleType> hazards,
  List<_Press?> presses,
  double meters, {
  List<double> gaps = const [],
  bool boosted = false,
}) async {
  final game = await bareStreetGame(meters, boosted: boosted);
  var hits = 0;
  game.gameState.onDamageTaken = () => hits++;
  final player = game.player;
  final speed = game.currentSpeed;

  final placed = <ObstacleComponent>[];
  var x = player.position.x + 900.0;
  for (var i = 0; i < hazards.length; i++) {
    if (i > 0) x = placed.last.position.x + placed.last.size.x + gaps[i - 1];
    final hazard = hazardAt(hazards[i], x);
    placed.add(hazard);
    game.activeObstacles.add(hazard);
    game.world.add(hazard);
  }
  game.update(0);
  await game.ready();

  var next = 0;
  double? heldFor;
  final last = placed.last;
  for (var f = 0; f < 60 * 12 && last.position.x + last.size.x > player.position.x - 80; f++) {
    final front = player.position.x + player.size.x;
    if (heldFor == null && next < placed.length) {
      final press = presses[next];
      if (press == null) {
        next++;
      } else if (placed[next].position.x - front <= press.secondsAhead * speed) {
        game.holdJump(next);
        heldFor = 0.0;
      }
    }
    if (heldFor != null) {
      heldFor += _frame;
      final landed = heldFor > 0.1 && player.simulator.isGrounded;
      if (heldFor >= presses[next]!.hold || landed) {
        game.letGoOfJump(next);
        heldFor = null;
        next++;
      }
    }
    game.update(_frame);
    if (last.isRemoved) break;
  }
  return hits > 0;
}

/// The longest unbroken run of press timings that get past [type] unhurt
/// with a press kept down for [hold]: the player's room for error, in steps.
Future<int> _roomForError(ObstacleType type, double hold, double meters, {bool boosted = false}) async {
  var longest = 0;
  var run = 0;
  for (var step = 0; step <= _steps; step++) {
    final hit = await _isHit([type], [_Press(step * _step, hold)], meters, boosted: boosted);
    run = hit ? 0 : run + 1;
    longest = math.max(longest, run);
  }
  return longest;
}

/// The same for a hazard [gap] px behind a van that has just been leapt with
/// [overTheVan], trying a tap and a held press at each timing. Stops
/// counting at [enough].
Future<int> _roomBehindVan(
  ObstacleType second,
  double gap,
  _Press overTheVan,
  double meters, {
  required bool boosted,
  int enough = 4,
}) async {
  var longest = 0;
  var run = 0;
  for (var step = 0; step <= _steps && longest < enough; step++) {
    var hit = true;
    for (final hold in const [_tap, _held]) {
      final hazards = [ObstacleType.van, second];
      final presses = [overTheVan, _Press(step * _step, hold)];
      if (!await _isHit(hazards, presses, meters, gaps: [gap], boosted: boosted)) {
        hit = false;
        break;
      }
    }
    run = hit ? 0 : run + 1;
    longest = math.max(longest, run);
  }
  return longest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Where in a shift, and whether both speed buffs are running: about 210
  // px/s up to about 780.
  const stages = <(String, double, bool)>[
    ('the start of a shift', 0.0, false),
    ('150 m', 150.0, false),
    ('1,000 m', 1000.0, false),
    ('top speed', 2000.0, false),
    ('top speed with two speed buffs', 2000.0, true),
  ];

  // How wide is the window of press timings that gets past each hazard?
  // Measured: a tap has 250 ms or more for everything it is meant for (the
  // dog at the start of a shift is the narrowest) and a held leap 350 ms or
  // more for a van. These are floors under those, so a change to a hazard's
  // size, the jump or the speed curve cannot quietly make one a coin toss.
  group('Every hazard can be cleared with room for error, at every speed', () {
    const hopped = [
      ObstacleType.scooter,
      ObstacleType.dog,
      ObstacleType.hydrant,
      ObstacleType.mailbox,
      ObstacleType.skateMessenger,
      ObstacleType.thirdRail,
    ];
    for (final type in hopped) {
      test('a tap clears a ${type.name} across at least 200 ms of timings', () async {
        for (final (label, meters, boosted) in stages) {
          final room = await _roomForError(type, _tap, meters, boosted: boosted);
          expect(room, greaterThanOrEqualTo(4), reason: label);
        }
      });
    }

    for (final type in const [ObstacleType.van, ObstacleType.subwayTrain]) {
      test('a held leap clears a ${type.name} across at least 300 ms of timings', () async {
        for (final (label, meters, boosted) in stages) {
          final room = await _roomForError(type, _held, meters, boosted: boosted);
          expect(room, greaterThanOrEqualTo(6), reason: label);
        }
      });
    }

    test('a van cannot be hopped, which is why it is given a leap\'s room', () async {
      expect(await _roomForError(ObstacleType.van, _tap, 150.0), equals(0));
      expect(await _roomForError(ObstacleType.van, _tap, 1000.0), equals(0));
      expect(await _roomForError(ObstacleType.subwayTrain, _tap, 150.0), equals(0));

      expect(WorldChunkManager.needsFullLeap(ObstacleType.van), isTrue);
      expect(WorldChunkManager.needsFullLeap(ObstacleType.subwayTrain), isTrue);
      for (final type in hopped) {
        expect(WorldChunkManager.needsFullLeap(type), isFalse, reason: type.name);
      }
      expect(WorldChunkManager.needsFullLeap(ObstacleType.pigeonFlock), isFalse);
    });
  });

  // The generator left three quarters of a second of street behind every
  // hazard: room to land a hop and react. A van cannot be hopped, and the
  // leap that clears it is in the air for 1.3 s. Started late, that leap
  // came down on the next hazard or a few frames short of it. Measured at
  // the old spacing: of the press timings that clear a van, 3 in 13 left no
  // way past a dog behind it at 1,000 m, 5 in 13 no way past a second van,
  // and at top speed 7 in 16.
  group('Behind a van there is room to land the leap and react', () {
    final manager = WorldChunkManager(random: math.Random(1));
    const speeds = [200.0, 375.0, 550.0, 780.0];

    test('a full leap is in the air for about one and a third seconds', () {
      expect(WorldChunkManager.fullLeapAirtime, inInclusiveRange(1.25, 1.45));
    });

    test('behind a hazard a hop clears, the usual three quarters of a second', () {
      for (final type in ObstacleType.values.where((t) => !WorldChunkManager.needsFullLeap(t))) {
        for (final speed in speeds) {
          final usual = manager.calculateMinClearance(speed);
          expect(manager.clearanceAfter(type, speed), equals(usual));
          for (final next in ObstacleType.values) {
            expect(manager.clearanceBetween(type, next, speed), equals(usual));
          }
        }
      }
    });

    test('behind a van, as far as the leap can land and a quarter of a second more', () {
      for (final speed in speeds) {
        final landing =
            (WorldChunkManager.fullLeapAirtime - WorldChunkManager.latestLeapStart) * speed - 120.0;
        final rule = landing + WorldChunkManager.landingReaction * speed;
        final usual = manager.calculateMinClearance(speed);
        expect(manager.clearanceAfter(ObstacleType.van, speed), closeTo(math.max(usual, rule), 0.001));
      }
      // Early in a shift the usual clearance already covers it.
      expect(
        manager.clearanceAfter(ObstacleType.van, 200.0),
        equals(manager.calculateMinClearance(200.0)),
      );
      expect(
        manager.clearanceAfter(ObstacleType.van, 550.0),
        greaterThan(manager.calculateMinClearance(550.0) + 250.0),
      );
    });

    test('a skater behind a van is set back by what it covers while the courier is in the air', () {
      for (final speed in speeds) {
        final extra = manager.clearanceBetween(ObstacleType.van, ObstacleType.skateMessenger, speed) -
            manager.clearanceAfter(ObstacleType.van, speed);
        expect(
          extra,
          closeTo(65.0 * (WorldChunkManager.fullLeapAirtime + WorldChunkManager.landingReaction), 0.001),
        );
      }
    });

    test('a second van gets the run-up its own leap needs', () {
      for (final speed in speeds) {
        final extra = manager.clearanceBetween(ObstacleType.van, ObstacleType.van, speed) -
            manager.clearanceAfter(ObstacleType.van, speed);
        expect(extra, closeTo(WorldChunkManager.leapRunUp * speed, 0.001));
      }
    });

    // The street: a van, and [second] behind it. Returns the least room for
    // error [second] is left with over every way of leaping the van. The gap
    // when the courier reaches the van is the generator's rule, or
    // [gapOnArrival] if given.
    Future<int> worstRoomBehindVan(
      ObstacleType second,
      double meters,
      bool boosted, {
      double? gapOnArrival,
    }) async {
      final speed = (await bareStreetGame(meters, boosted: boosted)).currentSpeed;
      final onArrival = gapOnArrival ?? manager.clearanceBetween(ObstacleType.van, second, speed);
      final gap = onArrival + _rolls(second) * (900.0 / speed);
      var worst = 99;
      var ways = 0;
      for (var step = 0; step <= _steps; step++) {
        final leap = _Press(step * _step, _held);
        if (await _isHit([ObstacleType.van], [leap], meters, boosted: boosted)) continue;
        ways++;
        worst = math.min(worst, await _roomBehindVan(second, gap, leap, meters, boosted: boosted));
      }
      expect(ways, greaterThanOrEqualTo(6), reason: 'ways of leaping the van');
      return worst;
    }

    for (final second in WorldChunkManager.streetHazards) {
      test('then a ${second.name}: every way of leaping the van leaves 200 ms or more for it', () async {
        for (final (label, meters, boosted) in stages.skip(1)) {
          final worst = await worstRoomBehindVan(second, meters, boosted);
          expect(worst, greaterThanOrEqualTo(4), reason: label);
        }
      });
    }

    test('at the old spacing a late leap over a van left no way past what was behind it', () async {
      for (final second in const [ObstacleType.dog, ObstacleType.van]) {
        for (final meters in const [1000.0, 2000.0]) {
          final old = manager.calculateMinClearance(manager.calculateSpeed(meters));
          final worst = await worstRoomBehindVan(second, meters, false, gapOnArrival: old);
          expect(worst, equals(0), reason: '${second.name} at ${meters.round()} m');
        }
      }
    });
  });

  group('The street generator keeps that room', () {
    const startX = 1440.0;
    const chunkWidth = 960.0;

    test('behind every van and every train, on 80 streets out to 3,000 m', () {
      var vans = 0;
      var trains = 0;
      for (var seed = 0; seed < 80; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        ObstacleData? ahead;
        var aheadShift = 0.0;
        var aheadSpeed = 0.0;
        for (var meters = 0.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(startX: startX, speed: speed, distanceMeters: meters);
          final hazards = [...chunk.obstacles]..sort((a, b) => a.x.compareTo(b.x));
          aheadShift -= chunkWidth;

          for (var i = 0; i < hazards.length; i++) {
            final sameChunk = i > 0;
            final a = sameChunk ? hazards[i - 1] : ahead;
            if (a == null || !WorldChunkManager.needsFullLeap(a.type)) continue;
            final b = hazards[i];
            // A hazard in the next chunk that rolls was not on the street
            // yet when this one set off: its clearance is the next chunk's
            // arithmetic, checked by its own tests.
            if (!sameChunk && _rolls(b.type) != 0) continue;

            final aSpeed = sameChunk ? speed : aheadSpeed;
            final arrival =
                (WorldChunkManager.chunkSpawnLead + a.x - startX) / (aSpeed + _rolls(a.type));
            final aEnd = a.x - _rolls(a.type) * arrival + a.width + (sameChunk ? 0.0 : aheadShift);
            final bStart = b.x - (sameChunk ? _rolls(b.type) * arrival : 0.0);
            expect(
              bStart - aEnd,
              greaterThanOrEqualTo(street.clearanceBetween(a.type, b.type, aSpeed) - 0.5),
              reason: 'seed $seed at ${meters.round()} m: ${b.type.name} behind a ${a.type.name}',
            );
            if (a.type == ObstacleType.van) {
              vans++;
            } else {
              trains++;
            }
          }

          if (hazards.isNotEmpty) {
            ahead = hazards.last;
            aheadShift = 0.0;
            aheadSpeed = speed;
          }
        }
      }
      expect(vans, greaterThan(500));
      expect(trains, greaterThan(60));
    });

    test('no standing hazard is built past the end of its own chunk', () {
      for (var seed = 0; seed < 80; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(startX: startX, speed: speed, distanceMeters: meters);
          for (final hazard in chunk.obstacles) {
            if (_rolls(hazard.type) != 0) continue;
            expect(hazard.x, lessThan(startX + chunkWidth), reason: 'seed $seed at ${meters.round()} m');
          }
        }
      }
    });
  });
}
