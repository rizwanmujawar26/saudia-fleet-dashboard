#!/usr/bin/env bash
# Move the dashboard to a different Firebase project.
#
# Dry-run by default, like restore.sh — it will not touch the target without
# --apply, and it never touches the SOURCE project at all.
#
#   ./scripts/migrate-project.sh <new-project-id>
#   ./scripts/migrate-project.sh <new-project-id> --apply
#   ./scripts/migrate-project.sh <new-project-id> --apply --snapshot backups/2026-08-20
#
# What it does NOT do, because these need the console or a human decision:
#   - create the project or the database instance
#   - enable Email/Password sign-in
#   - create accounts (deliberate: passwords are reset, not carried across)
set -euo pipefail

TARGET="${1:-}"; shift || true
APPLY=0; SNAP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --snapshot) shift; SNAP="$1" ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac; shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${FLEET_PROJECT:-saudia-fleet-dashboard}"
[ -n "$TARGET" ] || { echo "usage: migrate-project.sh <new-project-id> [--apply] [--snapshot DIR]" >&2; exit 2; }
[ "$TARGET" != "$SOURCE" ] || { echo "target and source are the same project" >&2; exit 2; }

TDB="https://${TARGET}-default-rtdb.firebaseio.com"
echo "Source : $SOURCE  (never written to by this script)"
echo "Target : $TARGET"
echo "         $TDB"
echo

# --- 1. a snapshot to move ---------------------------------------------------
if [ -z "$SNAP" ]; then
  SNAP="$ROOT/backups/$(date -u +%Y-%m-%d)"
  if [ ! -f "$SNAP/manifest.json" ]; then
    echo "No snapshot for today. Taking one from $SOURCE ..."
    [ "$APPLY" = "1" ] && "$ROOT/scripts/backup.sh" >/dev/null \
      || echo "  (dry run — would run scripts/backup.sh)"
  fi
fi
if [ -f "$SNAP/manifest.json" ]; then
  echo "Snapshot: $SNAP"
  python3 -c "
import json,sys
m=json.load(open('$SNAP/manifest.json'))
print('  taken', m['takenAtUTC'])
for f,meta in sorted(m['files'].items()):
    if f != 'database.rules.json': print(f\"  {f[:-5]:<12} {meta['records']} records\")"
else
  echo "Snapshot: $SNAP  (does not exist yet)"
fi
echo

# --- 2. is the target reachable? ---------------------------------------------
echo "Target preflight"
c="$(curl -s -o /dev/null -w '%{http_code}' "$TDB/.json" || echo 000)"
case "$c" in
  401) echo "  ✓ database instance responds (401 = exists, rules deny anon root read)";;
  200) echo "  ! database responds 200 on root — rules are wide open, deploying ours will fix it";;
  404|000) echo "  ✗ no database at $TDB"
           echo "    Create the project and a Realtime Database instance first."; exit 1;;
  *)   echo "  ? unexpected HTTP $c";;
esac
echo

# --- 3. plan -----------------------------------------------------------------
echo "Plan"
echo "  1. deploy database.rules.json  -> $TARGET"
echo "  2. restore data from snapshot  -> $TARGET"
echo "  3. verify enforcement on       -> $TARGET"
echo "  4. print the manual steps left"
echo

if [ "$APPLY" != "1" ]; then
  echo "DRY RUN — nothing was written. Re-run with --apply."
  exit 0
fi

printf "Type the TARGET project id to continue: "
read -r confirm
[ "$confirm" = "$TARGET" ] || { echo "Aborted."; exit 1; }
echo

echo "[1/3] Deploying rules ..."
( cd "$ROOT" && npx --yes firebase-tools deploy --only database --project "$TARGET" >/dev/null 2>&1 ) \
  && echo "      ok" || { echo "      FAILED" >&2; exit 1; }

echo "[2/3] Restoring data ..."
FLEET_PROJECT="$TARGET" "$ROOT/scripts/restore.sh" "$SNAP" --apply <<< "$TARGET" >/dev/null \
  && echo "      ok" || { echo "      FAILED" >&2; exit 1; }

echo "[3/3] Verifying ..."
"$ROOT/scripts/verify-deployment.sh" "$TARGET" || true
echo

cat <<EOF
Still to do by hand — none of these can be scripted safely:

  1. Firebase console -> Authentication -> enable Email/Password.

  2. Create each editor's account there. Passwords are NOT carried across:
     moving password hashes is worse than a reset, and there are few editors.

  3. Add their NEW uids to the allowlist — uids differ between projects, so the
     old ones are meaningless here:
       npx --yes firebase-tools database:update /editors --project $TARGET \\
         --data '{"<new-uid>": true}'

  4. Point the app at the new project. Two constants in index.html:
       const FIREBASE_DB_URL  = '$TDB';
       const FIREBASE_API_KEY = '<new web api key>';
     (console -> Project settings -> General -> Web API Key)

  5. Re-run ./scripts/verify-deployment.sh $TARGET and sign in to confirm a write.

  6. Only once all of the above passes, retire the old project.
EOF
