import '../../core/time/regions.dart';

enum TodayKind { unavailable, waiting, open }

enum AttemptStatus { started, finished, lost }

class AttemptInfo {
  const AttemptInfo({
    required this.startedAt,
    required this.onTime,
    required this.status,
    this.score,
  });

  factory AttemptInfo.fromJson(Map<String, dynamic> j) => AttemptInfo(
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      (j['startedAt'] as num).toInt(),
      isUtc: true,
    ),
    onTime: j['onTime'] as bool,
    status: AttemptStatus.values.byName(j['status'] as String),
    score: (j['score'] as num?)?.toInt(),
  );

  final DateTime startedAt;
  final bool onTime;
  final AttemptStatus status;
  final int? score;
}

/// Public streak / joker / badge summary of the player.
class ProfileSummary {
  const ProfileSummary({
    this.streak = 0,
    this.bestStreak = 0,
    this.jokers = 0,
    this.jokerAvailable = false,
    this.savedDays = const [],
    this.badges = const [],
  });

  factory ProfileSummary.fromJson(Map<String, dynamic> j) => ProfileSummary(
    streak: (j['streak'] as num?)?.toInt() ?? 0,
    bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
    jokers: (j['jokers'] as num?)?.toInt() ?? 0,
    jokerAvailable: j['jokerAvailable'] as bool? ?? false,
    savedDays: [
      for (final d in (j['savedDays'] as List<dynamic>? ?? const [])) '$d',
    ],
    badges: [for (final d in (j['badges'] as List<dynamic>? ?? const [])) '$d'],
  );

  final int streak;
  final int bestStreak;
  final int jokers;
  final bool jokerAvailable;
  final List<String> savedDays;
  final List<String> badges;
}

/// Answer of `getToday` (section 4.2): nothing is revealed before the alarm.
class TodayInfo {
  const TodayInfo({
    required this.kind,
    required this.serverNow,
    required this.region,
    this.dayKey,
    this.gameId,
    this.seed,
    this.modifierId,
    this.alertAt,
    this.attempt,
    this.profile = const ProfileSummary(),
  });

  factory TodayInfo.fromJson(Map<String, dynamic> j, Region region) =>
      TodayInfo(
        kind: switch (j['state']) {
          'waiting' => TodayKind.waiting,
          'open' => TodayKind.open,
          _ => TodayKind.unavailable,
        },
        serverNow: DateTime.fromMillisecondsSinceEpoch(
          (j['serverNow'] as num).toInt(),
          isUtc: true,
        ),
        region: region,
        dayKey: j['dayKey'] as String?,
        gameId: j['gameId'] as String?,
        seed: (j['seed'] as num?)?.toInt(),
        modifierId: j['modifierId'] as String?,
        alertAt: j['alertAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (j['alertAt'] as num).toInt(),
                isUtc: true,
              ),
        attempt: j['attempt'] == null
            ? null
            : AttemptInfo.fromJson(
                Map<String, dynamic>.from(j['attempt'] as Map),
              ),
        profile: j['profile'] == null
            ? const ProfileSummary()
            : ProfileSummary.fromJson(
                Map<String, dynamic>.from(j['profile'] as Map),
              ),
      );

  final TodayKind kind;
  final DateTime serverNow;
  final Region region;
  final String? dayKey;
  final String? gameId;
  final int? seed;
  final String? modifierId;
  final DateTime? alertAt;
  final AttemptInfo? attempt;
  final ProfileSummary profile;
}

class StartedAttempt {
  const StartedAttempt({
    required this.dayKey,
    required this.gameId,
    required this.seed,
    required this.modifierId,
    required this.onTime,
    required this.startDelay,
  });

  final String dayKey;
  final String gameId;
  final int seed;
  final String? modifierId;
  final bool onTime;
  final Duration startDelay;
}

class SubmitOutcome {
  const SubmitOutcome({
    required this.streak,
    required this.bestStreak,
    required this.newBadges,
  });

  final int streak;
  final int bestStreak;
  final List<String> newBadges;
}

enum DayStatus { onTime, late, missed, saved }

/// One day of the profile calendar.
class DayRecord {
  const DayRecord({
    required this.dayKey,
    required this.status,
    this.gameId,
    this.score,
  });

  final String dayKey;
  final DayStatus status;
  final String? gameId;
  final int? score;
}
