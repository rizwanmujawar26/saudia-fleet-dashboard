#!/usr/bin/env bash
# The leanest possible session start: "quick resume nsg dashboard".
#
# This ONE command is the whole start of a session. It replaces the old two-step
# start (read CLAUDE.md whole, then run resume.sh). Its entire output is a few
# hundred tokens — the guardrails you must not relearn, plus enough live state to
# know where you are — and then it stops. Everything else is loaded on demand as
# the work reaches it (doc.sh for a handoff section, fn.sh for a function).
#
#   ./scripts/quick-resume.sh
#
# What it deliberately does NOT do, to stay cheap and fast:
#   • it does not read CLAUDE.md, PROJECT_HANDOFF.md or CHANGELOG.md — nothing big
#   • it does not hash the live page or run the 12 deployment checks or read live
#     figures over the network. That is resume.sh's job (the full, slower check) and
#     check.sh's job (before a deploy). Run those when the work actually needs them,
#     not to answer "where do I start".
#
# Read-only. Safe to run repeatedly. Honours FLEET_PROJECT like the other scripts.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${FLEET_PROJECT:-saudia-fleet-dashboard}"
LIVE="${FLEET_LIVE_URL:-https://rizwanmujawar26.github.io/saudia-fleet-dashboard/index.html}"

b()    { printf '\033[1m%s\033[0m' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

printf '\033[1mSaudia Connectivity Fleet Status — quick resume\033[0m   %s\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"

# ---------------------------------------------------------------- where
head_ "Where"
printf '  dir   %s\n' "$ROOT"
printf '        (you opened in the NSG IFEC Fleet Portal — a different app; this cd moved you)\n'
printf '  live  %s\n' "${LIVE%index.html}"
printf '  db    %s-default-rtdb\n' "$PROJECT"

# ---------------------------------------------------------------- state (no network but git fetch)
head_ "State"
v="$(grep -m1 "APP_VERSION" "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
bld="$(grep -m1 "APP_BUILD" "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
env="$(grep -m1 "APP_ENV"   "$ROOT/index.html" | sed "s/.*'\(.*\)'.*/\1/")"
printf '  v%s  build %s · %s\n' "$v" "$bld" "$env"
cd "$ROOT" || exit 1
printf '  git   %s\n' "$(git log --oneline -1)"
if [ -z "$(git status --porcelain)" ]; then
  tree="clean"
else
  tree="DIRTY ($(git status --porcelain | wc -l | tr -d ' ') file(s)) — say so before changing anything"
fi
git fetch --quiet origin 2>/dev/null
ahead="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"
behind="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
if [ "$ahead" = "0" ] && [ "$behind" = "0" ]; then
  sync="in sync with origin/main"
else
  sync="NOT in sync — $ahead ahead, $behind behind"
fi
printf '        %s · %s\n' "$tree" "$sync"

# ---------------------------------------------------------------- guardrails
head_ "Guardrails — load-bearing, do not relearn"
printf '  • Deploy without asking — rules first, then the page; prove by hash, not build status\n'
printf '  • Ask before removing anything major — a tab, a page, a feature, a data node\n'
printf '  • Dates dd-mm-yyyy in, DD-Mon-YYYY stored; <input type="date"> is banned\n'
printf '  • A new DB node = FOUR edits: rules, backup.sh, restore.sh, verify-deployment.sh\n'
printf '  • Verify in the browser, and verify the thing the USER sees\n'
printf '  • Back up before any bulk or destructive write: ./scripts/backup.sh\n'

# ---------------------------------------------------------------- on demand
head_ "Load on demand — never read a whole big file"
printf '  ./scripts/doc.sh --list | --grep <term> | <section>   PROJECT_HANDOFF.md (~38k tokens)\n'
printf '  ./scripts/fn.sh  <name> | --list | --grep | --callers  index.html (~178k tokens)\n'
printf '  ./scripts/check.sh                                     before every deploy\n'
printf '  ./scripts/resume.sh                                    full state: live hash, 12 checks, live figures\n'
printf '  CLAUDE.md                                              the fuller briefing, if you want the reasons\n'

printf '\n  Next: ask what to work on, then pull only the section the work touches.\n\n'
