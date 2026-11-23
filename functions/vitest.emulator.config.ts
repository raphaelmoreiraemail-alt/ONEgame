import { defineConfig } from "vitest/config";

/** Run through `npm run test:emulators` (Firestore emulator required). */
export default defineConfig({
  test: { include: ["test/emulator/**/*.test.ts"], fileParallelism: false, testTimeout: 20_000 },
});
