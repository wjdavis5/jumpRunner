import 'dart:math' as math;

/// Build-time switches for looking at late-game content without playing to
/// it. They are compile-time constants read from `--dart-define`, so in a
/// normal build both are off and the code behind them is compiled out.
///
/// ```sh
/// flutter run -d chrome --dart-define=QA_START_METERS=2600 --dart-define=QA_IMMORTAL=true
/// ```
class QaFlags {
  /// Every shift starts this many meters in (0 = off). 2,600 lands in the
  /// night phase at top speed.
  static const int startMeters = int.fromEnvironment('QA_START_METERS');

  /// The courier never runs out of packages, so a shift only ends when it
  /// is quit.
  static const bool immortal = bool.fromEnvironment('QA_IMMORTAL');

  /// Whether this is a QA build at all.
  static const bool any = startMeters > 0 || immortal;

  /// Where a shift starts in this build. In a QA build on the web the page
  /// address can override the built-in distance, so one build covers every
  /// stage: `?qa_start=1200`. Always 0 in a normal build.
  static int get effectiveStartMeters {
    if (!any) return 0;
    final fromAddress = int.tryParse(Uri.base.queryParameters['qa_start'] ?? '');
    return fromAddress ?? startMeters;
  }

  /// `?qa_subway=1` in a QA build: every chunk that can be a subway station
  /// is one. Stations are otherwise about one per kilometre.
  static bool get forceSubway => any && Uri.base.queryParameters['qa_subway'] == '1';

  /// `--dart-define=QA_FORCE_CHUTE=true` in a QA build: every scaffolding
  /// route that has room carries a debris chute, so slides can be recorded
  /// without waiting on the dice. Compiled out of a normal build.
  static const bool forceChute = bool.fromEnvironment('QA_FORCE_CHUTE');

  /// `--dart-define=QA_FORCE_CRADLE=true` in a QA build: every chunk that can
  /// carry a window-washer cradle does, for deterministic ride recordings.
  /// Compiled out of a normal build.
  static const bool forceCradle = bool.fromEnvironment('QA_FORCE_CRADLE');

  /// `?qa_seed=7` in a QA build: the street is generated from that seed, so
  /// two page loads build the same street. Frame rates can only be compared
  /// between runs that drew the same things. Null in a normal build and
  /// when no seed is given. Off-web builds take it as `--dart-define=QA_SEED=7`.
  static const int seedDefine = int.fromEnvironment('QA_SEED');

  static math.Random? get streetRandom {
    if (!any) return null;
    final seed = int.tryParse(Uri.base.queryParameters['qa_seed'] ?? '') ??
        (seedDefine > 0 ? seedDefine : null);
    return seed == null ? null : math.Random(seed);
  }
}
