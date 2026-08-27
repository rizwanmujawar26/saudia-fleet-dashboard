#!/usr/bin/env bash
# One-command session start: everything needed to answer "where do things stand".
#
# This is the mechanical half of the RESUME protocol (see PROJECT_HANDOFF.md).
# It only reads — no writes, no deploys — so it is safe to run repeatedly.
#
#   ./scripts/resume.sh
#
# Honours FLEET_PROJECT / FLEET_DB_URL / FLEET_LIVE_URL like the other scripts.
#
# ⚠️ It deliberately carries NO node list. Node coverage is verify-deployment.sh's
#    job and is delegated to it below, so adding a node stays four edits (rules,
#    backup.sh, restore.sh, verify-deployment.sh) and never becomes five.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${FLEET_PROJECT:-saudia-fleet-dashboard}"
DB="${FLEET_DB_URL:-https://${PROJECT}-default-rtdb.firebaseio.com}"
LIVE="${FLEET_LIVE_URL:-https://rizwanmujawar26.github.io/saudia-fleet-dashboard/index.html}"
BACKUP_HOME="${FLEET_BACKUP_HOME:-$HOME/Documents/fleet-backups}"
warn=0

ok()   { printf '  \033[32m✓\033[0m %-52s %s\n' "$1" "${2:-}"; }
bad()  { printf '  \033[31m✗\033[0m %-52s %s\n' "$1" "${2:-}"; warn=$((warn+1)); }
note() { printf '  \033[33m•\033[0m %-52s %s\n' "$1" "${2:-}"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

printf '\033[1mSaudia Connectivity Fleet Status — resume\033[0m\n'
printf '%s\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"

# ---------------------------------------------------------------- release
head_ "Release"
v="$(grep -m1 "APP_VERSION" "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
b="$(grep -m1 "APP_BUILD"   "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
e="$(grep -m1 "APP_ENV"     "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
d="$(grep -m1 "APP_DEPLOYED" "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
ok "v$v" "build $b · $e · deployed $d"

# ---------------------------------------------------------------- git
head_ "Git"
cd "$ROOT" || exit 1
git log --oneline -5 | sed 's/^/    /'
echo
if [ -z "$(git status --porcelain)" ]; then
  ok "working tree clean"
else
  bad "working tree DIRTY" "$(git status --porcelain | wc -l | tr -d ' ') file(s)"
  git status --porcelain | sed 's/^/      /'
fi
git fetch --quiet origin 2>/dev/null
ahead="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"
behind="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
if [ "$ahead" = "0" ] && [ "$behind" = "0" ]; then
  ok "in sync with origin/main" "$(git rev-parse --short HEAD)"
else
  bad "NOT in sync with origin/main" "$ahead ahead, $behind behind"
fi

# ---------------------------------------------------------------- deployment
head_ "Deployment checks"
verify_out="$("$ROOT/scripts/verify-deployment.sh" "$PROJECT" 2>&1)"
echo "$verify_out" | sed -n '/Reachability/,$p' | sed 's/^/  /'
echo "$verify_out" | grep -q "0 failed" || { warn=$((warn+1)); }

# ---------------------------------------------------------------- live page
head_ "Live page — proof by hash, never by build status"
local_h="$(shasum -a 256 "$ROOT/index.html" | awk '{print $1}')"
live_h="$(curl -sL --max-time 30 "$LIVE" | shasum -a 256 | awk '{print $1}')"
if [ "$local_h" = "$live_h" ]; then
  ok "live index.html == local" "${local_h:0:16}…"
else
  bad "LIVE DIFFERS FROM LOCAL" "deploy has not landed"
  printf '      local %s\n      live  %s\n' "$local_h" "$live_h"
fi

# ---------------------------------------------------------------- live figures
# Content breakdowns for "Where things stand". NOT a node coverage list —
# these are the headline splits the handoff quotes, and the doc's own warning
# applies: the user edits live, so read them, never quote them from memory.
head_ "Live figures (read now — the user edits constantly)"
curl -s --max-time 30 "$DB/fleet.json" | python3 -c "
import json,sys,collections
try: d=json.load(sys.stdin) or {}
except Exception: print('  fleet: unreadable'); raise SystemExit
s=collections.Counter(v.get('fleetStatus') for v in d.values())
f=collections.Counter(v.get('fit') for v in d.values())
print('  aircraft      %d  —  %s' % (len(d), ', '.join('%d %s'%(n,k) for k,n in s.most_common())))
print('  fit           %s' % ', '.join('%d %s'%(n,k) for k,n in f.most_common()))
" 2>/dev/null
curl -s --max-time 30 "$DB/mediaLoads.json" | python3 -c "
import json,sys,collections
try: d=json.load(sys.stdin) or {}
except Exception: print('  mediaLoads: unreadable'); raise SystemExit
c=collections.Counter(v.get('cycle') or 'DEV/none' for v in d.values())
print('  media loads   %d  —  %s' % (len(d), ', '.join('%d x %s'%(n,k) for k,n in c.most_common())))
" 2>/dev/null
curl -s --max-time 30 "$DB/units.json" | python3 -c "
import json,sys,collections
try: d=json.load(sys.stdin) or {}
except Exception: print('  units: unreadable'); raise SystemExit
l=collections.Counter(v.get('lruId') for v in d.values())
top=', '.join('%d %s'%(n,k) for k,n in l.most_common(4))
print('  units         %d  —  %s' % (len(d), top))
" 2>/dev/null

# ---------------------------------------------------------------- backups
head_ "Backups"
if [ -d "$BACKUP_HOME" ]; then
  # A snapshot is a folder with a manifest.json — that is what restore.sh verifies
  # against. Sort by mtime, not by name: backup-secrets.sh writes a `secrets` folder
  # that is NOT a data snapshot, and it sorts after every dated one alphabetically.
  latest="$(find "$BACKUP_HOME" -maxdepth 2 -name manifest.json -print0 2>/dev/null \
            | xargs -0 stat -f '%m %N' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
  if [ -n "$latest" ]; then
    dir="$(dirname "$latest")"
    n="$(ls -1 "$dir"/*.json 2>/dev/null | wc -l | tr -d ' ')"
    age="$(( ( $(date +%s) - $(stat -f %m "$latest") ) / 86400 ))"
    ok "latest snapshot" "$(basename "$dir") · $n files · ${age}d old"
    [ "$age" -gt 7 ] && note "snapshot is over a week old" "consider ./scripts/backup.sh"
  else
    bad "no snapshot with a manifest found in $BACKUP_HOME"
  fi
else
  bad "backup dir missing" "$BACKUP_HOME"
fi

# ---------------------------------------------------------------- open items
head_ "Open items — ask, don't guess"
sed -n '/^### Waiting on the user/,/^### Ideas raised/p' "$ROOT/PROJECT_HANDOFF.md" \
  | grep '^- \*\*' | sed 's/^- \*\*/  · /; s/\*\*.*//' | head -12

head_ "Result"
if [ "$warn" -eq 0 ]; then
  printf '  \033[32mAll clear — safe to start work.\033[0m\n\n'
  exit 0
else
  printf '  \033[31m%d thing(s) need attention before changing anything.\033[0m\n\n' "$warn"
  exit 1
fi
