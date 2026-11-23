import { describe, expect, it } from "vitest";
import { checkPseudo, normalizeForFilter } from "../src/core/pseudo.js";
import { friendshipId, inviteCode, percentile, rankEntries } from "../src/core/social.js";

describe("pseudo", () => {
  it("length and charset", () => {
    expect(checkPseudo("ab")).toBe("length");
    expect(checkPseudo("a".repeat(17))).toBe("length");
    expect(checkPseudo("jean dupont")).toBe("charset");
    expect(checkPseudo("Zoé")).toBe("charset");
    expect(checkPseudo("Raph_42")).toBeNull();
    expect(checkPseudo("the.cat-9")).toBeNull();
  });
  it("insult filter with leetspeak", () => {
    expect(normalizeForFilter("C0nn4rd!")).toBe("connard");
    expect(checkPseudo("C0nn4rd")).toBe("offensive");
    expect(checkPseudo("xxF_u_c_kxx")).toBe("offensive");
    expect(checkPseudo("pd")).toBe("length");
    expect(checkPseudo("PD.")).toBe("offensive");
    expect(checkPseudo("Speedy")).toBeNull(); // contains "pd"? no: short words match whole pseudo only
    expect(checkPseudo("Essex_fan")).toBeNull(); // short words only match the whole pseudo
  });
});

describe("social helpers", () => {
  it("friendship ids are order independent", () => {
    expect(friendshipId("b", "a")).toBe("a_b");
    expect(friendshipId("a", "b")).toBe("a_b");
  });
  it("competition ranking", () => {
    const r = rankEntries([
      { uid: "a", score: 10 }, { uid: "b", score: 30 }, { uid: "c", score: 30 }, { uid: "d", score: 5 },
    ]);
    expect(r.map((e) => [e.uid, e.rank])).toEqual([["b", 1], ["c", 1], ["a", 3], ["d", 4]]);
  });
  it("percentile", () => {
    expect(percentile(0, 100)).toBe(100);
    expect(percentile(99, 100)).toBe(0);
    expect(percentile(10, 101)).toBe(90);
    expect(percentile(0, 1)).toBe(100);
  });
  it("invite codes", () => {
    let i = 0;
    const code = inviteCode(() => i++ % 32);
    expect(code).toMatch(/^[2-9A-HJ-NP-Z]{8}$/);
  });
});
