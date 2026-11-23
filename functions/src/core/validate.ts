import type { GameInfo } from "./catalog.js";
import { type Attempt, INTRO_ALLOWANCE_MS, SUBMIT_GRACE_MS } from "./today.js";

export interface Submission {
  score: number;
  playedMs: number;
  /** Compact input log: [step, phase(0 down,1 move,2 up), pointer, x*10, y*10]. */
  inputLog: number[][];
  stats: Record<string, number>;
  highlights: string[];
  partial: boolean;
}

export type Verdict = { ok: true } | { ok: false; reason: string };

const STEPS_PER_SECOND = 120;
const MAX_TAPS_PER_SECOND = 25;
const MAX_INPUTS = 20_000;

/** Anti-cheat checks of section 10.2 / 10.3. */
export function validateSubmission(
  attempt: Attempt | null,
  game: GameInfo | undefined,
  sub: Submission,
  now: number,
): Verdict {
  if (!attempt) return { ok: false, reason: "no-attempt" };
  if (attempt.status !== "started") return { ok: false, reason: "already-finished" };
  if (!game || game.id !== attempt.gameId) return { ok: false, reason: "wrong-game" };
  if (!Number.isInteger(sub.score)) return { ok: false, reason: "score-not-integer" };
  if (sub.score < game.scoreMin || sub.score > game.scoreMax) return { ok: false, reason: "score-out-of-bounds" };
  if (now - attempt.startedAt > INTRO_ALLOWANCE_MS + game.maxDurationMs + SUBMIT_GRACE_MS) {
    return { ok: false, reason: "too-late" };
  }
  if (!(sub.playedMs >= 0) || sub.playedMs > game.maxDurationMs + 1000) {
    return { ok: false, reason: "bad-duration" };
  }
  if (sub.playedMs > now - attempt.startedAt + 1000) return { ok: false, reason: "duration-exceeds-wall-clock" };
  return checkInputLog(sub.inputLog, sub.playedMs);
}

export function checkInputLog(log: number[][], playedMs: number): Verdict {
  if (!Array.isArray(log) || log.length > MAX_INPUTS) return { ok: false, reason: "input-log-size" };
  const maxStep = Math.ceil((playedMs / 1000) * STEPS_PER_SECOND) + 1;
  let prevStep = 0;
  const downs: number[] = [];
  for (const e of log) {
    if (!Array.isArray(e) || e.length !== 5 || e.some((v) => !Number.isInteger(v))) {
      return { ok: false, reason: "input-log-format" };
    }
    const [step, phase] = e;
    if (step < prevStep || step > maxStep) return { ok: false, reason: "input-log-order" };
    if (phase < 0 || phase > 2) return { ok: false, reason: "input-log-phase" };
    prevStep = step;
    if (phase === 0) downs.push(step);
  }
  // No more than MAX_TAPS_PER_SECOND touches in any one-second window.
  let lo = 0;
  for (let hi = 0; hi < downs.length; hi++) {
    while (downs[hi] - downs[lo] >= STEPS_PER_SECOND) lo++;
    if (hi - lo + 1 > MAX_TAPS_PER_SECOND) return { ok: false, reason: "inhuman-input-rate" };
  }
  return { ok: true };
}
