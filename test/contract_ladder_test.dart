// ignore_for_file: invalid_use_of_internal_member
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/contract_manager.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';
import 'package:jump_runner/game/models/shift_contract.dart';

Future<CourierGame> _shift(int seed, {GameState? state}) async {
  final game = CourierGame(
    gameState: state,
    audioController: GameAudioController()..isMuted = true,
    chunkManager: WorldChunkManager(random: math.Random(seed)),
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  return game;
}

/// A player who presses jump on a loose rhythm without looking: about the
/// worst a real player does. Plays [game] until the shift is lost.
Future<void> _mash(CourierGame game, int seed, {void Function()? eachFrame}) async {
  final dice = math.Random(seed);
  var nextPress = 20;
  var releaseAt = -1;
  for (var f = 0; f < 60 * 300 && game.gameState.status == GameStatus.running; f++) {
    if (f == nextPress) {
      game.player.pressJump();
      releaseAt = f + 3 + dice.nextInt(10);
      nextPress = f + 25 + dice.nextInt(35);
    }
    if (f == releaseAt) game.player.releaseJump();
    game.update(1 / 60);
    if (f % 4 == 0) await Future<void>.delayed(Duration.zero);
    eachFrame?.call();
  }
}

/// A player who jumps each hazard at about the right moment and cannot lose.
/// Plays [game] to [meters].
Future<void> _playWell(CourierGame game, double meters, {void Function()? eachFrame}) async {
  var releaseAt = -1;
  for (var f = 0; f < 60 * 400 && game.gameState.distanceMeters < meters; f++) {
    if (game.gameState.packages < GameState.defaultMaxPackages) {
      game.gameState.packages = GameState.defaultMaxPackages;
    }
    final player = game.player;
    final front = player.position.x + player.size.x / 2;
    ObstacleComponent? next;
    for (final o in game.activeObstacles) {
      final centre = o.position.x + o.size.x / 2;
      if (centre > front && (next == null || centre < next.position.x + next.size.x / 2)) next = o;
    }
    if (next != null && player.simulator.isGrounded && releaseAt < 0) {
      final tall = next.size.y > 50 || next.size.x > 80;
      final lead = game.currentSpeed * (tall ? 0.60 : 0.385);
      if (next.position.x + next.size.x / 2 - front <= lead + next.size.x / 2) {
        player.pressJump();
        releaseAt = f + (tall ? 18 : 3);
      }
    }
    if (releaseAt >= 0 && f >= releaseAt) {
      player.releaseJump();
      releaseAt = -1;
    }
    game.update(1 / 60);
    if (f % 4 == 0) await Future<void>.delayed(Duration.zero);
    eachFrame?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = ContractCatalog.generateShiftContracts();
  ShiftContract byType(ContractType type) => catalog.singleWhere((c) => c.type == type);

  // The five contracts were written when a shift earned a handful of tips.
  // By the time the street had forty ways to earn them, "collect $15" and
  // "3 stunts" were both finished within 150 m of the start of every shift,
  // and all five together paid $115 against shifts worth $660 to $14,000.
  group('The contracts are a ladder worth climbing', () {
    test('there is one of each kind', () {
      expect(catalog, hasLength(5));
      expect(catalog.map((c) => c.type).toSet(), hasLength(5));
      expect(catalog.map((c) => c.id).toSet(), hasLength(5));
    });

    test('they are listed easiest first, each paying more than the last', () {
      for (var i = 1; i < catalog.length; i++) {
        expect(catalog[i].rewardTips, greaterThan(catalog[i - 1].rewardTips),
            reason: '${catalog[i].title} after ${catalog[i - 1].title}');
      }
    });

    test('every reward is big enough to notice', () {
      // A poor shift earns about $400-$700.
      for (final contract in catalog) {
        expect(contract.rewardTips, greaterThanOrEqualTo(100), reason: contract.title);
      }
    });

    test('a clean sweep is worth less than the first outfit', () {
      final sweep = catalog.fold<int>(0, (sum, c) => sum + c.rewardTips);
      expect(sweep, inInclusiveRange(1500, 3500));
    });

    test('no target is one the first hundred metres hand out', () {
      // About $100 of tips and five stunts come in the first 100 m.
      expect(byType(ContractType.tipCollector).targetValue, greaterThanOrEqualTo(300));
      expect(byType(ContractType.stuntSpecialist).targetValue, greaterThanOrEqualTo(10));
      expect(byType(ContractType.fragileFreight).targetValue, greaterThanOrEqualTo(200));
    });

    test('each description states its own target', () {
      for (final contract in catalog) {
        expect(contract.description, contains('${contract.targetValue}'), reason: contract.title);
      }
    });
  });

  // "Collect $500 in tips" has to mean the number the HUD shows. Stunts,
  // doorstep and VIP deliveries, drone catches and the milestone bonus all
  // paid tips without telling the contract, which nobody could see while the
  // target was $15.
  group('The tips contract counts every tip', () {
    for (final seed in [3, 8]) {
      test('its progress is the shift\'s tips, all the way down street $seed', () async {
        final open = [
          ShiftContract(
            id: 'tips_open',
            type: ContractType.tipCollector,
            title: 'Tips',
            description: 'Tips',
            targetValue: 1 << 30,
            rewardTips: 0,
          ),
        ];
        final state = GameState(contractManager: ContractManager(contracts: open));
        final game = await _shift(seed, state: state);

        var checked = 0;
        var worstGap = 0;
        var atMeters = 0.0;
        await _playWell(game, 1500.0, eachFrame: () {
          checked++;
          final gap = (open.single.currentProgress - state.tips).abs();
          if (gap > worstGap) {
            worstGap = gap;
            atMeters = state.distanceMeters;
          }
        });
        expect(state.distanceMeters, greaterThanOrEqualTo(1500.0));
        expect(state.tips, greaterThan(3000));
        expect(checked, greaterThan(1000));
        expect(worstGap, equals(0),
            reason: 'contract and HUD disagreed by \$$worstGap at ${atMeters.round()} m');
      });
    }
  });

  group('How the ladder plays for someone mashing the button', () {
    // Forty mortal shifts, the same forty every time.
    late final Map<String, List<double>> doneAt;
    late final List<int> bonuses;
    late final List<int> shiftTips;
    const shifts = 40;

    setUpAll(() async {
      doneAt = {for (final c in catalog) c.id: <double>[]};
      bonuses = [];
      shiftTips = [];
      for (var seed = 1; seed <= shifts; seed++) {
        final game = await _shift(seed * 7);
        final seen = <String>{};
        await _mash(game, seed, eachFrame: () {
          for (final c in game.gameState.contractManager.contracts) {
            if (c.isCompleted && seen.add(c.id)) {
              doneAt[c.id]!.add(game.gameState.distanceMeters);
            }
          }
        });
        // Nearly every one of these ends in a lost shift. The odd masher
        // who is still going after five minutes is simply counted as far as
        // they got.
        bonuses.add(game.gameState.contractManager.totalBonusTips);
        shiftTips.add(game.gameState.tips);
      }
    });

    double share(ContractType type) => doneAt[byType(type).id]!.length / shifts;

    test('nothing is handed out in the first 80 m', () {
      for (final entry in doneAt.entries) {
        for (final meters in entry.value) {
          expect(meters, greaterThan(80.0), reason: '${entry.key} done at ${meters.round()} m');
        }
      }
    });

    test('the first rung is finished in many shifts but not all of them', () {
      expect(share(ContractType.tipCollector), inInclusiveRange(0.35, 0.90));
    });

    test('the stunt rung is harder than the tips rung, and still reachable', () {
      expect(share(ContractType.stuntSpecialist), inInclusiveRange(0.10, 0.70));
      expect(share(ContractType.stuntSpecialist),
          lessThanOrEqualTo(share(ContractType.tipCollector)));
    });

    test('a clean 300 m and Midnight City are for players who look where they are going', () {
      expect(share(ContractType.fragileFreight), lessThanOrEqualTo(0.15));
      expect(share(ContractType.nightOwl), lessThanOrEqualTo(0.15));
    });

    test('contracts add to a shift without becoming most of it', () {
      final sortedBonus = [...bonuses]..sort();
      final sortedTips = [...shiftTips]..sort();
      final medianBonus = sortedBonus[shifts ~/ 2];
      final medianTips = sortedTips[shifts ~/ 2];
      expect(medianBonus, greaterThanOrEqualTo(100));
      expect(medianBonus, lessThanOrEqualTo(medianTips * 0.6));
      // Some shifts end too soon to finish any.
      final empty = bonuses.where((b) => b == 0).length;
      expect(empty, inInclusiveRange(2, shifts ~/ 2));
    });

    test('measured figures, for whoever retunes this', () {
      String line(ShiftContract c) {
        final at = [...doneAt[c.id]!]..sort();
        final median = at.isEmpty ? '-' : '${at[at.length ~/ 2].round()} m';
        return '${c.id}: ${(100 * at.length / shifts).round()}% (median $median)';
      }

      // ignore: avoid_print
      print(catalog.map(line).join('; '));
    });
  });
}
