#!/usr/bin/env bash
# Local data feed for Raj: reads every dashboard node fresh (locked ones as admin, via
# backup.sh) and writes one Excel workbook, one sheet per area, plus a "Changes" sheet
# listing what changed since the previous export.
#
#   ./scripts/export-feed.sh                      → ~/Documents/Saudia Fleet Feed/Saudia-Fleet-Data-DD-Mon-YYYY.xlsx
#   FLEET_FEED_DIR=/some/folder ./scripts/export-feed.sh
#
# Read-only against the database. The workbook contains serials, MACs and ICCIDs —
# share it privately only.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${FLEET_FEED_DIR:-$HOME/Documents/Saudia Fleet Feed}"
DATA="$(mktemp -d)"
trap 'rm -rf "$DATA"' EXIT

echo "Reading the live database…"
if ! FLEET_BACKUP_DIR="$DATA" ./scripts/backup.sh > "$DATA/.log" 2>&1; then
  cat "$DATA/.log" >&2
  echo "!! Read failed — no export written." >&2
  exit 1
fi

node scripts/export-feed.js "$DATA" "$OUT"
