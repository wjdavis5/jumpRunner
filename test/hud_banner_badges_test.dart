import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/ui/hud_overlay.dart';

const _badgeKeys = [
  'energy_boost_badge',
  'drone_assist_badge',
  'stunt_combo_badge',
  'delivery_streak_badge',
  'vip_mission_badge',
  'drafting_stream_badge',
  'floral_aroma_badge',
  'notoriety_badge',
  'caffeine_surge_badge',
  'urban_groove_badge',
  'hydroplane_badge',
  'thermal_updraft_badge',
];

Future<HUDOverlay> _pumpHud(
  WidgetTester tester,
  GameState state, {
  Size size = const Size(960, 540),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final hud = HUDOverlay(gameState: state);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: hud)));
  await tester.pump();
  return hud;
}

/// The badges actually on screen, as rectangles.
List<Rect> _badgesShown(WidgetTester tester) => [
      for (final key in _badgeKeys)
        if (find.byKey(Key(key)).evaluate().isNotEmpty) tester.getRect(find.byKey(Key(key))),
    ];

void main() {
  // The 500 m milestone banner and the status badges (boost timer, stunt
  // combo, VIP clock...) both live under the distance readout. The banner
  // used to be drawn at a fixed height, straight over the badges, hiding the
  // boost timer for the three seconds it was up.
  group('Celebration banners sit below the status badges', () {
    testWidgets('with no badges the banner is right under the distance pill', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(500.0);
      final hud = await _pumpHud(tester, state);
      expect(hud.activeBadgeCount, equals(0));
      final banner = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
      expect(banner.top, closeTo(HUDOverlay.bannerTopOffset, 1.0));
    });

    testWidgets('with badges up, the banner clears every one of them', (tester) async {
      final state = GameState()..startRun();
      state.activateEnergyDrink();
      state.activateDrone();
      state.startVipMission();
      state.isDrafting = true;
      state.updateDistance(500.0);
      final hud = await _pumpHud(tester, state);

      final badges = _badgesShown(tester);
      expect(badges.length, greaterThanOrEqualTo(4));
      expect(hud.activeBadgeCount, equals(badges.length));

      final banner = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
      for (final badge in badges) {
        expect(banner.overlaps(badge), isFalse, reason: 'banner $banner covers badge $badge');
        expect(banner.top, greaterThanOrEqualTo(badge.bottom - 0.5));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the contract banner stacks under the milestone banner, clear of badges',
        (tester) async {
      final state = GameState()..startRun();
      state.activateEnergyDrink();
      state.updateDistance(500.0); // milestone, and the fragile-freight contract
      final hud = await _pumpHud(tester, state);
      expect(state.isContractCelebrationVisible, isTrue);

      final badges = _badgesShown(tester);
      final milestone = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
      final contract = tester.getRect(find.byKey(const Key('contract_celebration_banner')));
      expect(hud.activeBadgeCount, equals(badges.length));
      expect(contract.top, greaterThanOrEqualTo(milestone.bottom - 0.5));
      for (final badge in badges) {
        expect(milestone.overlaps(badge), isFalse);
        expect(contract.overlaps(badge), isFalse);
      }
    });

    testWidgets('the badge count matches what is drawn, whatever is active', (tester) async {
      // Each line switches on one more badge.
      final steps = <void Function(GameState)>[
        (s) => s.activateEnergyDrink(),
        (s) => s.activateDrone(),
        (s) => s.recordStunt(clearance: 10.0),
        (s) => s.startVipMission(),
        (s) => s.isDrafting = true,
      ];
      final state = GameState()..startRun();
      for (var i = 0; i < steps.length; i++) {
        steps[i](state);
        final hud = await _pumpHud(tester, state);
        expect(hud.activeBadgeCount, equals(_badgesShown(tester).length), reason: 'after step $i');
      }
    });

    testWidgets('on a small phone the banner is still on screen with four badges up',
        (tester) async {
      final state = GameState()..startRun();
      state.activateEnergyDrink();
      state.activateDrone();
      state.startVipMission();
      state.isDrafting = true;
      state.updateDistance(500.0);
      await _pumpHud(tester, state, size: const Size(667, 375));
      final banner = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
      expect(banner.bottom, lessThanOrEqualTo(375.0));
      expect(tester.takeException(), isNull);
    });
  });
}
