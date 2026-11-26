#!/usr/bin/env bash
# Capture the two things scripts/backup.sh cannot: the editor allowlist and who
# the accounts behind it are. Both need admin (firebase CLI login).
#
# Deliberately does NOT export password hashes. They are the most sensitive thing
# in the project, and with a handful of editors a password reset in the new project
# is safer than carrying hash material around. Use `firebase auth:export` directly
# if you ever genuinely need them.
#
# Refuses to write anywhere inside the repo — this output must not reach git.
set -euo pipefail

PROJECT="${FLEET_PROJECT:-saudia-fleet-dashboard}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-${FLEET_SECRETS_DIR:-}}"

if [ -z "$OUT" ]; then
  echo "usage: backup-secrets.sh <private-output-dir>" >&2
  echo "  e.g. ./scripts/backup-secrets.sh ~/Documents/fleet-backups/secrets" >&2
  exit 2
fi
# Resolve BEFORE creating anything, or a refused path still leaves a directory behind.
ABS="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd)/$(basename "$OUT")"
case "$ABS" in
  "$ROOT"|"$ROOT"/*)
    echo "REFUSING: $ABS is inside the repo. This output must never reach git." >&2
    exit 1 ;;
esac
mkdir -p "$ABS"
OUT="$ABS"

STAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
echo "Project : $PROJECT"
echo "Output  : $OUT"

npx --yes firebase-tools database:get /editors --project "$PROJECT" 2>/dev/null \
  > "$OUT/editors-$STAMP.json"
n="$(python3 -c "
import json
d = json.load(open('$OUT/editors-$STAMP.json')) or {}
print(len(d))")"
echo "  ok editors            $n uid(s)"

# Read-only accounts (v2.245.0): may see the locked registers, cannot edit.
npx --yes firebase-tools database:get /viewers --project "$PROJECT" 2>/dev/null \
  > "$OUT/viewers-$STAMP.json"
n="$(python3 -c "
import json
d = json.load(open('$OUT/viewers-$STAMP.json')) or {}
print(len(d))")"
echo "  ok viewers            $n uid(s)"

# Passcode viewers (v2.250.0): name + 6-digit code per read-only account. Holds the
# codes themselves, so it lives here with the other secrets, never in backup.sh or
# the feed.
npx --yes firebase-tools database:get /passcodes --project "$PROJECT" 2>/dev/null \
  > "$OUT/passcodes-$STAMP.json"
n="$(python3 -c "
import json
d = json.load(open('$OUT/passcodes-$STAMP.json')) or {}
print(len(d))")"
echo "  ok passcodes          $n passcode(s)"

# The admin (v2.253.0): may see who is online and the sign-in history. CLI-only.
npx --yes firebase-tools database:get /admins --project "$PROJECT" 2>/dev/null \
  > "$OUT/admins-$STAMP.json"
echo "  ok admins             $(python3 -c "import json; print(len(json.load(open('$OUT/admins-$STAMP.json')) or {}))") uid(s)"

# Accounts, minus anything secret — enough to rebuild the allowlist, not enough to
# impersonate anyone.
TMPU="$(mktemp)"
npx --yes firebase-tools auth:export "$TMPU" --format=json --project "$PROJECT" >/dev/null 2>&1
python3 - "$TMPU" "$OUT/accounts-$STAMP.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
users = json.load(open(src)).get('users', [])
safe = [{
    'uid': u.get('localId'),
    'email': u.get('email'),
    'emailVerified': u.get('emailVerified'),
    'createdAt': u.get('createdAt'),
    'lastSignedInAt': u.get('lastSignedInAt'),
} for u in users]
json.dump({'note': 'Password material deliberately omitted.', 'accounts': safe},
          open(dst, 'w'), indent=2)
print(f"  ok accounts           {len(safe)} account(s), no password material")
PY
rm -f "$TMPU"

chmod 600 "$OUT"/editors-"$STAMP".json "$OUT"/viewers-"$STAMP".json "$OUT"/passcodes-"$STAMP".json "$OUT"/admins-"$STAMP".json "$OUT"/accounts-"$STAMP".json
echo "Done. Keep this directory out of any repo and off shared storage."
