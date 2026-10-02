import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Offline key-value persistence service for courier career records and preferences.
///
/// Guaranteed zero network calls, zero third-party telemetry, 100% offline.
class LocalStorageService {
  LocalStorageService();

  static const String _keyHighDistance = 'courier_high_distance';
  static const String _keyCareerTips = 'courier_career_tips';
  static const String _keySoundMuted = 'courier_sound_muted';

  SharedPreferences? _prefs;

  /// Initializes SharedPreferences instance.
  Future<void> init([SharedPreferences? mockPrefs]) async {
    _prefs = mockPrefs ?? await SharedPreferences.getInstance();
  }

  /// Personal best distance in meters.
  int get highDistance => _prefs?.getInt(_keyHighDistance) ?? 0;

  /// Total career tips collected in dollars ($).
  int get careerTips => _prefs?.getInt(_keyCareerTips) ?? 0;

  /// Whether audio is muted by player preference.
  bool get isSoundMuted => _prefs?.getBool(_keySoundMuted) ?? false;

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
}
