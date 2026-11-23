export const BADGES = [
  "first_day",
  "week",
  "month",
  "ace",
  "panenka",
  "carreau",
  "one_eighty",
  "early_bird",
  "all_games",
] as const;
export type Badge = (typeof BADGES)[number];

const HIGHLIGHT_BADGES: Record<string, Badge> = {
  ace: "ace",
  panenka: "panenka",
  carreau: "carreau",
  oneEighty: "one_eighty",
};

/** Badges earned by an official result (section 9). */
export function newBadges(
  owned: readonly string[],
  ctx: {
    streak: number;
    highlights: readonly string[];
    startDelayMs: number;
    onTime: boolean;
    gamesPlayed: readonly string[];
    catalogSize: number;
  },
): Badge[] {
  const has = new Set(owned);
  const earned: Badge[] = [];
  const add = (b: Badge, cond: boolean) => {
    if (cond && !has.has(b) && !earned.includes(b)) earned.push(b);
  };
  add("first_day", true);
  add("week", ctx.streak >= 7);
  add("month", ctx.streak >= 30);
  for (const h of ctx.highlights) {
    const b = HIGHLIGHT_BADGES[h];
    if (b) add(b, true);
  }
  add("early_bird", ctx.onTime && ctx.startDelayMs <= 10_000);
  add("all_games", new Set(ctx.gamesPlayed).size >= Math.max(24, ctx.catalogSize));
  return earned;
}
