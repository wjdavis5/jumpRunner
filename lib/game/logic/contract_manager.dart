import 'package:flutter/foundation.dart';
import '../models/shift_contract.dart';

/// Manages active shift delivery contracts, evaluates completion triggers, and calculates rewards.
class ContractManager extends ChangeNotifier {
  ContractManager({
    List<ShiftContract>? contracts,
  }) : contracts = contracts ?? ContractCatalog.generateShiftContracts();

  final List<ShiftContract> contracts;

  /// Callback fired immediately when an objective is successfully completed during a shift.
  void Function(ShiftContract contract)? onContractCompleted;

  /// Total number of contracts completed during the current shift.
  int get completedCount => contracts.where((c) => c.isCompleted).length;

  /// Total bonus Career Tips earned from completed contracts during the current shift.
  int get totalBonusTips =>
      contracts.where((c) => c.isCompleted).fold(0, (sum, c) => sum + c.rewardTips);

  /// Evaluates distance progression across runner distance and damage status.
  void onDistanceProgress(double meters, {required int damageCount}) {
    for (final c in contracts) {
      if (c.isCompleted) continue;

      if (c.type == ContractType.fragileFreight) {
        if (damageCount > 0) {
          c.isFailed = true;
        } else {
          c.currentProgress = meters.toInt();
          _checkCompletion(c);
        }
      } else if (c.type == ContractType.nightOwl) {
        c.currentProgress = meters.toInt();
        _checkCompletion(c);
      }
    }
  }

  /// Evaluates stunt execution progress.
  void onStuntPerformed() {
    for (final c in contracts) {
      if (c.isCompleted || c.isFailed) continue;

      if (c.type == ContractType.stuntSpecialist) {
        c.currentProgress++;
        _checkCompletion(c);
      }
    }
  }

  /// Evaluates Career Tips gathered during the shift.
  void onTipCollected(int amount) {
    for (final c in contracts) {
      if (c.isCompleted || c.isFailed) continue;

      if (c.type == ContractType.tipCollector) {
        c.currentProgress += amount;
        _checkCompletion(c);
      }
    }
  }

  /// Evaluates Energy Drink speed boosts activated.
  void onEnergyBoostActivated() {
    for (final c in contracts) {
      if (c.isCompleted || c.isFailed) continue;

      if (c.type == ContractType.speedDemon) {
        c.currentProgress++;
        _checkCompletion(c);
      }
    }
  }

  /// Handles hazard collision damage, failing any fragile cargo contracts.
  void onDamageTaken() {
    for (final c in contracts) {
      if (!c.isCompleted && c.type == ContractType.fragileFreight) {
        c.isFailed = true;
      }
    }
    notifyListeners();
  }

  void _checkCompletion(ShiftContract c) {
    if (!c.isCompleted && !c.isFailed && c.currentProgress >= c.targetValue) {
      c.isCompleted = true;
      onContractCompleted?.call(c);
      notifyListeners();
    }
  }

  /// Resets all contract objectives for a fresh shift.
  void reset() {
    for (final c in contracts) {
      c.reset();
    }
    notifyListeners();
  }
}
