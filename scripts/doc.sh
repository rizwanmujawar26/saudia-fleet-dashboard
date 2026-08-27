#!/usr/bin/env bash
# Pull ONE section out of the project documentation, instead of reading all of it.
#
# The handoff is a ~49,000-token reference manual. Reading it whole to answer a
# question about one tab costs a quarter of a context window before any work
# starts — which is exactly what this exists to stop.
#
#   ./scripts/doc.sh --list              # every section, with its size
#   ./scripts/doc.sh media               # the Media section
#   ./scripts/doc.sh "sticky header"     # heading match, case-insensitive
#   ./scripts/doc.sh --all sort          # every match, not just the first
#
# Matches ## and ### headings across the handoff, the runbook and the change log.
# ⚠️ It matches HEADINGS, never line numbers — line numbers rot on the first edit.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS=("$ROOT/PROJECT_HANDOFF.md" "$ROOT/DISASTER-RECOVERY.md" "$ROOT/CHANGELOG.md")

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
[ $# -eq 0 ] && usage 1

ALL=0
[ "${1:-}" = "--all" ] && { ALL=1; shift; }

# --------------------------------------------------------------- --list
if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  # ⚠️ A ## figure is its WHOLE SUBTREE — what `doc.sh <that section>` actually
  # costs. Measuring heading-to-next-heading instead reported "Data model" as 50
  # tokens when pulling it costs 3,300, which is worse than no number at all.
  python3 - "${DOCS[@]}" <<'PY'
import os, re, sys

print('\033[1m%-54s %7s %8s\033[0m' % ('SECTION', 'LINES', '~TOKENS'))
grand = 0
for path in sys.argv[1:]:
    if not os.path.exists(path):
        continue
    lines = open(path).read().split('\n')
    grand += sum(len(l) + 1 for l in lines)
    heads = [(i, len(m.group(1)), l[m.end():].strip())
             for i, l in enumerate(lines)
             for m in [re.match(r'(#{2,3}) ', l)] if m]
    print('\n\033[1m%s\033[0m' % os.path.basename(path))
    for n, (start, lvl, title) in enumerate(heads):
        end = len(lines)
        for s2, l2, _ in heads[n + 1:]:
            if l2 <= lvl:                      # same or higher level closes it
                end = s2
                break
        body = lines[start:end]
        tok = sum(len(l) + 1 for l in body) // 4
        indent = '  ' if lvl == 2 else '    · '
        width = 52 if lvl == 2 else 48
        print('%s%-*s %7d %8d' % (indent, width, title[:width], end - start, tok))
print('\n  \033[33mReading everything costs ~%d tokens. Pull one section instead.\033[0m\n' % (grand // 4))
PY
  exit 0
fi

# --------------------------------------------------------------- section match
Q="$*"
found=0
for f in "${DOCS[@]}"; do
  [ -f "$f" ] || continue
  # Collect the heading lines that match, then print each from its heading to the
  # next heading of the SAME OR HIGHER level (## stops at ##, ### stops at ## or ###).
  while IFS=: read -r ln head; do
    [ -z "$ln" ] && continue
    level="$(printf '%s' "$head" | awk '{print length($1)}')"
    body="$(awk -v start="$ln" -v lvl="$level" '
      NR < start { next }
      NR == start { print; next }
      /^#+ / {
        match($0, /^#+/); h = RLENGTH
        if (h <= lvl) exit
      }
      { print }
    ' "$f")"
    printf '\033[1m─── %s ───\033[0m\n' "$(basename "$f")"
    printf '%s\n\n' "$body"
    found=$((found+1))
    [ "$ALL" -eq 0 ] && exit 0
  # grep -n already emits "lineno:heading"; the heading keeps any colons of its
  # own because `head` is the last read field. BSD cut has no --output-delimiter,
  # so do not reintroduce one here.
  done < <(grep -niE "^#{2,3} .*${Q}" "$f")
done

if [ "$found" -eq 0 ]; then
  printf '\033[31mNo section heading matches "%s".\033[0m\n\n' "$Q" >&2
  printf 'Try:  ./scripts/doc.sh --list\n' >&2
  exit 1
fi
