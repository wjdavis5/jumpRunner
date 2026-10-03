import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/floating_text_component.dart';
import 'package:jump_runner/game/components/pr_marker_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersonalRecordMarkerComponent', () {
    test('initializes with default dimensions and correct target distance', () {
      final marker = PersonalRecordMarkerComponent(
        prDistance: 250,
        position: Vector2(500, 380),
      );

      expect(marker.prDistance, equals(250));
      expect(marker.position.x, equals(500));
      expect(marker.position.y, equals(380));
      expect(marker.size.x, equals(36));
      expect(marker.size.y, equals(80));
      expect(marker.hasBeenSurpassed, isFalse);
      expect(marker.primaryColor, equals(const Color(0xFF00E5FF)));
    });

    test('switches color palette from cyan to gold when surpassed', () {
      final marker = PersonalRecordMarkerComponent(
        prDistance: 300,
        position: Vector2(400, 380),
      );

      expect(marker.primaryColor, equals(const Color(0xFF00E5FF)));
      marker.hasBeenSurpassed = true;
      expect(marker.primaryColor, equals(const Color(0xFFF1C40F)));
    });

    test('renders on canvas without error and advances animation timer on update', () {
      final marker = PersonalRecordMarkerComponent(
        prDistance: 150,
        position: Vector2(200, 380),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => marker.render(canvas), returnsNormally);

      final initialTimer = marker.animationTimer;
      marker.update(0.5);
      expect(marker.animationTimer, greaterThan(initialTimer));

      // Surpassed rendering
      marker.hasBeenSurpassed = true;
      expect(() => marker.render(canvas), returnsNormally);
    });
  });

  group('CourierGame PR Marker Spawning and Celebration (Issue #31)', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'courier_high_distance': 400,
      });
      storage = LocalStorageService();
      await storage.init();
    });

    test('does not spawn PR marker if personalRecordDistance < 100m', () async {
      final game = CourierGame(
        personalRecordDistance: 50,
      );
      await game.onLoad();
      game.gameState.startRun();

      // Advance game distance
      game.update(1.0);
      expect(game.activePrMarker, isNull);
      expect(game.hasSpawnedPrMarker, isFalse);

      game.gameState.updateDistance(45.0);
      game.update(1.0);
      expect(game.activePrMarker, isNull);
      expect(game.hasSpawnedPrMarker, isFalse);
    });

    test('spawns PR marker when approaching within 45m ahead of record', () async {
      final game = CourierGame(
        personalRecordDistance: 300,
      );
      await game.onLoad();
      game.gameState.startRun();

      // Distance at 200m -> remaining is 100m (>45m) -> should not spawn yet
      game.gameState.updateDistance(200.0);
      game.update(0.1);
      expect(game.activePrMarker, isNull);
      expect(game.hasSpawnedPrMarker, isFalse);

      // Distance at 260m -> remaining is 40m (<=45m) -> marker should spawn
      game.gameState.updateDistance(260.0);
      game.update(0.1);

      expect(game.hasSpawnedPrMarker, isTrue);
      expect(game.activePrMarker, isNotNull);
      expect(game.activePrMarker!.prDistance, equals(300));
      expect(game.world.children.whereType<PersonalRecordMarkerComponent>().length, equals(1));

      // Verify position is ahead of player and at ground baseline
      expect(game.activePrMarker!.position.x, greaterThan(game.player.position.x));
      expect(game.activePrMarker!.position.x, lessThan(CourierGame.virtualResolution.x));
      expect(game.activePrMarker!.position.y, equals(CourierGame.groundY - 80.0));
    });

    test('scrolls PR marker leftward with world scrolling', () async {
      final game = CourierGame(
        personalRecordDistance: 200,
      );
      await game.onLoad();
      game.gameState.startRun();

      // Spawn marker
      game.gameState.updateDistance(170.0);
      game.update(0.1);
      expect(game.activePrMarker, isNotNull);

      final initialX = game.activePrMarker!.position.x;

      // Update 0.2s with active speed
      game.update(0.2);
      expect(game.activePrMarker!.position.x, lessThan(initialX));
    });

    test('surpassing PR marker triggers celebration, screen shake, and floating text', () async {
      final game = CourierGame(
        personalRecordDistance: 200,
      );
      await game.onLoad();
      game.gameState.startRun();

      // Spawn marker
      game.gameState.updateDistance(190.0);
      game.update(0.01);
      expect(game.activePrMarker, isNotNull);
      final marker = game.activePrMarker!;

      expect(marker.hasBeenSurpassed, isFalse);
      expect(game.hasSurpassedPr, isFalse);

      // Position runner right at or past the marker
      game.player.position.x = marker.position.x + 5.0;
      game.update(0.01);

      expect(marker.hasBeenSurpassed, isTrue);
      expect(game.hasSurpassedPr, isTrue);
      expect(game.cameraJuice.trauma, greaterThan(0.0));

      final banners = game.world.children.whereType<FloatingTextComponent>();
      expect(banners.isNotEmpty, isTrue);
      expect(banners.first.text, contains('NEW RECORD! 200m BEATEN!'));
    });

    test('restartRun cleans up marker and reloads PR from storage', () async {
      final game = CourierGame(
        storageService: storage,
      );
      await game.onLoad();
      expect(game.personalRecordDistance, equals(400));

      game.gameState.startRun();
      // Reach threshold
      game.gameState.updateDistance(370.0);
      game.update(0.01);

      expect(game.activePrMarker, isNotNull);
      expect(game.hasSpawnedPrMarker, isTrue);

      // Surpass
      game.player.position.x = game.activePrMarker!.position.x + 10.0;
      game.update(0.01);
      expect(game.hasSurpassedPr, isTrue);

      // Now call restartRun()
      game.restartRun();

      expect(game.activePrMarker, isNull);
      expect(game.hasSpawnedPrMarker, isFalse);
      expect(game.hasSurpassedPr, isFalse);
      expect(game.personalRecordDistance, equals(400));
      expect(game.world.children.whereType<PersonalRecordMarkerComponent>(), isEmpty);
    });
  });
}
