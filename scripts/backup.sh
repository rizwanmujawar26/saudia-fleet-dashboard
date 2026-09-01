#!/usr/bin/env bash
# Snapshot every readable node of the Realtime Database to backups/<UTC date>/.
#
# Uses anonymous reads only, so it needs NO credentials and runs anywhere — this
# machine, a CI runner, a future host. That is deliberate: a backup that depends on
# a secret is one expired token away from silently not happening.
#
# NOT captured: /editors. It is readable only by the account it belongs to, by
# design. Keep the editor uid list somewhere else; see DISASTER-RECOVERY.md.
set -euo pipefail

DB="${FLEET_DB_URL:-https://saudia-fleet-dashboard-default-rtdb.firebaseio.com}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y-%m-%d)"
# FLEET_BACKUP_DIR lets a caller aim somewhere other than today's folder. restore.sh
# uses it so a pre-restore safety copy cannot overwrite the snapshot being restored.
OUT="${FLEET_BACKUP_DIR:-$ROOT/backups/$STAMP}"
NODES="fleet aircraft activities hardware units mediaLoads modmans visits"

mkdir -p "$OUT"
echo "Backing up $DB"
echo "        -> $OUT"

fail=0
for node in $NODES; do
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' "$DB/$node.json?print=pretty")"
  if [ "$code" != "200" ]; then
    echo "  !! $node — HTTP $code" >&2; fail=1; rm -f "$body"; continue
  fi
  # "null" is a legitimately empty node, but an error object is not.
  if grep -q '"error"' "$body"; then
    echo "  !! $node — $(cat "$body")" >&2; fail=1; rm -f "$body"; continue
  fi
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$body" \
    || { echo "  !! $node — invalid JSON" >&2; fail=1; rm -f "$body"; continue; }
  mv "$body" "$OUT/$node.json"
  n="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print(len(d) if isinstance(d,(dict,list)) else ('empty' if d is None else 1))" "$OUT/$node.json")"
  printf '  ok %-12s %s records\n' "$node" "$n"
done

# The rules are part of the system's state — a restore without them is half a restore.
cp "$ROOT/database.rules.json" "$OUT/database.rules.json"
echo "  ok rules"

# A manifest makes a snapshot self-describing years later.
python3 - "$OUT" "$DB" <<'PY'
import json, os, sys, datetime, hashlib
out, db = sys.argv[1], sys.argv[2]
files = sorted(f for f in os.listdir(out) if f.endswith('.json') and f != 'manifest.json')
man = {
    'takenAtUTC': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'source': db,
    'note': '/editors is not included: it is not anonymously readable by design.',
    'files': {},
}
for f in files:
    p = os.path.join(out, f)
    raw = open(p, 'rb').read()
    d = json.loads(raw)
    man['files'][f] = {
        'records': len(d) if isinstance(d, (dict, list)) else (0 if d is None else 1),
        'bytes': len(raw),
        'sha256': hashlib.sha256(raw).hexdigest(),
    }
json.dump(man, open(os.path.join(out, 'manifest.json'), 'w'), indent=2)
print('  ok manifest')
PY

[ "$fail" = "0" ] || { echo "BACKUP INCOMPLETE — see errors above" >&2; exit 1; }
echo "Backup complete: $OUT"
