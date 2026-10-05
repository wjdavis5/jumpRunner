import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/particle_effect.dart';
import 'package:jump_runner/game/components/pickup_component.dart';
import 'package:jump_runner/game/components/solar_panel_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SolarPanelComponent Unit Tests (Issue #69)', () {
    test('initializes with accurate properties, charge level, and surface coordinates', () {
      final panel = SolarPanelComponent(
        position: Vector2(250.0, 396.0),
        size: Vector2(220.0, 18.0),
        groundY: 460.0,
      );

      expect(panel.position.x, equals(250.0));
      expect(panel.position.y, equals(396.0));
      expect(panel.size.x, equals(220.0));
      expect(panel.size.y, equals(18.0));
      expect(panel.surfaceY, equals(396.0));
      expect(panel.groundY, equals(460.0));
      expect(panel.chargeLevel, equals(0.0));
      expect(panel.isCharging, isFalse);
      expect(panel.hasDischarged, isFalse);
      expect(panel.shouldRecycle, isFalse);
    });

    test('shouldRecycle triggers when panel has scrolled past offscreen threshold', () {
      final panel = SolarPanelComponent(
        position: Vector2(-350.0, 396.0),
        size: Vector2(200.0, 18.0),
      );

      expect(panel.shouldRecycle, isTrue);
    });

    test('addCharge increments chargeLevel and clamps strictly between 0.0 and 1.0', () {
      final panel = SolarPanelComponent(
        position: Vector2(100.0, 396.0),
        size: Vector2(200.0, 18.0),
      );

      panel.addCharge(0.4);
      expect(panel.chargeLevel, closeTo(0.4, 0.001));

      panel.addCharge(0.5);
      expect(panel.chargeLevel, closeTo(0.9, 0.001));

      panel.addCharge(0.5); // Should clamp to 1.0
      expect(panel.chargeLevel, equals(1.0));
    });

    test('isUnderCourierFootprint accurately evaluates landing overlap bounds', () {
      final panel = SolarPanelComponent(
        position: Vector2(200.0, 380.0),
        size: Vector2(200.0, 20.0),
      );

      // Directly on surface in center
      expect(panel.isUnderCourierFootprint(300.0, 380.0), isTrue);

      // Within vertical landing tolerance (-14 to +18)
      expect(panel.isUnderCourierFootprint(300.0, 370.0), isTrue);
      expect(panel.isUnderCourierFootprint(300.0, 395.0), isTrue);

      // Outside vertical landing tolerance
      expect(panel.isUnderCourierFootprint(300.0, 360.0), isFalse);
      expect(panel.isUnderCourierFootprint(300.0, 410.0), isFalse);

      // Outside horizontal bounds
      expect(panel.isUnderCourierFootprint(190.0, 380.0), isFalse);
      expect(panel.isUnderCourierFootprint(410.0, 380.0), isFalse);
    });

    test('isPastForwardEdge returns true when courier has crossed forward dismount edge', () {
      final panel = SolarPanelComponent(
        position: Vector2(200.0, 380.0),
        size: Vector2(200.0, 20.0),
      );

      expect(panel.isPastForwardEdge(350.0), isFalse);
      expect(panel.isPastForwardEdge(400.0), isFalse);
      expect(panel.isPastForwardEdge(401.0), isTrue);
      expect(panel.isPastForwardEdge(450.0), isTrue);
    });

    test('renders procedural aluminum chassis, cells, busbars, and LEDs without error', () {
      final panel = SolarPanelComponent(
        position: Vector2(100.0, 340.0),
        size: Vector2(220.0, 20.0),
        groundY: 460.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Test rendering across charge phases
      panel.render(canvas);

      panel.chargeLevel = 0.5;
      panel.isCharging = true;
      panel.render(canvas);

      panel.chargeLevel = 1.0;
      panel.render(canvas);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('ParticleEffectComponent Electric Sparks Tests (Issue #69)', () {
    test('electricSparks factory generates dual-tone high-voltage particles', () {
      final sparks = ParticleEffectComponent.electricSparks(
        position: Vector2(200.0, 300.0),
        count: 14,
      );

      expect(sparks.particles.length, equals(14));
      for (final p in sparks.particles) {
        expect(p.isAlive, isTrue);
        expect(p.maxLife, greaterThan(0.2));
        expect(p.maxLife, lessThan(0.5));
        expect(p.gravity, equals(60.0));
      }
    });

    test('electricSparks particles update and expire over lifecycle', () {
      final sparks = ParticleEffectComponent.electricSparks(
        position: Vector2(200.0, 300.0),
        count: 5,
      );

      expect(sparks.isFinished, isFalse);

      // Simulate 0.5s passing (beyond max life)
      sparks.update(0.5);
      expect(sparks.isFinished, isTrue);
    });
  });

  group('GameState Solar Surge Economy & Combo Tests (Issue #69)', () {
    test('recordSolarSurge increments counter and advances stunt combo streak', () {
      final state = GameState();
      state.startRun();

      expect(state.solarSurgesInRun, equals(0));
      expect(state.stuntStreak, equals(0));

      final event = state.recordSolarSurge(baseTips: 35, coinsHarvested: 2);
      expect(event, isNotNull);
      expect(event!.baseTips, equals(35));
      expect(event.multiplier, equals(1.2)); // Streak 1 gives 1.2x
      expect(event.totalTips, equals(42)); // 35 * 1.2 = 42
      expect(event.stuntStreak, equals(1));
      expect(event.coinsHarvested, equals(2));

      expect(state.solarSurgesInRun, equals(1));
      expect(state.stuntStreak, equals(1));
      expect(state.tips, equals(42));
    });

    test('recordSolarSurge scales with higher stunt combo streaks', () {
      final state = GameState();
      state.startRun();

      state.stuntStreak = 3; // Streak 3 gives 2.0x multiplier
      state.stuntStreakTimer = 5.0;

      // When streak is 3, stuntMultiplier is 2.0. recordSolarSurge increments streak to 4, where stuntMultiplier is 2.5.
      final event = state.recordSolarSurge(baseTips: 35);
      expect(event, isNotNull);
      expect(event!.multiplier, equals(2.5));
      expect(event.totalTips, equals((35 * 2.5).round())); // 88
    });

    test('recordSolarSurge doubles tips when energy drink boost is active', () {
      final state = GameState();
      state.startRun();
      state.activateEnergyDrink(8.0);

      // Streak 1 (1.2x): 35 * 1.2 = 42; energy drink doubles to 84
      final event = state.recordSolarSurge(baseTips: 35);
      expect(event, isNotNull);
      expect(event!.totalTips, equals(84));
    });

    test('recordSolarSurge doubles tips when Skate Commute daily shift is active', () {
      final state = GameState();
      state.startRun(
        dailyShift: const DailyShift(
          dateString: '2026-10-04',
          modifier: DailyModifier.skateCommute,
          targetDistanceMeters: 1000,
          completionBonusTips: 100,
        ),
      );

      // Streak 1 (1.2x): 35 * 1.2 = 42; skate commute doubles to 84
      final event = state.recordSolarSurge(baseTips: 35);
      expect(event, isNotNull);
      expect(event!.totalTips, equals(84));
    });

    test('recordSolarSurge triggers onSolarSurge callback', () {
      final state = GameState();
      state.startRun();

      SolarSurgeEvent? received;
      state.onSolarSurge = (e) => received = e;

      state.recordSolarSurge(baseTips: 35, coinsHarvested: 3);
      expect(received, isNotNull);
      expect(received!.coinsHarvested, equals(3));
    });

    test('startRun resets solarSurgesInRun to 0', () {
      final state = GameState();
      state.startRun();
      state.recordSolarSurge();
      expect(state.solarSurgesInRun, equals(1));

      state.startRun();
      expect(state.solarSurgesInRun, equals(0));
    });
  });

  group('WorldChunkManager Solar Panel Spawning Tests (Issue #69)', () {
    test('SolarPanelData stores coordinates and dimensions', () {
      const data = SolarPanelData(
        x: 400.0,
        y: 396.0,
        width: 220.0,
        height: 18.0,
      );

      expect(data.x, equals(400.0));
      expect(data.y, equals(396.0));
      expect(data.width, equals(220.0));
      expect(data.height, equals(18.0));
    });

    test('ChunkData includes solarPanels list', () {
      const chunk = ChunkData(
        obstacles: [],
        pickups: [],
        solarPanels: [
          SolarPanelData(x: 300.0, y: 396.0, width: 200.0, height: 18.0),
        ],
      );

      expect(chunk.solarPanels.length, equals(1));
      expect(chunk.solarPanels.first.x, equals(300.0));
    });

    test('WorldChunkManager procedurally generates solar panels at distance >= 110m', () {
      final manager = WorldChunkManager(random: math.Random(1));
      var foundPanel = false;

      for (var i = 0; i < 40; i++) {
        final chunk = manager.generateChunk(
          startX: 400.0 + (i * 960.0),
          groundY: 460.0,
          speed: 250.0,
          distanceMeters: 140.0,
        );
        if (chunk.solarPanels.isNotEmpty) {
          foundPanel = true;
          final sp = chunk.solarPanels.first;
          expect(sp.width, greaterThanOrEqualTo(160.0));
          expect(sp.height, equals(18.0));
          break;
        }
      }

      expect(foundPanel, isTrue);
    });
  });

  group('CourierGame Solar Panel Integration Tests (Issue #69)', () {
    test('landing on solar panel initiates skate slide and accumulates charge', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final panel = SolarPanelComponent(
        position: Vector2(200.0, 396.0),
        size: Vector2(220.0, 18.0),
        groundY: 460.0,
      );
      game.activeSolarPanels.add(panel);
      game.world.add(panel);

      // Position courier right above panel surface
      game.player.position.x = 220.0;
      game.player.simulator.currentY = panel.surfaceY;
      game.player.simulator.isGrounded = true;

      expect(game.player.isGrinding, isFalse);
      expect(panel.chargeLevel, equals(0.0));

      // Advance game loop
      game.update(0.05);

      expect(game.player.isGrinding, isTrue);
      expect(panel.isCharging, isTrue);
      expect(panel.chargeLevel, greaterThan(0.0));
    });

    test('sliding off forward edge of solar panel triggers SOLAR SURGE and EMP coin vacuum', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final panel = SolarPanelComponent(
        position: Vector2(200.0, 396.0),
        size: Vector2(220.0, 18.0),
        groundY: 460.0,
      );
      game.activeSolarPanels.add(panel);
      game.world.add(panel);

      // Place a nearby coin within 320px EMP radius
      late final PickupComponent nearbyCoin;
      nearbyCoin = PickupComponent(
        type: PickupType.coin,
        position: Vector2(260.0, 370.0),
        onCollected: (type) {
          nearbyCoin.isCollected = true;
          game.gameState.addTip(1);
        },
      );
      game.activePickups.add(nearbyCoin);
      game.world.add(nearbyCoin);

      // Start player on panel
      game.player.position.x = 220.0;
      game.player.simulator.currentY = panel.surfaceY;
      game.player.simulator.isGrounded = true;
      game.update(0.05);

      expect(game.player.isGrinding, isTrue);
      expect(game.gameState.solarSurgesInRun, equals(0));
      expect(nearbyCoin.isCollected, isFalse);

      // Accumulate charge
      panel.addCharge(0.7);

      // Move player past the forward dismount edge of the panel
      game.player.position.x = 440.0;
      game.update(0.05);

      // Player should dismount and trigger solar surge
      expect(panel.hasDischarged, isTrue);
      expect(game.gameState.solarSurgesInRun, equals(1));
      expect(nearbyCoin.isCollected, isTrue);

      // Floating text should be present
      final floatingTexts = game.world.children.whereType<FloatingTextComponent>().toList();
      expect(floatingTexts.any((ft) => ft.text.contains('SOLAR SURGE!')), isTrue);
    });

    test('jumping off charged solar panel triggers SOLAR SURGE', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final panel = SolarPanelComponent(
        position: Vector2(200.0, 396.0),
        size: Vector2(220.0, 18.0),
        groundY: 460.0,
      );
      game.activeSolarPanels.add(panel);
      game.world.add(panel);

      // Start player on panel
      game.player.position.x = 230.0;
      game.player.simulator.currentY = panel.surfaceY;
      game.player.simulator.isGrounded = true;
      game.update(0.05);

      expect(game.player.isGrinding, isTrue);

      // Accumulate charge
      panel.addCharge(0.6);

      // Courier jumps while on panel
      game.player.jump();
      expect(game.player.isGrinding, isFalse);

      // Next game update evaluates dismount with charge
      game.update(0.05);

      expect(panel.hasDischarged, isTrue);
      expect(game.gameState.solarSurgesInRun, equals(1));
    });

    test('restartRun cleans up activeSolarPanels and state', () async {
      final game = CourierGame();
      await game.onLoad();
      game.gameState.startRun();

      final panel = SolarPanelComponent(
        position: Vector2(200.0, 396.0),
        size: Vector2(220.0, 18.0),
        groundY: 460.0,
      );
      game.activeSolarPanels.add(panel);
      game.world.add(panel);

      expect(game.activeSolarPanels.length, equals(1));

      game.restartRun();

      expect(game.activeSolarPanels.isEmpty, isTrue);
      expect(game.world.children.whereType<SolarPanelComponent>().isEmpty, isTrue);
    });
  });

  group('GameOverModal Solar Badge UI Tests (Issue #69)', () {
    testWidgets('GameOverModal displays game_over_solar_badge with singular text when solarSurgesCompleted == 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 450,
              tips: 120,
              isNewRecord: false,
              careerTips: 1200,
              solarSurgesCompleted: 1,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_solar_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('1 SOLAR SURGE'), findsOneWidget);
      expect(find.byIcon(Icons.solar_power), findsOneWidget);
    });

    testWidgets('GameOverModal displays game_over_solar_badge with plural text when solarSurgesCompleted > 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 980,
              tips: 340,
              isNewRecord: true,
              careerTips: 4500,
              solarSurgesCompleted: 3,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_solar_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('3 SOLAR SURGES'), findsOneWidget);
    });

    testWidgets('GameOverModal hides game_over_solar_badge when solarSurgesCompleted == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameOverModal(
              distance: 300,
              tips: 80,
              isNewRecord: false,
              careerTips: 800,
              solarSurgesCompleted: 0,
              onRestart: () {},
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const Key('game_over_solar_badge'));
      expect(badgeFinder, findsNothing);
    });
  });
}
