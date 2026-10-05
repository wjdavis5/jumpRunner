import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';

import 'support/app_harness.dart';

void main() {
  // Something left behind by each shift (an overlay not taken down, a street
  // piece not cleared, a listener added again) costs nothing once and a
  // great deal over an evening. Sixty shifts in a row left nothing: the
  // street came back to between 6 and 11 components after every restart and
  // the depot was built from the same 591 widgets on each of twenty visits.
  // This is that run cut down to what the suite can afford.
  testWidgets('Shift after shift, nothing is left behind', (tester) async {
    await bootApp(tester);
    final game = gameOf(tester);
    final state = game.gameState;
    final widgetsAtDepot = <int>[];

    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 8);

    for (var shift = 0; shift < 6; shift++) {
      expect(state.status, equals(GameStatus.running), reason: 'shift $shift did not start');
      // Two seconds of street, hopping, kept alive.
      for (var f = 0; f < 120; f++) {
        state.packages = state.maxPackages;
        if (f % 23 == 0) {
          f.isEven ? game.holdJump('test') : game.letGoOfJump('test');
        }
        await tester.pump(const Duration(milliseconds: 16));
        if (f % 20 == 0) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
      }
      game.letGoOfJump('test');
      while (state.status == GameStatus.running) {
        state.applyHazardDamage();
      }
      for (var i = 0; i < 60 && find.text('START NEXT SHIFT').evaluate().isEmpty; i++) {
        await settle(tester, frames: 3);
      }
      expect(find.text('START NEXT SHIFT'), findsOneWidget, reason: 'no results card after shift $shift');
      expect(tester.takeException(), isNull, reason: 'shift $shift');

      // Every other shift goes by way of the depot.
      if (shift.isOdd) {
        await tester.tap(find.byKey(const Key('game_over_depot_button')));
        await settle(tester, frames: 8);
        expect(find.text('START SHIFT'), findsOneWidget, reason: 'no depot after shift $shift');
        widgetsAtDepot.add(tester.allElements.length);
        await tester.tap(find.text('START SHIFT'));
      } else {
        await tester.tap(find.text('START NEXT SHIFT'));
      }
      await settle(tester, frames: 8);

      expect(game.overlays.activeOverlays, equals(['HUD']), reason: 'after shift $shift');
      expect(game.world.children.length, lessThan(25), reason: 'the street after shift $shift was not cleared');
    }

    expect(widgetsAtDepot, hasLength(3));
    expect(widgetsAtDepot.toSet(), hasLength(1), reason: 'the depot grew between visits: $widgetsAtDepot');
    // The last shift's own timers run out before the test ends.
    await tester.pump(const Duration(seconds: 5));
  });
}
