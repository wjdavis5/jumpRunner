import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/drop_zone_component.dart';
import 'package:jump_runner/game/components/subway_station_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/achievement_manager.dart';
import 'package:jump_runner/game/models/achievement.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What [manager] awards for a shift described by the named figures.
Future<Set<String>> _awards(
  AchievementManager manager, {
  double distance = 0,
  int stations = 0,
  int deliveries = 0,
  int dailyStars = 0,
}) async {
  final unlocked = await manager.evaluateProgress(
    distanceMeters: distance,
    stuntCombo: 0,
    lifetimeContracts: 0,
    lifetimeCareerTips: 0,
    subwayStationsInRun: stations,
    lifetimeDeliveries: deliveries,
    dailyStars: dailyStars,
  );
  return unlocked.map((a) => a.id).toSet();
}

Future<CourierGame> _shift({Map<String, Object> saved = const {}}) async {
  SharedPreferences.setMockInitialValues(saved);
  final storage = LocalStorageService();
  await storage.init();
  final game = CourierGame(
    storageService: storage,
    audioController: GameAudioController()..isMuted = true,
    achievementManager: AchievementManager(storageService: storage),
  );
  await game.onLoad();
  game.gameState.startRun();
  // An empty street: nothing to run into while the test sets things up.
  game.nextChunkX = 1e12;
  for (final o in game.activeObstacles.toList()) {
    o.removeFromParent();
  }
  game.activeObstacles.clear();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The trophy shelf had six trophies. Four more reward things the game was
  // already counting and showing on the results card.
  group('The trophy shelf', () {
    test('holds ten, each with its own id and title', () {
      expect(Achievement.catalog, hasLength(10));
      expect(Achievement.catalog.map((a) => a.id).toSet(), hasLength(10));
      expect(Achievement.catalog.map((a) => a.title).toSet(), hasLength(10));
    });

    test('says what each of the new four asks for, in the numbers the rules use', () {
      String description(String id) => Achievement.findById(id)!.description;
      expect(description('long_haul'), contains('1,000m'));
      expect(AchievementManager.longHaulMeters, equals(1000.0));
      expect(description('door_to_door'), contains('${AchievementManager.doorToDoorDeliveries}'));
      expect(description('daily_regular'), contains('${AchievementManager.regularDailyGoals}'));
      expect(description('straphanger'), contains('subway station'));
    });
  });

  group('The rules for the new four', () {
    test('Long Haul: 1,000 m in one shift, not 999', () async {
      final manager = AchievementManager();
      expect(await _awards(manager, distance: 999.9), isNot(contains('long_haul')));
      expect(await _awards(manager, distance: 1000.0), contains('long_haul'));
    });

    test('Straphanger: the first subway station', () async {
      final manager = AchievementManager();
      expect(await _awards(manager), isEmpty);
      expect(await _awards(manager, stations: 1), equals({'straphanger'}));
    });

    test('Door to Door: the 25th delivery of a career', () async {
      final manager = AchievementManager();
      expect(await _awards(manager, deliveries: 24), isEmpty);
      expect(await _awards(manager, deliveries: 25), equals({'door_to_door'}));
    });

    test('Regular: the fifth daily goal', () async {
      final manager = AchievementManager();
      expect(await _awards(manager, dailyStars: 4), isEmpty);
      expect(await _awards(manager, dailyStars: 5), equals({'daily_regular'}));
    });

    test('each is awarded once', () async {
      final manager = AchievementManager();
      final first = await _awards(manager, distance: 1200, stations: 2, deliveries: 30, dailyStars: 9);
      // 1,200 m is also past the old 500 m trophy.
      expect(first, containsAll(['long_haul', 'straphanger', 'door_to_door', 'daily_regular']));
      final again = await _awards(manager, distance: 1200, stations: 2, deliveries: 30, dailyStars: 9);
      expect(again, isEmpty);
    });

    test('they are saved', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();
      await _awards(AchievementManager(storageService: storage), stations: 1, dailyStars: 5);
      expect(storage.unlockedAchievements, containsAll(['straphanger', 'daily_regular']));
      // And a later launch knows.
      final later = AchievementManager(storageService: storage);
      expect(later.isUnlocked('straphanger'), isTrue);
      expect(later.isUnlocked('long_haul'), isFalse);
    });
  });

  group('Earned during a shift, the moment it happens', () {
    test('crossing 1,000 m', () async {
      final game = await _shift();
      final earned = <String>[];
      final announce = game.achievementManager.onAchievementUnlocked;
      game.achievementManager.onAchievementUnlocked = (a) {
        earned.add(a.id);
        announce?.call(a);
      };
      game.gameState.distanceMeters = 998.0;
      for (var frame = 0; frame < 30 && !earned.contains('long_haul'); frame++) {
        game.update(1 / 60);
        await Future<void>.delayed(Duration.zero);
      }
      expect(game.gameState.distanceMeters, greaterThanOrEqualTo(1000.0));
      expect(earned, contains('long_haul'));
      expect(game.achievementManager.isUnlocked('shift_veteran'), isFalse);
    });

    test('running into a subway station', () async {
      final game = await _shift();
      expect(game.achievementManager.isUnlocked('straphanger'), isFalse);
      final station = SubwayStationComponent(
        position: Vector2(game.player.position.x - 50.0, 200.0),
        size: Vector2(960.0, 260.0),
      );
      game.activeSubwayStations.add(station);
      game.world.add(station);
      game.update(1 / 60);
      await Future<void>.delayed(Duration.zero);
      expect(game.gameState.subwayStationsInRun, equals(1));
      expect(game.achievementManager.isUnlocked('straphanger'), isTrue);
    });

    test('the 25th doorstep delivery of a career', () async {
      final game = await _shift(saved: {'courier_lifetime_deliveries': 24});
      expect(game.achievementManager.isUnlocked('door_to_door'), isFalse);
      final doorstep = DropZoneComponent(
        position: Vector2(game.player.position.x - 10.0, 390.0),
        size: Vector2(68.0, 70.0),
        groundY: 460.0,
      );
      game.activeDropZones.add(doorstep);
      game.world.add(doorstep);
      for (var frame = 0; frame < 10 && game.gameState.deliveriesInRun == 0; frame++) {
        game.update(1 / 60);
        await Future<void>.delayed(Duration.zero);
      }
      expect(game.gameState.deliveriesInRun, equals(1));
      expect(game.storage!.lifetimeDeliveries, equals(25));
      expect(game.achievementManager.isUnlocked('door_to_door'), isTrue);
    });

    test('the 24th delivery is not enough', () async {
      final game = await _shift(saved: {'courier_lifetime_deliveries': 23});
      final doorstep = DropZoneComponent(
        position: Vector2(game.player.position.x - 10.0, 390.0),
        size: Vector2(68.0, 70.0),
        groundY: 460.0,
      );
      game.activeDropZones.add(doorstep);
      game.world.add(doorstep);
      for (var frame = 0; frame < 10 && game.gameState.deliveriesInRun == 0; frame++) {
        game.update(1 / 60);
        await Future<void>.delayed(Duration.zero);
      }
      expect(game.storage!.lifetimeDeliveries, equals(24));
      expect(game.achievementManager.isUnlocked('door_to_door'), isFalse);
    });
  });
}
