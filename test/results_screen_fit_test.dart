import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/ui/game_over_modal.dart';

/// A results screen for a strong run: a record, contracts, and [stunts]
/// different kinds of stunt, each of which adds its own badge row.
Widget _results({
  required int stunts,
  required VoidCallback onRestart,
  VoidCallback? onReturnToDepot,
}) {
  int n(int index) => index < stunts ? 2 : 0;
  return MaterialApp(
    home: Scaffold(
      body: GameOverModal(
        distance: 1840,
        tips: 960,
        isNewRecord: true,
        careerTips: 5120,
        completedContracts: 2,
        contractBonusTips: 30,
        onRestart: onRestart,
        onReturnToDepot: onReturnToDepot,
        deliveriesCompleted: n(0),
        grindsCompleted: n(1),
        vaultsCompleted: n(2),
        glidesCompleted: n(3),
        subwayStationsCompleted: n(4),
        craneSwingsCompleted: n(5),
        vipDeliveriesCompleted: n(6),
        bikeDraftSlingshotsCompleted: n(7),
        pigeonScattersCompleted: n(8),
        highFivesCompleted: n(9),
        foodCartBouncesCompleted: n(10),
        drainGeysersCompleted: n(11),
        solarSurgesCompleted: n(12),
        puddleSkimsCompleted: n(13),
        windTunnelGlidesCompleted: n(14),
        turnstilesCompleted: n(15),
        droneCatchesCompleted: n(16),
        fireEscapesCompleted: n(17),
        foodTruckDriftsCompleted: n(18),
        barricadesCompleted: n(19),
        satelliteLaunchesCompleted: n(20),
        mailboxesCompleted: n(21),
        acCondensersCompleted: n(22),
        skylightsCompleted: n(23),
        flowerKiosksCompleted: n(24),
        waterTowersCompleted: n(25),
        newsstandsCompleted: n(26),
        cafeBistrosCompleted: n(27),
        buskersCompleted: n(28),
        hydrantsCompleted: n(29),
        clotheslinesCompleted: n(30),
        subwayGratesCompleted: n(31),
        ziplinesCompleted: n(32),
        busSheltersCompleted: n(33),
        securityShuttersCompleted: n(34),
      ),
    ),
  );
}

void main() {
  // Phones in landscape, and the 16:9 web canvas.
  const screens = {
    'small phone landscape 667x375': Size(667, 375),
    'phone landscape 844x390': Size(844, 390),
    'web 960x540': Size(960, 540),
  };

  for (final entry in screens.entries) {
    for (final stunts in const [0, 6, 12, 35]) {
      testWidgets(
        'Results screen fits and can be restarted with $stunts stunt badges (${entry.key})',
        (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          int restarts = 0;
          int depotVisits = 0;
          await tester.pumpWidget(
            _results(
              stunts: stunts,
              onRestart: () => restarts++,
              onReturnToDepot: () => depotVisits++,
            ),
          );

          expect(tester.takeException(), isNull, reason: 'layout overflowed');

          final restart = find.text('START NEXT SHIFT');
          expect(restart, findsOneWidget);
          final box = tester.getRect(restart);
          expect(box.top, greaterThanOrEqualTo(0.0), reason: 'restart button above the screen');
          expect(
            box.bottom,
            lessThanOrEqualTo(entry.value.height),
            reason: 'restart button below the screen',
          );

          await tester.tap(restart);
          expect(restarts, equals(1));

          // The way back to the Locker and Bodega is just as reachable.
          final depot = find.byKey(const Key('game_over_depot_button'));
          expect(depot, findsOneWidget);
          final depotBox = tester.getRect(depot);
          expect(depotBox.top, greaterThanOrEqualTo(0.0));
          expect(depotBox.bottom, lessThanOrEqualTo(entry.value.height));
          expect(depotBox.left, greaterThanOrEqualTo(0.0));
          await tester.tap(depot);
          expect(depotVisits, equals(1));
        },
      );
    }
  }

  testWidgets('Badges that do not fit are reached by scrolling the list', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_results(stunts: 35, onRestart: () {}));

    final lastBadge = find.byKey(const Key('game_over_security_shutter_badge'));
    final list = find.byKey(const Key('game_over_badges_scroll'));
    expect(lastBadge, findsOneWidget);
    final listRect = tester.getRect(list);
    expect(
      tester.getRect(lastBadge).top,
      greaterThan(listRect.bottom),
      reason: 'with 35 badges the last one starts below the visible list',
    );

    await tester.ensureVisible(lastBadge);
    await tester.pumpAndSettle();

    final badgeRect = tester.getRect(lastBadge);
    expect(badgeRect.top, greaterThanOrEqualTo(listRect.top));
    expect(badgeRect.bottom, lessThanOrEqualTo(listRect.bottom + 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('A long badge list shows a scrollbar; a short one has nothing to scroll', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const barKey = Key('game_over_badges_scrollbar');
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(barKey), matching: find.byType(Scrollable)),
        )
        .position;

    await tester.pumpWidget(_results(stunts: 35, onRestart: () {}));
    await tester.pumpAndSettle();
    expect(position().maxScrollExtent, greaterThan(0.0));
    // With something to scroll, the thumb is drawn without the player
    // touching anything: the old fade could not hint at more badges when the
    // list ended between two rows.
    expect(tester.widget<Scrollbar>(find.byKey(barKey)).thumbVisibility, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_results(stunts: 0, onRestart: () {}));
    await tester.pumpAndSettle();
    expect(position().maxScrollExtent, equals(0.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Without a depot handler the card shows only the restart button', (tester) async {
    await tester.pumpWidget(_results(stunts: 0, onRestart: () {}));
    expect(find.byKey(const Key('game_over_depot_button')), findsNothing);
    expect(find.text('START NEXT SHIFT'), findsOneWidget);
  });

  testWidgets('A short run still shows a compact card', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_results(stunts: 0, onRestart: () {}));

    final card = tester.getRect(
      find.ancestor(of: find.text('PACKAGES DROPPED!'), matching: find.byType(Container)).first,
    );
    expect(card.height, lessThan(360.0));
    expect(card.width, equals(GameOverModal.maxCardWidth));
  });
}
