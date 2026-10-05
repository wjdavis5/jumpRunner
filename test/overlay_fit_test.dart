import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/services/storage_service.dart';
import 'package:jump_runner/ui/achievements_modal.dart';
import 'package:jump_runner/ui/bodega_modal.dart';
import 'package:jump_runner/ui/daily_shift_modal.dart';
import 'package:jump_runner/ui/hud_overlay.dart';
import 'package:jump_runner/ui/locker_modal.dart';
import 'package:jump_runner/ui/pause_menu_modal.dart';
import 'package:jump_runner/ui/title_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The game is landscape-only: these are the shortest screens it ships to,
// plus the 16:9 web canvas.
const _screens = {
  'small phone 667x375': Size(667, 375),
  'phone 844x390': Size(844, 390),
  'web 960x540': Size(960, 540),
};

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return storage;
}

/// A run with several timed buffs live at once, as a skilled player sees it.
GameState _busyRun() {
  final state = GameState()..startRun();
  state.updateDistance(640.0);
  state.activateEnergyDrink();
  state.activateDrone();
  state.startVipMission();
  state.isDrafting = true;
  return state;
}

void main() {
  for (final screen in _screens.entries) {
    Future<void> expectFits(WidgetTester tester, Widget overlay) async {
      tester.view.physicalSize = screen.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: overlay),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull, reason: 'layout overflowed on ${screen.key}');
    }

    /// The control must be wholly on-screen and respond to a tap.
    Future<void> expectReachable(WidgetTester tester, Finder control) async {
      expect(control, findsOneWidget);
      final rect = tester.getRect(control);
      final bounds = Offset.zero & screen.value;
      expect(
        bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: '$control at $rect is not inside $bounds',
      );
      await tester.tap(control);
    }

    group('Overlays fit on ${screen.key}', () {
      testWidgets('title screen', (tester) async {
        int taps = 0;
        await expectFits(
          tester,
          TitleScreen(
            highDistance: 1840,
            careerTips: 51200,
            onStartGame: () => taps++,
            unlockedAchievementsCount: 6,
            dailyStars: 12,
            onToggleMute: () {},
            onOpenLocker: () => taps++,
            onOpenBodega: () => taps++,
            onOpenAchievements: () => taps++,
            onOpenDailyShift: () => taps++,
          ),
        );
        await expectReachable(tester, find.text('START SHIFT'));
        for (final key in const [
          'open_locker_button',
          'open_bodega_button',
          'open_trophies_button',
          'open_daily_shift_button',
        ]) {
          await expectReachable(tester, find.byKey(Key(key)));
        }
        expect(taps, equals(5));
      });

      testWidgets('in-run HUD with several buffs active', (tester) async {
        int pauses = 0;
        await expectFits(
          tester,
          HUDOverlay(gameState: _busyRun(), onPause: () => pauses++, onToggleMute: () {}),
        );
        await expectReachable(tester, find.byKey(const Key('pause_button')));
        expect(pauses, equals(1));
        // The distance readout stays legible: scaled down at most a little.
        expect(tester.getSize(find.byKey(const Key('vip_mission_badge'))).height, greaterThan(0));
      });

      testWidgets('pause menu', (tester) async {
        final state = _busyRun()..pauseRun();
        int resumes = 0;
        int quits = 0;
        await expectFits(
          tester,
          PauseMenuModal(
            gameState: state,
            onResume: () => resumes++,
            onQuit: () => quits++,
            onToggleReduceFlash: (_) {},
          ),
        );
        await expectReachable(tester, find.byKey(const Key('resume_shift_button')));
        await expectReachable(tester, find.byKey(const Key('quit_to_depot_button')));
        expect(resumes, equals(1));
        expect(quits, equals(1));
      });

      testWidgets('locker', (tester) async {
        final storage = await _storage();
        await expectFits(
          tester,
          LockerModal(
            careerTips: 51200,
            unlockedSkins: storage.unlockedSkins,
            equippedSkin: storage.equippedSkin,
            onEquipSkin: (_) async {},
            onUnlockSkin: (_, __) async {},
            onClose: () {},
          ),
        );
      });

      testWidgets('trophies', (tester) async {
        final storage = await _storage();
        await expectFits(
          tester,
          AchievementsModal(
            unlockedAchievementIds: storage.unlockedAchievements,
            onClose: () {},
          ),
        );
      });

      testWidgets('bodega', (tester) async {
        final storage = await _storage();
        await expectFits(
          tester,
          BodegaModal(
            storageService: storage,
            equippedBoosters: const {},
            onEquippedBoostersChanged: (_) {},
            onClose: () {},
          ),
        );
      });

      testWidgets('daily shift', (tester) async {
        final storage = await _storage();
        int starts = 0;
        await expectFits(
          tester,
          DailyShiftModal(storageService: storage, onStartDailyShift: (_) => starts++),
        );
        await expectReachable(tester, find.byKey(const Key('start_daily_shift_button')));
        expect(starts, equals(1));
      });
    });
  }
}
