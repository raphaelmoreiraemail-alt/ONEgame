import { readFileSync } from "node:fs";

import {
  type RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-onegame",
    firestore: { rules: readFileSync(new URL("../../../firestore.rules", import.meta.url), "utf8") },
  });
});
afterAll(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/alice"), { pseudo: "alice", streak: 3, avatar: 1, lang: "fr" });
    await setDoc(doc(db, "daily/2026-11-24"), { gameId: "minigolf", seed: 1 });
    await setDoc(doc(db, "attempts/alice_2026-11-24"), { uid: "alice", score: 10 });
    await setDoc(doc(db, "attempts/bob_2026-11-24"), { uid: "bob", score: 10 });
    await setDoc(doc(db, "scores/2026-11-24/entries/alice"), { score: 10 });
  });
});

describe("firestore.rules", () => {
  it("nobody reads the daily challenge (game, seed, alarm time)", async () => {
    await assertFails(getDoc(doc(env.authenticatedContext("alice").firestore(), "daily/2026-11-24")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "daily/2026-11-24")));
  });

  it("clients never write scores, attempts or daily", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(db, "scores/2026-11-24/entries/alice"), { score: 99999 }));
    await assertFails(setDoc(doc(db, "attempts/alice_2026-11-25"), { uid: "alice" }));
    await assertFails(setDoc(doc(db, "daily/2026-11-25"), { gameId: "x" }));
  });

  it("players read only their own attempts", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "attempts/alice_2026-11-24")));
    await assertFails(getDoc(doc(db, "attempts/bob_2026-11-24")));
  });

  it("leaderboards are readable by signed-in players only", async () => {
    await assertSucceeds(getDoc(doc(env.authenticatedContext("bob").firestore(), "scores/2026-11-24/entries/alice")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "scores/2026-11-24/entries/alice")));
  });

  it("owners edit only cosmetic profile fields", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/alice"), { avatar: 7 }));
    await assertFails(updateDoc(doc(db, "users/alice"), { streak: 999 }));
    await assertFails(updateDoc(doc(env.authenticatedContext("bob").firestore(), "users/alice"), { avatar: 2 }));
    await assertFails(setDoc(doc(db, "users/mallory"), { pseudo: "x" }));
  });
});
