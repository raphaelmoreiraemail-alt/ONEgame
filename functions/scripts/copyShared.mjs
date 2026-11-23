// Copies ../shared/*.json into src/shared so they ship with the functions.
import { copyFileSync, mkdirSync, readdirSync } from "node:fs";
const from = new URL("../../shared/", import.meta.url);
const to = new URL("../src/shared/", import.meta.url);
mkdirSync(to, { recursive: true });
for (const f of readdirSync(from)) if (f.endsWith(".json")) copyFileSync(new URL(f, from), new URL(f, to));
