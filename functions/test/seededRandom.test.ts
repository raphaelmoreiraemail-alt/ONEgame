import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { SeededRandom, fnv1a32 } from "../src/core/seededRandom.js";

const vectors = JSON.parse(
  readFileSync(new URL("../../shared/rng_vectors.json", import.meta.url), "utf8"),
);

/** Reference mulberry32 as published (Tommy Ettinger / bryc), used as an oracle. */
function canonicalMulberry32(a: number) {
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

describe("SeededRandom (TS)", () => {
  it("matches the canonical mulberry32", () => {
    for (const seed of [0, 1, 42, 2938471923, 4294967295]) {
      const ours = new SeededRandom(seed);
      const ref = canonicalMulberry32(seed);
      for (let i = 0; i < 1000; i++) expect(ours.nextDouble()).toBe(ref());
    }
  });

  it("matches shared reference vectors", () => {
    for (const { label, hash } of vectors.hashes) expect(fnv1a32(label)).toBe(hash);
    for (const { seed, uint32 } of vectors.sequences) {
      const r = new SeededRandom(seed);
      expect(uint32.map(() => r.nextUint32())).toEqual(uint32);
    }
    for (const { seed, label, uint32 } of vectors.derived) {
      const r = SeededRandom.derive(seed, label);
      expect(uint32.map(() => r.nextUint32())).toEqual(uint32);
    }
    const h = vectors.helpers;
    const r = new SeededRandom(h.seed);
    expect(h.nextInt100.map(() => r.nextInt(100))).toEqual(h.nextInt100);
    expect(h.intInRange_10_20.map(() => r.intInRange(10, 20))).toEqual(h.intInRange_10_20);
    expect(r.shuffled([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])).toEqual(h.shuffled);
  });

  it("is deterministic and seed-sensitive", () => {
    const a = new SeededRandom(7), b = new SeededRandom(7), c = new SeededRandom(8);
    const sa = Array.from({ length: 50 }, () => a.nextUint32());
    expect(Array.from({ length: 50 }, () => b.nextUint32())).toEqual(sa);
    expect(Array.from({ length: 50 }, () => c.nextUint32())).not.toEqual(sa);
  });

  it("stays in range", () => {
    const r = new SeededRandom(123);
    for (let i = 0; i < 10000; i++) {
      const d = r.nextDouble();
      expect(d).toBeGreaterThanOrEqual(0);
      expect(d).toBeLessThan(1);
      const n = r.intInRange(-3, 3);
      expect(n).toBeGreaterThanOrEqual(-3);
      expect(n).toBeLessThanOrEqual(3);
    }
    expect(() => r.nextInt(0)).toThrow();
    expect(() => r.pick([])).toThrow();
  });
});
