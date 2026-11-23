import { CATALOG, type GameInfo, gameById } from "./catalog.js";
import { SeededRandom, fnv1a32 } from "./seededRandom.js";
import { REGION_IDS, REGIONS, type Region, addDays, dayOfWeek, parseDayKey, zonedToUtc } from "./time.js";

export interface DailyChallenge {
  dayKey: string;
  gameId: string;
  seed: number;
  modifierId: string | null;
  /** UTC ms of the alarm per region. */
  alertAt: Record<Region, number>;
  gameVersion: number;
}

export interface HistoryEntry {
  dayKey: string;
  gameId: string;
}

export const ALERT_START_HOUR = 10;
export const ALERT_END_HOUR = 21;
export const MODIFIER_CHANCE = 1 / 3;

/**
 * Picks the game of [dayKey] (section 4.3), given the previous days
 * ([history], oldest first). Rules, from strongest to weakest:
 * 1. Sunday is reserved for the Sport category;
 * 2. never the same game two days in a row;
 * 3. a game does not come back before 7 days;
 * 4. never the same category three days in a row;
 * 5. look-ahead: on Saturday, avoid Sport if Friday was Sport (so that
 *    Sunday never breaks rule 4).
 * When a small catalog makes the rules impossible, the weakest rules are
 * relaxed first (5, then 3 becomes "least recently played", then 4).
 * Weights come from Remote Config (`gameWeights`, default 1, 0 = disabled).
 */
export function pickGame(
  dayKey: string,
  history: readonly HistoryEntry[],
  rng: SeededRandom,
  weights: Readonly<Record<string, number>> = {},
  catalog: readonly GameInfo[] = CATALOG,
): string {
  const enabled = catalog.filter((g) => (weights[g.id] ?? 1) > 0);
  const dow = dayOfWeek(dayKey);
  const recent = (n: number) => new Set(history.slice(-n).map((h) => h.gameId));
  const catOf = (id: string) => gameById(id)?.category ?? catalog.find((g) => g.id === id)?.category;
  const last = history.at(-1);
  const last2 = history.slice(-2);
  const twoSameCat = last2.length === 2 && catOf(last2[0].gameId) === catOf(last2[1].gameId)
    ? catOf(last2[1].gameId)
    : undefined;

  const hard = (g: GameInfo) => (dow !== 0 || g.category === "sport") && g.id !== last?.gameId;
  const rule3 = (g: GameInfo) => !recent(6).has(g.id);
  const rule4 = (g: GameInfo) => g.category !== twoSameCat;
  const rule5 = (g: GameInfo) => !(dow === 6 && last && catOf(last.gameId) === "sport" && g.category === "sport");

  const attempts: ((g: GameInfo) => boolean)[] = [
    (g) => hard(g) && rule3(g) && rule4(g) && rule5(g),
    (g) => hard(g) && rule3(g) && rule4(g),
    (g) => hard(g) && rule4(g),
    (g) => hard(g),
    (g) => dow !== 0 || g.category === "sport",
    () => true,
  ];
  for (let i = 0; i < attempts.length; i++) {
    let pool = enabled.filter(attempts[i]);
    if (pool.length === 0) continue;
    if (i >= 2) {
      // Rule 3 relaxed: keep only the least recently played candidates.
      const lastSeen = (id: string) => {
        for (let k = history.length - 1; k >= 0; k--) if (history[k].gameId === id) return k;
        return -1;
      };
      const oldest = Math.min(...pool.map((g) => lastSeen(g.id)));
      pool = pool.filter((g) => lastSeen(g.id) === oldest);
    }
    return weightedPick(pool, weights, rng).id;
  }
  throw new Error("empty catalog");
}

function weightedPick(pool: GameInfo[], weights: Readonly<Record<string, number>>, rng: SeededRandom): GameInfo {
  const sorted = [...pool].sort((a, b) => a.id.localeCompare(b.id));
  const total = sorted.reduce((s, g) => s + (weights[g.id] ?? 1), 0);
  let x = rng.nextDouble() * total;
  for (const g of sorted) {
    x -= weights[g.id] ?? 1;
    if (x < 0) return g;
  }
  return sorted[sorted.length - 1];
}

/** Uniform alarm instant between 10:00 and 21:00 local time of [region]. */
export function alertTime(dayKey: string, region: Region, rng: SeededRandom): number {
  const [y, m, d] = parseDayKey(dayKey);
  const span = (ALERT_END_HOUR - ALERT_START_HOUR) * 3600;
  const s = rng.nextInt(span);
  const h = ALERT_START_HOUR + Math.floor(s / 3600);
  return zonedToUtc(y, m, d, h, Math.floor((s % 3600) / 60), s % 60, REGIONS[region]);
}

/**
 * Builds the challenge of [dayKey] from a master seed. The server draws the
 * master seed with crypto randomness (unpredictable); local/demo mode
 * derives it from the day key.
 */
export function generateDaily(
  dayKey: string,
  history: readonly HistoryEntry[],
  masterSeed: number,
  weights: Readonly<Record<string, number>> = {},
  override?: { gameId: string; modifierId?: string | null },
  catalog: readonly GameInfo[] = CATALOG,
): DailyChallenge {
  const gameId = override?.gameId ?? pickGame(dayKey, history, SeededRandom.derive(masterSeed, "pick"), weights, catalog);
  const game = catalog.find((g) => g.id === gameId);
  if (!game) throw new Error(`unknown game ${gameId}`);
  const mr = SeededRandom.derive(masterSeed, "modifier");
  let modifierId: string | null = null;
  if (override && override.modifierId !== undefined) {
    modifierId = override.modifierId;
  } else if (mr.chance(MODIFIER_CHANCE) && game.modifiers.length > 0) {
    modifierId = mr.pick(game.modifiers);
  }
  const alertAt = {} as Record<Region, number>;
  for (const r of REGION_IDS) alertAt[r] = alertTime(dayKey, r, SeededRandom.derive(masterSeed, `alert:${r}`));
  return {
    dayKey,
    gameId,
    seed: SeededRandom.derive(masterSeed, "seed").nextUint32(),
    modifierId,
    alertAt,
    gameVersion: game.rulesVersion,
  };
}

/** Local / demo mode: master seed derived from the day key (predictable). */
export function localMasterSeed(dayKey: string): number {
  return fnv1a32(`onegame:local:${dayKey}`);
}

/** Simulates the local schedule from [epoch] up to [dayKey] (inclusive). */
export function localSchedule(epoch: string, dayKey: string, weights: Readonly<Record<string, number>> = {}, catalog: readonly GameInfo[] = CATALOG): DailyChallenge[] {
  const out: DailyChallenge[] = [];
  const history: HistoryEntry[] = [];
  for (let k = epoch; k <= dayKey; k = addDays(k, 1)) {
    const d = generateDaily(k, history.slice(-14), localMasterSeed(k), weights, undefined, catalog);
    out.push(d);
    history.push({ dayKey: k, gameId: d.gameId });
  }
  return out;
}
