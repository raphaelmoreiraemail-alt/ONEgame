import { describe, expect, it } from "vitest";
import { CATALOG, type Category, type GameInfo } from "../src/core/catalog.js";
import { type HistoryEntry, generateDaily, localSchedule, pickGame } from "../src/core/daily.js";
import { SeededRandom } from "../src/core/seededRandom.js";
import { REGIONS, REGION_IDS, addDays, dayKeyIn, dayOfWeek, tzOffsetMs } from "../src/core/time.js";

/** The full 24-game catalog of the spec (section 7). */
const FULL: GameInfo[] = (
  [
    ["minigolf", "sport"], ["penalty", "sport"], ["freekick", "sport"], ["basket", "sport"],
    ["bowling", "sport"], ["petanque", "sport"], ["tennis", "sport"], ["airhockey", "sport"],
    ["curling", "sport"], ["archery", "sport"], ["ski", "sport"], ["billard", "sport"],
    ["darts", "adresse"], ["stack", "adresse"], ["fishing", "adresse"], ["parking", "adresse"],
    ["survival", "arcade"], ["flappy", "arcade"], ["runner", "arcade"], ["snake", "arcade"],
    ["racing", "arcade"], ["motflash", "reflexion"], ["memory", "reflexion"], ["calcul", "reflexion"],
  ] as [string, Category][]
).map(([id, category]) => ({ id, category, rulesVersion: 1, maxDurationMs: 120000, modifiers: [], scoreMin: 0, scoreMax: 1, name: { fr: id, en: id } }));

function simulate(catalog: GameInfo[], days: number, start = "2026-01-01", weights = {}) {
  const history: HistoryEntry[] = [];
  let k = start;
  for (let i = 0; i < days; i++, k = addDays(k, 1)) {
    const id = pickGame(k, history, new SeededRandom(i * 2654435761), weights, catalog);
    history.push({ dayKey: k, gameId: id });
  }
  return history;
}

function checkAll(history: HistoryEntry[], catalog: GameInfo[]) {
  const cat = (id: string) => catalog.find((g) => g.id === id)!.category;
  for (let i = 0; i < history.length; i++) {
    const h = history[i];
    if (dayOfWeek(h.dayKey) === 0) expect(cat(h.gameId), `sunday ${h.dayKey}`).toBe("sport");
    if (i >= 1) expect(h.gameId, `repeat ${h.dayKey}`).not.toBe(history[i - 1].gameId);
    for (let k = 1; k <= 6 && i - k >= 0; k++) {
      expect(h.gameId, `7-day rule ${h.dayKey}`).not.toBe(history[i - k].gameId);
    }
    if (i >= 2) {
      const three = new Set([cat(history[i - 2].gameId), cat(history[i - 1].gameId), cat(h.gameId)]);
      expect(three.size > 1, `category x3 ${h.dayKey}`).toBe(true);
    }
  }
}

describe("pickGame", () => {
  it("respects every rule of 4.3 over 365 simulated days (full catalog)", () => {
    for (const start of ["2026-01-01", "2027-06-15"]) checkAll(simulate(FULL, 365, start), FULL);
  });

  it("weights push a game and 0 disables it", () => {
    const h = simulate(FULL, 365, "2026-01-01", { snake: 0, memory: 20 });
    expect(h.some((e) => e.gameId === "snake")).toBe(false);
    const memory = h.filter((e) => e.gameId === "memory").length;
    expect(memory).toBeGreaterThan(365 / 24);
  });

  it("keeps the hard rules with the current (small) catalog", () => {
    const h = simulate([...CATALOG], 365);
    const cat = (id: string) => CATALOG.find((g) => g.id === id)!.category;
    for (let i = 0; i < h.length; i++) {
      if (dayOfWeek(h[i].dayKey) === 0) expect(cat(h[i].gameId)).toBe("sport");
      if (i > 0) expect(h[i].gameId).not.toBe(h[i - 1].gameId);
    }
  });
});

describe("generateDaily", () => {
  it("alarm between 10:00 and 21:00 local time, per region", () => {
    for (let i = 0; i < 200; i++) {
      const day = addDays("2026-01-01", i);
      const d = generateDaily(day, [], 1000 + i, {}, undefined, FULL);
      for (const r of REGION_IDS) {
        const t = d.alertAt[r];
        expect(dayKeyIn(t, REGIONS[r])).toBe(day);
        const local = new Date(t + tzOffsetMs(t, REGIONS[r]));
        const h = local.getUTCHours() + local.getUTCMinutes() / 60;
        expect(h).toBeGreaterThanOrEqual(10);
        expect(h).toBeLessThan(21);
      }
    }
  });

  it("is deterministic from the master seed, honours overrides", () => {
    const a = generateDaily("2026-11-24", [], 42);
    expect(generateDaily("2026-11-24", [], 42)).toEqual(a);
    expect(generateDaily("2026-11-24", [], 43).seed).not.toBe(a.seed);
    const o = generateDaily("2026-11-24", [], 42, {}, { gameId: "penalty", modifierId: "giant" });
    expect(o.gameId).toBe("penalty");
    expect(o.modifierId).toBe("giant");
  });

  it("about one day in three has a modifier, always supported by the game", () => {
    const days = localSchedule("2026-01-01", "2026-12-31");
    const withMod = days.filter((d) => d.modifierId !== null);
    for (const d of withMod) {
      expect(CATALOG.find((g) => g.id === d.gameId)!.modifiers).toContain(d.modifierId);
    }
    expect(withMod.length).toBeGreaterThan(70);
    expect(withMod.length).toBeLessThan(160);
  });
});
