/// Types of shift delivery objectives a courier can undertake.
enum ContractType {
  /// Reach target distance in meters without sustaining package damage.
  fragileFreight,

  /// Execute target number of near-miss stunts in a single shift.
  stuntSpecialist,

  /// Gather target number of Career Tips in a single shift.
  tipCollector,

  /// Reach the Midnight City environmental phase (2500m+).
  nightOwl,

  /// Activate target number of Energy Drink speed boosts in a single shift.
  speedDemon,
}

/// Represents an individual shift delivery contract objective.
class ShiftContract {
  ShiftContract({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.rewardTips,
    this.currentProgress = 0,
    this.isCompleted = false,
    this.isFailed = false,
  });

  final String id;
  final ContractType type;
  final String title;
  final String description;
  final int targetValue;
  final int rewardTips;

  int currentProgress;
  bool isCompleted;
  bool isFailed;

  /// Progress fraction towards completion (0.0 to 1.0).
  double get progressRatio =>
      targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  /// Resets progress for a fresh shift.
  void reset() {
    currentProgress = 0;
    isCompleted = false;
    isFailed = false;
  }
}

/// Factory templates for active shift contracts.
class ContractCatalog {
  static List<ShiftContract> generateShiftContracts() => [
        ShiftContract(
          id: 'fragile_500',
          type: ContractType.fragileFreight,
          title: 'Fragile Delivery',
          description: 'Travel 500m without sustaining package damage',
          targetValue: 500,
          rewardTips: 25,
        ),
        ShiftContract(
          id: 'stunts_3',
          type: ContractType.stuntSpecialist,
          title: 'Daredevil Shift',
          description: 'Perform 3 near-miss stunts in a single shift',
          targetValue: 3,
          rewardTips: 20,
        ),
        ShiftContract(
          id: 'tips_15',
          type: ContractType.tipCollector,
          title: 'Rush Hour Tips',
          description: 'Collect 15 Career Tips during your shift',
          targetValue: 15,
          rewardTips: 15,
        ),
        ShiftContract(
          id: 'night_shift',
          type: ContractType.nightOwl,
          title: 'Night Shift Veteran',
          description: 'Reach Midnight City (2500m)',
          targetValue: 2500,
          rewardTips: 35,
        ),
        ShiftContract(
          id: 'boosts_2',
          type: ContractType.speedDemon,
          title: 'High-Octane Courier',
          description: 'Drink 2 Energy Boosts in a single shift',
          targetValue: 2,
          rewardTips: 20,
        ),
      ];
}
