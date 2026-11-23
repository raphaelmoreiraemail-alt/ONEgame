import { describe, expect, it } from "vitest";
import { newBadges } from "../src/core/badges.js";
import { generateDaily } from "../src/core/daily.js";
import { EMPTY_STREAK, effectiveStreak, jokerCase, recordPlay, useJoker } from "../src/core/streak.js";
import { type Attempt, finalizeLost, isLost, todayFor } from "../src/core/today.js";
import { checkInputLog, validateSubmission } from "../src/core/validate.js";
import { gameById } from "../src/core/catalog.js";

const daily = generateDaily("2026-11-24", [], 7);
const alert = daily.alertAt.europe;
const attempt: Attempt = {
  uid: "u", dayKey: daily.dayKey, gameId: daily.gameId, region: "europe",
  startedAt: alert + 30_000, onTime: true, status: "started",
};

describe("todayFor", () => {
  it("hides game, seed and alarm time before the alarm", () => {
    const t = todayFor(alert - 1, "europe", daily, null);
    expect(t).toEqual({ state: "waiting", dayKey: daily.dayKey, serverNow: alert - 1 });
    expect(JSON.stringify(t)).not.toContain(String(daily.seed));
  });
  it("reveals everything after the alarm", () => {
    const t = todayFor(alert, "europe", daily, null);
    expect(t.state).toBe("open");
    if (t.state === "open") {
      expect(t.gameId).toBe(daily.gameId);
      expect(t.alertAt).toBe(alert);
      expect(t.attempt).toBeNull();
    }
  });
  it("lost attempts keep the last partial score", () => {
    const max = gameById(daily.gameId)!.maxDurationMs;
    expect(isLost(attempt, attempt.startedAt + max, max)).toBe(false);
    expect(isLost(attempt, attempt.startedAt + max + 20_000, max)).toBe(true);
    expect(finalizeLost({ ...attempt, partialScore: 340 }, 1).score).toBe(340);
    expect(finalizeLost(attempt, 1).score).toBe(0);
  });
});

describe("validateSubmission", () => {
  const game = gameById(daily.gameId)!;
  const ok = { score: 100, playedMs: 60_000, inputLog: [[10, 0, 1, 100, 100], [20, 2, 1, 100, 200]], stats: {}, highlights: [], partial: false };
  it("accepts a plausible result", () => {
    expect(validateSubmission(attempt, game, ok, attempt.startedAt + 65_000)).toEqual({ ok: true });
  });
  it("rejects out-of-bounds, late, finished, inhuman", () => {
    expect(validateSubmission(attempt, game, { ...ok, score: game.scoreMax + 1 }, attempt.startedAt + 65_000)).toMatchObject({ ok: false, reason: "score-out-of-bounds" });
    expect(validateSubmission(attempt, game, ok, attempt.startedAt + 200_000)).toMatchObject({ reason: "too-late" });
    expect(validateSubmission({ ...attempt, status: "finished" }, game, ok, attempt.startedAt + 1)).toMatchObject({ reason: "already-finished" });
    expect(validateSubmission(null, game, ok, 0)).toMatchObject({ reason: "no-attempt" });
    expect(validateSubmission(attempt, game, { ...ok, playedMs: 90_000 }, attempt.startedAt + 30_000)).toMatchObject({ reason: "duration-exceeds-wall-clock" });
    const spam = Array.from({ length: 40 }, (_, i) => [i * 2, 0, i, 10, 10]);
    expect(checkInputLog(spam, 2000)).toMatchObject({ reason: "inhuman-input-rate" });
    expect(checkInputLog([[50, 0, 1, 0, 0], [10, 0, 1, 0, 0]], 2000)).toMatchObject({ reason: "input-log-order" });
  });
});

describe("streak & joker", () => {
  it("counts consecutive on-time days and resets when late", () => {
    let s = recordPlay(EMPTY_STREAK, "2026-11-01", true);
    s = recordPlay(s, "2026-11-02", true);
    s = recordPlay(s, "2026-11-03", true);
    expect(s.streak).toBe(3);
    expect(s.jokers).toBe(1);
    expect(effectiveStreak(s, "2026-11-04")).toBe(3);
    expect(effectiveStreak(s, "2026-11-05")).toBe(0);
    const late = recordPlay(s, "2026-11-04", false);
    expect(late.streak).toBe(0);
    expect(late.bestStreak).toBe(3);
  });

  it("a joker saves a missed day within 24 h", () => {
    let s = recordPlay(EMPTY_STREAK, "2026-11-01", true);
    s = recordPlay(s, "2026-11-02", true); // streak 2, missed 11-03
    expect(jokerCase(s, "2026-11-04")).toBe("missed-yesterday");
    expect(jokerCase(s, "2026-11-05")).toBeNull(); // more than 24 h
    s = useJoker(s, "2026-11-04");
    expect(s.jokers).toBe(0);
    expect(s.savedDays).toEqual(["2026-11-03"]);
    s = recordPlay(s, "2026-11-04", true);
    expect(s.streak).toBe(3);
    expect(jokerCase(s, "2026-11-06")).toBeNull(); // no joker left
  });

  it("a joker restores a streak broken by a late game", () => {
    let s = recordPlay(EMPTY_STREAK, "2026-11-10", true);
    s = recordPlay(s, "2026-11-11", true);
    s = recordPlay(s, "2026-11-12", false); // late
    expect(s.streak).toBe(0);
    expect(jokerCase(s, "2026-11-12")).toBe("broken-recently");
    s = useJoker(s, "2026-11-12");
    expect(s.streak).toBe(2);
    s = recordPlay(s, "2026-11-13", true);
    expect(s.streak).toBe(3);
  });

  it("one joker per month, granted on the 1st, not cumulative", () => {
    let s = recordPlay(EMPTY_STREAK, "2026-11-30", true);
    expect(s.jokers).toBe(1);
    s = { ...s, jokers: 1 };
    s = recordPlay(s, "2026-12-01", true);
    expect(s.jokers).toBe(1);
    expect(s.jokerMonth).toBe("2026-12");
  });
});

describe("badges", () => {
  it("awards badges once", () => {
    const ctx = { streak: 7, highlights: ["ace", "oneEighty"], startDelayMs: 5000, onTime: true, gamesPlayed: ["minigolf"], catalogSize: 7 };
    expect(newBadges([], ctx)).toEqual(["first_day", "week", "ace", "one_eighty", "early_bird"]);
    expect(newBadges(["first_day", "week", "ace", "one_eighty", "early_bird"], ctx)).toEqual([]);
    expect(newBadges([], { ...ctx, streak: 30 })).toContain("month");
  });
});
