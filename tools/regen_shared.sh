#!/usr/bin/env bash
# Regenerates the files shared by the app and the server after a change of
# the game catalog: shared/games.json, then shared/daily_vectors.json.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
(cd "$ROOT/app" && UPDATE_SHARED=1 flutter test test/shared_catalog_test.dart > /dev/null)
(cd "$ROOT/functions" && npm run --silent gen:daily-vectors)
