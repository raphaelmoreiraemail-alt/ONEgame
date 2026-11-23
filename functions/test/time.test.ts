import { describe, expect, it } from "vitest";
import { addDays, dayKeyFor, dayOfWeek, tzOffsetMs, weekKey, zonedToUtc } from "../src/core/time.js";

describe("time", () => {
  it("converts wall-clock times across DST", () => {
    // Paris: UTC+1 in winter, UTC+2 in summer.
    expect(new Date(zonedToUtc(2026, 1, 15, 10, 0, 0, "Europe/Paris")).toISOString()).toBe("2026-01-15T09:00:00.000Z");
    expect(new Date(zonedToUtc(2026, 7, 15, 10, 0, 0, "Europe/Paris")).toISOString()).toBe("2026-07-15T08:00:00.000Z");
    expect(new Date(zonedToUtc(2026, 3, 8, 21, 0, 0, "America/Los_Angeles")).toISOString()).toBe("2026-03-09T04:00:00.000Z");
    expect(tzOffsetMs(Date.UTC(2026, 0, 1), "Asia/Tokyo")).toBe(9 * 3600_000);
  });

  it("computes day keys per region", () => {
    const t = Date.UTC(2026, 10, 24, 23, 30); // 23:30 UTC
    expect(dayKeyFor(t, "europe")).toBe("2026-11-25");
    expect(dayKeyFor(t, "americas")).toBe("2026-11-24");
    expect(dayKeyFor(t, "asia")).toBe("2026-11-25");
    expect(dayKeyFor(t, "west")).toBe("2026-11-24");
  });

  it("day arithmetic", () => {
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
    expect(addDays("2026-03-01", -1)).toBe("2026-02-28");
    expect(dayOfWeek("2026-11-29")).toBe(0); // Sunday
    expect(weekKey("2026-01-01")).toBe("2026-W01");
    expect(weekKey("2026-12-31")).toBe("2026-W53");
    expect(weekKey("2027-01-04")).toBe("2027-W01");
  });
});
