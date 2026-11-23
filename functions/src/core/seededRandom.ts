/**
 * Deterministic PRNG shared with the Flutter client.
 *
 * MUST stay bit-for-bit identical to `app/lib/core/rng/seeded_random.dart`.
 * Both implementations are checked against `shared/rng_vectors.json`.
 */

const MASK32 = 0xffffffff;

/** FNV-1a 32-bit hash of the UTF-8 bytes of [input]. */
export function fnv1a32(input: string): number {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(input)) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

export class SeededRandom {
  private state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** Sub-generator independent from other draws: `seed ^ fnv1a32(label)`. */
  static derive(seed: number, label: string): SeededRandom {
    return new SeededRandom(((seed >>> 0) ^ fnv1a32(label)) >>> 0);
  }

  /** mulberry32 step. Returns an unsigned 32-bit integer. */
  nextUint32(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t = (t + Math.imul(t ^ (t >>> 7), t | 61)) ^ t;
    return (t ^ (t >>> 14)) >>> 0;
  }

  /** Uniform double in [0, 1). */
  nextDouble(): number {
    return this.nextUint32() / 4294967296;
  }

  /** Uniform integer in [0, max). */
  nextInt(max: number): number {
    if (!Number.isInteger(max) || max <= 0 || max > MASK32) {
      throw new RangeError(`max must be in [1, 2^32-1], got ${max}`);
    }
    return Math.floor(this.nextDouble() * max);
  }

  /** Uniform integer in [min, max] (inclusive). */
  intInRange(min: number, max: number): number {
    return min + this.nextInt(max - min + 1);
  }

  /** Uniform double in [min, max). */
  doubleInRange(min: number, max: number): number {
    return min + this.nextDouble() * (max - min);
  }

  /** True with probability [p]. */
  chance(p: number): boolean {
    return this.nextDouble() < p;
  }

  pick<T>(items: readonly T[]): T {
    if (items.length === 0) throw new RangeError("cannot pick from empty list");
    return items[this.nextInt(items.length)];
  }

  /** Fisher-Yates shuffle, returns a new array. */
  shuffled<T>(items: readonly T[]): T[] {
    const out = items.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j = this.nextInt(i + 1);
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  }
}
