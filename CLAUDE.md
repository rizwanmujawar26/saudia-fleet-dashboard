# Saudia Connectivity Fleet Status — briefing

**This file is the whole session briefing. Read it and stop.** `PROJECT_HANDOFF.md`
is a ~38,000-token reference manual, not a document to read at session start — pull
the one section you need with `./scripts/doc.sh` when the work reaches it.

A single-file HTML dashboard (`index.html`, ~7,700 lines, vanilla, no build step,
no external scripts) for Saudia's wireless IFEC fleet: software loading, monthly
media loading, the maintenance schedule and the fleet roster. GitHub Pages in
front, Firebase Realtime Database behind, live-synced so the team sees one truth.

- Live: https://rizwanmujawar26.github.io/saudia-fleet-dashboard/
- DB: `https://saudia-fleet-dashboard-default-rtdb.firebaseio.com` (project
  `saudia-fleet-dashboard`). Public read, authenticated write — `/editors/{uid}`
  is the allowlist and the **rules** enforce it, not the UI.
- `gh` and `npx firebase-tools` are already authenticated on this Mac.

---

## The two code words

### RESUME — start of session

Means: *get up to speed and tell me where things stand.* Three steps, no asking:

1. **Read this file.** That is the briefing — do **not** read the handoff or the
   runbook to start a session.
2. **Run the state check:**
   ```bash
   ./scripts/resume.sh
   ```
   Release · git state · the 12 deployment checks · live-vs-local `index.html`
   hash · live figures read fresh from the database · latest verifiable snapshot ·
   open items. Read-only, safe to repeat.
3. **Report briefly** — version and commit, tree clean and pushed, check result,
   hash match, current figures, open items waiting on the user. Then ask what to
   work on.

⚠️ **Never quote figures from any document as fact.** The user edits live; that is
why `resume.sh` reads them. ⚠️ **If the script flags anything, say so before
changing anything** — it exits non-zero on a dirty tree, an out-of-sync branch, a
failed check, a hash mismatch, or no verifiable snapshot.

### CHECKPOINT — end of session

Wrap up so the next session resumes cleanly. Four steps, no asking:

1. `FLEET_BACKUP_DIR="$HOME/Documents/fleet-backups/$(date -u +%F)-session-close" ./scripts/backup.sh`
   — check the output lists **every** node.
2. **Update only the sections you touched**, via `./scripts/doc.sh <section>` to
   read them first. Do not open the whole handoff. Record any ⚠️ lesson that cost
   real debugging time, and update *Where things stand* if the shape of the
   project changed.
3. `./scripts/resume.sh` must come back **All clear** — clean tree, pushed, 12/12,
   live hash == local. **Never report a deploy from build status alone.**
4. Tell the user the next session starts with the word **RESUME**.

A close-out, not a stopping point: finish what is in flight or name it unfinished.

---

## Working agreements

- **Deploy without asking.** Rules first, then the page, and prove it by **hash**,
  never by build status. Additive and cosmetic changes just ship.
- **Ask before removing anything major** — a tab, a page, a feature, a data node.
- **Never US month-first dates, anywhere.** Stored `DD-Mon-YYYY`, typed
  `dd-mm-yyyy`. `<input type="date">` is banned: its display format follows the
  browser locale and nothing overrides it. `fmtDate` / `toDMY` / `readDateField`
  are the only three functions that parse a date.
- **Don't guess at open items.** `resume.sh` prints them; most await a decision.
- **Back up before any bulk or destructive write.** `./scripts/backup.sh`.

## The rules that cost real debugging time

| | |
|---|---|
| A new node needs **four edits** — the rules, and the node lists in `backup.sh`, `restore.sh`, `verify-deployment.sh` | Backups |
| A "view" that changes what a row **means** must **rebuild**, not re-filter | Media / Modem |
| A write to a **polled** node must be mirrored locally, or the save looks like it vanished | Media / Modem |
| Style a frozen-head table **by class** — the floating copy inherits `className`, never `id` | Sticky header |
| `dir` in a sort is a numeric **multiplier** — `'asc'` makes every comparison `NaN` | Table sorting |
| A date column's `data-sort` goes through `dateSortKey()`, and the undated sentinel needs the **same digit count** as a real key | Table sorting |
| Never put `x` and `x/field` in one PATCH — Firebase rejects a multi-path update where one path contains another | Saves |
| Regex in `database.rules.json`: a literal dot is `\\.` — over-escaping fails **silently** and blocked every Software save once | Rules |
| A new sideways-scrolling strip must join **`HSCROLL_SELECTOR`** and the `any-pointer: fine` scrollbar rule, or it is unreachable with a mouse | Horizontal strips |

⚠️ **Verify in the browser, and verify the thing the USER sees.** Three bugs
shipped or nearly shipped in one session that every diff and syntax check passed.

⚠️ **Before concluding data is gone, `curl` the node.** A save that redraws from a
stale local store looks exactly like data loss, and never is.

⚠️ **Guard scripted edits to `index.html`.** Assert the needle is non-empty and
unique before any replace; a brace-matcher once ate 19 functions, and a
negative-length slice once produced a 17-million-line file. Check the line count
and diff the function list against `git show HEAD:index.html` immediately after.

---

## Looking things up — never read a whole file

**The two big files are off limits as a whole.** `PROJECT_HANDOFF.md` is ~38k
tokens and `index.html` is ~178k. Both have a tool that pulls only what you need.

### Documentation — `doc.sh`

```bash
./scripts/doc.sh --list            # every section, with its token cost
./scripts/doc.sh --grep fmtDate    # WHICH section talks about this
./scripts/doc.sh media             # pull one section
./scripts/doc.sh --all media       # every match, not just the first
```

`--grep` first when you don't know the section name — the term you remember
(`fmtDate`, `Kontron`, `ex-ASV`) is rarely in a heading.

| when the work touches | pull |
|---|---|
| what a node stores | `doc.sh "data model"` |
| one tab | `doc.sh overview` · `software` · `media` · `modem` · `activity` · `hardware` · `serials` · `schedule` · `fleet` · `"4G SIM"` |
| filters / pills / popovers | `doc.sh "filter bar"` |
| sorting, tiers, date keys | `doc.sh "table sorting"` |
| widgets, cards, colour meaning | `doc.sh "widget vocabulary"` |
| media cycles, DEV, Light Media | `doc.sh "media module"` |
| LRUs, serials, fitments | `doc.sh "hardware tab"` |
| frozen heads, pinned layers | `doc.sh "sticky header"` |
| backups, restore, going private | `doc.sh backups` |
| why something is the way it is | `doc.sh --grep <thing>` then `CHANGELOG.md`, or `git log` |

⚠️ Some topics span two sections — Media has a **tab** section and a **module
specifics** section. `--all` gets both.

### Code — `fn.sh`

```bash
./scripts/fn.sh simRowFor          # print that function or constant
./scripts/fn.sh --list sim         # every declaration matching "sim", with sizes
./scripts/fn.sh --grep mediaCycle  # every line mentioning it
./scripts/fn.sh --callers fmtDate  # who calls it
```

387 functions and 1,222 constants are indexed. It says when a slice is a fallback
rather than a real declaration end, so a wrong answer announces itself.

## Local dev

```bash
python3 -m http.server 8765
```

Use the Browser tool's `preview_start {name: "dashboard"}` — direct `navigate` to
localhost is blocked by policy. **No build, lint or type tooling, deliberately** —
don't add a toolchain unasked.

**Before every deploy:**

```bash
./scripts/check.sh
```

JS syntax · rules JSON · duplicate DOM ids · every inline handler defined · no
`<input type="date">` · no string sort directions · no external assets ·
`APP_VERSION` · and a diff against HEAD for line and function counts, which is
what caught a scripted edit that once deleted 19 functions. **It cannot check the
browser** — that is still on you, and it is where the bugs that pass every other
check are found.

Rules deploy separately and **must land before the page** when a change adds a
field, or the page's writes fail with `Permission denied`:

```bash
npx --yes firebase-tools deploy --only database --project saudia-fleet-dashboard
```
