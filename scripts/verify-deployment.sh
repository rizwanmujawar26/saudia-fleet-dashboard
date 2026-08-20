#!/usr/bin/env bash
# Health and enforcement check for a Firebase project behind this dashboard.
#
# Run it against the current project any time as a regression check, and against a
# new project after migrating. It only reads, so it is safe to run repeatedly.
#
#   ./scripts/verify-deployment.sh                 # default project
#   ./scripts/verify-deployment.sh <project-id>    # any other
set -uo pipefail

PROJECT="${1:-${FLEET_PROJECT:-saudia-fleet-dashboard}}"
DB="https://${PROJECT}-default-rtdb.firebaseio.com"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

ok()   { printf '  \033[32m✓\033[0m %-52s %s\n' "$1" "${2:-}"; pass=$((pass+1)); }
bad()  { printf '  \033[31m✗\033[0m %-52s %s\n' "$1" "${2:-}"; fail=$((fail+1)); }
code() { curl -s -o "$TMP/body" -w '%{http_code}' "$@"; }

echo "Verifying: $PROJECT"
echo "           $DB"
echo

echo "Reachability & data"
for n in fleet aircraft schedule activities hardware units; do
  c="$(code "$DB/$n.json?shallow=true")"
  if [ "$c" = "200" ]; then
    cnt="$(python3 -c "import json,sys;d=json.load(open('$TMP/body'));print(len(d) if isinstance(d,dict) else 0)" 2>/dev/null || echo '?')"
    ok "/$n readable" "$cnt records"
  elif [ "$c" = "401" ]; then
    # Not a failure: this is the expected state once reads require auth.
    ok "/$n requires auth" "(private mode)"
  else
    bad "/$n" "HTTP $c"
  fi
done
echo

echo "Enforcement — these MUST hold"
c="$(code "$DB/editors.json")"
[ "$c" = "401" ] && ok "/editors not anonymously readable" || bad "/editors is READABLE" "HTTP $c"
c="$(code "$DB/.json")"
[ "$c" = "401" ] && ok "root not anonymously readable" || bad "root is READABLE" "HTTP $c"

printf '"2.1.0"' > "$TMP/v"
c="$(curl -s -o /dev/null -w '%{http_code}' -X PUT --data-binary @"$TMP/v" "$DB/aircraft/__verify__/swVersion.json")"
[ "$c" = "401" ] && ok "anonymous write rejected" || bad "ANONYMOUS WRITE ACCEPTED" "HTTP $c"

printf '{"hacked":1}' > "$TMP/j"
c="$(curl -s -o /dev/null -w '%{http_code}' -X PUT --data-binary @"$TMP/j" "$DB/__verify__.json")"
[ "$c" = "401" ] && ok "unknown top-level node rejected" || bad "UNKNOWN NODE ACCEPTED" "HTTP $c"
echo

echo "Rules regressions — the escaping bug that blocked every Software save"
# A valid semver must be *accepted* by the deployed swVersion rule. Anonymous writes
# are always rejected, so this cannot be probed directly; check the source instead.
if [ -f "$(dirname "$0")/../database.rules.json" ]; then
  python3 - "$(dirname "$0")/../database.rules.json" <<'PY'
import json, re, sys
r = json.load(open(sys.argv[1]))['rules']
bad = []
def walk(node, path):
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ('.validate', '.write') and isinstance(v, str):
                for m in re.findall(r'/(\^.*?\$)/', v):
                    # \\ in the decoded rule means "escaped backslash", almost never
                    # what was meant — it is the bug that shipped in swVersion.
                    if '\\\\' in m:
                        bad.append(f'{path}{k}: {m}')
            elif isinstance(v, dict):
                walk(v, path + '/' + k)
walk(r, '')
if bad:
    print('  \033[31m✗\033[0m over-escaped regex (matches a literal backslash):')
    for b in bad: print('      ' + b)
    sys.exit(1)
print('  \033[32m✓\033[0m no over-escaped regexes in database.rules.json')
PY
  [ $? -eq 0 ] && pass=$((pass+1)) || fail=$((fail+1))
fi
echo

echo "Result: $pass passed, $fail failed"
[ "$fail" = "0" ] || exit 1
