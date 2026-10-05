import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const _groundY = 460.0;

/// Every chunk of [seeds] streets, out to 3,000 m.
Iterable<ChunkData> _streets({int seeds = 200}) sync* {
  for (var seed = 0; seed < seeds; seed++) {
    final manager = WorldChunkManager(random: math.Random(seed));
    // A chunk is 960 px and the game counts 20 px to the metre.
    for (var meters = 0.0; meters < 3000.0; meters += 48.0) {
      yield manager.generateChunk(
        startX: 1440.0,
        speed: manager.calculateSpeed(meters),
        distanceMeters: meters,
      );
    }
  }
}

/// Everything in [chunk] that is neither the station, its hazards nor coins.
Map<String, int> _streetPieces(ChunkData chunk) {
  final lists = <String, List<Object>>{
    'scaffolding': chunk.scaffoldings,
    'ramps': chunk.ramps,
    'drop zones': chunk.dropZones,
    'grind rails': chunk.grindRails,
    'steam vents': chunk.steamVents,
    'crane swings': chunk.craneSwings,
    'cyclists': chunk.cyclists,
    'pigeon flocks': chunk.pigeonFlocks,
    'crosswalks': chunk.crosswalks,
    'food carts': chunk.foodCarts,
    'storm drains': chunk.stormDrains,
    'solar panels': chunk.solarPanels,
    'puddles': chunk.puddles,
    'wind tunnels': chunk.windTunnels,
    'turnstiles': chunk.turnstiles,
    'drone cargo': chunk.droneCargos,
    'fire escapes': chunk.fireEscapes,
    'food truck slicks': chunk.foodTruckSlicks,
    'barricades': chunk.barricades,
    'satellite dishes': chunk.satelliteDishes,
    'mailboxes': chunk.postalMailboxes,
    'AC condensers': chunk.acCondensers,
    'glass skylights': chunk.glassSkylights,
    'flower kiosks': chunk.flowerKiosks,
    'water towers': chunk.waterTowers,
    'newsstands': chunk.newsstands,
    'cafe tables': chunk.cafeBistros,
    'buskers': chunk.streetBuskers,
    'fire hydrants': chunk.fireHydrants,
    'clotheslines': chunk.clotheslines,
    'exhaust grates': chunk.subwayExhaustGrates,
    'ziplines': chunk.catenaryZiplines,
    'bus shelters': chunk.busShelters,
    'security shutters': chunk.securityShutters,
  };
  return {
    for (final entry in lists.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.length,
  };
}

void main() {
  // A subway station is a tiled wall a whole chunk wide, with a third rail
  // and an oncoming train. Twenty-one kinds of street piece were written to
  // stay out of a station chunk. The five newest (clotheslines, exhaust
  // grates, ziplines, bus shelters, security shutters) were not, and rooftop
  // solar arrays and wind tunnels are placed before the station is decided
  // and were never taken back out. Nobody saw the result, because stations
  // never came on screen. Once they did, each of those seven kinds turned up
  // in a fifth to a third of stations: rooftop laundry, a bus shelter or a
  // storefront shutter on the platform, or a solar array straddling the
  // train with its deck ten pixels below the train's roof.
  group('A subway station has the chunk to itself', () {
    late final List<ChunkData> stations;
    late final int chunksPast200m;

    setUpAll(() {
      final all = _streets().toList();
      stations = all.where((c) => c.subwayStations.isNotEmpty).toList();
      // 63 chunks to a street, the first five of them before 200 m.
      chunksPast200m = all.length - 200 * 5;
    });

    test('there are plenty of stations to judge by', () {
      expect(stations.length, greaterThan(500));
    });

    test('its only hazards are one third rail and one train, rail first', () {
      for (final chunk in stations) {
        expect(chunk.obstacles.map((o) => o.type),
            orderedEquals([ObstacleType.thirdRail, ObstacleType.subwayTrain]));
        final rail = chunk.obstacles.first;
        final train = chunk.obstacles.last;
        expect(train.x - (rail.x + rail.width), greaterThanOrEqualTo(200.0));
      }
    });

    test('no other street piece is built in it', () {
      final intruders = <String, int>{};
      for (final chunk in stations) {
        _streetPieces(chunk).forEach((name, _) {
          intruders[name] = (intruders[name] ?? 0) + 1;
        });
      }
      expect(intruders, isEmpty,
          reason: 'street pieces found in ${stations.length} station chunks');
    });

    test('the coins of a removed solar array or wind tunnel go with it', () {
      // Their coins are laid in a row 80 px (solar array) or 93 px (wind
      // tunnel) above the street, and nothing else puts a pickup there.
      bool onRooftopKit(PickupData p) => p.y == _groundY - 80.0 || p.y == _groundY - 93.0;
      for (final chunk in stations) {
        expect(chunk.pickups.where(onRooftopKit), isEmpty);
      }
      // The heights are a fair fingerprint: ordinary chunks with the kit have
      // such coins, ordinary chunks without it have none.
      var withKit = 0;
      for (final chunk in _streets(seeds: 40)) {
        if (chunk.subwayStations.isNotEmpty) continue;
        final hasKit = chunk.solarPanels.isNotEmpty || chunk.windTunnels.isNotEmpty;
        if (hasKit) {
          withKit += chunk.pickups.where(onRooftopKit).length;
        } else {
          expect(chunk.pickups.where(onRooftopKit), isEmpty);
        }
      }
      expect(withKit, greaterThan(100));
    });

    test('every pickup is inside the station', () {
      for (final chunk in stations) {
        final station = chunk.subwayStations.single;
        for (final pickup in chunk.pickups) {
          expect(pickup.x, inInclusiveRange(station.x, station.x + station.width));
        }
      }
    });

    test('stations are as common as before: about 1.4 per 1,000 m', () {
      final perKilometer = stations.length / 200 / 2.8;
      expect(perKilometer, inInclusiveRange(1.1, 1.7));
      expect(stations.length / chunksPast200m, inInclusiveRange(0.05, 0.085));
    });
  });

  // Past 800 m a street draws its hazards from a list. The list was "every
  // kind of hazard there is", which was right until the third rail and the
  // subway train were added for stations: from then on two late-game
  // hazards in nine were a live rail or a train on the open street.
  group('Third rails and subway trains belong to stations', () {
    late final List<ChunkData> all;
    setUpAll(() => all = _streets().toList());

    test('none is built on an open street, at any distance', () {
      var strays = 0;
      var ordinary = 0;
      for (final chunk in all) {
        if (chunk.subwayStations.isNotEmpty) continue;
        ordinary++;
        strays += chunk.obstacles
            .where((o) => o.type == ObstacleType.thirdRail || o.type == ObstacleType.subwayTrain)
            .length;
      }
      expect(ordinary, greaterThan(10000));
      expect(strays, equals(0));
    });

    test('the street list is the five fixed hazards and the two that move', () {
      expect(
        WorldChunkManager.streetHazards.toSet(),
        equals({
          ObstacleType.scooter,
          ObstacleType.dog,
          ObstacleType.hydrant,
          ObstacleType.mailbox,
          ObstacleType.van,
          ObstacleType.skateMessenger,
          ObstacleType.pigeonFlock,
        }),
      );
    });

    test('skaters and pigeons still turn up on the open street', () {
      final seen = <ObstacleType, int>{};
      for (final chunk in all) {
        if (chunk.subwayStations.isNotEmpty) continue;
        for (final o in chunk.obstacles) {
          seen[o.type] = (seen[o.type] ?? 0) + 1;
        }
      }
      for (final type in WorldChunkManager.streetHazards) {
        expect(seen[type] ?? 0, greaterThan(300), reason: '${type.name} has become rare');
      }
    });
  });

  // The train rolls toward the courier at 80 px/s on top of the street's
  // speed. It was built 280-340 px behind the rail, and had made that up by
  // the time the pair arrived: at 300 px/s it was just ahead of the rail, at
  // 400 on top of it, at 550 just behind. One block up to 230 px wide.
  group('The train is still a hazard away when the courier has passed the rail', () {
    final manager = WorldChunkManager(random: math.Random(1));
    const approach = 80.0;

    /// How far the train is from the end of the rail at the moment the rail
    /// has gone by the courier.
    double gapOnArrival(double railOffset, double speed) {
      final setback = manager.subwayTrainSetback(railOffset: railOffset, speed: speed);
      final secondsToPassRail =
          (WorldChunkManager.chunkSpawnLead + railOffset + WorldChunkManager.thirdRailWidth) / speed;
      return setback - WorldChunkManager.thirdRailWidth - approach * secondsToPassRail;
    }

    test('at every speed the gap is the clearance any two hazards get', () {
      for (final speed in [235.0, 300.0, 400.0, 550.0, 660.0, 780.0]) {
        for (final railOffset in [220.0, 260.0, 300.0]) {
          final gap = gapOnArrival(railOffset, speed);
          expect(gap, closeTo(manager.calculateMinClearance(speed + approach), 0.01),
              reason: '$speed px/s, rail $railOffset px in');
          // In time, at the speed they are closing: three quarters of a second.
          expect(gap / (speed + approach), greaterThanOrEqualTo(0.74));
        }
      }
    });

    test('the old fixed setback had left nothing by arrival', () {
      // What used to be built: 280 to 340 px behind the start of the rail.
      for (final speed in [300.0, 400.0, 550.0]) {
        final secondsToPassRail = (WorldChunkManager.chunkSpawnLead + 260.0 + 58.0) / speed;
        final oldGap = 310.0 - 58.0 - approach * secondsToPassRail;
        expect(oldGap, lessThan(60.0), reason: '$speed px/s');
      }
    });

    test('built stations use it', () {
      var checked = 0;
      for (var seed = 0; seed < 60; seed++) {
        final street = WorldChunkManager(random: math.Random(seed));
        for (var meters = 0.0; meters < 3000.0; meters += 48.0) {
          final speed = street.calculateSpeed(meters);
          final chunk = street.generateChunk(startX: 1440.0, speed: speed, distanceMeters: meters);
          if (chunk.subwayStations.isEmpty) continue;
          checked++;
          final rail = chunk.obstacles.first;
          final train = chunk.obstacles.last;
          final setback = street.subwayTrainSetback(railOffset: rail.x - 1440.0, speed: speed);
          // Plus up to 60 px of variety.
          expect(train.x - rail.x, inInclusiveRange(setback, setback + 60.0));
        }
      }
      expect(checked, greaterThan(100));
    });
  });

  group('Ordinary chunks keep their street pieces', () {
    test('the seven kinds kept out of stations still appear elsewhere', () {
      final seen = <String, int>{};
      for (final chunk in _streets(seeds: 40)) {
        if (chunk.subwayStations.isNotEmpty) continue;
        _streetPieces(chunk).forEach((name, _) => seen[name] = (seen[name] ?? 0) + 1);
      }
      for (final kind in [
        'solar panels',
        'wind tunnels',
        'clotheslines',
        'exhaust grates',
        'ziplines',
        'bus shelters',
        'security shutters',
      ]) {
        expect(seen[kind] ?? 0, greaterThan(100), reason: '$kind have become rare');
      }
    });
  });
}
