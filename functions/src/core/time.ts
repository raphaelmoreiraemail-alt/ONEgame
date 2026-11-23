/** Regions and their reference time zones (section 4.1). */
export const REGIONS = {
  europe: "Europe/Paris",
  americas: "America/New_York",
  asia: "Asia/Tokyo",
  west: "America/Los_Angeles",
} as const;

export type Region = keyof typeof REGIONS;
export const REGION_IDS = Object.keys(REGIONS) as Region[];

export function isRegion(r: unknown): r is Region {
  return typeof r === "string" && r in REGIONS;
}

function parts(utcMs: number, tz: string) {
  const f = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const p: Record<string, number> = {};
  for (const { type, value } of f.formatToParts(new Date(utcMs))) {
    if (type !== "literal") p[type] = Number(value);
  }
  return p as { year: number; month: number; day: number; hour: number; minute: number; second: number };
}

/** Offset of [tz] at [utcMs], in ms (local = utc + offset). */
export function tzOffsetMs(utcMs: number, tz: string): number {
  const p = parts(utcMs, tz);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return asUtc - Math.floor(utcMs / 1000) * 1000;
}

/** UTC instant of a wall-clock time in [tz]. */
export function zonedToUtc(
  y: number, m: number, d: number, h: number, min: number, s: number, tz: string,
): number {
  const guess = Date.UTC(y, m - 1, d, h, min, s);
  let utc = guess - tzOffsetMs(guess, tz);
  utc = guess - tzOffsetMs(utc, tz); // second pass handles DST edges
  return utc;
}

/** `YYYY-MM-DD` of the instant [utcMs] in [tz]. */
export function dayKeyIn(utcMs: number, tz: string): string {
  const p = parts(utcMs, tz);
  return `${p.year}-${String(p.month).padStart(2, "0")}-${String(p.day).padStart(2, "0")}`;
}

export function dayKeyFor(utcMs: number, region: Region): string {
  return dayKeyIn(utcMs, REGIONS[region]);
}

export function parseDayKey(k: string): [number, number, number] {
  const [y, m, d] = k.split("-").map(Number);
  return [y, m, d];
}

export function addDays(k: string, n: number): string {
  const [y, m, d] = parseDayKey(k);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/** 0 = Sunday … 6 = Saturday. */
export function dayOfWeek(k: string): number {
  const [y, m, d] = parseDayKey(k);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

export function monthOf(k: string): string {
  return k.slice(0, 7);
}

/** ISO week key `YYYY-Www` for weekly leaderboards. */
export function weekKey(k: string): string {
  const [y, m, d] = parseDayKey(k);
  const date = new Date(Date.UTC(y, m - 1, d));
  const dayNum = date.getUTCDay() || 7; // Monday = 1 … Sunday = 7
  date.setUTCDate(date.getUTCDate() + 4 - dayNum); // Thursday of this week
  const yearStart = Date.UTC(date.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((date.getTime() - yearStart) / 86400000 + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}
