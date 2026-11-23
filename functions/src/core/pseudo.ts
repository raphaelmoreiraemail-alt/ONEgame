import banned from "../shared/banned_words.json" with { type: "json" };

export const PSEUDO_MIN = 3;
export const PSEUDO_MAX = 16;
const ALLOWED = /^[A-Za-z0-9_.-]+$/;

/** Lowercase, no accents, leetspeak mapped, separators removed. */
export function normalizeForFilter(s: string): string {
  const leet: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", $: "s" };
  return s
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[013457@$]/g, (c) => leet[c])
    .replace(/[^a-z]/g, "");
}

export type PseudoProblem = "length" | "charset" | "offensive" | null;

/** Validates a pseudo (section 9.1): 3–16 chars, letters/digits/._-, no insults. */
export function checkPseudo(p: string): PseudoProblem {
  if (p.length < PSEUDO_MIN || p.length > PSEUDO_MAX) return "length";
  if (!ALLOWED.test(p)) return "charset";
  const n = normalizeForFilter(p);
  for (const w of banned.words) {
    // Short words must match the whole pseudo, longer ones anywhere.
    if (w.length <= 3 ? n === w : n.includes(w)) return "offensive";
  }
  return null;
}

export function pseudoKey(p: string): string {
  return p.toLowerCase();
}
