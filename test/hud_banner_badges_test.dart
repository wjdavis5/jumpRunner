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

    // On a 320 px screen, with a boost and a drone running, a milestone and
    // a contract landing together put the lower banner over the courier and
    // the hazards in front of them for its whole three seconds.
    for (final size in const [Size(568, 320), Size(640, 360), Size(667, 375), Size(844, 390)]) {
      testWidgets('two banners under two badges end above the street on ${size.width.round()}x${size.height.round()}',
          (tester) async {
        final state = GameState()..startRun();
        state.activateEnergyDrink();
        state.activateDrone();
        state.updateDistance(500.0); // milestone, and the fragile-freight contract
        await _pumpHud(tester, state, size: size);
        expect(state.isMilestoneBannerVisible && state.isContractCelebrationVisible, isTrue);

        final milestone = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
        final contract = tester.getRect(find.byKey(const Key('contract_celebration_banner')));
        expect(contract.top, greaterThanOrEqualTo(milestone.bottom - 0.5));
        expect(contract.bottom, lessThanOrEqualTo(HUDOverlay.bannerFloor(size) + 0.5),
            reason: 'the lower banner reaches $contract, over the street');
        for (final badge in _badgesShown(tester)) {
          expect(milestone.overlaps(badge), isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('where the street starts on the screen', (tester) async {
      // The game fills the height of a 16:9 screen: the street's business
      // starts 72 of its 540 units above the pavement at 460.
      expect(HUDOverlay.bannerFloor(const Size(960, 540)), closeTo(388.0, 0.01));
      expect(HUDOverlay.bannerFloor(const Size(640, 360)), closeTo(388.0 * 360 / 540, 0.01));
      // A wider screen shows more street, at the same height.
      expect(HUDOverlay.bannerFloor(const Size(1200, 540)), closeTo(388.0, 0.01));
      // An upright phone letterboxes the game in the middle of the screen.
      const scale = 375 / 960;
      expect(HUDOverlay.bannerFloor(const Size(375, 667)), closeTo((667 - 540 * scale) / 2 + 388.0 * scale, 0.01));
    });

    testWidgets('with room to spare the banners are full size, one under the other', (tester) async {
      final state = GameState()..startRun();
      state.updateDistance(500.0);
      await _pumpHud(tester, state);
      final full = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
      final contract = tester.getRect(find.byKey(const Key('contract_celebration_banner')));
      expect(contract.top, closeTo(full.bottom + HUDOverlay.bannerGap, 0.5));

      // And never shrunk past reading: four badges on a small phone leave
      // no room above the street at all.
      final crowded = GameState()..startRun();
      crowded.activateEnergyDrink();
      crowded.activateDrone();
      crowded.startVipMission();
      crowded.isDrafting = true;
      crowded.updateDistance(500.0);
      await _pumpHud(tester, crowded, size: const Size(568, 320));
      final small = tester.getRect(find.byKey(const Key('milestone_celebration_banner')));
      expect(small.height, greaterThanOrEqualTo(full.height * HUDOverlay.smallestBannerScale * (568 / 600) - 6.0));
      expect(small.height, lessThan(full.height));
      expect(tester.takeException(), isNull);
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
