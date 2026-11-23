/**
 * Firestore-backed handlers. Each takes its dependencies explicitly
 * (database, current time) so it can be tested against the emulator.
 */
import { randomInt } from "node:crypto";

import { type Firestore, Timestamp, FieldValue } from "firebase-admin/firestore";

import { newBadges } from "./core/badges.js";
import { CATALOG, gameById } from "./core/catalog.js";
import { type DailyChallenge, type HistoryEntry, generateDaily } from "./core/daily.js";
import { EMPTY_STREAK, type StreakState, effectiveStreak, jokerCase, recordPlay, useJoker } from "./core/streak.js";
import { type Region, REGION_IDS, addDays, dayKeyFor, isRegion, weekKey } from "./core/time.js";
import { type Attempt, ON_TIME_WINDOW_MS, type TodayResponse, finalizeLost, isLost, todayFor } from "./core/today.js";
import { type Submission, validateSubmission } from "./core/validate.js";

export class AppError extends Error {
  constructor(
    readonly code: "failed-precondition" | "already-exists" | "invalid-argument" | "not-found" | "permission-denied",
    message: string,
  ) {
    super(message);
  }
}

export const REGION_CHANGE_COOLDOWN_MS = 30 * 24 * 3600_000;

// ------------------------------------------------------------------ daily

function dailyToDoc(d: DailyChallenge) {
  const alertAt: Record<string, Timestamp> = {};
  for (const r of REGION_IDS) alertAt[r] = Timestamp.fromMillis(d.alertAt[r]);
  return { ...d, alertAt };
}

function dailyFromDoc(data: FirebaseFirestore.DocumentData | undefined): DailyChallenge | null {
  if (!data) return null;
  const alertAt = {} as Record<Region, number>;
  for (const r of REGION_IDS) alertAt[r] = (data.alertAt[r] as Timestamp).toMillis();
  return {
    dayKey: data.dayKey,
    gameId: data.gameId,
    seed: data.seed,
    modifierId: data.modifierId ?? null,
    alertAt,
    gameVersion: data.gameVersion,
  };
}

/** Creates `daily/{dayKey}` if missing. Returns the challenge. */
export async function createDailyFor(
  db: Firestore,
  dayKey: string,
  weights: Record<string, number> = {},
  masterSeed: number = randomInt(0, 2 ** 32 - 1),
): Promise<{ daily: DailyChallenge; created: boolean }> {
  const ref = db.doc(`daily/${dayKey}`);
  const existing = await ref.get();
  if (existing.exists) return { daily: dailyFromDoc(existing.data())!, created: false };

  const history: HistoryEntry[] = [];
  const prev = await db
    .collection("daily")
    .where("dayKey", "<", dayKey)
    .orderBy("dayKey", "desc")
    .limit(14)
    .get();
  for (const doc of prev.docs.reverse()) history.push({ dayKey: doc.get("dayKey"), gameId: doc.get("gameId") });

  const ov = await db.doc(`calendarOverrides/${dayKey}`).get();
  const override = ov.exists ? { gameId: ov.get("gameId") as string, modifierId: ov.get("modifierId") as string | null | undefined } : undefined;
  const daily = generateDaily(dayKey, history, masterSeed, weights, override);
  await ref.create(dailyToDoc(daily));
  return { daily, created: true };
}

async function loadDaily(db: Firestore, dayKey: string) {
  return dailyFromDoc((await db.doc(`daily/${dayKey}`).get()).data());
}

// ------------------------------------------------------------------ users

export interface Profile {
  region: Region;
  lang: string;
  country: string | null;
  pseudo: string | null;
  regionChangedAt: number | null;
  badges: string[];
  gamesPlayed: string[];
  streakState: StreakState;
}

async function loadProfile(db: Firestore, uid: string): Promise<Profile> {
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) throw new AppError("failed-precondition", "profile-missing");
  const d = snap.data()!;
  return {
    region: d.region,
    lang: d.lang ?? "fr",
    country: d.country ?? null,
    pseudo: d.pseudo ?? null,
    regionChangedAt: d.regionChangedAt?.toMillis?.() ?? null,
    badges: d.badges ?? [],
    gamesPlayed: d.gamesPlayed ?? [],
    streakState: { ...EMPTY_STREAK, ...(d.streakState ?? {}) },
  };
}

/** Creates the profile on first launch (anonymous auth). Idempotent. */
export async function ensureProfile(
  db: Firestore,
  uid: string,
  input: { region: unknown; lang: unknown; country: unknown },
  now: number,
) {
  if (!isRegion(input.region)) throw new AppError("invalid-argument", "bad-region");
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return;
    tx.create(ref, {
      region: input.region,
      lang: input.lang === "en" ? "en" : "fr",
      country: typeof input.country === "string" ? input.country.slice(0, 2).toUpperCase() : null,
      createdAt: Timestamp.fromMillis(now),
      pseudo: null,
      badges: [],
      gamesPlayed: [],
      streakState: EMPTY_STREAK,
      streak: 0,
      bestStreak: 0,
      jokers: 0,
      regionChangedAt: null,
    });
  });
  return publicStreak(await loadProfile(db, uid), dayKeyFor(now, input.region));
}

/** Region change, at most once per 30 days (section 4.1). */
export async function setRegion(db: Firestore, uid: string, region: unknown, now: number) {
  if (!isRegion(region)) throw new AppError("invalid-argument", "bad-region");
  const p = await loadProfile(db, uid);
  if (p.region === region) return { region };
  if (p.regionChangedAt !== null && now - p.regionChangedAt < REGION_CHANGE_COOLDOWN_MS) {
    throw new AppError("failed-precondition", "region-cooldown");
  }
  await db.doc(`users/${uid}`).update({ region, regionChangedAt: Timestamp.fromMillis(now) });
  return { region };
}

function publicStreak(p: Profile, today: string) {
  const s = p.streakState;
  return {
    streak: effectiveStreak(s, today),
    bestStreak: s.bestStreak,
    jokers: s.jokerMonth === today.slice(0, 7) ? s.jokers : 1,
    jokerAvailable: jokerCase(s, today) !== null,
    savedDays: s.savedDays,
    badges: p.badges,
  };
}

// ------------------------------------------------------------------ today

export async function getToday(db: Firestore, uid: string, now: number): Promise<TodayResponse & { profile: ReturnType<typeof publicStreak> }> {
  const p = await loadProfile(db, uid);
  const dayKey = dayKeyFor(now, p.region);
  const daily = await loadDaily(db, dayKey);
  const attemptRef = db.doc(`attempts/${uid}_${dayKey}`);
  let attempt = (await attemptRef.get()).data() as Attempt | undefined;
  if (attempt && daily) {
    const game = gameById(attempt.gameId);
    if (game && isLost(attempt, now, game.maxDurationMs)) {
      attempt = finalizeLost(attempt, now);
      await attemptRef.set(attempt);
      await recordOfficialResult(db, uid, p, attempt, now);
    }
  }
  return { ...todayFor(now, p.region, daily, attempt ?? null), profile: publicStreak(await loadProfile(db, uid), dayKey) };
}

export async function startAttempt(db: Firestore, uid: string, now: number) {
  const p = await loadProfile(db, uid);
  const dayKey = dayKeyFor(now, p.region);
  const daily = await loadDaily(db, dayKey);
  if (!daily) throw new AppError("not-found", "no-daily");
  const alertAt = daily.alertAt[p.region];
  if (now < alertAt) throw new AppError("failed-precondition", "alarm-not-rung");
  const ref = db.doc(`attempts/${uid}_${dayKey}`);
  const attempt: Attempt = {
    uid,
    dayKey,
    gameId: daily.gameId,
    region: p.region,
    startedAt: now,
    onTime: now - alertAt <= ON_TIME_WINDOW_MS,
    status: "started",
  };
  try {
    await ref.create(attempt);
  } catch {
    throw new AppError("already-exists", "attempt-exists");
  }
  return {
    dayKey,
    gameId: daily.gameId,
    seed: daily.seed,
    modifierId: daily.modifierId,
    onTime: attempt.onTime,
    startedAt: now,
    startDelayMs: now - alertAt,
  };
}

export async function submitScore(db: Firestore, uid: string, raw: unknown, now: number) {
  const sub = parseSubmission(raw);
  const p = await loadProfile(db, uid);
  const dayKey = typeof (raw as { dayKey?: unknown })?.dayKey === "string"
    ? (raw as { dayKey: string }).dayKey
    : dayKeyFor(now, p.region);
  const ref = db.doc(`attempts/${uid}_${dayKey}`);
  const attempt = (await ref.get()).data() as Attempt | undefined;
  const game = attempt ? gameById(attempt.gameId) : undefined;
  const verdict = validateSubmission(attempt ?? null, game, sub, now);
  if (!verdict.ok) throw new AppError("failed-precondition", verdict.reason);

  if (sub.partial) {
    await ref.update({ partialScore: sub.score });
    return { accepted: true, partial: true };
  }
  const finished: Attempt = {
    ...attempt!,
    status: "finished",
    finishedAt: now,
    score: sub.score,
    stats: sub.stats,
    highlights: sub.highlights,
  };
  await ref.set(finished);
  // Input logs kept for later replay checks (v1: stored for every result,
  // pruned to the top 1 % by a maintenance job).
  await db.doc(`inputLogs/${uid}_${dayKey}`).set({ uid, dayKey, score: sub.score, log: JSON.stringify(sub.inputLog) });
  const result = await recordOfficialResult(db, uid, p, finished, now);
  return { accepted: true, partial: false, ...result };
}

/** Streak, badges and leaderboards for a finished (or lost) attempt. */
async function recordOfficialResult(db: Firestore, uid: string, p: Profile, a: Attempt, now: number) {
  const streakState = recordPlay(p.streakState, a.dayKey, a.onTime);
  const gamesPlayed = Array.from(new Set([...p.gamesPlayed, a.gameId]));
  const daily = await loadDaily(db, a.dayKey);
  const startDelayMs = daily ? a.startedAt - daily.alertAt[a.region] : Number.MAX_SAFE_INTEGER;
  const earned = newBadges(p.badges, {
    streak: streakState.streak,
    highlights: a.highlights ?? [],
    startDelayMs,
    onTime: a.onTime,
    gamesPlayed,
    catalogSize: CATALOG.length,
  });
  const score = a.score ?? 0;
  const batch = db.batch();
  batch.update(db.doc(`users/${uid}`), {
    streakState,
    streak: streakState.streak,
    bestStreak: streakState.bestStreak,
    jokers: streakState.jokers,
    gamesPlayed,
    badges: [...p.badges, ...earned],
    lastPlayedAt: Timestamp.fromMillis(now),
  });
  batch.set(db.doc(`scores/${a.dayKey}/entries/${uid}`), {
    uid,
    pseudo: p.pseudo,
    score,
    onTime: a.onTime,
    country: p.country,
    region: a.region,
    lang: p.lang,
    gameId: a.gameId,
    highlights: a.highlights ?? [],
    at: Timestamp.fromMillis(now),
  });
  if (a.onTime) {
    batch.set(
      db.doc(`weekly/${weekKey(a.dayKey)}/entries/${uid}`),
      { uid, pseudo: p.pseudo, country: p.country, region: a.region, score: FieldValue.increment(score), days: FieldValue.increment(1) },
      { merge: true },
    );
  }
  await batch.commit();
  return { streak: streakState.streak, bestStreak: streakState.bestStreak, newBadges: earned };
}

/** Games already released as a daily game (training, section 9.9). */
export async function releasedGames(db: Firestore, uid: string, now: number) {
  const p = await loadProfile(db, uid);
  const today = dayKeyFor(now, p.region);
  const snap = await db.collection("daily").where("dayKey", "<", today).select("gameId").get();
  const games = new Set(snap.docs.map((d) => d.get("gameId") as string));
  const attempt = await db.doc(`attempts/${uid}_${today}`).get();
  if (attempt.exists && attempt.get("status") !== "started") games.add(attempt.get("gameId"));
  return { games: [...games].sort() };
}

export async function spendJoker(db: Firestore, uid: string, now: number) {
  const p = await loadProfile(db, uid);
  const today = dayKeyFor(now, p.region);
  if (jokerCase(p.streakState, today) === null) throw new AppError("failed-precondition", "no-joker-case");
  const s = useJoker(p.streakState, today);
  await db.doc(`users/${uid}`).update({ streakState: s, streak: s.streak, bestStreak: s.bestStreak, jokers: s.jokers });
  return publicStreak({ ...p, streakState: s }, today);
}

/** Deletes everything belonging to [uid] (store requirement). */
export async function deleteUserData(db: Firestore, uid: string) {
  const user = await db.doc(`users/${uid}`).get();
  const pseudo = user.get("pseudo") as string | undefined;
  const writer = db.bulkWriter();
  for (const q of [
    db.collection("attempts").where("uid", "==", uid),
    db.collection("inputLogs").where("uid", "==", uid),
    db.collection("friendships").where("users", "array-contains", uid),
  ]) {
    for (const d of (await q.get()).docs) writer.delete(d.ref);
  }
  for (const q of [
    db.collectionGroup("entries").where("uid", "==", uid),
    db.collectionGroup("from").where("uid", "==", uid),
    db.collectionGroup("from").where("target", "==", uid),
  ]) {
    for (const d of (await q.get()).docs) writer.delete(d.ref);
  }
  if (pseudo) writer.delete(db.doc(`pseudos/${pseudo.toLowerCase()}`));
  writer.delete(db.doc(`users/${uid}`));
  await writer.close();
}

function parseSubmission(raw: unknown): Submission {
  const r = raw as Partial<Submission> | null;
  if (!r || typeof r !== "object") throw new AppError("invalid-argument", "bad-submission");
  return {
    score: Number(r.score),
    playedMs: Number(r.playedMs),
    inputLog: Array.isArray(r.inputLog) ? r.inputLog : [],
    stats: typeof r.stats === "object" && r.stats ? r.stats : {},
    highlights: Array.isArray(r.highlights) ? r.highlights.map(String).slice(0, 50) : [],
    partial: r.partial === true,
  };
}

export { addDays };
