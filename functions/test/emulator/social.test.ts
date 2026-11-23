import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { afterAll, beforeEach, describe, expect, it } from "vitest";

import { gameById } from "../../src/core/catalog.js";
import { dayKeyFor } from "../../src/core/time.js";
import * as h from "../../src/handlers.js";
import * as s from "../../src/socialHandlers.js";

const app = getApps()[0] ?? initializeApp({ projectId: "demo-onegame" });
const db = getFirestore(app);

async function clear() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-onegame/databases/(default)/documents`, { method: "DELETE" });
}

afterAll(() => deleteApp(app));

const T0 = Date.UTC(2026, 10, 24, 6, 0);

async function player(uid: string, pseudo: string, country = "FR") {
  await h.ensureProfile(db, uid, { region: "europe", lang: "fr", country }, T0);
  await s.claimPseudo(db, uid, pseudo);
}

async function play(uid: string, score: number, delayMs: number, alert: number, max: number) {
  await h.startAttempt(db, uid, alert + delayMs);
  await h.submitScore(db, uid, { score, playedMs: 30_000, inputLog: [], stats: {}, highlights: [], partial: false }, alert + delayMs + 40_000);
  void max;
}

describe("social on the emulator", () => {
  beforeEach(clear);

  it("pseudos are unique, filtered, and can be changed", async () => {
    await h.ensureProfile(db, "a", { region: "europe", lang: "fr", country: "FR" }, T0);
    await h.ensureProfile(db, "b", { region: "europe", lang: "fr", country: "FR" }, T0);
    await s.claimPseudo(db, "a", "Raph");
    await expect(s.claimPseudo(db, "b", "raph")).rejects.toThrow("pseudo-taken");
    await expect(s.claimPseudo(db, "b", "c0nnard")).rejects.toThrow("pseudo-offensive");
    await s.claimPseudo(db, "a", "Raphael");
    await s.claimPseudo(db, "b", "raph"); // freed
  });

  it("friend requests, invites, leaderboards, feed and reactions", async () => {
    const dayKey = dayKeyFor(T0, "europe");
    const { daily } = await h.createDailyFor(db, dayKey, {}, 77);
    const alert = daily.alertAt.europe;
    const game = gameById(daily.gameId)!;
    const top = Math.min(game.scoreMax, 1000);
    await player("ann", "Ann");
    await player("bob", "Bob", "BE");
    await player("cid", "Cid");
    await player("dee", "Dee");

    // ann ↔ bob via request, ann ↔ cid via invite link.
    expect(await s.sendFriendRequest(db, "ann", { pseudo: "bob" }, T0)).toEqual({ status: "pending" });
    expect((await s.listFriends(db, "bob")).friends).toEqual([{ uid: "ann", status: "pending", incoming: true, pseudo: "Ann" }]);
    await s.respondFriendRequest(db, "bob", { uid: "ann", accept: true }, T0);
    const { code } = await s.createInvite(db, "ann", T0);
    expect((await s.acceptInvite(db, "cid", { code }, T0)).pseudo).toBe("Ann");

    // Feed is locked before playing.
    expect((await s.feed(db, "ann", {}, alert + 1000)).locked).toBe(true);

    await play("ann", Math.round(top * 0.5), 10_000, alert, game.maxDurationMs);
    await play("bob", Math.round(top * 0.8), 20_000, alert, game.maxDurationMs);
    await play("cid", Math.round(top * 0.9), 10 * 60_000, alert, game.maxDurationMs); // late
    await play("dee", Math.round(top * 0.3), 5_000, alert, game.maxDurationMs);

    const now = alert + 15 * 60_000;
    const world = await s.leaderboard(db, "ann", { scope: "world" }, now);
    expect(world.top.map((r) => r.pseudo)).toEqual(["Bob", "Ann", "Dee"]); // late cid excluded
    expect(world.me).toMatchObject({ rank: 2 });
    expect(world.percentile).toBe(50);
    const friends = await s.leaderboard(db, "ann", { scope: "friends" }, now);
    expect(friends.top.map((r) => [r.pseudo, r.late])).toEqual([["Cid", true], ["Bob", false], ["Ann", false]]);
    const country = await s.leaderboard(db, "ann", { scope: "country" }, now);
    expect(country.top.map((r) => r.pseudo)).toEqual(["Ann", "Dee"]);
    const language = await s.leaderboard(db, "ann", { scope: "language" }, now);
    expect(language.top.map((r) => r.pseudo)).toEqual(["Bob", "Ann", "Dee"]); // all "fr"
    const weekly = await s.leaderboard(db, "bob", { scope: "weekly" }, now);
    expect(weekly.me).toMatchObject({ rank: 1 });

    const feed = await s.feed(db, "ann", {}, now);
    expect(feed.locked).toBe(false);
    expect(feed.items.map((i) => i.pseudo)).toEqual(["Cid", "Bob"]);
    await s.react(db, "ann", { dayKey, target: "bob", emoji: "🔥" });
    await expect(s.react(db, "ann", { dayKey, target: "dee", emoji: "🔥" })).rejects.toThrow("not-friends");
    await expect(s.react(db, "ann", { dayKey, target: "bob", emoji: "🍕" })).rejects.toThrow("bad-emoji");
    const bobFeed = await s.feed(db, "cid", {}, now);
    expect(bobFeed.items.find((i) => i.uid === "ann")).toBeDefined();
    const annView = await s.feed(db, "ann", {}, now);
    expect(annView.items.find((i) => i.uid === "bob")).toMatchObject({ reactions: { "🔥": 1 }, myReaction: "🔥" });
    await s.report(db, "ann", { dayKey, target: "bob", reason: "suspicious" }, now);

    // Account deletion removes the player everywhere.
    await h.deleteUserData(db, "bob");
    expect((await s.listFriends(db, "ann")).friends.map((f) => f.uid)).toEqual(["cid"]);
    expect((await db.doc(`reactions/${dayKey}/targets/bob/from/ann`).get()).exists).toBe(false);
    await expect(s.sendFriendRequest(db, "ann", { pseudo: "Bob" }, now)).rejects.toThrow("pseudo-not-found");
  });

  it("contacts matching with hashed numbers", async () => {
    await player("eve", "Eve");
    await player("fay", "Fay");
    const hash = "a".repeat(64);
    await s.registerPhone(db, "fay", { hash });
    expect(await s.matchContacts(db, "eve", { hashes: [hash, "b".repeat(64), "nothex"] }, T0)).toEqual({ matched: 1 });
    expect((await s.listFriends(db, "fay")).friends[0]).toMatchObject({ uid: "eve", incoming: true });
  });
});
