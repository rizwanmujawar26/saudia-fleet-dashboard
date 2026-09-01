#!/usr/bin/env bash
# Restore a snapshot taken by backup.sh back into the Realtime Database.
#
# This is the destructive half, so it is deliberately awkward:
#   - dry run is the DEFAULT; nothing is written without --apply
#   - it takes a safety backup of the current state first, always
#   - it names every node and record count before touching anything
#   - --apply requires typing the project id to confirm
#
# Needs the firebase CLI (admin), because a restore writes as owner and bypasses
# the rules — which is what you want when the rules themselves may be the problem.
#
#   ./scripts/restore.sh backups/2026-08-20              # show what would happen
#   ./scripts/restore.sh backups/2026-08-20 --apply      # actually do it
#   ./scripts/restore.sh backups/2026-08-20 --apply --only aircraft,fleet
set -euo pipefail

SNAP="${1:-}"
shift || true
APPLY=0
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --only)  shift; ONLY="$1" ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

PROJECT="${FLEET_PROJECT:-saudia-fleet-dashboard}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -n "$SNAP" ] || { echo "usage: restore.sh <snapshot-dir> [--apply] [--only a,b]" >&2; exit 2; }
[ -d "$SNAP" ] || SNAP="$ROOT/$SNAP"
[ -d "$SNAP" ] || { echo "no such snapshot: $SNAP" >&2; exit 2; }
[ -f "$SNAP/manifest.json" ] || { echo "not a snapshot (no manifest.json): $SNAP" >&2; exit 2; }

echo "Snapshot: $SNAP"
python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))
print('Taken   :', m['takenAtUTC'])
print('Source  :', m['source'])" "$SNAP/manifest.json"
echo "Target  : $PROJECT"
echo

# Verify the snapshot is intact before trusting it with anything.
python3 - "$SNAP" <<'PY'
import json, os, sys, hashlib
snap = sys.argv[1]
man = json.load(open(os.path.join(snap, 'manifest.json')))
bad = []
for f, meta in man['files'].items():
    p = os.path.join(snap, f)
    if not os.path.exists(p):
        bad.append(f'{f}: missing'); continue
    raw = open(p, 'rb').read()
    if hashlib.sha256(raw).hexdigest() != meta['sha256']:
        bad.append(f'{f}: checksum mismatch')
if bad:
    print('SNAPSHOT IS CORRUPT:'); [print('  ' + b) for b in bad]; sys.exit(1)
print('Snapshot integrity: OK (all checksums match)')
PY
echo

NODES="fleet aircraft activities hardware units mediaLoads modmans visits"
[ -z "$ONLY" ] || NODES="$(echo "$ONLY" | tr ',' ' ')"

echo "Would restore:"
for node in $NODES; do
  f="$SNAP/$node.json"
  [ -f "$f" ] || { printf '  -- %-12s not in this snapshot, skipping\n' "$node"; continue; }
  have="$(curl -sS "https://${PROJECT}-default-rtdb.firebaseio.com/$node.json?shallow=true" \
          | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,dict) else 0)" 2>/dev/null || echo '?')"
  want="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print(len(d) if isinstance(d,(dict,list)) else 0)" "$f")"
  printf '  /%-12s live now: %-5s  ->  from snapshot: %s\n' "$node" "$have" "$want"
done
echo

if [ "$APPLY" != "1" ]; then
  echo "DRY RUN — nothing was written. Re-run with --apply to restore."
  exit 0
fi

echo "This OVERWRITES the nodes listed above in project '$PROJECT'."
printf "Type the project id to continue: "
read -r confirm
[ "$confirm" = "$PROJECT" ] || { echo "Aborted."; exit 1; }

echo
echo "Taking a safety backup of the CURRENT state first..."
# Its own folder, never today's: restoring today's snapshot would otherwise have the
# safety copy overwrite the very thing being restored from.
SAFETY="$ROOT/backups/pre-restore-$(date -u +%Y-%m-%dT%H%M%SZ)"
FLEET_BACKUP_DIR="$SAFETY" FLEET_DB_URL="https://${PROJECT}-default-rtdb.firebaseio.com" \
  "$ROOT/scripts/backup.sh" >/dev/null
echo "  saved to ${SAFETY#$ROOT/}"
echo

for node in $NODES; do
  f="$SNAP/$node.json"
  [ -f "$f" ] || continue
  echo "  restoring /$node ..."
  npx --yes firebase-tools database:set "/$node" "$f" --project "$PROJECT" --force >/dev/null 2>&1 \
    && echo "    ok" || { echo "    FAILED on /$node" >&2; exit 1; }
done

echo
echo "Restore complete. Rules are NOT restored automatically —"
echo "if they need it too:  npx --yes firebase-tools deploy --only database --project $PROJECT"
echo "(the snapshot's copy is at $SNAP/database.rules.json)"
