import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jump_runner/game/components/delivery_drone_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/models/daily_shift.dart';
import 'package:jump_runner/game/models/run_booster.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/bodega_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RunBooster Model Catalog Tests', () {
    test('catalog contains all 3 single-run consumable supplies', () {
      expect(RunBooster.values.length, equals(3));
      expect(RunBooster.values, containsAll([
        RunBooster.espresso,
        RunBooster.satchel,
        RunBooster.droneBeacon,
      ]));
    });

    test('findById retrieves corresponding booster or null if absent', () {
      expect(RunBooster.findById('espresso'), equals(RunBooster.espresso));
      expect(RunBooster.findById('satchel'), equals(RunBooster.satchel));
      expect(RunBooster.findById('drone_beacon'), equals(RunBooster.droneBeacon));
      expect(RunBooster.findById('non_existent'), isNull);
    });

    test('booster pricing, max inventory and metadata adhere to design spec', () {
      expect(RunBooster.espresso.cost, equals(150));
      expect(RunBooster.satchel.cost, equals(250));
      expect(RunBooster.droneBeacon.cost, equals(350));
      expect(RunBooster.maxInventory, equals(5));

      for (final booster in RunBooster.values) {
        expect(booster.id, isNotEmpty);
        expect(booster.name, isNotEmpty);
        expect(booster.description, isNotEmpty);
      }
    });
  });

  group('LocalStorageService Booster Inventory Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'courier_career_tips': 500,
      });
      storage = LocalStorageService();
      await storage.init();
    });

    test('getBoosterCount returns 0 for unpurchased boosters', () {
      expect(storage.getBoosterCount(RunBooster.espresso.id), equals(0));
      expect(storage.getBoosterCount(RunBooster.satchel.id), equals(0));
      expect(storage.getBoosterCount(RunBooster.droneBeacon.id), equals(0));
    });

    test('buyBooster succeeds when funds are sufficient', () async {
      final success = await storage.buyBooster(
        RunBooster.espresso.id,
        RunBooster.espresso.cost,
      );

      expect(success, isTrue);
      expect(storage.careerTips, equals(350)); // 500 - 150
      expect(storage.getBoosterCount(RunBooster.espresso.id), equals(1));
    });

    test('buyBooster fails when career tips are insufficient', () async {
      final buyDrone = await storage.buyBooster(
        RunBooster.droneBeacon.id,
        RunBooster.droneBeacon.cost, // 350
      );
      expect(buyDrone, isTrue);
      expect(storage.careerTips, equals(150));

      // Attempt to buy another drone ($350) with only $150
      final failedBuy = await storage.buyBooster(
        RunBooster.droneBeacon.id,
        RunBooster.droneBeacon.cost,
      );

      expect(failedBuy, isFalse);
      expect(storage.careerTips, equals(150));
      expect(storage.getBoosterCount(RunBooster.droneBeacon.id), equals(1));
    });

    test('buyBooster respects max capacity limit of 5', () async {
      SharedPreferences.setMockInitialValues({
        'courier_career_tips': 5000,
        'courier_booster_satchel': 4,
      });
      final richStorage = LocalStorageService();
      await richStorage.init();

      // 5th purchase should succeed
      final fifth = await richStorage.buyBooster(RunBooster.satchel.id, RunBooster.satchel.cost);
      expect(fifth, isTrue);
      expect(richStorage.getBoosterCount(RunBooster.satchel.id), equals(5));

      // 6th purchase should fail due to capacity
      final sixth = await richStorage.buyBooster(RunBooster.satchel.id, RunBooster.satchel.cost);
      expect(sixth, isFalse);
      expect(richStorage.getBoosterCount(RunBooster.satchel.id), equals(5));
    });

    test('consumeBooster decrements inventory count and handles 0 gracefully', () async {
      await storage.buyBooster(RunBooster.espresso.id, RunBooster.espresso.cost);
      expect(storage.getBoosterCount(RunBooster.espresso.id), equals(1));

      final consumed = await storage.consumeBooster(RunBooster.espresso.id);
      expect(consumed, isTrue);
      expect(storage.getBoosterCount(RunBooster.espresso.id), equals(0));

      final secondConsume = await storage.consumeBooster(RunBooster.espresso.id);
      expect(secondConsume, isFalse);
      expect(storage.getBoosterCount(RunBooster.espresso.id), equals(0));
    });
  });

  group('GameState Equipped Boosters Integration', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState();
    });

    test('startRun with no boosters initializes default values', () {
      gameState.startRun();
      expect(gameState.packages, equals(3));
      expect(gameState.maxPackages, equals(3));
      expect(gameState.isEnergyBoostActive, isFalse);
      expect(gameState.isDroneActive, isFalse);
      expect(gameState.activeBoosters, isEmpty);
    });

    test('startRun with Reinforced Satchel expands package capacity to 4', () {
      gameState.startRun(equippedBoosters: {RunBooster.satchel});
      expect(gameState.hasReinforcedSatchel, isTrue);
      expect(gameState.maxPackages, equals(4));
      expect(gameState.packages, equals(4));
    });

    test('Fragile Freight daily modifier overrides Reinforced Satchel to 1 package', () {
      const fragileShift = DailyShift(
        dateString: '2026-10-03',
        modifier: DailyModifier.fragileFreight,
        targetDistanceMeters: 500,
        completionBonusTips: 100,
      );

      gameState.startRun(
        dailyShift: fragileShift,
        equippedBoosters: {RunBooster.satchel},
      );
      expect(gameState.maxPackages, equals(1));
      expect(gameState.packages, equals(1));
    });

    test('startRun with Espresso Shot activates immediate 8s Cold Brew boost', () {
      gameState.startRun(equippedBoosters: {RunBooster.espresso});
      expect(gameState.isEnergyBoostActive, isTrue);
      expect(gameState.energyDrinkTimer, equals(8.0));
    });

    test('startRun with Drone Beacon activates immediate 8s Companion Drone assist', () {
      gameState.startRun(equippedBoosters: {RunBooster.droneBeacon});
      expect(gameState.isDroneActive, isTrue);
      expect(gameState.droneTimer, equals(8.0));
    });

    test('startRun with all 3 boosters equips and activates all simultaneously', () {
      gameState.startRun(equippedBoosters: {
        RunBooster.espresso,
        RunBooster.satchel,
        RunBooster.droneBeacon,
      });

      expect(gameState.packages, equals(4));
      expect(gameState.maxPackages, equals(4));
      expect(gameState.isEnergyBoostActive, isTrue);
      expect(gameState.isDroneActive, isTrue);
    });
  });

  group('CourierGame Pre-Run Booster Integration', () {
    test('CourierGame mounts drone and activates boost when equipped with boosters', () async {
      final gameState = GameState();
      final game = CourierGame(
        gameState: gameState,
        initialBoosters: {RunBooster.espresso, RunBooster.droneBeacon},
      );

      await game.onLoad();

      expect(gameState.isEnergyBoostActive, isTrue);
      expect(gameState.isDroneActive, isTrue);
      expect(game.player.isBoosted, isTrue);

      // Trigger one frame update to mount drone component
      game.update(0.016);
      expect(game.deliveryDrone, isNotNull);
      expect(game.world.children.whereType<DeliveryDroneComponent>().length, equals(1));
    });

    test('CourierGame restartRun applies updated equipped boosters', () async {
      final gameState = GameState();
      final game = CourierGame(gameState: gameState);

      await game.onLoad();
      expect(gameState.isEnergyBoostActive, isFalse);

      game.restartRun(equippedBoosters: {RunBooster.espresso, RunBooster.satchel});
      expect(gameState.isEnergyBoostActive, isTrue);
      expect(gameState.packages, equals(4));
      expect(game.player.isBoosted, isTrue);
    });
  });

  group('BodegaModal Widget Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'courier_career_tips': 600,
        'courier_booster_espresso': 1,
        'courier_booster_satchel': 0,
        'courier_booster_drone_beacon': 5,
      });
      storage = LocalStorageService();
      await storage.init();
    });

    testWidgets('renders header, tips balance, and booster items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BodegaModal(
              storageService: storage,
              equippedBoosters: const {},
              onEquippedBoostersChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('CORNER BODEGA'), findsOneWidget);
      expect(find.text('\$600 TIPS'), findsOneWidget);
      expect(find.text('Cold Brew Double-Shot'), findsOneWidget);
      expect(find.text('Reinforced Satchel'), findsOneWidget);
      expect(find.text('Express Drone Beacon'), findsOneWidget);
      expect(find.text('Stock: 1/5'), findsOneWidget); // espresso
      expect(find.text('Stock: 0/5'), findsOneWidget); // satchel
      expect(find.text('Stock: 5/5'), findsOneWidget); // droneBeacon
      expect(find.text('MAX'), findsOneWidget); // droneBeacon is at max
    });

    testWidgets('buying booster deducts tips, increments stock, and auto-equips', (tester) async {
      Set<RunBooster> updatedEquipped = {};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BodegaModal(
              storageService: storage,
              equippedBoosters: const {},
              onEquippedBoostersChanged: (b) => updatedEquipped = b,
              onClose: () {},
            ),
          ),
        ),
      );

      // Buy satchel ($250)
      final buySatchelFinder = find.byKey(const Key('buy_booster_satchel'));
      expect(buySatchelFinder, findsOneWidget);

      await tester.tap(buySatchelFinder);
      await tester.pump();

      expect(storage.careerTips, equals(350)); // 600 - 250
      expect(storage.getBoosterCount(RunBooster.satchel.id), equals(1));
      expect(updatedEquipped, contains(RunBooster.satchel));
      expect(find.text('Stock: 1/5'), findsNWidgets(2)); // espresso and satchel
    });

    testWidgets('toggling equip and unequip updates equipped loadout', (tester) async {
      Set<RunBooster> equippedState = {RunBooster.espresso};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BodegaModal(
              storageService: storage,
              equippedBoosters: equippedState,
              onEquippedBoostersChanged: (b) => equippedState = b,
              onClose: () {},
            ),
          ),
        ),
      );

      // Espresso is already equipped
      final equipEspressoFinder = find.byKey(const Key('equip_booster_espresso'));
      expect(equipEspressoFinder, findsOneWidget);
      expect(find.text('EQUIPPED'), findsOneWidget);

      // Tap to unequip
      await tester.tap(equipEspressoFinder);
      await tester.pump();

      expect(equippedState.contains(RunBooster.espresso), isFalse);
      expect(find.text('EQUIPPED'), findsNothing);

      // Tap to re-equip
      await tester.tap(equipEspressoFinder);
      await tester.pump();

      expect(equippedState.contains(RunBooster.espresso), isTrue);
    });

    testWidgets('tapping close or ready triggers onClose callback', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BodegaModal(
              storageService: storage,
              equippedBoosters: const {},
              onEquippedBoostersChanged: (_) {},
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('bodega_done_button')));
      expect(closed, isTrue);

      closed = false;
      await tester.tap(find.byKey(const Key('bodega_close_button')));
      expect(closed, isTrue);
    });
  });

  group('TitleScreen Bodega UI Integration', () {
    testWidgets('renders BODEGA button and loadout badges when equipped', (tester) async {
      bool bodegaOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleScreen(
              highDistance: 1200,
              careerTips: 800,
              equippedBoosters: const {RunBooster.espresso, RunBooster.droneBeacon},
              onStartGame: () {},
              onOpenBodega: () => bodegaOpened = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('open_bodega_button')), findsOneWidget);
      expect(find.text('BODEGA'), findsOneWidget);
      expect(find.text('LOADOUT: '), findsOneWidget);
      expect(find.text('Cold Brew Double-Shot'), findsOneWidget);
      expect(find.text('Express Drone Beacon'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_bodega_button')));
      expect(bodegaOpened, isTrue);
    });
  });
}
