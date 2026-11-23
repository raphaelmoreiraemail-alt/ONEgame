import '../../core/time/regions.dart';
import '../../games/common/game_types.dart';
import 'models.dart';

/// Daily challenge backend (section 10.2). Implementations: local / demo
/// (on-device, same rules as the server) and Firebase (Cloud Functions).
abstract class DailyRepository {
  Region get region;

  /// Region change, max once per 30 days. Throws [RegionCooldown].
  Future<void> setRegion(Region region);

  DateTime? get regionChangedAt;

  Future<TodayInfo> getToday();

  /// Records the one official attempt. Throws [AttemptAlreadyExists].
  Future<StartedAttempt> startAttempt();

  Future<SubmitOutcome?> submit(GameResult result, {bool partial = false});

  Future<ProfileSummary> useJoker();

  /// Official history, newest first, for the calendar and records.
  Future<List<DayRecord>> history({int days = 112});

  /// Games already released as a daily game (training, section 9.9).
  Future<Set<String>> releasedGames();

  /// Next alarm instants known in advance (local mode only, for local
  /// notifications). Empty with a real server.
  Future<List<(DateTime, String, String?)>> upcomingAlerts({int days = 7});
}

class AttemptAlreadyExists implements Exception {
  const AttemptAlreadyExists();
}

class RegionCooldown implements Exception {
  const RegionCooldown(this.until);

  final DateTime until;
}
