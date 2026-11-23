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
echo "ALL CHECKS PASSED"
