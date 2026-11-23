// Regenerates shared/daily_vectors.json: the local schedule and streak
// scenarios that the Dart port must reproduce exactly.
import { writeFileSync } from "node:fs";
import { localSchedule } from "../src/core/daily.js";
import { EMPTY_STREAK, jokerCase, recordPlay, useJoker, type StreakState } from "../src/core/streak.js";

const schedule = localSchedule("2026-11-01", "2027-02-28").map((d) => ({
  dayKey: d.dayKey, gameId: d.gameId, seed: d.seed, modifierId: d.modifierId, alertAt: d.alertAt,
}));

type Op = ["play", string, boolean] | ["joker", string];
const scenarios: Op[][] = [
  [["play", "2026-11-01", true], ["play", "2026-11-02", true], ["play", "2026-11-04", true]],
  [["play", "2026-11-01", true], ["play", "2026-11-02", true], ["joker", "2026-11-04"], ["play", "2026-11-04", true]],
  [["play", "2026-11-10", true], ["play", "2026-11-11", true], ["play", "2026-11-12", false], ["joker", "2026-11-12"], ["play", "2026-11-13", true]],
  [["play", "2026-11-29", true], ["play", "2026-11-30", true], ["play", "2026-12-01", false], ["play", "2026-12-02", true], ["joker", "2026-12-02"]],
];
const streaks = scenarios.map((ops) => {
  let s: StreakState = EMPTY_STREAK;
  const states: unknown[] = [];
  for (const op of ops) {
    if (op[0] === "play") s = recordPlay(s, op[1], op[2]);
    else s = jokerCase(s, op[1]) ? useJoker(s, op[1]) : s;
    states.push({ ...s });
  }
  return { ops, states };
});

writeFileSync(new URL("../../shared/daily_vectors.json", import.meta.url), JSON.stringify({ schedule, streaks }, null, 1) + "\n");
console.log(`wrote ${schedule.length} days, ${streaks.length} streak scenarios`);
