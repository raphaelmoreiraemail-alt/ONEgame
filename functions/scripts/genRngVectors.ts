// Regenerates shared/rng_vectors.json. Run only if the algorithm changes ON PURPOSE.
import { writeFileSync } from "node:fs";
import { SeededRandom, fnv1a32 } from "../src/core/seededRandom.js";

const seeds = [0, 1, 42, 2938471923, 4294967295];
const labels = ["", "a", "minigolf:hole2", "penalty:keeper", "éàü⛳"];
const vectors = {
  hashes: labels.map((label) => ({ label, hash: fnv1a32(label) })),
  sequences: seeds.map((seed) => {
    const r = new SeededRandom(seed);
    return { seed, uint32: Array.from({ length: 8 }, () => r.nextUint32()) };
  }),
  derived: seeds.map((seed) => {
    const r = SeededRandom.derive(seed, "minigolf:hole2");
    return { seed, label: "minigolf:hole2", uint32: Array.from({ length: 4 }, () => r.nextUint32()) };
  }),
  helpers: (() => {
    const r = new SeededRandom(2938471923);
    return {
      seed: 2938471923,
      nextInt100: Array.from({ length: 6 }, () => r.nextInt(100)),
      intInRange_10_20: Array.from({ length: 6 }, () => r.intInRange(10, 20)),
      shuffled: r.shuffled([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    };
  })(),
};
writeFileSync(new URL("../../shared/rng_vectors.json", import.meta.url), JSON.stringify(vectors, null, 2) + "\n");
console.log("wrote shared/rng_vectors.json");
