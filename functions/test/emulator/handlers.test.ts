import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { afterAll, beforeEach, describe, expect, it } from "vitest";

import { gameById } from "../../src/core/catalog.js";
import { dayKeyFor } from "../../src/core/time.js";
import * as h from "../../src/handlers.js";

const app = getApps()[0] ?? initializeApp({ projectId: "demo-onegame" });
const db = getFirestore(app);

async function clear() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-onegame/databases/(default)/documents`, { method: "DELETE" });
}

afterAll(() => deleteApp(app));

describe("daily flow on the emulator", () => {
  beforeEach(clear);

  it("createDaily → getToday hides then reveals → startAttempt once → submitScore", async () => {
    const now0 = Date.UTC(2026, 10, 24, 6, 0); // 07:00 in Paris
    const dayKey = dayKeyFor(now0, "europe");
    const { daily, created } = await h.createDailyFor(db, dayKey, {}, 1234);
    expect(created).toBe(true);
    expect((await h.createDailyFor(db, dayKey)).created).toBe(false);
    await h.ensureProfile(db, "alice", { region: "europe", lang: "fr", country: "fr" }, now0);

    const waiting = await h.getToday(db, "alice", now0);
    expect(waiting.state).toBe("waiting");
    expect(JSON.stringify(waiting)).not.toContain(daily.gameId);
    await expect(h.startAttempt(db, "alice", now0)).rejects.toThrow("alarm-not-rung");

    const alert = daily.alertAt.europe;
    const open = await h.getToday(db, "alice", alert + 5_000);
    expect(open.state).toBe("open");

    const start = await h.startAttempt(db, "alice", alert + 30_000);
    expect(start.onTime).toBe(true);
    expect(start.seed).toBe(daily.seed);
    await expect(h.startAttempt(db, "alice", alert + 31_000)).rejects.toThrow("attempt-exists");

    const game = gameById(daily.gameId)!;
    const res = await h.submitScore(db, "alice", {
      score: game.scoreMin, playedMs: 40_000, inputLog: [[1, 0, 1, 10, 10]], stats: {}, highlights: [], partial: false,
    }, alert + 80_000);
    expect(res).toMatchObject({ accepted: true, streak: 1, newBadges: expect.arrayContaining(["first_day"]) });
    await expect(h.submitScore(db, "alice", { score: 1, playedMs: 1, inputLog: [] }, alert + 81_000))
      .rejects.toThrow("already-finished");

    const entry = (await db.doc(`scores/${dayKey}/entries/alice`).get()).data();
    expect(entry).toMatchObject({ uid: "alice", onTime: true, region: "europe", country: "FR" });
    const played = await h.getToday(db, "alice", alert + 90_000);
    expect(played.state === "open" && played.attempt?.status).toBe("finished");
    expect(played.profile.streak).toBe(1);
  });

  it("late start breaks the streak and stays out of the weekly board; lost attempt = partial score", async () => {
    const now0 = Date.UTC(2026, 10, 24, 6, 0);
    const dayKey = dayKeyFor(now0, "europe");
    const { daily } = await h.createDailyFor(db, dayKey, {}, 99);
    await h.ensureProfile(db, "bob", { region: "europe", lang: "en", country: "BE" }, now0);
    const alert = daily.alertAt.europe;
    const start = await h.startAttempt(db, "bob", alert + 10 * 60_000);
    expect(start.onTime).toBe(false);
    await h.submitScore(db, "bob", { score: 0, playedMs: 1000, inputLog: [], stats: {}, highlights: [], partial: true }, alert + 10 * 60_000 + 3000);
    const game = gameById(daily.gameId)!;
    const later = alert + 10 * 60_000 + game.maxDurationMs + 60_000;
    const t = await h.getToday(db, "bob", later);
    expect(t.state === "open" && t.attempt?.status).toBe("lost");
    expect((await db.doc(`scores/${dayKey}/entries/bob`).get()).get("onTime")).toBe(false);
  });

  it("region can change once per 30 days; account deletion wipes data", async () => {
    const now = Date.UTC(2026, 10, 24);
    await h.ensureProfile(db, "carol", { region: "asia", lang: "fr", country: null }, now);
    await h.setRegion(db, "carol", "west", now);
    await expect(h.setRegion(db, "carol", "europe", now + 86_400_000)).rejects.toThrow("region-cooldown");
    await h.setRegion(db, "carol", "europe", now + 31 * 86_400_000);
    await db.doc("scores/2026-11-24/entries/carol").set({ uid: "carol", score: 1 });
    await h.deleteUserData(db, "carol");
    expect((await db.doc("users/carol").get()).exists).toBe(false);
    expect((await db.doc("scores/2026-11-24/entries/carol").get()).exists).toBe(false);
  });
});
