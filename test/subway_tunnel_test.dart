import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/components/subway_station_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SubwayStationComponent Unit Tests (Issue #49)', () {
    test('initializes with default and custom transit parameters', () {
      final defaultStation = SubwayStationComponent(position: Vector2(400.0, 200.0));
      expect(defaultStation.size.x, equals(1000.0));
      expect(defaultStation.size.y, equals(260.0));
      expect(defaultStation.stationName, equals('8th Ave Express'));
      expect(defaultStation.lineColor, equals(const Color(0xFF2980B9)));
      expect(defaultStation.hasTriggeredTransit, isFalse);
      expect(defaultStation.shouldRecycle, isFalse);

      final customStation = SubwayStationComponent(
        position: Vector2(100.0, 150.0),
        size: Vector2(800.0, 300.0),
        groundY: 450.0,
        stationName: 'Grand Central Line',
        lineColor: const Color(0xFF27AE60),
      );
      expect(customStation.stationName, equals('Grand Central Line'));
      expect(customStation.lineColor, equals(const Color(0xFF27AE60)));
      expect(customStation.groundY, equals(450.0));
      expect(customStation.size.x, equals(800.0));
    });

    test('shouldRecycle returns true once station has scrolled past screen horizon', () {
      final station = SubwayStationComponent(
        position: Vector2(100.0, 200.0),
        size: Vector2(500.0, 260.0),
      );
      expect(station.shouldRecycle, isFalse);

      station.position.x = -750.0;
      expect(station.shouldRecycle, isTrue);
    });

    test('update advances fluorescent light flicker timer and toggles flicker state', () {
      final station = SubwayStationComponent(position: Vector2.zero());
      expect(station.lightsFlicker, isFalse);
      expect(station.flickerTimer, equals(0.0));

      // Advance past 0.7s interval
      station.update(0.75);
      expect(station.lightsFlicker, isTrue);
      expect(station.flickerTimer, lessThan(0.1));
    });

    test('procedural canvas rendering of tiles, transit bands, signs, and rails executes cleanly', () {
      final station = SubwayStationComponent(position: Vector2.zero());
      station.update(0.05);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => station.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('Subway Obstacles Unit Tests (Issue #49)', () {
    test('ObstacleType.thirdRail is vaultable and stationary on track bed', () {
      final thirdRail = ObstacleComponent(
        position: Vector2(300.0, 436.0),
        type: ObstacleType.thirdRail,
      );
      expect(thirdRail.size.x, equals(58.0));
      expect(thirdRail.size.y, equals(24.0));
      expect(thirdRail.isVaultable, isTrue);
      expect(thirdRail.relativeVelocityX, equals(0.0));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => thirdRail.render(canvas), returnsNormally);
      recorder.endRecording().dispose();
    });

    test('ObstacleType.subwayTrain is non-vaultable and moves with relative oncoming speed', () {
      final train = ObstacleComponent(
        position: Vector2(600.0, 396.0),
        type: ObstacleType.subwayTrain,
      );
      expect(train.size.x, equals(110.0));
      expect(train.size.y, equals(64.0));
      expect(train.isVaultable, isFalse);
      expect(train.relativeVelocityX, equals(80.0));

      final initialX = train.position.x;
      train.update(0.1);
      expect(train.position.x, equals(initialX - (80.0 * 0.1)));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => train.render(canvas), returnsNormally);
      recorder.endRecording().dispose();
    });
  });

  group('GameState Subway Transit Mechanics (Issue #49)', () {
    test('recordSubwayTransit increments counter, applies combo multipliers, and fires transit event', () {
      final state = GameState();
      state.startRun();
      expect(state.subwayStationsInRun, equals(0));

      SubwayTransitEvent? capturedEvent;
      state.onSubwayTransit = (event) {
        capturedEvent = event;
      };

      // 1st transit at 1.0x combo multiplier
      final event1 = state.recordSubwayTransit(stationName: '8th Ave Express');
      expect(state.subwayStationsInRun, equals(1));
      expect(event1, isNotNull);
      expect(event1!.totalTips, equals(25)); // 25 * 1.0 = 25
      expect(state.tips, equals(25));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.stationName, equals('8th Ave Express'));
      expect(capturedEvent!.baseTips, equals(25));
      expect(capturedEvent!.totalTips, equals(25));
      expect(capturedEvent!.multiplier, equals(1.0));

      // Increase stunt combo multiplier
      state.recordStunt(clearance: 10.0);
      expect(state.stuntMultiplier, greaterThan(1.0));
      final mult = state.stuntMultiplier;

      // 2nd transit at boosted combo
      final event2 = state.recordSubwayTransit(stationName: 'Broadway Metro');
      expect(state.subwayStationsInRun, equals(2));
      expect(event2!.totalTips, equals((25 * mult).round()));
      expect(capturedEvent!.stationName, equals('Broadway Metro'));
      expect(capturedEvent!.totalTips, equals(event2.totalTips));
      expect(capturedEvent!.multiplier, equals(mult));
    });

    test('startRun resets subwayStationsInRun to 0', () {
      final state = GameState();
      state.startRun();
      state.recordSubwayTransit();
      expect(state.subwayStationsInRun, equals(1));

      state.startRun();
      expect(state.subwayStationsInRun, equals(0));
    });
  });

  group('WorldChunkManager Subway Procedural Generation (Issue #49)', () {
    test('subway stations do not spawn prior to 200 meters', () {
      final manager = WorldChunkManager(random: math.Random(12345));
      for (int i = 0; i < 10; i++) {
        final chunk = manager.generateChunk(
          startX: i * 960.0,
          speed: 260.0,
          distanceMeters: 50.0 + (i * 10.0),
        );
        expect(chunk.subwayStations, isEmpty);
      }
    });

    test('subway station spawns with third rail and oncoming train hazards beyond 200m', () {
      // Find a deterministic seed that triggers subway station generation at distance >= 200m
      WorldChunkManager? manager;
      ChunkData? subwayChunk;
      for (int seed = 1; seed < 100; seed++) {
        final m = WorldChunkManager(random: math.Random(seed));
        final chunk = m.generateChunk(
          startX: 1000.0,
          speed: 280.0,
          distanceMeters: 250.0,
        );
        if (chunk.subwayStations.isNotEmpty) {
          manager = m;
          subwayChunk = chunk;
          break;
        }
      }

      expect(manager, isNotNull);
      expect(subwayChunk, isNotNull);
      expect(subwayChunk!.subwayStations.length, equals(1));
      final station = subwayChunk.subwayStations.first;
      expect(station.stationName, isNotEmpty);
      expect(station.width, equals(960.0));

      // Check subterranean hazards spawned inside the station
      expect(
        subwayChunk.obstacles.any((o) => o.type == ObstacleType.thirdRail),
        isTrue,
      );
      expect(
        subwayChunk.obstacles.any((o) => o.type == ObstacleType.subwayTrain),
        isTrue,
      );

      // Mutually exclusive with aerial routes and ground drop zones
      expect(subwayChunk.scaffoldings, isEmpty);
      expect(subwayChunk.grindRails, isEmpty);
      expect(subwayChunk.steamVents, isEmpty);
      expect(subwayChunk.dropZones, isEmpty);
    });
  });

  group('CourierGame Subway Transit Integration (Issue #49)', () {
    late CourierGame game;

    setUp(() async {
      game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();
    });

    tearDown(() {
      game.gameState.status = GameStatus.idle;
    });

    test('entering subway station corridor triggers transit event, tip reward, and indicator', () {
      final station = SubwayStationComponent(
        position: Vector2(game.player.position.x - 50.0, 200.0),
        size: Vector2(1000.0, 260.0),
        stationName: 'Broadway Metro',
      );
      game.activeSubwayStations.add(station);
      game.world.add(station);

      expect(station.hasTriggeredTransit, isFalse);
      expect(game.gameState.subwayStationsInRun, equals(0));

      // Advance game loop
      game.update(0.016);

      expect(station.hasTriggeredTransit, isTrue);
      expect(game.gameState.subwayStationsInRun, equals(1));
      expect(game.gameState.tips, greaterThanOrEqualTo(25));

      // Floating text should be spawned
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>();
      expect(floatingTexts.any((t) => t.text.contains('SUBWAY: Broadway Metro!')), isTrue);

      // Further updates do not re-trigger transit for the same station
      game.update(0.016);
      expect(game.gameState.subwayStationsInRun, equals(1));
    });

    test('step 6 recycling removes off-screen activeSubwayStations', () {
      final station = SubwayStationComponent(
        position: Vector2(-1300.0, 200.0),
        size: Vector2(1000.0, 260.0),
      );
      game.activeSubwayStations.add(station);
      game.world.add(station);

      expect(station.shouldRecycle, isTrue);
      expect(game.activeSubwayStations.contains(station), isTrue);

      game.update(0.016);

      expect(game.activeSubwayStations.contains(station), isFalse);
      expect(station.isMounted, isFalse);
    });

    test('restartRun cleans up active subway stations and resets counters', () {
      final station = SubwayStationComponent(
        position: Vector2(game.player.position.x, 200.0),
      );
      game.activeSubwayStations.add(station);
      game.world.add(station);

      game.gameState.recordSubwayTransit();
      expect(game.gameState.subwayStationsInRun, equals(1));

      game.restartRun();

      expect(game.gameState.subwayStationsInRun, equals(0));
      expect(game.activeSubwayStations.contains(station), isFalse);
    });
  });

  group('GameOverModal Subway Badge UI Tests (Issue #49)', () {
    testWidgets('GameOverModal displays game_over_subway_badge with singular text when subwayStationsCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 500,
              tips: 120,
              careerTips: 900,
              isNewRecord: false,
              subwayStationsCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_subway_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('1 SUBWAY TRANSIT'), findsOneWidget);
    });

    testWidgets('GameOverModal displays plural text when subwayStationsCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 850,
              tips: 260,
              careerTips: 1200,
              isNewRecord: false,
              subwayStationsCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_subway_badge')), findsOneWidget);
      expect(find.text('3 SUBWAY TRANSITS'), findsOneWidget);
    });

    testWidgets('GameOverModal hides game_over_subway_badge when subwayStationsCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 150,
              tips: 30,
              careerTips: 400,
              isNewRecord: false,
              subwayStationsCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('game_over_subway_badge')), findsNothing);
    });
  });
}
