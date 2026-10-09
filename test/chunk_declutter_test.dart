import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/chunk_declutter.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const double _groundY = 460.0;

class _Span {
  _Span(this.kind, this.x, this.width);
  final String kind;
  final double x;
  final double width;
  double get end => x + width;
}

/// Street-level footprints the declutter pass is responsible for, tagged by
/// feature. Puddles, cyclists and crane masts are exempt by design.
List<_Span> _streetSpans(ChunkData chunk) {
  final spans = <_Span>[];
  void add(String kind, double x, double y, double width, double height) {
    if (y + height >= _groundY - 6.0) spans.add(_Span(kind, x, width));
  }

  for (final p in chunk.obstacles) {
    add('anchor', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.dropZones) {
    add('anchor', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.scaffoldings) {
    add('anchor', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.ramps) {
    add('anchor', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.grindRails) {
    add('anchor', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.turnstiles) {
    add('anchor', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.steamVents) {
    add('steamVent', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.foodCarts) {
    add('foodCart', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.stormDrains) {
    add('stormDrain', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.solarPanels) {
    add('solarPanel', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.droneCargos) {
    add('droneCargo', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.fireEscapes) {
    add('fireEscape', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.foodTruckSlicks) {
    add('foodTruckSlick', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.barricades) {
    add('barricade', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.satelliteDishes) {
    add('satelliteDish', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.postalMailboxes) {
    add('mailbox', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.acCondensers) {
    add('acCondenser', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.glassSkylights) {
    add('skylight', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.flowerKiosks) {
    add('flowerKiosk', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.waterTowers) {
    add('waterTower', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.newsstands) {
    add('newsstand', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.cafeBistros) {
    add('cafeBistro', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.streetBuskers) {
    add('busker', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.fireHydrants) {
    add('fireHydrant', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.clotheslines) {
    add('clothesline', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.subwayExhaustGrates) {
    add('exhaustGrate', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.busShelters) {
    add('busShelter', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.securityShutters) {
    add('shutter', p.x, p.y, p.width, p.height);
  }
  for (final p in chunk.cementMixers) {
    add('cementMixer', p.x, p.y, p.width, p.height);
  }
  return spans;
}

void main() {
  group('declutterStreet', () {
    StreetPiece piece(double x, double width, {List<String>? log, String name = ''}) {
      return StreetPiece(
        x: x,
        width: width,
        baseY: _groundY,
        remove: log == null ? null : () => log.add(name),
      );
    }

    test('removes an optional piece that sits on an anchor', () {
      final removed = <String>[];
      final count = declutterStreet(
        groundY: _groundY,
        anchors: [piece(100, 50)],
        optionalByPriority: [
          piece(120, 40, log: removed, name: 'on-anchor'),
          piece(400, 40, log: removed, name: 'clear'),
        ],
      );
      expect(count, equals(1));
      expect(removed, equals(['on-anchor']));
    });

    test('the higher-priority of two overlapping optional pieces keeps its spot', () {
      final removed = <String>[];
      final left = piece(100, 60, log: removed, name: 'left');
      final right = piece(140, 60, log: removed, name: 'right');

      declutterStreet(groundY: _groundY, anchors: const [], optionalByPriority: [left, right]);
      expect(removed, equals(['right']));

      removed.clear();
      declutterStreet(groundY: _groundY, anchors: const [], optionalByPriority: [right, left]);
      expect(removed, equals(['left']));
    });

    test('enforces the minimum gap between neighbours', () {
      final removed = <String>[];
      declutterStreet(
        groundY: _groundY,
        anchors: [piece(100, 50)],
        optionalByPriority: [
          piece(160, 30, log: removed, name: '10px-away'),
          piece(300, 30, log: removed, name: 'far'),
        ],
        minGap: 20,
      );
      expect(removed, equals(['10px-away']));
    });

    test('ignores pieces that never reach the sidewalk', () {
      final removed = <String>[];
      final count = declutterStreet(
        groundY: _groundY,
        anchors: [piece(100, 50)],
        optionalByPriority: [
          StreetPiece(x: 110, width: 40, baseY: 300, remove: () => removed.add('rooftop')),
        ],
      );
      expect(count, equals(0));
      expect(removed, isEmpty);
    });
  });

  group('Generated chunks stay readable', () {
    test('no two street set pieces overlap, and hazards are never thinned out', () {
      for (final meters in const [150.0, 600.0, 2000.0]) {
        final manager = WorldChunkManager(random: math.Random(7));
        final control = WorldChunkManager(random: math.Random(7));
        double x = 960.0;
        for (var i = 0; i < 300; i++) {
          final chunk = manager.generateChunk(
            startX: x,
            chunkWidth: 960.0,
            speed: manager.calculateSpeed(meters),
            distanceMeters: meters,
          );
          final spans = _streetSpans(chunk)..sort((a, b) => a.x.compareTo(b.x));
          for (var a = 0; a < spans.length; a++) {
            for (var b = a + 1; b < spans.length; b++) {
              if (spans[a].kind == 'anchor' && spans[b].kind == 'anchor') continue;
              final overlap = spans[b].x < spans[a].end && spans[a].x < spans[b].end;
              expect(
                overlap,
                isFalse,
                reason: '${spans[a].kind} [${spans[a].x.round()}..${spans[a].end.round()}] overlaps '
                    '${spans[b].kind} [${spans[b].x.round()}..${spans[b].end.round()}] '
                    'in chunk $i at ${meters.round()}m',
              );
            }
          }

          // Same seed, same draw order: the pass consumes no randomness, so
          // hazards and delivery targets match an identically seeded manager.
          final twin = control.generateChunk(
            startX: x,
            chunkWidth: 960.0,
            speed: control.calculateSpeed(meters),
            distanceMeters: meters,
          );
          expect(chunk.obstacles.length, equals(twin.obstacles.length));
          expect(chunk.dropZones.length, equals(twin.dropZones.length));
          x += 960.0;
        }
      }
    });

    test('every street feature still shows up regularly after thinning', () {
      final manager = WorldChunkManager(random: math.Random(11));
      final seen = <String, int>{};
      double x = 960.0;
      const chunks = 1500;
      for (var i = 0; i < chunks; i++) {
        final chunk = manager.generateChunk(
          startX: x,
          chunkWidth: 960.0,
          speed: manager.calculateSpeed(1500.0),
          distanceMeters: 1500.0,
        );
        for (final span in _streetSpans(chunk)) {
          seen[span.kind] = (seen[span.kind] ?? 0) + 1;
        }
        x += 960.0;
      }

      const expected = [
        'steamVent', 'foodCart', 'stormDrain', 'fireEscape', 'foodTruckSlick',
        'barricade', 'mailbox', 'flowerKiosk', 'newsstand', 'cafeBistro',
        'busker', 'fireHydrant', 'clothesline', 'exhaustGrate', 'busShelter',
        'shutter', 'cementMixer',
      ];
      for (final kind in expected) {
        expect(
          seen[kind] ?? 0,
          greaterThan(chunks ~/ 50),
          reason: '$kind appeared ${seen[kind] ?? 0} times in $chunks chunks',
        );
      }
    });
  });
}
