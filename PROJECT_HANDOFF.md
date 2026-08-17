# Saudia Connectivity Fleet Status — Project Handoff (v2.4.1, 2026-08-17)

Paste this whole document into a new chat to resume work with full context.

## What this is

A single-file HTML dashboard for Saudia's wireless IFEC fleet: software
(middleware) loading, monthly media loading, the maintenance schedule, and the
fleet roster itself. Hosted free on GitHub Pages, live-synced via Firebase
Realtime Database so the whole team sees the same data instantly.

- **Live site:** https://rizwanmujawar26.github.io/saudia-fleet-dashboard/
- **GitHub repo:** https://github.com/rizwanmujawar26/saudia-fleet-dashboard (public)
- **Local path:** `/Users/rizwanmujawar/Downloads/saudia-fleet-dashboard/index.html`
- **Firebase project:** `saudia-fleet-dashboard` (Realtime Database, us-central1)
  DB URL: `https://saudia-fleet-dashboard-default-rtdb.firebaseio.com`
- Single file, ~4100 lines, vanilla HTML/CSS/JS. No build step, no framework,
  and **no external scripts at all** — nothing to fetch from a CDN.

`gh` CLI and `firebase` CLI (via `npx firebase-tools`) are already authenticated
on this Mac — no login needed to keep working.

Current data (2026-08-17): 42 aircraft (40 retrofit + 2 linefit), 24 on
Middleware 2.1.0, 38 with media loaded, 22 schedule entries, 1 allowlisted
editor.

---

## Security model

**Public read, authenticated write.** Anyone can view; only a signed-in account
listed under `/editors/{uid}` can change data. The check lives in the database
rules, so bypassing the UI with a raw REST call gains nothing. (The original
gate was a shared PIN checked in JavaScript — bypassable with one REST call —
which is why it was replaced.)

Auth is **REST, not the SDK**: `identitytoolkit.googleapis.com` for sign-in,
`securetoken.googleapis.com` for refresh, keeping the page a single file.
Tokens live in `sessionStorage` (closing the tab signs you out) and refresh a
minute before expiry. Writes carry `?auth=<idToken>`.

`FIREBASE_API_KEY` is embedded in the page on purpose — Firebase web API keys
are public client config that identify the project, not secrets. The rules
grant access.

`canEdit()` shapes the UI only. The rules decide; tampering with it client-side
still earns `Permission denied` (verified).

Manage the editor allowlist from the CLI (uid from Firebase Console →
Authentication → Users):

```bash
firebase database:update /editors --project saudia-fleet-dashboard --data '{"<uid>": true}'
```

Admin changes that skip auth entirely still work via `firebase database:update`,
since the CLI is admin-authenticated.

---

## Data model

Everything is validated in `database.rules.json`; `$other` is `false` at every
level, so **an unknown field is rejected outright** — adding a field means
adding it to the rules first.

### `/fleet/{tail}` — the roster, single source of truth for which aircraft exist

| field | values |
|---|---|
| `type` | e.g. `A320-214`, `A321-253NY XLR` |
| `station` | `JED` / `RUH` / `N/A` |
| `fit` | `retrofit` (the 40) \| `linefit` (ASBA, ASBB) |
| `fleetStatus` | `active` \| `stored` \| `retired` |
| `comments` | free text |

### `/aircraft/{tail}` — per-aircraft state

| field | values |
|---|---|
| `swVersion` | semver, e.g. `2.0.0` / `2.1.0` |
| `completionLocation` | `Jeddah` \| `Riyadh` |
| `completionDate` | `DD-Mon-YYYY` |
| `iphoStatus` | `completed` |
| `mg101Status` | `provisioned` \| `done` |
| `beamcfgStatus` | `pending` \| `done` (linefit pair only) |
| `note` | Software-page comment |
| `media` | `{ mediaCycle, mediaDisplay, mediaSource, loadedDateUTC, comments }` |
| `maintenance` | `{ open, reason, flaggedAt }` — see the Maintenance tab |

`media.comments` is deliberately separate from `note` so editing one cannot
clobber the other.

### `/schedule/{id}` — forward-looking work packages

`aircraft`, `date` (DD-Mon-YYYY), `time` (HH:MM), `workpackage`, `wo_flags`,
`station` (JED/RUH), `status` (`scheduled|in-progress|completed|postponed`).

### `/editors/{uid}` — allowlist, readable only by that uid, never client-writable

### `/visits` — the only world-writable node in the database

`total` and `daily/{YYYY-MM-DD}`, both plain integers. **A write is accepted only
when it equals the stored value plus one** (or is the first write, equal to 1), so
the rule doubles as the compare-and-swap: a concurrent visit is rejected rather
than overwriting, and the client re-reads and retries. RTDB has no increment verb
over REST — this is what replaces it.

Deletes, decrements, jumps, non-numbers, malformed day keys and unknown children
are all rejected (12 curl cases verified). The residual exposure is that anyone
can inflate the counter one increment per request; nothing else in the database
is reachable this way. If that ever matters, the fix is an authenticated
endpoint, not tighter rules here.

---

## Single sources — do not reintroduce duplicates

Two facts were each stored twice, which let an editor change one and leave the
dashboard contradicting itself. Both are now derived from exactly one field.
**If you add a page, read these helpers — don't re-derive.**

- **Linefit / HBC+ scope** → `isLinefit(a)` reads `fit === 'linefit'` only.
  The old `/aircraft` `status === 'excluded'` is deleted and rejected by rules.
- **Completion** → `isCompletedStrict(a)` is
  `swVersionOf(a) === latestSwVersion() && completionLocation`.
  The Status column is a *view* via `aircraftStatusOf(a)`, not a stored field.
  The old stored `status` is deleted and rejected by rules.

So an editor sets **Middleware version** and **Completion Location**, and the
Status badge, row highlight, type cards, station cards, Timeline and global
widgets all follow. (Verified: one upgrade moves all of them 24 → 25.)

Scope numbers are **counted, never hardcoded**: `projectScope()` (roster size),
`hbcScope()` (linefit count), `middlewareScope()`, `mediaScope()`.
Adding an aircraft moves every table, filter and percentage at once.

Note the software widget counts aircraft *on the latest middleware*, while
completion additionally requires a location — they can legitimately differ by
an aircraft showing "⚠ needed to count as done".

---

## Widget vocabulary

- **Global widgets** — fixed 2×2 grid above the tab bar (`.global-widgets`),
  fleet-wide, on every tab. Top row: Software Loading Progress ×2, pilled
  `Retrofit` (Middleware, the 40) and `Linefit` (SBC Configuration A.13, the
  HBC+ pair). Bottom row: Media Loading Progress, Maintenance.
- **Local widgets** — `.media-widget-strip` rows inside a tab, showing that
  tab's own breakdown. All strips scroll sideways in one row; they never wrap.

Figure convention everywhere: **count at the left edge of the progress bar,
percentage at the right edge** (`margin-left: auto` on `.metric-pct`).

---

## Tabs (6)

1. **Overview** — starts with the Timeline (calendar strip + grouped-by-date
   list). One divider per day, nothing between aircraft. Beware
   `.timeline-items li`: it must stay `.timeline-items > li`, or the descendant
   match hits nested per-aircraft `<li>`s and double rules return.
2. **Software** (tab id is still `aircraft`) — local widgets: Middleware
   Version Progress, Completion by Aircraft Type, Completed by Station.
   Main table (40) + HBC+ table (2). `SW_VERSIONS` is ordered oldest-first and
   the **last entry is "latest"** — add a version there and it gains a widget,
   an edit option, retitles the global card and demotes the previous one. No
   other change needed.
3. **Media** — monthly media loading for the main fleet only (linefit excluded).
   Columns: `# | Aircraft | Type | Status | Media Loaded | Date UTC | Comments`.
4. **Maintenance** — the **active** fleet only (`fleetStatus === 'active'`), the same
   set the global Maintenance card counts against, so the two cannot disagree.
   Columns: `# | ▸ | Aircraft | Type | Station | Maintenance | Flagged | Reason`.
   Clicking anywhere on a row opens a drawer of per-aircraft detail — that is where
   **SSID status and the remaining system checks go**. The caret has a hair-width
   column to itself (col 1, `.maint-expand-col`) so the Aircraft cell stays plain
   `<strong>` and lines up with the Software, Media and Fleet tables; inline before
   the registration it read as a stray dot. It rotates rather than swapping glyph.
   `maintRowClick()` exempts selects and inputs, or opening a dropdown in Edit mode
   would collapse the row. **Sortable columns start at 2** — sorting also collapses
   the drawers first (`sortMaintTable()`), because `sortTable` treats a one-cell
   detail row as a peer.
   `N/A` is not a station: it is what the roster stores for the linefit pair, which
   is based nowhere, so it gets no pill and no widget card and its Station cell
   reads `—`. The station cards therefore need not sum to Open Issues.
5. **Schedule** — standalone forward-looking plan, deliberately **not** linked
   to completion status. Entries drop off automatically 24h past their slot
   (`SCHEDULE_GRACE_MS`); in that window they show `⚠ Overdue` so they can be
   rescheduled rather than vanishing.
6. **Fleet** — owns the roster: add / edit / remove, incl. linefit. Removing
   deletes only the `/fleet` entry; `/aircraft` history survives, so re-adding
   the registration restores it.

---

## Media module specifics

Editors type **one string** — `2026-08-16 04:22:00 (ME-SVA-UGO-0826)` — and
`parseMediaEntry()` derives all four stored fields. Seconds optional; source
parses with or without parentheses; bad input is flagged inline and never
staged.

- A cycle is **MMYY** (`0826`). `cycleSortKey()` maps it to YYYYMM so January
  correctly outranks the previous December; `previousCycle()` rolls the year.
  **Never compare cycle strings directly.**
- `mediaStatus` is **never stored** — it is relative to the newest cycle in the
  fleet, so a stored value goes stale the moment a newer cycle lands.
  `mediaStatusType()` derives it: latest (green), one month back (blue), older
  (amber), none (grey).
- Widgets and month filter pills are built from cycles actually present, newest
  first. A new cycle creates its own widget and pill with no code change
  (verified with a simulated September).

---

## Maintenance

`maintenanceOpen(a)` reads `a.maintenance && a.maintenance.open` — the one place
"is this aircraft flagged?" is answered, for both the tab and the global card.
Denominator is the **active** fleet (`fleetStatus === 'active'`), so
stored/retired aircraft drop out — including their flags, if any survive from
before they were stored. The card is neutral grey at zero (`.alert-clear`) and
turns light red when anything is open.

The stored shape is deliberately small — only what the flag needs:

| field | values |
|---|---|
| `open` | boolean; **the** flag. Anything true here counts on the global card |
| `reason` | free text, ≤ 500 |
| `flaggedAt` | `YYYY-MM-DDTHH:MM:SSZ`, stamped on Save |

Clearing an aircraft writes `maintenance: null` rather than `open: false`, so a
clear aircraft carries no stale reason or timestamp. Re-saving a row that is
already open leaves `flaggedAt` alone — the clock does not restart on an old
issue. Never put `maintenance` and `maintenance/<field>` in the same PATCH:
Firebase rejects a multi-path update where one path contains another.

**Adding SSID status (or anything else) means editing `database.rules.json`
first** — `$other` is `false` under `maintenance`, so an undeclared field is
rejected outright. Then render it in `maintDetailRow()`, which is the drawer
under each row and the intended home for the per-aircraft checks.

`flaggedBy` was deliberately left out: `/aircraft` is world-readable, so storing
the editor's email would publish the team's addresses. Add it only if that is
acceptable.

Reserved: 🛠️ emoji is the Maintenance tab's.

---

## System status bar (the footer)

The old three-line footer is gone. In its place `.sysbar` is a compact capsule
strip — brand, version, aircraft count, sync age, visit count, environment —
mirroring the header's gradient and accent stripe so the page is bookended.
Clicking any capsule opens `#sysInfoOverlay`, a technical panel in three
sections (Build / Data / Usage).

- **Release identity has one home:** `APP_VERSION`, `APP_BUILD`, `APP_ENV`,
  `APP_DEPLOYED`. Bump those and the bar, the panel and the page title text all
  follow. Never write a version anywhere else.
- **Every figure is read from the existing helpers** — `projectScope()`,
  `middlewareScope()`, `mediaScope()`, `latestSwVersion()`, `latestMediaCycle()`.
  The panel's Software/Media Tracked are the same numbers as the global widgets;
  they are not a second copy.
- **`setSyncStatus()` kept its signature** — all ~20 call sites are untouched —
  but now drives the bar instead of a `<p>`. Healthy collapses to the breathing
  brand dot; warn and error open a capsule showing the message in full, because
  a failed save must never end up hidden in a tooltip. `syncLevelOf()` maps the
  old colour argument to the level.
- **`markDataSync()`** is called only where Firebase data actually lands (the
  initial fetch and the stream `put`/`patch`), not on local re-renders — that is
  what "Synced 2m ago" measures. It spins the arrows, throttled to one turn per
  1.2s so a burst of stream events is not a blur.
- **The visit counter counts once per browser session**, guarded by
  `sessionStorage` plus an in-memory `visitCounted` flag, so a reload or a second
  `initVisitCounter()` call cannot double count. Private mode reads the totals
  and counts nothing.
- Animation is decoration only; everything is disabled under
  `prefers-reduced-motion`.

The HBC+ exclusion note the old footer carried still exists — it is the
`.footnote` at the bottom of the Overview tab, which is where it always was.

---

## Conventions

- **Dates are always `DD-Mon-YYYY`** (e.g. `17-Aug-2026`). Never `M/D/YYYY` —
  month-first numeric dates are not used in this region and read as the wrong
  day. `parseScheduleUTC()` / `toISODate()` / `fmtDate()` are the only parsers.
- All times UTC/Zulu.
- No external scripts. Keep it that way.

---

## Local dev workflow

```bash
cd "/Users/rizwanmujawar/Downloads/saudia-fleet-dashboard"
python3 -m http.server 8765
```

Use the Browser tool's `preview_start` (not direct `navigate` — `localhost`
gets blocked by policy that way). `.claude/launch.json` defines that server as
`dashboard`, so `preview_start {name: "dashboard"}` starts and opens it.

Before every deploy:
1. Extract the `<script>` block and run `node --check` on it.
2. Test the change in the local browser preview.
3. `git add/commit/push` — GitHub Pages auto-deploys.

Rules deploy separately:

```bash
firebase deploy --only database --project saudia-fleet-dashboard
```

After changing rules, re-check enforcement with plain `curl`: anonymous read of
`/aircraft.json` should be `200`; anonymous write, and reads of `/editors.json`
and root, should all be `401`.

For **data-only** changes use `firebase database:update` (admin, bypasses
rules). Always read current state first and patch only deltas — teammates edit
live.

### Deploy gotchas (learned the hard way)

- **Verify by hash, not by eye:** `curl` the live `index.html` and `diff` it
  against local. `shasum -a 256` on both is the fastest proof.
- **Pages builds can wedge.** A build stuck in `building`, or `errored` with
  "Page build failed", is usually GitHub-side. `gh api -X POST .../pages/builds`
  often returns 503 during incidents. The reliable nudge is an empty commit:
  `git commit --allow-empty -m "Retrigger Pages build" && git push`.
- `.nojekyll` is in the repo root — this is one static file and Jekyll only
  added a build step that could fail. Don't remove it.
- **The in-app browser cannot reach Firebase.** Pages load but tables render
  empty. That is a tooling limitation, not a site fault — verify by injecting
  data client-side, or check the served file's markup and hash instead.
- **Back up before bulk edits.** `cp index.html` to a scratch path before any
  scripted multi-block deletion; a section-comment-based removal once cut 3,256
  lines instead of ~600 and the backup was the only thing that made it a
  non-event.

---

## Open items

- **SSID status on the Maintenance tab** — the drawer (`maintDetailRow()`) is
  built and waiting for it; add the field to the rules first. Whether the flag
  should then be *derived* from SSID and the other checks, instead of set by
  hand, is still open — today it is a manual editor toggle.
- **Sorting the Maintenance table is lost on re-render** — expanding a drawer,
  staging an edit or a live update repopulates the table in registration order.
  Every other table behaves the same way; fix it for all of them or none.
- **`AQL` carries a vestigial `pinHash`** from the old PIN system. Nothing
  reads it; rules now reject writing it. Safe to clear whenever.
- **"In Progress" no longer exists on the Software page.** The old stored enum
  had it, nothing used it, and neither version nor location expresses it. If
  it's wanted back it needs its own field.
- **`ASBA`/`ASBB` notes read "HBC+ Aircraft"** — redundant against the table
  title, now visible in the HBC+ Comments column. Clear whenever.

## Status

The user considers this a working portal under active extension. Expect
targeted asks — new modules (Maintenance, SIM tracking), data updates, and UI
polish — rather than rebuilds. **Do not rebuild from scratch; reuse the
existing table framework, filter pills, widget strips, status badges and
auth-gated edit flow.**
