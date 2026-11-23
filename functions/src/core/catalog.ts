import games from "../shared/games.json" with { type: "json" };

export type Category = "sport" | "adresse" | "arcade" | "reflexion";

export interface GameInfo {
  id: string;
  category: Category;
  rulesVersion: number;
  maxDurationMs: number;
  modifiers: string[];
  scoreMin: number;
  scoreMax: number;
  name: { fr: string; en: string };
}

/** Game catalog exported from the Flutter registry (shared/games.json). */
export const CATALOG: readonly GameInfo[] = games.games as GameInfo[];

/** Localized modifier names. */
export const MODIFIER_NAMES: Readonly<Record<string, { fr: string; en: string }>> = games.modifiers;

export function gameById(id: string): GameInfo | undefined {
  return CATALOG.find((g) => g.id === id);
}
