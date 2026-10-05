import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/game_over_modal.dart';
import 'package:jump_runner/ui/hazard_lesson.dart';

import 'support/app_harness.dart';
import 'support/bare_street.dart';

Widget _results({ObstacleType? endedBy, int stunts = 0}) {
  int n(int index) => index < stunts ? 2 : 0;
  return MaterialApp(
    home: Scaffold(
      body: GameOverModal(
        distance: 240,
        tips: 60,
        isNewRecord: stunts > 0,
        careerTips: 320,
        endedBy: endedBy,
        onRestart: () {},
        onReturnToDepot: () {},
        completedContracts: n(0),
        deliveriesCompleted: n(1),
        grindsCompleted: n(2),
        vaultsCompleted: n(3),
        glidesCompleted: n(4),
        subwayStationsCompleted: n(5),
        craneSwingsCompleted: n(6),
        vipDeliveriesCompleted: n(7),
        bikeDraftSlingshotsCompleted: n(8),
        pigeonScattersCompleted: n(9),
        highFivesCompleted: n(10),
        foodCartBouncesCompleted: n(11),
      ),
    ),
  );
}

Future<void> _show(WidgetTester tester, Size size, Widget results) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(results);
  await tester.pump();
}

void main() {
  // The results card said "Shift Concluded". The game has nine hazards that
  // want three different answers, and a new player who has just lost three
  // packages to vans by tapping at them was told nothing.
  group('Every hazard has something to say', () {
    test('what it was and how to get past it, in two short sentences', () {
      for (final type in ObstacleType.values) {
        final lesson = HazardLesson.forType(type);
        expect(lesson.what, endsWith('got you.'), reason: type.name);
        expect(lesson.how, endsWith('.'), reason: type.name);
        expect(lesson.line, equals('${lesson.what} ${lesson.how}'));
        expect(lesson.line.length, lessThan(70), reason: type.name);
      }
    });

    test('a van and a train want the held leap, as the street generator assumes', () {
      for (final type in const [ObstacleType.van, ObstacleType.subwayTrain]) {
        expect(HazardLesson.forType(type).how, equals('Hold the jump to leap it.'));
      }
    });

    test('what a hop clears says so', () {
      for (final type in const [
        ObstacleType.scooter,
        ObstacleType.dog,
        ObstacleType.hydrant,
        ObstacleType.mailbox,
        ObstacleType.thirdRail,
      ]) {
        expect(HazardLesson.forType(type).how, equals('A short jump clears it.'));
      }
    });

    test('pigeons are the one not to jump at, and a skater the one to jump early', () {
      expect(HazardLesson.forType(ObstacleType.pigeonFlock).how, contains('run under'));
      expect(HazardLesson.forType(ObstacleType.skateMessenger).how, contains('early'));
    });
  });

  group('The results card says what ended the shift', () {
    testWidgets('in place of "Shift Concluded"', (tester) async {
      await _show(tester, const Size(960, 540), _results(endedBy: ObstacleType.van));
      expect(find.text('A van got you. Hold the jump to leap it.'), findsOneWidget);
      expect(find.text('Shift Concluded'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and on a phone held sideways, where there was no subtitle at all', (tester) async {
      await _show(tester, const Size(667, 375), _results(endedBy: ObstacleType.pigeonFlock));
      expect(find.byKey(const Key('game_over_lesson')), findsOneWidget);
      expect(find.text('Pigeons got you. Stay on the ground and run under them.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('when nothing is known it is the card it was', (tester) async {
      await _show(tester, const Size(960, 540), _results());
      expect(find.text('Shift Concluded'), findsOneWidget);
      expect(find.byKey(const Key('game_over_lesson')), findsNothing);

      await _show(tester, const Size(667, 375), _results());
      expect(find.text('Shift Concluded'), findsNothing);
      expect(find.byKey(const Key('game_over_lesson')), findsNothing);
    });

    for (final size in const [Size(667, 375), Size(844, 390), Size(568, 320), Size(375, 667)]) {
      testWidgets('with a dozen badges it still fits ${size.width.round()}x${size.height.round()}',
          (tester) async {
        await _show(tester, size, _results(endedBy: ObstacleType.subwayTrain, stunts: 12));
        expect(tester.takeException(), isNull);
        final screen = Offset.zero & size;
        final lesson = tester.getRect(find.byKey(const Key('game_over_lesson')));
        expect(screen.contains(lesson.topLeft) && screen.contains(lesson.bottomRight), isTrue);
        final restart = tester.getRect(find.text('START NEXT SHIFT'));
        expect(restart.bottom, lessThanOrEqualTo(size.height));
        expect(restart.top, greaterThanOrEqualTo(0.0));
      });
    }
  });

  group('The shift remembers what hit the courier', () {
    test('the hazard says what it is, and a new shift forgets it', () async {
      final game = await bareStreetGame(300.0);
      expect(game.gameState.lastHitBy, isNull);

      final van = hazardAt(ObstacleType.van, game.player.position.x + 300.0);
      game.activeObstacles.add(van);
      game.world.add(van);
      game.update(0);
      await game.ready();
      for (var f = 0; f < 240 && game.gameState.lastHitBy == null; f++) {
        game.update(1 / 60);
      }
      expect(game.gameState.lastHitBy, equals(ObstacleType.van));
      expect(game.gameState.packages, equals(game.gameState.maxPackages - 1));

      game.gameState.startRun();
      expect(game.gameState.lastHitBy, isNull);
    });

    test('a hit that does not count does not change it', () async {
      final game = await bareStreetGame(300.0);
      game.gameState.lastHitBy = ObstacleType.dog;
      // Already flickering from the last hit: this one is ignored.
      game.player.takeDamage(source: ObstacleType.dog);
      final before = game.gameState.packages;
      expect(game.player.takeDamage(source: ObstacleType.van), isFalse);
      expect(game.gameState.packages, equals(before));
      expect(game.gameState.lastHitBy, equals(ObstacleType.dog));
    });

    testWidgets('and the app hands it to the results card', (tester) async {
      await bootApp(tester, size: const Size(915, 412));
      await tester.tap(find.text('START SHIFT'));
      await settle(tester, frames: 10);
      final state = gameOf(tester).gameState;
      state.lastHitBy = ObstacleType.skateMessenger;
      while (state.status == GameStatus.running) {
        state.applyHazardDamage();
      }
      for (var i = 0; i < 80 && find.text('PACKAGES DROPPED!').evaluate().isEmpty; i++) {
        await settle(tester, frames: 1);
      }
      expect(find.text('A skater got you. Jump early: they roll toward you.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
