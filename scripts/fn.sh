#!/usr/bin/env bash
# Find code in index.html without reading index.html.
#
# The page is one ~178,000-token file. Opening it to look at one function costs
# more than a whole context window, so nothing should ever read it whole.
#
#   ./scripts/fn.sh simRowFor            # print that function or constant
#   ./scripts/fn.sh --list               # every function, with its size
#   ./scripts/fn.sh --list sim           # ...whose name matches "sim"
#   ./scripts/fn.sh --grep mediaCycle    # every line mentioning it, with line numbers
#   ./scripts/fn.sh --callers fmtDate    # who calls it
#
# ⚠️ The brace scanner skips // and /* */ comments, quoted strings, template
#    literals and regex literals. A naive one once treated the apostrophe in
#    "// Don't yank..." as an open quote, ran past the function end and deleted 19
#    functions. This tool only READS, but the same care applies to the slice.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${FLEET_PAGE:-$ROOT/index.html}"
[ -f "$FILE" ] || { echo "no such file: $FILE" >&2; exit 1; }
[ $# -eq 0 ] && { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

MODE=find
case "${1:-}" in
  --list)    MODE=list;    shift ;;
  --grep)    MODE=grep;    shift ;;
  --callers) MODE=callers; shift ;;
esac

python3 - "$FILE" "$MODE" "${1:-}" <<'PY'
import re, sys

path, mode, arg = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ''
src = open(path).read()
lines = src.split('\n')

DECL = re.compile(
    r'^\s*(?:async\s+)?function\s+(?P<f>[A-Za-z_$][\w$]*)\s*\('
    r'|^\s*(?:const|let|var)\s+(?P<c>[A-Za-z_$][\w$]*)\s*='
)

def decls():
    for i, ln in enumerate(lines):
        m = DECL.match(ln)
        if m:
            yield i, (m.group('f') or m.group('c')), bool(m.group('f'))

# A '/' starts a regex only where a VALUE may begin. After punctuation that is
# obvious; after a keyword it is not, and missing that is what broke
# exportSerialsCsv — `return /[",\n]/.test(s)` has a quote inside the character
# class, so treating it as division made the scanner read that " as a string
# opener and run past the end of the function.
REGEX_OK_KEYWORDS = {
    'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void',
    'throw', 'case', 'do', 'else', 'yield', 'await',
}
REGEX_OK_CHARS = '(,=:[!&|?{};+-*%<>~^'

def regex_allowed(src, i):
    j = i - 1
    while j >= 0 and src[j] in ' \t\n':
        j -= 1
    if j < 0:
        return True
    if src[j] in REGEX_OK_CHARS:
        return True
    k = j
    while k >= 0 and (src[k].isalnum() or src[k] in '_$'):
        k -= 1
    return src[k + 1:j + 1] in REGEX_OK_KEYWORDS

LINE_OFF = []
_acc = 0
for _l in lines:
    LINE_OFF.append(_acc)
    _acc += len(_l) + 1

def block_end(start):
    """Walk from line `start` to the end of its declaration.

    A context STACK, not a scan-to-next-delimiter. Template literals nest:
    `...${cond ? `<span>` : '...'}...` is routine in this codebase, and scanning
    for "the next backtick" ends the OUTER template on the INNER one, after which
    every brace is counted in the wrong context. That produced a 318-line slice
    for a 140-line function before this was rewritten.

    Returns (end_line, ok). ok is False when no matching close was found, so the
    caller can say so instead of quietly handing back a plausible-looking slice.
    """
    n = len(src)
    i = LINE_OFF[start]
    depth, seen_open = 0, False
    stack = []                      # 'tmpl', or ('expr', depth_at_entry)

    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''

        # ---- inside a template literal: only ` and ${ matter
        if stack and stack[-1] == 'tmpl':
            if c == '\\':
                i += 2; continue
            if c == '`':
                stack.pop(); i += 1; continue
            if c == '$' and nxt == '{':
                stack.append(('expr', depth)); i += 2; continue
            i += 1; continue

        # ---- code context (top level, or inside a ${ } expression)
        if c == '/' and nxt == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and nxt == '*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in '"\'':
            q, j = c, i + 1
            while j < n:
                if src[j] == '\\': j += 2; continue
                if src[j] == q: j += 1; break
                if src[j] == '\n': break        # unterminated — do not run on
                j += 1
            i = j; continue
        if c == '`':
            stack.append('tmpl'); i += 1; continue
        if c == '/' and regex_allowed(src, i):
            j, ok = i + 1, False
            while j < n:
                if src[j] == '\\': j += 2; continue
                if src[j] == '\n': break
                if src[j] == '/': ok = True; break
                j += 1
            if ok:
                i = j + 1; continue
        if c == '{':
            depth += 1; seen_open = True
        elif c == '}':
            if stack and isinstance(stack[-1], tuple) and depth == stack[-1][1]:
                stack.pop(); i += 1; continue   # this } closes a ${ }
            depth -= 1
            if seen_open and depth == 0:
                return src[:i].count('\n'), True
        elif c == ';' and not seen_open and depth == 0 and not stack:
            return src[:i].count('\n'), True    # a one-line const
        i += 1
    return min(start + 200, len(lines) - 1), False

# ------------------------------------------------------------------ list
if mode == 'list':
    rows = []
    for i, name, isfn in decls():
        if arg and arg.lower() not in name.lower():
            continue
        end, _ = block_end(i)
        rows.append((name, i + 1, end - i + 1, 'fn' if isfn else 'const'))
    if not rows:
        print('nothing matches "%s"' % arg, file=sys.stderr); sys.exit(1)
    print('\033[1m%-38s %7s %6s %6s\033[0m' % ('NAME', 'LINE', 'LINES', 'KIND'))
    for name, ln, sz, kind in sorted(rows, key=lambda r: -r[2]):
        print('  %-36s %7d %6d %6s' % (name[:36], ln, sz, kind))
    print('\n  %d declaration(s). Whole file is ~%d tokens — never read it.\n'
          % (len(rows), len(src) // 4))
    sys.exit(0)

# ------------------------------------------------------------------ grep
if mode in ('grep', 'callers'):
    if not arg:
        print('need a term', file=sys.stderr); sys.exit(1)
    pat = re.compile(r'\b%s\s*\(' % re.escape(arg)) if mode == 'callers' \
          else re.compile(re.escape(arg))
    hits = [(i + 1, l) for i, l in enumerate(lines) if pat.search(l)]
    if not hits:
        print('no match for "%s"' % arg, file=sys.stderr); sys.exit(1)
    for ln, l in hits:
        print('\033[36m%6d\033[0m  %s' % (ln, l.strip()[:150]))
    print('\n  %d line(s).' % len(hits))
    sys.exit(0)

# ------------------------------------------------------------------ find
if not arg:
    print('need a name', file=sys.stderr); sys.exit(1)
exact = [(i, n, f) for i, n, f in decls() if n == arg]
if not exact:
    near = sorted({n for _, n, _ in decls() if arg.lower() in n.lower()})
    print('no declaration named "%s".' % arg, file=sys.stderr)
    if near:
        print('did you mean: %s' % ', '.join(near[:12]), file=sys.stderr)
    else:
        print('try: ./scripts/fn.sh --grep %s' % arg, file=sys.stderr)
    sys.exit(1)

for i, name, isfn in exact:
    end, ok = block_end(i)
    body = lines[i:end + 1]
    print('\033[1m─── %s  (index.html:%d-%d, %d lines, ~%d tokens) ───\033[0m'
          % (name, i + 1, end + 1, len(body), sum(len(l) + 1 for l in body) // 4))
    for k, l in enumerate(body):
        print('\033[36m%6d\033[0m  %s' % (i + 1 + k, l))
    if not ok:
        print('\n  \033[33m⚠ no matching close found — this slice is a fallback, '
              'not the real end of the declaration\033[0m')
    print()
PY
