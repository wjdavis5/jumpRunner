import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Offline key-value persistence service for courier career records, locker unlocks,
/// and audio preferences.
///
/// Guaranteed zero network calls, zero third-party telemetry, 100% offline.
class LocalStorageService {
  LocalStorageService();

  static const String _keyHighDistance = 'courier_high_distance';
  static const String _keyCareerTips = 'courier_career_tips';
  static const String _keySoundMuted = 'courier_sound_muted';
  static const String _keyUnlockedSkins = 'courier_unlocked_skins';
  static const String _keyEquippedSkin = 'courier_equipped_skin';
  static const String _keyCompletedContracts = 'courier_completed_contracts';
  static const String _keyUnlockedAchievements = 'courier_unlocked_achievements';

  SharedPreferences? _prefs;

  /// Initializes SharedPreferences instance.
  Future<void> init([SharedPreferences? mockPrefs]) async {
    _prefs = mockPrefs ?? await SharedPreferences.getInstance();
  }

  /// Personal best distance in meters.
  int get highDistance => _prefs?.getInt(_keyHighDistance) ?? 0;

  /// Total career tips collected in dollars ($).
  int get careerTips => _prefs?.getInt(_keyCareerTips) ?? 0;

  /// Lifetime delivery contracts completed by the courier.
  int get completedContracts => _prefs?.getInt(_keyCompletedContracts) ?? 0;

  /// List of achievement identifiers unlocked by the player.
  List<String> get unlockedAchievements =>
      _prefs?.getStringList(_keyUnlockedAchievements) ?? const [];

  /// Whether audio is muted by player preference.
  bool get isSoundMuted => _prefs?.getBool(_keySoundMuted) ?? false;

  /// List of skin identifiers unlocked by the player.
  List<String> get unlockedSkins =>
      _prefs?.getStringList(_keyUnlockedSkins) ?? const ['standard'];

  /// Identifier of the currently equipped vanity courier outfit.
  String get equippedSkin => _prefs?.getString(_keyEquippedSkin) ?? 'standard';

  /// Records completed run stats, updating personal best distance and cumulative career tips.
  ///
  /// Returns `true` if a new personal best distance record was set.
  Future<bool> recordRun({required int distance, required int tips}) async {
    final prefs = _prefs;
    if (prefs == null) return false;

    final currentHigh = highDistance;
    final isNewRecord = distance > currentHigh;

    if (isNewRecord) {
      await prefs.setInt(_keyHighDistance, distance);
    }

    final newCareerTips = careerTips + math.max<int>(0, tips);
    await prefs.setInt(_keyCareerTips, newCareerTips);

    return isNewRecord;
  }

  /// Saves user audio mute preference.
  Future<void> setSoundMuted(bool muted) async {
    await _prefs?.setBool(_keySoundMuted, muted);
  }

  /// Purchases and unlocks a cosmetic courier skin using accumulated career tips.
  ///
  /// Returns `true` if skin was successfully purchased; `false` if insufficient funds or already owned.
  Future<bool> unlockSkin(String skinId, int cost) async {
    final prefs = _prefs;
    if (prefs == null) return false;

    final currentUnlocked = List<String>.from(unlockedSkins);
    if (currentUnlocked.contains(skinId)) return true;

    if (careerTips < cost) return false;

    await prefs.setInt(_keyCareerTips, careerTips - cost);
    currentUnlocked.add(skinId);
    await prefs.setStringList(_keyUnlockedSkins, currentUnlocked);
    return true;
  }

  /// Equips an unlocked vanity courier outfit.
  Future<bool> equipSkin(String skinId) async {
    final prefs = _prefs;
    if (prefs == null) return false;

    if (unlockedSkins.contains(skinId)) {
      await prefs.setString(_keyEquippedSkin, skinId);
      return true;
    }
    return false;
  }

  /// Increments total completed shift delivery contracts.
  Future<void> recordCompletedContracts(int count) async {
    final prefs = _prefs;
    if (prefs == null || count <= 0) return;
    await prefs.setInt(_keyCompletedContracts, completedContracts + count);
  }

  /// Unlocks an achievement and persists it to local storage.
  ///
  /// Returns `true` if newly unlocked; `false` if already unlocked.
  Future<bool> unlockAchievement(String achievementId) async {
    final prefs = _prefs;
    if (prefs == null) return false;

    final current = List<String>.from(unlockedAchievements);
    if (current.contains(achievementId)) return false;

    current.add(achievementId);
    await prefs.setStringList(_keyUnlockedAchievements, current);
    return true;
  }
}
