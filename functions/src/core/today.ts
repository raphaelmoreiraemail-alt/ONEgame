import type { DailyChallenge } from "./daily.js";
import type { Region } from "./time.js";

/** Window after the alarm to start "on time" (section 4.5). */
export const ON_TIME_WINDOW_MS = 120_000;
/** Allowance for the 3-2-1-GO intro between startAttempt and the game. */
export const INTRO_ALLOWANCE_MS = 5_000;
/** Grace period on top of the game's max duration (section 10.2). */
export const SUBMIT_GRACE_MS = 10_000;

export type AttemptStatus = "started" | "finished" | "lost";

export interface Attempt {
  uid: string;
  dayKey: string;
  gameId: string;
  region: Region;
  startedAt: number;
  finishedAt?: number;
  onTime: boolean;
  status: AttemptStatus;
  score?: number;
  partialScore?: number;
  stats?: Record<string, number>;
  highlights?: string[];
}

export type TodayResponse =
  | { state: "unavailable"; serverNow: number }
  | { state: "waiting"; dayKey: string; serverNow: number }
  | {
      state: "open";
      dayKey: string;
      serverNow: number;
      gameId: string;
      seed: number;
      modifierId: string | null;
      alertAt: number;
      gameVersion: number;
      attempt: Pick<Attempt, "startedAt" | "onTime" | "status" | "score" | "finishedAt"> | null;
    };

/**
 * What the client may know right now. The alarm time, game and seed are
 * only revealed once the alarm has rung (section 4.2).
 */
export function todayFor(
  now: number,
  region: Region,
  daily: DailyChallenge | null,
  attempt: Attempt | null,
): TodayResponse {
  if (!daily) return { state: "unavailable", serverNow: now };
  const alertAt = daily.alertAt[region];
  if (now < alertAt) return { state: "waiting", dayKey: daily.dayKey, serverNow: now };
  return {
    state: "open",
    dayKey: daily.dayKey,
    serverNow: now,
    gameId: daily.gameId,
    seed: daily.seed,
    modifierId: daily.modifierId,
    alertAt,
    gameVersion: daily.gameVersion,
    attempt: attempt
      ? {
          startedAt: attempt.startedAt,
          onTime: attempt.onTime,
          status: attempt.status,
          score: attempt.score,
          finishedAt: attempt.finishedAt,
        }
      : null,
  };
}

/** An attempt that was started but never submitted in time is lost. */
export function isLost(attempt: Attempt, now: number, maxDurationMs: number): boolean {
  return attempt.status === "started" &&
    now > attempt.startedAt + INTRO_ALLOWANCE_MS + maxDurationMs + SUBMIT_GRACE_MS;
}

/** Finalises a lost attempt: score = last partial score sent, else 0. */
export function finalizeLost(attempt: Attempt, now: number): Attempt {
  return { ...attempt, status: "lost", finishedAt: now, score: attempt.partialScore ?? 0 };
}
