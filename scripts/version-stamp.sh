#!/usr/bin/env bash
# Write version.json from the release identity in index.html.
#
# version.json ships in the same GitHub Pages deploy as index.html and is what an
# already-open tab polls to learn a newer build exists (see startVersionWatch in the
# page). It is DERIVED from APP_BUILD / APP_VERSION — the one home for release
# identity — so it can never disagree with the page it ships beside.
#
#   ./scripts/version-stamp.sh
#
# Run it after bumping APP_VERSION / APP_BUILD and before committing. check.sh fails
# the deploy if version.json has drifted, so a forgotten stamp cannot ship silently.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGE="${FLEET_PAGE:-$ROOT/index.html}"
OUT="$ROOT/version.json"

build="$(grep -m1 "APP_BUILD" "$PAGE"   | sed "s/.*'\(.*\)'.*/\1/")"
ver="$(grep -m1 "APP_VERSION" "$PAGE"   | sed "s/.*'\(.*\)'.*/\1/")"

if [ -z "$build" ] || [ -z "$ver" ]; then
  echo "version-stamp: could not read APP_BUILD / APP_VERSION from $PAGE" >&2
  exit 1
fi

printf '{\n  "build": "%s",\n  "version": "%s"\n}\n' "$build" "$ver" > "$OUT"
echo "version.json ← build $build · v$ver"
