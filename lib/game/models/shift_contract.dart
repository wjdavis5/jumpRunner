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

/// The five contracts every shift carries.
///
/// They are a ladder, from one most shifts finish to one few ever will, and
/// each pays enough to notice. Measured on autoplayed shifts (60 each of a
/// button-masher, median 240 m and $660 of tips, and a careful player,
/// median 2,300 m and $13,800):
///
/// * tips come to about $100 by 100 m, $400 by 200 m and $1,300 by 300 m;
/// * anything acrobatic counts as a stunt, about five in the first 100 m
///   and seven per 100 m after that;
/// * an energy drink turns up about every 300 m;
/// * the masher's first hit comes at 47 m (median) and the careful
///   player's at 305 m.
///
/// The original targets ($15 of tips, 3 stunts) were met inside the first
/// 150 m of every single shift, and the five rewards together came to $115.
class ContractCatalog {
  static List<ShiftContract> generateShiftContracts() => [
        ShiftContract(
          id: 'tips_500',
          type: ContractType.tipCollector,
          title: 'Rush Hour Tips',
          description: r'Collect $500 in tips in one shift',
          targetValue: 500,
          rewardTips: 100,
        ),
        ShiftContract(
          id: 'stunts_20',
          type: ContractType.stuntSpecialist,
          title: 'Daredevil Shift',
          description: 'Pull off 20 stunts in one shift',
          targetValue: 20,
          rewardTips: 150,
        ),
        ShiftContract(
          id: 'boosts_2',
          type: ContractType.speedDemon,
          title: 'High-Octane Courier',
          description: 'Drink 2 Energy Boosts in one shift',
          targetValue: 2,
          rewardTips: 200,
        ),
        ShiftContract(
          id: 'fragile_300',
          type: ContractType.fragileFreight,
          title: 'Fragile Delivery',
          description: 'Travel 300m without losing a package',
          targetValue: 300,
          rewardTips: 400,
        ),
        ShiftContract(
          id: 'night_shift',
          type: ContractType.nightOwl,
          title: 'Night Shift Veteran',
          description: 'Reach Midnight City (2500m)',
          targetValue: 2500,
          rewardTips: 1500,
        ),
      ];
}
