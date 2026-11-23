/// Dart port of `functions/src/core/streak.ts` (local / demo backend).
library;

import '../../core/time/regions.dart';

class StreakState {
  const StreakState({
    this.streak = 0,
    this.bestStreak = 0,
    this.lastOnTimeDay,
    this.jokers = 0,
    this.jokerMonth,
    this.streakBeforeBreak = 0,
    this.brokenDay,
    this.savedDays = const [],
  });

  factory StreakState.fromJson(Map<String, dynamic> j) => StreakState(
    streak: j['streak'] as int? ?? 0,
    bestStreak: j['bestStreak'] as int? ?? 0,
    lastOnTimeDay: j['lastOnTimeDay'] as String?,
    jokers: j['jokers'] as int? ?? 0,
    jokerMonth: j['jokerMonth'] as String?,
    streakBeforeBreak: j['streakBeforeBreak'] as int? ?? 0,
    brokenDay: j['brokenDay'] as String?,
    savedDays: [
      for (final d in (j['savedDays'] as List<dynamic>? ?? const []))
        d as String,
    ],
  );

  final int streak;
  final int bestStreak;
  final String? lastOnTimeDay;
  final int jokers;
  final String? jokerMonth;
  final int streakBeforeBreak;
  final String? brokenDay;
  final List<String> savedDays;

  Map<String, Object?> toJson() => {
    'streak': streak,
    'bestStreak': bestStreak,
    'lastOnTimeDay': lastOnTimeDay,
    'jokers': jokers,
    'jokerMonth': jokerMonth,
    'streakBeforeBreak': streakBeforeBreak,
    'brokenDay': brokenDay,
    'savedDays': savedDays,
  };

  StreakState copyWith({
    int? streak,
    int? bestStreak,
    String? Function()? lastOnTimeDay,
    int? jokers,
    String? jokerMonth,
    int? streakBeforeBreak,
    String? Function()? brokenDay,
    List<String>? savedDays,
  }) => StreakState(
    streak: streak ?? this.streak,
    bestStreak: bestStreak ?? this.bestStreak,
    lastOnTimeDay: lastOnTimeDay != null ? lastOnTimeDay() : this.lastOnTimeDay,
    jokers: jokers ?? this.jokers,
    jokerMonth: jokerMonth ?? this.jokerMonth,
    streakBeforeBreak: streakBeforeBreak ?? this.streakBeforeBreak,
    brokenDay: brokenDay != null ? brokenDay() : this.brokenDay,
    savedDays: savedDays ?? this.savedDays,
  );
}

String monthOf(String dayKey) => dayKey.substring(0, 7);

StreakState grantMonthlyJoker(StreakState s, String today) =>
    s.jokerMonth == monthOf(today)
    ? s
    : s.copyWith(jokers: 1, jokerMonth: monthOf(today));

int effectiveStreak(StreakState s, String today) =>
    s.lastOnTimeDay == today || s.lastOnTimeDay == addDays(today, -1)
    ? s.streak
    : 0;

StreakState recordPlay(StreakState state, String dayKey, bool onTime) {
  var s = grantMonthlyJoker(state, dayKey);
  if (onTime) {
    if (s.lastOnTimeDay == dayKey) return s;
    if (s.lastOnTimeDay == addDays(dayKey, -1)) {
      s = s.copyWith(streak: s.streak + 1);
    } else {
      final had = s.lastOnTimeDay != null;
      s = s.copyWith(
        streakBeforeBreak: had ? s.streak : 0,
        brokenDay: () => had ? addDays(dayKey, -1) : null,
        streak: 1,
      );
    }
    return s.copyWith(
      lastOnTimeDay: () => dayKey,
      bestStreak: s.bestStreak > s.streak ? s.bestStreak : s.streak,
    );
  }
  return s.copyWith(
    streakBeforeBreak: effectiveStreak(s, dayKey),
    brokenDay: () => dayKey,
    streak: 0,
  );
}

enum JokerCase { missedYesterday, brokenRecently }

JokerCase? jokerCase(StreakState state, String today) {
  final s = grantMonthlyJoker(state, today);
  if (s.jokers <= 0) return null;
  final yesterday = addDays(today, -1);
  if (s.lastOnTimeDay == addDays(today, -2) &&
      s.streak > 0 &&
      s.brokenDay != yesterday) {
    return JokerCase.missedYesterday;
  }
  if ((s.brokenDay == today || s.brokenDay == yesterday) &&
      s.streakBeforeBreak > 0) {
    return JokerCase.brokenRecently;
  }
  return null;
}

StreakState useJoker(StreakState state, String today) {
  final s = grantMonthlyJoker(state, today);
  switch (jokerCase(s, today)) {
    case JokerCase.missedYesterday:
      final day = addDays(today, -1);
      return s.copyWith(
        jokers: s.jokers - 1,
        lastOnTimeDay: () => day,
        savedDays: [...s.savedDays, day],
      );
    case JokerCase.brokenRecently:
      final day = s.brokenDay!;
      final playedTodayOnTime = s.lastOnTimeDay == today && day != today;
      final streak = playedTodayOnTime
          ? s.streakBeforeBreak + s.streak
          : s.streakBeforeBreak;
      return s.copyWith(
        jokers: s.jokers - 1,
        streak: streak,
        bestStreak: s.bestStreak > streak ? s.bestStreak : streak,
        lastOnTimeDay: () => playedTodayOnTime ? today : day,
        savedDays: [...s.savedDays, day],
        streakBeforeBreak: 0,
        brokenDay: () => null,
      );
    case null:
      throw StateError('no joker case');
  }
}
