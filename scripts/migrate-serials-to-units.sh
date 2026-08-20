#!/usr/bin/env bash
# Move serials out of /activities and into /units, the unit register.
#
# The activity records stay exactly as they are — they are the event log, and
# nothing here deletes anything. This only creates the /units entries the same
# serials imply, so /units becomes the one place a serial's identity and its
# fitment history live.
#
# Dry run by default. Pass --apply to write. Needs no credentials to read; the
# write is admin, via the firebase CLI, same as the other data scripts.
set -euo pipefail

DB="${FLEET_DB_URL:-https://saudia-fleet-dashboard-default-rtdb.firebaseio.com}"
PROJECT="${FLEET_PROJECT:-saudia-fleet-dashboard}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -sf "$DB/activities.json" > "$TMP/activities.json"
curl -sf "$DB/units.json"      > "$TMP/units.json"
curl -sf "$DB/fleet.json"      > "$TMP/fleet.json"

python3 - "$TMP" <<'PY'
import json, sys, os, datetime, random, string

tmp = sys.argv[1]
acts  = json.load(open(f'{tmp}/activities.json')) or {}
units = json.load(open(f'{tmp}/units.json')) or {}
fleet = json.load(open(f'{tmp}/fleet.json')) or {}

# Mirrors HARDWARE_LRUS in index.html. Only the aliases are needed here, and only
# to resolve the handful of records logged BEFORE the part picker existed — those
# carry free text in details.partReplaced instead of details.lruId. The aircraft's
# own fit decides which of the two lists a match belongs to, so retrofit and
# linefit can share alias spellings without colliding.
ALIASES = {
    'retrofit': [
        ('sim', ['sim', 'sim card', 'simcard']),
        ('ife_server', ['ife server', 'ifeserver', 'ife']),
        ('modman', ['modman', 'mod man']),
        ('kandu', ['kandu']),
        ('krfu', ['krfu']),
        ('rx_antenna', ['rx antenna', 'rx ant', 'rx']),
        ('tx_antenna', ['tx antenna', 'tx ant', 'tx']),
        ('waveguide_adapter', ['waveguide adapter', 'waveguide', 'wg adapter']),
        ('coax_cable_j12', ['coax cable j12', 'coax j12', 'j12']),
        ('cwap', ['cwap', 'wap']),
    ],
    'linefit': [
        ('lf_sim', ['sim', 'sim card', 'simcard']),
        ('lf_ife_server', ['ife server', 'ifeserver', 'ife']),
        ('lf_modman', ['modman', 'mod man']),
        ('lf_kandu', ['kandu']),
        ('lf_krfu', ['krfu']),
        ('lf_rx_antenna', ['rx antenna', 'rx ant', 'rx']),
        ('lf_tx_antenna', ['tx antenna', 'tx ant', 'tx']),
    ],
}

def resolve_lru(details, tail):
    lru = details.get('lruId')
    if lru:
        return lru, False
    part = ' '.join(str(details.get('partReplaced') or '').strip().lower().split())
    if not part:
        return None, False
    fit = (fleet.get(tail) or {}).get('fit') or 'retrofit'
    for lid, al in ALIASES.get(fit, []):
        if part in al or any(a in part for a in al):
            return lid, True
    return None, False

def uid(p='u'):
    return p + datetime.datetime.now(datetime.timezone.utc).strftime('%y%m%d') + \
        ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(6))

seen  = {(u.get('lruId'), u.get('serial')) for u in units.values()}
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
out   = {}
rows  = []

for aid, a in sorted(acts.items()):
    if a.get('category') != 'hardware_rr':
        continue
    d = a.get('details') or {}
    tail = a.get('aircraft')
    pos, date = d.get('position', ''), a.get('date', '')
    if not tail:
        continue
    lru, by_alias = resolve_lru(d, tail)
    if not lru:
        continue
    # What went ON is on wing from this date; what came OFF was removed on it.
    for serial, state in ((d.get('newPart'), 'on_wing'), (d.get('oldPart'), 'removed')):
        if not serial or (lru, serial) in seen:
            continue
        seen.add((lru, serial))
        fit = {'aircraft': tail, 'state': state, 'activityId': aid, 'loggedAt': stamp}
        if pos:
            fit['position'] = pos
        if date:
            fit['removedDate' if state == 'removed' else 'fittedDate'] = date
        out[uid()] = {'lruId': lru, 'serial': serial, 'addedAt': stamp,
                      'fitments': {uid('f'): fit}}
        rows.append((lru + (' (alias)' if by_alias else ''), serial, tail, state, date or '(no date)'))

for r in rows:
    print('  %-28s %-24s %-6s %-8s %s' % r)
print('\n%d unit(s) to create.' % len(out))
json.dump(out, open(f'{tmp}/payload.json', 'w'))
PY

COUNT=$(python3 -c "import json;print(len(json.load(open('$TMP/payload.json'))))")
if [ "$COUNT" = "0" ]; then
  echo "Nothing to migrate — every serial in /activities is already in /units."
  exit 0
fi

if [ "$APPLY" = "0" ]; then
  echo
  echo "DRY RUN — nothing written. Re-run with --apply to write."
  exit 0
fi

npx --yes firebase-tools database:update /units "$TMP/payload.json" \
  --project "$PROJECT" --force
echo "Written."
