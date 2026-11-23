import { addDays, monthOf } from "./time.js";

/** Streak and joker fields of `users/{uid}` (section 4.5). */
export interface StreakState {
  streak: number;
  bestStreak: number;
  lastOnTimeDay: string | null;
  jokers: number;
  jokerMonth: string | null;
  /** Streak value before the last break, restorable with a joker. */
  streakBeforeBreak: number;
  /** Day that broke the streak (missed or late). */
  brokenDay: string | null;
  /** Days saved with a joker (shown on the calendar). */
  savedDays: string[];
}

export const EMPTY_STREAK: StreakState = {
  streak: 0,
  bestStreak: 0,
  lastOnTimeDay: null,
  jokers: 0,
  jokerMonth: null,
  streakBeforeBreak: 0,
  brokenDay: null,
  savedDays: [],
};

/** One joker per month, granted automatically on the 1st (not cumulative). */
export function grantMonthlyJoker(s: StreakState, today: string): StreakState {
  const month = monthOf(today);
  return s.jokerMonth === month ? s : { ...s, jokers: 1, jokerMonth: month };
}

/** Streak to display today: alive only if the last on-time day is today or yesterday. */
export function effectiveStreak(s: StreakState, today: string): number {
  if (s.lastOnTimeDay === today || s.lastOnTimeDay === addDays(today, -1)) return s.streak;
  return 0;
}

/** Applies today's official result. */
export function recordPlay(state: StreakState, dayKey: string, onTime: boolean): StreakState {
  let s = grantMonthlyJoker(state, dayKey);
  if (onTime) {
    if (s.lastOnTimeDay === dayKey) return s;
    if (s.lastOnTimeDay === addDays(dayKey, -1)) {
      s = { ...s, streak: s.streak + 1 };
    } else {
      s = {
        ...s,
        streakBeforeBreak: s.lastOnTimeDay ? s.streak : 0,
        brokenDay: s.lastOnTimeDay ? addDays(dayKey, -1) : null,
        streak: 1,
      };
    }
    return { ...s, lastOnTimeDay: dayKey, bestStreak: Math.max(s.bestStreak, s.streak) };
  }
  // Late: the streak goes back to 0 (restorable with a joker within 24 h).
  return { ...s, streakBeforeBreak: effectiveStreak(s, dayKey), brokenDay: dayKey, streak: 0 };
}

export type JokerCase = "missed-yesterday" | "broken-recently" | null;

/** Whether a joker can save the streak today ("dans les 24 h"). */
export function jokerCase(state: StreakState, today: string): JokerCase {
  const s = grantMonthlyJoker(state, today);
  if (s.jokers <= 0) return null;
  const yesterday = addDays(today, -1);
  if (s.lastOnTimeDay === addDays(today, -2) && s.streak > 0 && s.brokenDay !== yesterday) {
    return "missed-yesterday";
  }
  if ((s.brokenDay === today || s.brokenDay === yesterday) && s.streakBeforeBreak > 0) {
    return "broken-recently";
  }
  return null;
}

export function useJoker(state: StreakState, today: string): StreakState {
  const s = grantMonthlyJoker(state, today);
  switch (jokerCase(s, today)) {
    case "missed-yesterday": {
      const day = addDays(today, -1);
      return { ...s, jokers: s.jokers - 1, lastOnTimeDay: day, savedDays: [...s.savedDays, day] };
    }
    case "broken-recently": {
      const day = s.brokenDay!;
      // If today was already played on time after the break, keep counting.
      const playedTodayOnTime = s.lastOnTimeDay === today && day !== today;
      const streak = playedTodayOnTime ? s.streakBeforeBreak + s.streak : s.streakBeforeBreak;
      return {
        ...s,
        jokers: s.jokers - 1,
        streak,
        bestStreak: Math.max(s.bestStreak, streak),
        lastOnTimeDay: playedTodayOnTime ? today : day,
        savedDays: [...s.savedDays, day],
        streakBeforeBreak: 0,
        brokenDay: null,
      };
    }
    default:
      throw new Error("no joker case");
  }
}
