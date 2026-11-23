#!/usr/bin/env bash
# Runs every check required before a commit. Exits non-zero on any failure.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
flutter test --timeout 200s
cd "$ROOT/functions"
npm run --silent lint
npm test --silent
npm run --silent test:emulators > /tmp/onegame-emulators.log 2>&1 || { tail -40 /tmp/onegame-emulators.log; exit 1; }
echo "ALL CHECKS PASSED"
