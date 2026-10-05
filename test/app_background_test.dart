import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('Quitting from the pause menu banks the shift, as "Tips Banked" promises', (tester) async {
    final storage = (await bootApp(tester)).storage;
    expect(storage.highDistance, equals(0));

    await tester.tap(find.text('START SHIFT'));
    // Run for a few seconds of game time so there is distance to bank.
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, frames: 2);

    await tester.tap(find.byKey(const Key('pause_button')));
    await settle(tester, frames: 3);
    await tester.tap(find.byKey(const Key('quit_to_depot_button')));
    await settle(tester, frames: 5);

    expect(storage.highDistance, greaterThan(0));
    expect(find.text('START SHIFT'), findsOneWidget);
    // The title screen shows the distance that was just banked.
    expect(find.text('${storage.highDistance} m'), findsOneWidget);
  });

  testWidgets('Return to depot from the pause menu lands on a usable title screen', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    await tester.tap(find.byKey(const Key('pause_button')));
    await settle(tester, frames: 3);
    expect(find.text('SHIFT ON HOLD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quit_to_depot_button')));
    await settle(tester, frames: 3);

    expect(find.text('SHIFT ON HOLD'), findsNothing);
    expect(find.byKey(const Key('pause_button')), findsNothing);
    expect(find.text('START SHIFT'), findsOneWidget);

    // And a new shift starts from there.
    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    expect(find.byKey(const Key('pause_button')), findsOneWidget);
    expect(find.text('START SHIFT'), findsNothing);
  });

  testWidgets('Backgrounding the app mid-run opens the pause menu and holds the music', (tester) async {
    final backend = (await bootApp(tester)).audioBackend;

    await tester.tap(find.text('START SHIFT'));
    await settle(tester, frames: 10);
    expect(find.byKey(const Key('pause_button')), findsOneWidget);
    expect(find.text('SHIFT ON HOLD'), findsNothing);
    expect(backend.bgmPlaying, isTrue);

    // The player switches to another app.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester, frames: 1);

    expect(find.text('SHIFT ON HOLD'), findsOneWidget);
    expect(backend.bgmPlaying, isFalse);

    // And comes back: still paused, music playing again, waiting for a tap.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, frames: 1);

    expect(find.text('SHIFT ON HOLD'), findsOneWidget);
    expect(backend.bgmPlaying, isTrue);
  });
}
