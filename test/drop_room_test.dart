// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

import 'support/bare_street.dart';

const double _frame = 1 / 60;
const double _groundY = 460.0;
const double _deckHeight = 120.0;

/// Where a leap started: from the street after coming down off the deck,
/// or from anywhere else (the deck, the air).
enum _From { street, elsewhere }

/// A ramp, 300 px of scaffold and a van [gap] px behind the end of the deck.
/// The courier is carried up the ramp, and holds one leap from the moment
/// the van is [secondsAhead] away until landing. Returns whether the van
/// was cleared, and where the leap started.
Future<(bool, _From)> _leapVanBehindScaffold(double meters, double gap, double secondsAhead) async {
  final game = await scriptedStreetGame(meters, (startX, speed) {
    final rampX = startX + 100.0;
    final deckX = rampX + 74.0 + 10.0;
    const deckWidth = 300.0;
    final size = ObstacleComponent.defaultSizeForType(ObstacleType.van);
    return ChunkData(
      obstacles: [
        ObstacleData(
          type: ObstacleType.van,
          x: deckX + deckWidth + gap,
          y: _groundY - size.y,
          width: size.x,
          height: size.y,
        ),
      ],
      pickups: const [],
      ramps: [RampData(x: rampX, y: _groundY - 36.0, width: 74.0, height: 36.0)],
      scaffoldings: [
        ScaffoldingData(x: deckX, y: _groundY - _deckHeight, width: deckWidth, height: 12.0),
      ],
    );
  });

  var hits = 0;
  game.gameState.onDamageTaken = () => hits++;
  final player = game.player;
  var from = _From.elsewhere;
  var pressed = false;
  var holding = false;
  for (var f = 0; f < 60 * 20; f++) {
    final van = game.activeObstacles.isEmpty ? null : game.activeObstacles.first;
    if (van != null) {
      if (van.position.x + van.size.x < player.position.x - 80) break;
      final gapNow = van.position.x - (player.position.x + player.size.x);
      if (!pressed && gapNow <= secondsAhead * game.currentSpeed) {
        final onStreet = player.simulator.isGrounded && player.simulator.heightAboveGround < 1.0;
        from = onStreet ? _From.street : _From.elsewhere;
        game.holdJump('leap');
        pressed = true;
        holding = true;
      }
    }
    game.update(_frame);
    if (holding && pressed && player.simulator.isGrounded) {
      game.letGoOfJump('leap');
      holding = false;
    }
    if (f % 20 == 0) await Future<void>.delayed(Duration.zero);
  }
  expect(pressed, isTrue, reason: 'the van never arrived');
  return (hits == 0, from);
}

/// The longest unbroken run of press timings, 50 ms apart from 0 to 1 s
/// ahead of the van, that are made from the street and clear it.
Future<int> _roomFromTheStreet(double meters, double gap) async {
  var longest = 0;
  var run = 0;
  for (var step = 0; step <= 20; step++) {
    final (cleared, from) = await _leapVanBehindScaffold(meters, gap, step * 0.05);
    run = (cleared && from == _From.street) ? run + 1 : 0;
    longest = math.max(longest, run);
  }
  return longest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = WorldChunkManager(random: math.Random(1));

  // The ramp carries the courier up onto a scaffold whether they press or
  // not, and 200 to 480 px later they run off the end of it, 120 px up. The
  // fall takes 0.6 s. With the usual three quarters of a second of street
  // behind the deck, a van stood a tenth of a second from where they came
  // down: too late to start the leap a van needs. The only way past was to
  // have jumped from the deck.
  group('A van behind a scaffold can be leapt from the street', () {
    test('running off a scaffold takes 0.6 s to reach the street, a rail 0.4 s', () {
      expect(WorldChunkManager.dropSeconds(120.0), closeTo(0.595, 0.01));
      expect(WorldChunkManager.dropSeconds(48.0), closeTo(0.413, 0.01));
      expect(WorldChunkManager.dropSeconds(0.0), closeTo(0.1, 0.001));
    });

    test('a van stands back by the drop, a moment to react and its run-up', () {
      for (final speed in const [235.0, 375.0, 550.0]) {
        final needed = (WorldChunkManager.dropSeconds(_deckHeight) +
                WorldChunkManager.landingReaction +
                WorldChunkManager.leapRunUp) *
            speed;
        expect(
          manager.roomAfterDrop(ObstacleType.van, _deckHeight, speed),
          closeTo(needed - manager.calculateMinClearance(speed), 0.001),
        );
        expect(manager.roomAfterDrop(ObstacleType.van, _deckHeight, speed), greaterThan(0.2 * speed));
        // Lower pieces need less.
        expect(
          manager.roomAfterDrop(ObstacleType.van, 48.0, speed),
          lessThan(manager.roomAfterDrop(ObstacleType.van, _deckHeight, speed)),
        );
      }
    });

    test('what a hop clears needs nothing more: it can be pressed on landing', () {
      for (final type in ObstacleType.values.where((t) => !WorldChunkManager.needsFullLeap(t))) {
        expect(manager.roomAfterDrop(type, _deckHeight, 375.0), equals(0.0), reason: type.name);
      }
    });

    for (final meters in const [200.0, 1000.0, 2000.0]) {
      test('at ${meters.round()} m there is 200 ms or more to leap it after landing', () async {
        final speed = manager.calculateSpeed(meters);
        final gap =
            manager.calculateMinClearance(speed) + manager.roomAfterDrop(ObstacleType.van, _deckHeight, speed);
        expect(await _roomFromTheStreet(meters, gap), greaterThanOrEqualTo(4));
      });
    }

    test('with only the usual clearance there was 100 ms at best', () async {
      for (final meters in const [200.0, 1000.0]) {
        final usual = manager.calculateMinClearance(manager.calculateSpeed(meters));
        expect(await _roomFromTheStreet(meters, usual), lessThanOrEqualTo(2), reason: '$meters m');
      }
    });

    test('jumping from the deck still clears it', () async {
      final speed = manager.calculateSpeed(1000.0);
      final gap =
          manager.calculateMinClearance(speed) + manager.roomAfterDrop(ObstacleType.van, _deckHeight, speed);
      final (cleared, from) = await _leapVanBehindScaffold(1000.0, gap, 0.9);
      expect(from, equals(_From.elsewhere));
      expect(cleared, isTrue);
    });
  });

  group('The street generator keeps that room', () {
    test('behind every scaffold, rail and solar array, on 120 streets out to 3,000 m', () {
      var checked = 0;
      for (var seed = 0; seed < 120; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(startX: 1440.0, speed: speed, distanceMeters: meters);

          // Each piece the courier can come off, with its end and height.
          final pieces = <(double, double)>[
            for (final s in chunk.scaffoldings) (s.x + s.width, _groundY - s.y),
            for (final r in chunk.grindRails) (r.x + r.width, _groundY - r.y),
            for (final p in chunk.solarPanels) (p.x + p.width, _groundY - p.y),
          ];
          if (pieces.isEmpty) continue;
          final lastEnd = pieces.map((p) => p.$1).reduce(math.max);
          final height = pieces.firstWhere((p) => p.$1 == lastEnd).$2;

          final behind = chunk.obstacles.where((o) => o.x > lastEnd).toList()
            ..sort((a, b) => a.x.compareTo(b.x));
          if (behind.isEmpty || behind.first.type != ObstacleType.van) continue;
          expect(
            behind.first.x - lastEnd,
            greaterThanOrEqualTo(
              street.calculateMinClearance(speed) +
                  street.roomAfterDrop(ObstacleType.van, height, speed) -
                  0.5,
            ),
            reason: 'seed $seed at ${meters.round()} m, piece $height px up',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(60));
    });
  });
}
