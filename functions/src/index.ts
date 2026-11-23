/**
 * OneGame Cloud Functions (section 10.2). Business rules live in ./core
 * (pure, unit-tested) and ./handlers (Firestore, emulator-tested).
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getFunctions } from "firebase-admin/functions";
import { getMessaging } from "firebase-admin/messaging";
import { getRemoteConfig } from "firebase-admin/remote-config";
import { defineBoolean } from "firebase-functions/params";
import * as v1 from "firebase-functions/v1";
import { HttpsError, type CallableRequest, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onTaskDispatched } from "firebase-functions/v2/tasks";

import { MODIFIER_NAMES, gameById } from "./core/catalog.js";
import { REGION_IDS, addDays, isRegion } from "./core/time.js";
import * as h from "./handlers.js";
import * as social from "./socialHandlers.js";

initializeApp();
const db = getFirestore();

/** App Check enforcement (Play Integrity / App Attest), on in production. */
const ENFORCE_APP_CHECK = defineBoolean("ENFORCE_APP_CHECK", { default: false });

function callable<T>(fn: (uid: string, data: unknown, now: number) => Promise<T>) {
  return onCall({ enforceAppCheck: ENFORCE_APP_CHECK.value() }, async (req: CallableRequest) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "sign-in required");
    try {
      return await fn(req.auth.uid, req.data, Date.now());
    } catch (e) {
      if (e instanceof h.AppError) throw new HttpsError(e.code, e.message);
      throw e;
    }
  });
}

async function gameWeights(): Promise<Record<string, number>> {
  try {
    const t = await getRemoteConfig().getServerTemplate();
    const v = t.evaluate().getString("gameWeights");
    return v ? (JSON.parse(v) as Record<string, number>) : {};
  } catch {
    return {};
  }
}

/** 00:05 UTC: creates tomorrow's challenge and schedules the 4 alarms. */
export const createDaily = onSchedule({ schedule: "5 0 * * *", timeZone: "UTC" }, async () => {
  const tomorrow = addDays(new Date().toISOString().slice(0, 10), 1);
  const { daily, created } = await h.createDailyFor(db, tomorrow, await gameWeights());
  if (!created) return;
  const queue = getFunctions().taskQueue("sendAlert");
  for (const region of REGION_IDS) {
    await queue.enqueue(
      { dayKey: daily.dayKey, region },
      { scheduleTime: new Date(daily.alertAt[region]), id: `alert-${daily.dayKey}-${region}` },
    );
  }
});

/** Cloud Task fired at `alertAt[region]`: FCM push on `alert_{region}_{lang}`. */
export const sendAlert = onTaskDispatched(
  { retryConfig: { maxAttempts: 3, minBackoffSeconds: 5 }, rateLimits: { maxConcurrentDispatches: 4 } },
  async (req) => {
    const { dayKey, region } = req.data as { dayKey: string; region: string };
    if (!isRegion(region)) return;
    const snap = await db.doc(`daily/${dayKey}`).get();
    const game = gameById(snap.get("gameId"));
    const modifier = snap.get("modifierId") as string | null;
    for (const lang of ["fr", "en"] as const) {
      const name = game ? game.name[lang] : "";
      const mod = modifier ? ` · ${MODIFIER_NAMES[modifier]?.[lang] ?? modifier}` : "";
      const title = lang === "fr" ? "⏰ C'est l'heure du OneGame !" : "⏰ It's OneGame time!";
      const body = lang === "fr"
        ? `Le jeu du jour : ${name}${mod}. 2 minutes pour lancer.`
        : `Today's game: ${name}${mod}. 2 minutes to start.`;
      await getMessaging().send({
        topic: `alert_${region}_${lang}`,
        notification: { title, body },
        data: { type: "alert", dayKey },
        android: { priority: "high", notification: { channelId: "alarm", sound: "alarm", priority: "max" } },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "alarm.wav", "interruption-level": "time-sensitive" } },
        },
      });
    }
  },
);

export const ensureProfile = callable((uid, data, now) =>
  h.ensureProfile(db, uid, (data ?? {}) as { region: unknown; lang: unknown; country: unknown }, now),
);
export const setRegion = callable((uid, data, now) => h.setRegion(db, uid, (data as { region?: unknown })?.region, now));
export const getToday = callable((uid, _data, now) => h.getToday(db, uid, now));
export const startAttempt = callable((uid, _data, now) => h.startAttempt(db, uid, now));
export const submitScore = callable((uid, data, now) => h.submitScore(db, uid, data, now));
export const releasedGames = callable((uid, _data, now) => h.releasedGames(db, uid, now));
export const useJoker = callable((uid, _data, now) => h.spendJoker(db, uid, now));

type Data = Record<string, unknown>;
export const claimPseudo = callable((uid, data) => social.claimPseudo(db, uid, (data as Data)?.pseudo));
export const sendFriendRequest = callable((uid, data, now) => social.sendFriendRequest(db, uid, (data ?? {}) as Data, now));
export const respondFriendRequest = callable((uid, data, now) => social.respondFriendRequest(db, uid, (data ?? {}) as Data, now));
export const removeFriend = callable((uid, data) => social.removeFriend(db, uid, (data ?? {}) as Data));
export const listFriends = callable((uid) => social.listFriends(db, uid));
export const createInvite = callable((uid, _data, now) => social.createInvite(db, uid, now));
export const acceptInvite = callable((uid, data, now) => social.acceptInvite(db, uid, (data ?? {}) as Data, now));
export const registerPhone = callable((uid, data) => social.registerPhone(db, uid, (data ?? {}) as Data));
export const matchContacts = callable((uid, data, now) => social.matchContacts(db, uid, (data ?? {}) as Data, now));
export const getLeaderboard = callable((uid, data, now) => social.leaderboard(db, uid, (data ?? {}) as Data, now));
export const getFeed = callable((uid, data, now) => social.feed(db, uid, (data ?? {}) as Data, now));
export const react = callable((uid, data) => social.react(db, uid, (data ?? {}) as Data));
export const reportScore = callable((uid, data, now) => social.report(db, uid, (data ?? {}) as Data, now));

/** Account deletion requested from the app (store requirement). */
export const deleteAccount = callable(async (uid) => {
  await h.deleteUserData(db, uid);
  const { getAuth } = await import("firebase-admin/auth");
  await getAuth().deleteUser(uid);
  return { deleted: true };
});

/** Safety net when an auth user is deleted from the console. */
export const onUserDelete = v1.auth.user().onDelete((user) => h.deleteUserData(db, user.uid));
