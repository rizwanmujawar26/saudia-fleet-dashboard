#!/usr/bin/env bash
# The pre-deploy checklist, as one command.
#
# There is no build, lint or type tooling in this project, deliberately. These
# are the checks that stand in for it, and until now every one was a manual grep
# that was easy to skip. Run it before every deploy.
#
#   ./scripts/check.sh
#
# It only reads. Exit 0 means safe to deploy; non-zero names what is wrong.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGE="${FLEET_PAGE:-$ROOT/index.html}"
RULES="$ROOT/database.rules.json"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

ok()  { printf '  \033[32m✓\033[0m %-54s %s\n' "$1" "${2:-}"; pass=$((pass+1)); }
bad() { printf '  \033[31m✗\033[0m %-54s %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

printf '\033[1mPre-deploy checks\033[0m\n\n'

# ---------------------------------------------------------------- 1. JS syntax
# The script block is extracted and checked on its own; node cannot parse HTML.
awk '/<script>/{f=1;next} /<\/script>/{f=0} f' "$PAGE" > "$TMP/app.js"

# MARKUP ONLY — the file minus <script> and <style>. Checking the whole file
# instead gives false positives that look exactly like real failures: `id="${a.id}"`
# is JS building markup, not a duplicate id, and the CSS carries a comment reading
# `<input type="date">` to explain why that control is banned.
awk '
  /<script>/{s=1} /<\/script>/{s=0;next}
  /<style>/ {y=1} /<\/style>/ {y=0;next}
  !s && !y
' "$PAGE" > "$TMP/markup.html"
if node --check "$TMP/app.js" 2>"$TMP/err"; then
  ok "script block parses" "$(wc -l < "$TMP/app.js" | tr -d ' ') lines"
else
  bad "SCRIPT BLOCK HAS A SYNTAX ERROR"
  sed 's/^/      /' "$TMP/err" | head -6
fi

# ---------------------------------------------------------------- 2. rules JSON
if python3 -c "import json;json.load(open('$RULES'))" 2>"$TMP/err"; then
  ok "database.rules.json is valid JSON"
else
  bad "RULES ARE NOT VALID JSON"; sed 's/^/      /' "$TMP/err" | head -3
fi

# ---------------------------------------------------------------- 3. duplicate ids
dups="$(grep -oE 'id="[^"]+"' "$TMP/markup.html" | grep -v '\${' | sort | uniq -d)"
if [ -z "$dups" ]; then
  ok "no duplicate DOM ids" "$(grep -coE 'id="[^"]+"' "$TMP/markup.html" | tr -d ' ') ids"
else
  bad "DUPLICATE DOM IDS"; printf '      %s\n' $dups | head -8
fi

# ---------------------------------------------------------------- 4. handlers exist
# Every onclick/onchange/oninput named in the markup must exist in the script.
grep -oE 'on(click|change|input|submit)="[a-zA-Z_$][a-zA-Z0-9_$]*\(' "$PAGE" \
  | sed 's/.*"//; s/($//; s/(//' | sort -u > "$TMP/handlers"
missing=""
while IFS= read -r h; do
  [ -z "$h" ] && continue
  grep -qE "(function[[:space:]]+$h[[:space:]]*\(|(const|let|var)[[:space:]]+$h[[:space:]]*=)" "$TMP/app.js" \
    || missing="$missing $h"
done < "$TMP/handlers"
if [ -z "$missing" ]; then
  ok "every inline handler exists" "$(wc -l < "$TMP/handlers" | tr -d ' ') handlers"
else
  bad "HANDLERS NAMED IN MARKUP BUT NOT DEFINED"; printf '      %s\n' $missing
fi

# ---------------------------------------------------------------- 5. project rules
printf '\n\033[1mProject rules that can be checked mechanically\033[0m\n'

# Never <input type="date"> — its display format follows the browser locale.
# Match real markup only: the CSS carries a comment explaining the ban.
n="$(grep -coE '<input[^>]*type="date"' "$TMP/markup.html" | tr -d ' ')"
[ "$n" = "0" ] && ok "no <input type=\"date\">" "day-first is not negotiable" \
                || bad "FOUND $n <input type=\"date\">" "browser locale wins — use a text input"

# A sort direction is a numeric multiplier; 'asc' makes every compare NaN.
n="$(grep -coE "dir: *'(asc|desc)'" "$PAGE" | tr -d ' ')"
[ "$n" = "0" ] && ok "no string sort directions" "dir is 1 or -1" \
                || bad "FOUND $n STRING SORT DIRECTION(S)" "dir * (a-b) becomes NaN"

# No external scripts, ever — the page is self-contained by design.
n="$(grep -coE '<(script|link)[^>]+(src|href)="https?://' "$TMP/markup.html" | tr -d ' ')"
[ "$n" = "0" ] && ok "no external assets" "page stays self-contained" \
                || bad "FOUND $n EXTERNAL ASSET REFERENCE(S)"

# Release identity has one home.
v="$(grep -m1 "APP_VERSION" "$PAGE" | sed "s/.*'\(.*\)'.*/\1/")"
[ -n "$v" ] && ok "APP_VERSION present" "v$v" || bad "APP_VERSION MISSING"

# ---------------------------------------------------------------- 6. edit sanity
# A scripted edit once produced a 17-million-line file and another deleted 19
# functions. Both were caught by comparing against HEAD straight afterwards.
printf '\n\033[1mEdit sanity — against HEAD\033[0m\n'
cur_l=$(wc -l < "$PAGE" | tr -d ' ')
if git -C "$ROOT" cat-file -e HEAD:index.html 2>/dev/null; then
  git -C "$ROOT" show HEAD:index.html > "$TMP/head.html"
  old_l=$(wc -l < "$TMP/head.html" | tr -d ' ')
  d=$(( cur_l - old_l )); ad=${d#-}
  if [ "$ad" -gt 2000 ]; then
    bad "LINE COUNT MOVED BY $d" "$old_l → $cur_l — check this was intended"
  else
    ok "line count sane" "$old_l → $cur_l ($d)"
  fi
  awk '/<script>/{f=1;next} /<\/script>/{f=0} f' "$TMP/head.html" > "$TMP/head.js"
  o=$(grep -cE '^\s*function [A-Za-z_$]' "$TMP/head.js" | tr -d ' ')
  c=$(grep -cE '^\s*function [A-Za-z_$]' "$TMP/app.js" | tr -d ' ')
  if [ "$c" -lt "$o" ]; then
    bad "FUNCTION COUNT FELL $o → $c" "$(( o - c )) gone — intended?"
    diff <(grep -oE '^\s*function [A-Za-z_$][A-Za-z0-9_$]*' "$TMP/head.js" | awk '{print $2}' | sort) \
         <(grep -oE '^\s*function [A-Za-z_$][A-Za-z0-9_$]*' "$TMP/app.js"  | awk '{print $2}' | sort) \
         | grep '^<' | sed 's/^</      removed:/' | head -10
  else
    ok "function count" "$o → $c"
  fi
else
  ok "no HEAD:index.html to compare" "(first commit?)"
fi

printf '\n\033[1mResult\033[0m\n'
if [ "$fail" -eq 0 ]; then
  printf '  \033[32m%d passed. Browser check is the one thing left — verify what the USER sees.\033[0m\n\n' "$pass"
  exit 0
fi
printf '  \033[31m%d passed, %d FAILED — do not deploy.\033[0m\n\n' "$pass" "$fail"
exit 1
