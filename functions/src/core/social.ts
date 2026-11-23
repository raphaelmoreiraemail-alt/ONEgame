export const REACTIONS = ["🔥", "😂", "😮", "👏", "💀"] as const;
export type Reaction = (typeof REACTIONS)[number];

export function isReaction(e: unknown): e is Reaction {
  return typeof e === "string" && (REACTIONS as readonly string[]).includes(e);
}

/** Friendship document id for two players (order independent). */
export function friendshipId(a: string, b: string): string {
  return a < b ? `${a}_${b}` : `${b}_${a}`;
}

export type Scope = "friends" | "country" | "region" | "world" | "weekly";

export function isScope(s: unknown): s is Scope {
  return s === "friends" || s === "country" || s === "region" || s === "world" || s === "weekly";
}

export interface Ranked {
  uid: string;
  pseudo: string | null;
  score: number;
  onTime: boolean;
  country: string | null;
  rank: number;
}

/** Competition ranking (1, 2, 2, 4) on score, highest first. */
export function rankEntries<T extends { uid: string; score: number }>(entries: T[]): (T & { rank: number })[] {
  const sorted = [...entries].sort((a, b) => b.score - a.score || a.uid.localeCompare(b.uid));
  let prevScore = Number.NaN;
  let prevRank = 0;
  return sorted.map((e, i) => {
    const rank = e.score === prevScore ? prevRank : i + 1;
    prevScore = e.score;
    prevRank = rank;
    return { ...e, rank };
  });
}

/** Share of players strictly below, in % (0–100, rounded down). */
export function percentile(above: number, total: number): number {
  if (total <= 1) return 100;
  return Math.floor(((total - 1 - above) / (total - 1)) * 100);
}

/** Random invite code (no ambiguous characters). */
export function inviteCode(random: (n: number) => number): string {
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  let s = "";
  for (let i = 0; i < 8; i++) s += alphabet[random(alphabet.length)];
  return s;
}
