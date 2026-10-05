import '../models/achievement.dart';
import '../../services/storage_service.dart';

/// Manages career achievement unlocks, live gameplay evaluation, and persistence.
class AchievementManager {
  AchievementManager({LocalStorageService? storageService})
      : _storage = storageService {
    _unlockedIds = Set<String>.from(_storage?.unlockedAchievements ?? const []);
  }

  final LocalStorageService? _storage;
  late final Set<String> _unlockedIds;

  /// Callback dispatched when an achievement is unlocked during gameplay.
  void Function(Achievement achievement)? onAchievementUnlocked;

  /// Unmodifiable set of unlocked achievement IDs.
  Set<String> get unlockedIds => Set.unmodifiable(_unlockedIds);

  /// Checks whether an achievement is unlocked.
  bool isUnlocked(String id) => _unlockedIds.contains(id);

  /// Total number of catalog achievements.
  int get totalCount => Achievement.catalog.length;

  /// Number of achievements unlocked by the player.
  int get unlockedCount => _unlockedIds.length;

  /// Unlocks an achievement by ID, saves to storage, and dispatches callbacks.
  ///
  /// Returns `true` if newly unlocked, `false` if already unlocked or invalid.
  Future<bool> unlock(String id) async {
    if (_unlockedIds.contains(id)) return false;
    final achievement = Achievement.findById(id);
    if (achievement == null) return false;

    _unlockedIds.add(id);
    await _storage?.unlockAchievement(id);
    onAchievementUnlocked?.call(achievement);
    return true;
  }

  /// Lifetime tips that earn the Big Tipper trophy. It was $150, which the
  /// first shift of any career cleared; this is roughly the whole Locker.
  static const int bigTipperLifetimeTips = 25000;

  /// One shift this long earns Long Haul.
  static const double longHaulMeters = 1000.0;

  /// Career doorstep deliveries that earn Door to Door. A street has about
  /// six drop zones per 1,000 m.
  static const int doorToDoorDeliveries = 25;

  /// Daily goals reached, on different days, that earn Regular.
  static const int regularDailyGoals = 5;

  /// Evaluates progress against run metrics and lifetime records.
  Future<List<Achievement>> evaluateProgress({
    required double distanceMeters,
    required int stuntCombo,
    required int lifetimeContracts,
    required int lifetimeCareerTips,
    int wetHazardsCleared = 0,
    int subwayStationsInRun = 0,
    int lifetimeDeliveries = 0,
    int dailyStars = 0,
  }) async {
    final newlyUnlocked = <Achievement>[];

    if (distanceMeters >= 500.0 && !isUnlocked('first_delivery')) {
      if (await unlock('first_delivery')) {
        newlyUnlocked.add(Achievement.findById('first_delivery')!);
      }
    }

    if (distanceMeters >= 2500.0 && !isUnlocked('shift_veteran')) {
      if (await unlock('shift_veteran')) {
        newlyUnlocked.add(Achievement.findById('shift_veteran')!);
      }
    }

    if (stuntCombo >= 4 && !isUnlocked('master_acrobat')) {
      if (await unlock('master_acrobat')) {
        newlyUnlocked.add(Achievement.findById('master_acrobat')!);
      }
    }

    if (lifetimeContracts >= 10 && !isUnlocked('contract_specialist')) {
      if (await unlock('contract_specialist')) {
        newlyUnlocked.add(Achievement.findById('contract_specialist')!);
      }
    }

    if (lifetimeCareerTips >= bigTipperLifetimeTips && !isUnlocked('big_tipper')) {
      if (await unlock('big_tipper')) {
        newlyUnlocked.add(Achievement.findById('big_tipper')!);
      }
    }

    if (wetHazardsCleared >= 5 && !isUnlocked('rain_rider')) {
      if (await unlock('rain_rider')) {
        newlyUnlocked.add(Achievement.findById('rain_rider')!);
      }
    }

    final more = <String, bool>{
      'long_haul': distanceMeters >= longHaulMeters,
      'straphanger': subwayStationsInRun >= 1,
      'door_to_door': lifetimeDeliveries >= doorToDoorDeliveries,
      'daily_regular': dailyStars >= regularDailyGoals,
    };
    for (final entry in more.entries) {
      if (entry.value && !isUnlocked(entry.key) && await unlock(entry.key)) {
        newlyUnlocked.add(Achievement.findById(entry.key)!);
      }
    }

    return newlyUnlocked;
  }
}
