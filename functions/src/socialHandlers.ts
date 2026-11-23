/** Social features (section 9: friends, leaderboards, feed, reactions). */
import { randomInt } from "node:crypto";

import { type Firestore, Timestamp } from "firebase-admin/firestore";

import { checkPseudo, pseudoKey } from "./core/pseudo.js";
import { friendshipId, inviteCode, isReaction, isScope, percentile, rankEntries, type Scope } from "./core/social.js";
import { dayKeyFor, isRegion, weekKey } from "./core/time.js";
import { AppError } from "./handlers.js";

const TOP = 100;

async function profile(db: Firestore, uid: string) {
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) throw new AppError("failed-precondition", "profile-missing");
  return snap.data()!;
}

export async function claimPseudo(db: Firestore, uid: string, raw: unknown) {
  const pseudo = typeof raw === "string" ? raw.trim() : "";
  const problem = checkPseudo(pseudo);
  if (problem) throw new AppError("invalid-argument", `pseudo-${problem}`);
  const key = pseudoKey(pseudo);
  await db.runTransaction(async (tx) => {
    const userRef = db.doc(`users/${uid}`);
    const user = await tx.get(userRef);
    if (!user.exists) throw new AppError("failed-precondition", "profile-missing");
    const owner = await tx.get(db.doc(`pseudos/${key}`));
    if (owner.exists && owner.get("uid") !== uid) throw new AppError("already-exists", "pseudo-taken");
    const old = user.get("pseudo") as string | null;
    if (old && pseudoKey(old) !== key) tx.delete(db.doc(`pseudos/${pseudoKey(old)}`));
    tx.set(db.doc(`pseudos/${key}`), { uid, pseudo });
    tx.update(userRef, { pseudo });
  });
  return { pseudo };
}

async function uidForPseudo(db: Firestore, pseudo: string): Promise<string> {
  const snap = await db.doc(`pseudos/${pseudoKey(pseudo)}`).get();
  if (!snap.exists) throw new AppError("not-found", "pseudo-not-found");
  return snap.get("uid");
}

export async function sendFriendRequest(db: Firestore, uid: string, data: { pseudo?: unknown }, now: number) {
  const other = await uidForPseudo(db, String(data.pseudo ?? ""));
  if (other === uid) throw new AppError("invalid-argument", "self");
  const ref = db.doc(`friendships/${friendshipId(uid, other)}`);
  return db.runTransaction(async (tx) => {
    const f = await tx.get(ref);
    if (f.exists) {
      // The other player already asked: accept.
      if (f.get("status") === "pending" && f.get("requester") === other) {
        tx.update(ref, { status: "accepted", since: Timestamp.fromMillis(now) });
        return { status: "accepted" };
      }
      return { status: f.get("status") as string };
    }
    tx.create(ref, { users: [uid, other].sort(), requester: uid, status: "pending", since: Timestamp.fromMillis(now) });
    return { status: "pending" };
  });
}

export async function respondFriendRequest(db: Firestore, uid: string, data: { uid?: unknown; accept?: unknown }, now: number) {
  const other = String(data.uid ?? "");
  const ref = db.doc(`friendships/${friendshipId(uid, other)}`);
  const f = await ref.get();
  if (!f.exists || f.get("status") !== "pending" || f.get("requester") === uid) {
    throw new AppError("not-found", "no-request");
  }
  if (data.accept === true) await ref.update({ status: "accepted", since: Timestamp.fromMillis(now) });
  else await ref.delete();
  return { ok: true };
}

export async function removeFriend(db: Firestore, uid: string, data: { uid?: unknown }) {
  await db.doc(`friendships/${friendshipId(uid, String(data.uid ?? ""))}`).delete();
  return { ok: true };
}

async function friendUids(db: Firestore, uid: string): Promise<string[]> {
  const snap = await db.collection("friendships").where("users", "array-contains", uid).where("status", "==", "accepted").get();
  return snap.docs.map((d) => (d.get("users") as string[]).find((u) => u !== uid)!);
}

async function pseudosOf(db: Firestore, uids: string[]): Promise<Map<string, string | null>> {
  const out = new Map<string, string | null>();
  for (let i = 0; i < uids.length; i += 100) {
    const refs = uids.slice(i, i + 100).map((u) => db.doc(`users/${u}`));
    if (refs.length === 0) continue;
    for (const s of await db.getAll(...refs)) out.set(s.id, (s.get("pseudo") as string) ?? null);
  }
  return out;
}

export async function listFriends(db: Firestore, uid: string) {
  const snap = await db.collection("friendships").where("users", "array-contains", uid).get();
  const rows = snap.docs.map((d) => ({
    uid: (d.get("users") as string[]).find((u) => u !== uid)!,
    status: d.get("status") as string,
    incoming: d.get("requester") !== uid,
  }));
  const names = await pseudosOf(db, rows.map((r) => r.uid));
  return { friends: rows.map((r) => ({ ...r, pseudo: names.get(r.uid) ?? null })) };
}

export async function createInvite(db: Firestore, uid: string, now: number) {
  const code = inviteCode((n) => randomInt(0, n));
  await db.doc(`invites/${code}`).set({ uid, createdAt: Timestamp.fromMillis(now) });
  return { code };
}

export async function acceptInvite(db: Firestore, uid: string, data: { code?: unknown }, now: number) {
  const snap = await db.doc(`invites/${String(data.code ?? "").toUpperCase()}`).get();
  if (!snap.exists) throw new AppError("not-found", "invite-not-found");
  const other = snap.get("uid") as string;
  if (other === uid) throw new AppError("invalid-argument", "self");
  await db.doc(`friendships/${friendshipId(uid, other)}`).set({
    users: [uid, other].sort(), requester: other, status: "accepted", since: Timestamp.fromMillis(now),
  });
  return { ok: true, pseudo: (await profile(db, other)).pseudo ?? null };
}

/** Opt-in: stores the SHA-256 of the player's own phone number. */
export async function registerPhone(db: Firestore, uid: string, data: { hash?: unknown }) {
  const hash = String(data.hash ?? "");
  if (!/^[0-9a-f]{64}$/.test(hash)) throw new AppError("invalid-argument", "bad-hash");
  await db.doc(`phoneHashes/${hash}`).set({ uid });
  await db.doc(`users/${uid}`).update({ phoneHash: hash });
  return { ok: true };
}

/** Contacts (hashed client-side, with consent): sends friend requests. */
export async function matchContacts(db: Firestore, uid: string, data: { hashes?: unknown }, now: number) {
  const hashes = Array.isArray(data.hashes) ? data.hashes.map(String).filter((h) => /^[0-9a-f]{64}$/.test(h)).slice(0, 2000) : [];
  const matches: string[] = [];
  for (let i = 0; i < hashes.length; i += 100) {
    const refs = hashes.slice(i, i + 100).map((h) => db.doc(`phoneHashes/${h}`));
    if (refs.length === 0) continue;
    for (const s of await db.getAll(...refs)) if (s.exists && s.get("uid") !== uid) matches.push(s.get("uid"));
  }
  for (const other of matches) {
    const ref = db.doc(`friendships/${friendshipId(uid, other)}`);
    if (!(await ref.get()).exists) {
      await ref.create({ users: [uid, other].sort(), requester: uid, status: "pending", since: Timestamp.fromMillis(now) });
    }
  }
  return { matched: matches.length };
}

interface BoardRow { uid: string; pseudo: string | null; score: number; onTime: boolean; country: string | null; rank: number; late?: boolean }

export async function leaderboard(db: Firestore, uid: string, data: { scope?: unknown; dayKey?: unknown }, now: number) {
  const scope: Scope = isScope(data.scope) ? data.scope : "world";
  const me = await profile(db, uid);
  const region = isRegion(me.region) ? me.region : "europe";
  const dayKey = typeof data.dayKey === "string" ? data.dayKey : dayKeyFor(now, region);
  const map = (d: FirebaseFirestore.QueryDocumentSnapshot | FirebaseFirestore.DocumentSnapshot) => ({
    uid: d.id,
    pseudo: (d.get("pseudo") as string) ?? null,
    score: (d.get("score") as number) ?? 0,
    onTime: d.get("onTime") !== false,
    country: (d.get("country") as string) ?? null,
  });

  if (scope === "friends") {
    // Friends see each other, late scores included (flagged).
    const uids = [uid, ...(await friendUids(db, uid))];
    const rows: Omit<BoardRow, "rank">[] = [];
    for (let i = 0; i < uids.length; i += 100) {
      const refs = uids.slice(i, i + 100).map((u) => db.doc(`scores/${dayKey}/entries/${u}`));
      for (const s of await db.getAll(...refs)) if (s.exists) rows.push(map(s));
    }
    const ranked = rankEntries(rows).map((r) => ({ ...r, late: !r.onTime }));
    return { scope, dayKey, top: ranked.slice(0, TOP), me: ranked.find((r) => r.uid === uid) ?? null, total: ranked.length, percentile: null };
  }

  const coll = scope === "weekly"
    ? db.collection(`weekly/${weekKey(dayKey)}/entries`)
    : db.collection(`scores/${dayKey}/entries`);
  let q: FirebaseFirestore.Query = coll;
  if (scope !== "weekly") q = q.where("onTime", "==", true);
  if (scope === "region") q = q.where("region", "==", region);
  if (scope === "country") q = q.where("country", "==", me.country ?? "??");
  const topSnap = await q.orderBy("score", "desc").limit(TOP).get();
  const top = rankEntries(topSnap.docs.map(map));
  const mine = await coll.doc(uid).get();
  const total = (await q.count().get()).data().count;
  let meRow: BoardRow | null = null;
  let pct: number | null = null;
  if (mine.exists && (scope === "weekly" || mine.get("onTime") === true)) {
    const above = (await q.where("score", ">", mine.get("score")).count().get()).data().count;
    meRow = { ...map(mine), rank: above + 1 };
    pct = percentile(above, total);
  }
  return { scope, dayKey, top, me: meRow, total, percentile: pct };
}

async function hasFinished(db: Firestore, uid: string, dayKey: string) {
  const a = await db.doc(`attempts/${uid}_${dayKey}`).get();
  return a.exists && a.get("status") !== "started";
}

/** Friends feed: only visible after playing (section 9.6, like BeReal). */
export async function feed(db: Firestore, uid: string, data: { dayKey?: unknown }, now: number) {
  const me = await profile(db, uid);
  const dayKey = typeof data.dayKey === "string" ? data.dayKey : dayKeyFor(now, isRegion(me.region) ? me.region : "europe");
  if (!(await hasFinished(db, uid, dayKey))) return { dayKey, locked: true, items: [] };
  const friends = await friendUids(db, uid);
  const items = [];
  for (const f of friends) {
    const e = await db.doc(`scores/${dayKey}/entries/${f}`).get();
    if (!e.exists) continue;
    const reacts = await db.collection(`reactions/${dayKey}/targets/${f}/from`).get();
    const counts: Record<string, number> = {};
    let mine: string | null = null;
    for (const r of reacts.docs) {
      const emoji = r.get("emoji") as string;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (r.id === uid) mine = emoji;
    }
    items.push({
      uid: f,
      pseudo: e.get("pseudo") ?? null,
      score: e.get("score") ?? 0,
      onTime: e.get("onTime") !== false,
      gameId: e.get("gameId") ?? null,
      highlights: e.get("highlights") ?? [],
      reactions: counts,
      myReaction: mine,
    });
  }
  items.sort((a, b) => b.score - a.score);
  return { dayKey, locked: false, items };
}

export async function react(db: Firestore, uid: string, data: { dayKey?: unknown; target?: unknown; emoji?: unknown }) {
  const dayKey = String(data.dayKey ?? "");
  const target = String(data.target ?? "");
  if (!(await hasFinished(db, uid, dayKey))) throw new AppError("failed-precondition", "play-first");
  if (!(await friendUids(db, uid)).includes(target)) throw new AppError("permission-denied", "not-friends");
  const ref = db.doc(`reactions/${dayKey}/targets/${target}/from/${uid}`);
  if (data.emoji === null) {
    await ref.delete();
  } else {
    if (!isReaction(data.emoji)) throw new AppError("invalid-argument", "bad-emoji");
    await ref.set({ emoji: data.emoji, uid, target });
  }
  return { ok: true };
}

export async function report(db: Firestore, uid: string, data: { dayKey?: unknown; target?: unknown; reason?: unknown }, now: number) {
  await db.collection("reports").add({
    by: uid,
    target: String(data.target ?? ""),
    dayKey: String(data.dayKey ?? ""),
    reason: String(data.reason ?? "").slice(0, 200),
    at: Timestamp.fromMillis(now),
  });
  return { ok: true };
}
