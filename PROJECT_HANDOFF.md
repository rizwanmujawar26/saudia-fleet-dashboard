# Saudia Connectivity Fleet Status — Project Handoff (v2.10.0, 2026-08-19)

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
- Single file, ~7,500 lines, vanilla HTML/CSS/JS. No build step, no framework,
  and **no external scripts at all** — nothing to fetch from a CDN.
- **There is no build, lint or type tooling, deliberately.** The checks that do
  exist are in *Local dev workflow* below. Don't add a toolchain unasked.

`gh` CLI and `firebase` CLI (via `npx firebase-tools`) are already authenticated
on this Mac — no login needed to keep working.

Live data (read from the database 2026-08-19): 42 aircraft (40 retrofit +
2 linefit), 24 on Middleware 2.1.0, 38 with media loaded, 24 schedule entries,
1 maintenance activity, 1 hardware record, 69 visits, 1 allowlisted editor.
`/activities` and `/hardware` are new and barely populated — a Hardware fitment
reading "no record" is a gap in the record, not a fault.

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
| `retrofitLocation` | free text ≤ 60: the city or MRO where the retrofit was done (Doha, Malta, Jeddah…) |
| `wifiVisibility` | `public` \| `hidden` |
| `activatedDate` | `DD-Mon-YYYY` |
| `simRoaming` | `active` \| `inactive` — the SIM subscription, not the card |

The last three are edited on the Maintenance tab but stored at the **top level**,
deliberately *not* under `maintenance` — clearing a flag writes `maintenance: null`,
which would take them with it every time an aircraft was marked serviceable.

`retrofitLocation` is not `completionLocation`. Completion is where the *software*
load finished and is constrained to Jeddah/Riyadh; retrofit location is where the
physical installation happened and can be any MRO anywhere. If those ever turn out
to mean the same thing operationally, collapse them — do not keep both in sync.

`media.comments` is deliberately separate from `note` so editing one cannot
clobber the other.

### `/schedule/{id}` — forward-looking work packages

`aircraft`, `date` (DD-Mon-YYYY), `time` (HH:MM), `workpackage`, `wo_flags`,
`station` (JED/RUH), `status` (`scheduled|in-progress|completed|postponed`).

### `/editors/{uid}` — allowlist, readable only by that uid, never client-writable

### `/activities/{id}` — what was actually done to an aircraft

`aircraft`, `date` (DD-Mon-YYYY), `location` (free text), `category`, `title`,
`task`, `outcome`, `notes`, `loggedAt`, and a `details` sub-object whose fields
depend on the category (`partReplaced`/`partNumber`/`oldPart`/`newPart`
plus `removalReason`, `shopStatus`, `shopRef`, `shopFinding`;
`softwareName`/`version`; `modemType`/`commissioningResult`).

A hardware record is the whole life-event of a unit: what came off, what went on,
why, and — filled in later — what the shop found. The Hardware tab reads all of it.

`category` is one of `hardware_rr`, `software_update`, `modem_commissioning`,
`troubleshooting`, `maintenance`, `configuration`, `inspection`, `modification`,
`other`. **`ACTIVITY_CATEGORIES` in the page is the one definition** — it carries
the label and the Timeline kind together, so adding a category is one line there
plus the regex in the rules.

This is the only record of maintenance work. The aircraft history reads it and
the Timeline derives from it — there is no Timeline collection and nothing is
entered twice.

### `/hardware/{lruId}` — what belongs to the unit, not to an aircraft

`swVersion`, `partNumber`, `vendor`, `notes`, and `issues/{id}`
(`title`, `detail`, `resolution`, `status` open|resolved, `loggedAt`).

**Serial numbers are deliberately NOT here.** They are derived from the on/off
details of hardware activities in `/activities` — see the Hardware tab below.

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

## Hardware tab — the LRU catalogue is code

`HARDWARE_LRUS` in the page is the single definition of which line-replaceable
units the programme fits: `{ id, label, fit, aliases }`. It is code, not data,
because the set changes with the programme rather than with an editor.

**Retrofit and linefit are separate entries even where the name matches** — they
are different units with their own serials and their own issues. The MODMAN is the
clearest case. The two lists can share alias spellings without colliding, because
the *aircraft's* fit decides which list a match belongs to.

**Quantity varies by aircraft type.** `lruQtyFor(lru, type)` reads `qtyByType`
falling back to `qty` (default 1). CWAP is the case that introduced it: three on an
A320, five on an A330. Any LRU fitted more than once anywhere in its fleet becomes
**position-tracked** — the fitment list shows one row per aircraft *per position*
and the activity carries `details.position`.

⚠️ CWAP quantities for the **A321 and A321neo were never specified** and currently
fall back to 1. Fix them in `qtyByType`.

**The part is picked, not typed.** The Add Activity form's Part dropdown is built
from `HARDWARE_LRUS`, filtered to the selected aircraft's fit and rebuilt when the
aircraft changes — add a part to the catalogue and it appears there with no other
wiring. New records store `details.lruId`, so the link to the Hardware tab is exact;
`activityMatchesLru()` falls back to alias matching only for records typed as free
text before the picker existed. Part number is **not** asked for on the activity:
it belongs to the unit and is defined once on the Hardware tab.

**Fitment is derived, never stored.** `hardwareFitment(lru)` walks `/activities`
for `hardware_rr` records whose `details.partReplaced` matches an alias and reads
the current state from the **latest** change, not from the last serial ever
mentioned. Three cases, all distinguished:

| case | record | shows as |
|---|---|---|
| first fit | `newPart` only | serial + install date, tagged "first fit", 0 removals |
| swap | `oldPart` + `newPart` | new serial, removals count +1 |
| removed, nothing refitted | `oldPart` only | "removed — none fitted" |

An aircraft with no recorded change reads "no record" — a gap in the record, not a
missing unit. **Removals count units that came off**, not changes, so a first fit
never reads as a removal.

**The Removed Units section is the shop queue.** `hardwareRemovals(lru)` lists every
unit ever taken off this LRU across the fleet, newest first, with its
`removalReason` and the shop's verdict (`shopStatus`, `shopRef`, `shopFinding`).
Those live on the removal activity because **the removal is the activity** — a
parallel collection would drift from it. "Shop report" PATCHes
`/activities/{id}/details`, so a finding can be filled in long after the removal
was logged.

**SIM roaming** is on `/aircraft/{tail}/simRoaming`, not on the card: it is a
subscription state that survives a card swap. The Roaming column appears only for
the SIM units, and editing it writes to `/aircraft` while the LRU's own fields
write to `/hardware` — one Save, two correctly-targeted writes.

⚠️ **The linefit list is a placeholder.** It currently mirrors the retrofit set so
the pane is usable; the real linefit equipment list has not been supplied.
Correcting it is an edit to `HARDWARE_LRUS` and nothing else.

The two-pane shell reuses the `.maint-*` classes — they style a generic
list/detail layout and the prefix is historical. Worth unifying under a neutral
name when something else needs the same shell.

---

## Timeline — derived, never stored

`timelineActivities()` is the one place the three sources are folded into a
single shape (`{ iso, kind, tail, type, location, title, sub }`):

| kind | source | date it uses |
|---|---|---|
| Software | `/aircraft` completion fields — `Middleware {swVersion}` for retrofit, `SBC Configuration A.13` for the linefit pair when `beamcfgStatus === 'done'` | `completionDate` |
| Media | `/aircraft/{tail}/media` | `loadedDateUTC` |
| Maintenance | `/activities` whose category maps to `maintenance` | `date` |
| Hardware | `/activities` with `category === 'hardware_rr'` | `date` |

Category → kind lives in `ACTIVITY_CATEGORIES`: `hardware_rr` → Hardware,
`software_update` → Software, **everything else → Maintenance**.

The kind filter drives the day counts as well as the rows, so a tile reading
"2" under Hardware means two hardware activities that day, not two of anything
else. Default sort is **newest first**. The title carries no count.

Filter pills are **All / Software / Hardware / Media**. There is no Maintenance
pill for now — maintenance-kind activities still appear under All, they just have
no filter of their own until the categories settle.

**Every month in the calendar strip gets a tile**, the current one included, so the
strip is navigable by month and this month's total reads first. The current month
is **open by default** (its days follow, after a `›` separator); earlier months are
folded. Clicking any month tile toggles it — collapsing the current month leaves
every month visible as a single tile each.

`timelineMonthOverrides` records only months the user actually clicked;
`timelineMonthIsOpen()` falls back to "is it the current month". That way the
default stays correct when the month rolls over, rather than freezing whatever was
current at page load. Month tiles keep the position their dates would have had, so
the grouping is right in both sort directions.

Tile geometry is load-bearing: `.cal-tile` is a **flex column** with
`margin-top: auto` on `.cal-tile-count`. The strip stretches every tile to the
tallest, and as a plain block the count band sat wherever the content ended — which
left a white sliver under the shorter month tiles. Day number and month
abbreviation also share one fixed-height slot so the two tile types match without
either being padded to fit.

**The day list shows `TIMELINE_VISIBLE_DAYS` (7) day cards**, the rest behind one
Show more control that names how many are hidden. The Overview is a screen, not an
archive.

Location pills show the station code via `locationCode()` — `LOCATION_CODES` maps
Jeddah→JED, Riyadh→RUH, Dammam→DMM, and anything else (a one-off MRO) passes
through unchanged. **Display only**: the stored value is untouched and is still
what `LOCATION_PILL_COLORS` is keyed on, and the full name is in the pill's
tooltip.

Nothing writes a Timeline record. Adding a maintenance activity makes it appear
on the Timeline on the next `updateMetrics()`, which the save already calls.

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

## Tabs (7)

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
   **Two panels, Outlook-style** (`.maint-split`): the aircraft list on the left
   (`renderMaintList`), the selected aircraft on the right (`renderMaintDetail`)
   — profile grid on top, activity history below, newest first. There is no
   expandable row; `maintSelectedId` is the selection and it re-resolves to a
   valid aircraft whenever a filter hides the current one.
   The profile fields that are editable (retrofit location, WiFi, activated,
   flag, reason) become inputs in Edit mode, using the same staged-then-Save
   flow the table used — nothing that could be edited before was lost.
   **Add New Activity** writes one `/activities` record and nothing else — the
   aircraft history and the Timeline both derive from it.
   Two widgets only — Open Issues and Serviceable — complements of one total, so a
   third card on that strip would just restate them.
   **"Serviceable", not "Clear"** — the MRO term for an aircraft with nothing
   outstanding against it. The badge, the widget and the filter pill all use it;
   the `mflag` dataset value is `serviceable`.
   Filters are Aircraft Type and Maintenance status. There is no station filter —
   the tab is about the retrofit and its systems, not which base an aircraft flies
   from. Base Station is one of the profile fields.
5. **Hardware** — the LRU catalogue on the left in two fit groups, the selected unit
   on the right: profile, known issues, fitment, removed units. See *Hardware tab*
   above. Serials are derived from `/activities` and never stored here.
6. **Schedule** — standalone forward-looking plan, deliberately **not** linked
   to completion status. Entries drop off automatically 24h past their slot
   (`SCHEDULE_GRACE_MS`); in that window they show `⚠ Overdue` so they can be
   rescheduled rather than vanishing.
7. **Fleet** — owns the roster: add / edit / remove, incl. linefit. Removing
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
rejected outright. Then render it in `renderMaintDetail()`, the right-hand panel.
The drawer that used to hold this is gone; SSID could equally become an LRU on the
Hardware tab instead — that decision is still open.

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

The HBC+ exclusion note that the old footer carried was moved to the Overview's
`.footnote` block, and then removed altogether at the user's request in v2.7.0.
The same fact is still stated in the Software tab's HBC+ table title and in the
Project Objectives list, so nothing was lost.

---

## Sticky header

The header is `position: sticky; top: 0` so the clock and fleet identity stay on
screen while the page scrolls behind. Two things make that work and are easy to
undo by accident:

- **`.container` must not have `overflow: hidden`.** An ancestor with it silently
  kills `position: sticky` on its children — the header simply never pins, with no
  error. The rounded corners it used to clip are now carried by `.header`
  (`12px 12px 0 0`) and `.sysbar` (`0 0 12px 12px`) themselves.
- **`z-index: 500`**, deliberately below the modal overlays (1000, and 1100 for the
  system information panel) so an overlay still covers the header.

**The tab strip pins under it**, at `top: var(--header-h)`, so the global widgets
scroll away but the tabs stay reachable. `initStickyHeader()` publishes
`--header-h` from the header's measured height and keeps it current with a
`ResizeObserver` — the header is a different height per breakpoint and different
again when the title wraps, so a hardcoded offset is wrong on most screens.

`.tabs` also needed `background-color: #ffffff`. Its four gradient layers are edge
fades for the scroll-shadow effect and are clear through the middle, so without an
opaque base the page showed through the strip once it was pinned.

`initStickyHeader()` otherwise only toggles `.is-stuck` for the shadow, and only
when the state changes — the pinning itself is pure CSS.

---

## Conventions

- **Regex escaping in `database.rules.json` is a trap that fails silently.** The
  file is JSON, so a backslash is written `\\` and *decodes* to one backslash. To
  match a literal dot the rule needs `\\.` in the file — `\\\\.` decodes to `\\.`,
  which the engine reads as *escaped backslash then any character*, and it then
  matches nothing you intended. This shipped and blocked every `swVersion` write on
  the Software tab; nothing in the deploy reported a problem, because the rules were
  syntactically valid. **After editing any rule containing a backslash, print the
  decoded string and check it**, then prove it against the live engine with a
  temporary `.write: true` test node before trusting it.

- **A date column's `data-sort` must go through `dateSortKey()`.** `sortTable`
  tries `parseFloat` before falling back to a string compare, and
  `parseFloat('2026-05-19')` is `2026` — so a raw ISO key made every date within a
  year compare equal, and date columns silently sorted by year only. `dateSortKey`
  strips the separators to give a real number (`20260519`). All four date columns
  use it.
- **Dates are always `DD-Mon-YYYY`** (e.g. `17-Aug-2026`). Never `M/D/YYYY` —
  month-first numeric dates are not used in this region and read as the wrong
  day. `parseScheduleUTC()` / `toISODate()` / `fmtDate()` are the only parsers.
- All times UTC/Zulu.
- No external scripts. Keep it that way.

---

## Backups & disaster recovery

Full runbook: **`DISASTER-RECOVERY.md`**. In short:

- `scripts/backup.sh` snapshots every readable node with a checksummed manifest
  and a copy of the rules. **Anonymous reads only, so it needs no credentials** —
  nothing to expire, nothing to leak.
- **Snapshots never go in this repo.** It is public, and git history is harder to
  walk back than a live database. `backups/` is gitignored; point
  `FLEET_BACKUP_DIR` at somewhere private. Automation options are in the runbook.
- **Anonymous backup stops working once reads require auth** (see *Making this
  private*). That migration has to include a service account for the backup.
- `scripts/restore.sh` is **dry-run by default**, verifies every checksum before
  proceeding, takes a safety copy of current state into its own folder, and needs
  the project id typed to confirm. Rules are never restored implicitly.
- **`/editors` is not in the backups** — it is not anonymously readable, by design.
  Keep the uid list outside the repo or a restore leaves nobody able to edit.

Four scripts, all dry-run-first where they can write:

| script | does |
|---|---|
| `backup.sh` | snapshot public nodes — no credentials needed |
| `backup-secrets.sh` | `/editors` + account list (no password material), private dirs only |
| `restore.sh` | put a snapshot back, checksum-verified |
| `migrate-project.sh` | move to a new Firebase project |
| `verify-deployment.sh` | health + enforcement check for any project |

All honour `FLEET_DB_URL` / `FLEET_PROJECT`, so they work against a new project
without edits. **The chosen future direction is a new, private Firebase project** —
the runbook for it is prepared and rehearsed in `DISASTER-RECOVERY.md`. The app itself is host-coupled by exactly two
constants, `FIREBASE_DB_URL` and `FIREBASE_API_KEY`.

---

## Local dev workflow

```bash
cd "/Users/rizwanmujawar/Downloads/saudia-fleet-dashboard"
python3 -m http.server 8765
```

Use the Browser tool's `preview_start` (not direct `navigate` — `localhost`
gets blocked by policy that way). `.claude/launch.json` defines that server as
`dashboard`, so `preview_start {name: "dashboard"}` starts and opens it.

There is no build, lint or type tooling. These are the checks that stand in for
it — run all of them before every deploy:

1. Extract the `<script>` block and `node --check` it.
2. `python3 -c "import json; json.load(open('database.rules.json'))"`.
3. **No duplicate DOM ids** in the markup — easy to introduce in a 7,500-line file.
4. **Every `onclick`/`onchange` handler named in the markup exists in the script.**
   Both of these are one-off greps; there is no linter to catch them.
5. Test in the local browser preview, and read the console for errors.
6. `git add/commit/push` — GitHub Pages auto-deploys.

Rules deploy separately, and **must land before the page** when a change adds a
field: the page's writes fail with `Permission denied` until they do.

```bash
npx --yes firebase-tools deploy --only database --project saudia-fleet-dashboard
```

The `--yes` matters. `~/.claude/settings.json` `autoMode.soft_deny` carries
`Bash(firebase deploy:*)`, and the exact string above is the form allowlisted in
the project settings; without `--yes` the deploy is gated.

After changing rules, re-check enforcement with plain `curl`: anonymous read of
`/aircraft.json` should be `200`; anonymous write, and reads of `/editors.json`
and root, should all be `401`.

For **data-only** changes use `firebase database:update` (admin, bypasses
rules). Always read current state first and patch only deltas — teammates edit
live.

### Deploy gotchas (learned the hard way)

- **Verify by hash, not by eye:** `curl` the live `index.html` and `diff` it
  against local. `shasum -a 256` on both is the fastest proof.
- **Pages builds can wedge**, usually during a GitHub incident — check
  githubstatus.com before assuming it is your change.
- **`pages/builds/latest` goes stale.** A wedged build sits at `building` with
  `updated == created` and never moves; the repo-level `gh api repos/.../pages`
  told the truth (`status: errored`) when `builds/latest` did not. Check both.
- **To recover a wedged build:** `gh api -X POST .../pages/builds` once the
  incident has passed — it returned `queued` and built in 61s. It only 503s
  *during* an incident. An empty commit is the fallback, but it did nothing during
  the outage, so try the API first and keep the history clean.
- `.nojekyll` is in the repo root — this is one static file and Jekyll only
  added a build step that could fail. Don't remove it.
- **The in-app browser reaches Firebase only sometimes.** When it cannot, pages
  load but tables render empty and the status bar stays on "Connecting" — a
  tooling limitation, not a site fault. Seed `fleetRoster` / `aircraftLive` /
  `activitiesLive` client-side and call `renderAll()` to exercise rendering, and
  stub `window.fetch` to capture write payloads without touching live data.
- **`read_console_messages` keeps a tab's whole history.** An error fixed ten
  minutes ago still shows. Open a fresh tab to confirm a clean load.
- **Back up before bulk edits.** `cp index.html` to a scratch path before any
  scripted multi-block deletion; a section-comment-based removal once cut 3,256
  lines instead of ~600 and the backup was the only thing that made it a
  non-event.

---

## Open items

### Waiting on the user — ask, don't guess

- **The linefit equipment list is a placeholder.** `HARDWARE_LRUS` currently
  mirrors the retrofit set for linefit so the pane is usable. The real list has
  never been supplied. One-array fix.
- **CWAP quantities for A321 and A321neo** were never given and fall back to 1.
  Stated so far: A320 ×3, A330 ×5, retrofit only. Whether linefit carries CWAP at
  all is also unanswered.
- **What should drive the maintenance flag.** Today it is a manual editor toggle.
  Deriving it from SSID and the other checks — the way completion derives from
  version + location — is the better shape, but the criteria have not been agreed.

### Known gaps and cleanups

- **SSID status has no home yet.** It was going in the old expandable drawer,
  which no longer exists. It now belongs either in the Maintenance right panel's
  profile grid or as an LRU on the Hardware tab. Rules first, either way.
- **Alias matching is legacy-only but still load-bearing.** Activities logged
  before the part picker carry free text in `details.partReplaced`; a typo in one
  of those silently detaches it from its LRU. New records use `lruId` and are
  exact. Consider a one-off backfill.
- **The two-pane shell is styled by `.maint-*` classes** that the Hardware tab also
  uses. They style a generic list/detail layout and the prefix is historical —
  worth a neutral name if a third page needs the same shell.
- **`AQL` carries a vestigial `pinHash`** from the old PIN system. Nothing reads
  it; rules reject writing it. Safe to clear whenever.
- **`ASBA`/`ASBB` notes read "HBC+ Aircraft"** — redundant against the table title,
  visible in the HBC+ Comments column. Clear whenever.
- **"In Progress" no longer exists on the Software page.** The old stored enum had
  it, nothing used it, and neither version nor location expresses it. It would need
  its own field.
- **No test suite.** A regression is only caught if someone exercises the page. One
  did slip through mid-session (a helper deleted with the block around it) and was
  caught in the browser, not by any check.

---

## Change log

Newest first. Each entry is one deployed commit; `git log` has the full reasoning
in the commit bodies.

### Rules fix (no client change) — Software tab could not save
`swVersion`'s validate regex was over-escaped: the engine received `\\.` (escaped
backslash + any char) instead of `\.`, so **no valid version string could match** and
every Software save was rejected. Because the batch is one atomic multi-path PATCH,
a version change took the whole save down with it. Proved with an A/B test node
against the live engine — old pattern `401`, corrected pattern `200` — before
touching the real rules. `wo_flags` had the same defect (permissive, so unnoticed)
and was fixed with it.

### Backups, restore and portability
`scripts/backup.sh`, `scripts/restore.sh`, a daily GitHub Actions workflow, and
`DISASTER-RECOVERY.md`.

### v2.10.0 — Hardware part picker, CWAP, per-position fitment
Part Replaced became a dropdown fed by `HARDWARE_LRUS`, filtered to the aircraft's
fit. Records store `details.lruId`, so the link is exact instead of typo-prone.
Part Number left the activity form and the fitment table — it belongs to the unit.
CWAP introduced **quantity per aircraft type**, so any multi-unit LRU is now tracked
per position.

### v2.9.1 — Calendar strip geometry and month grouping
Fixed the white sliver under month tiles (`.cal-tile` is a flex column with the
count band pushed to the bottom; the strip stretches tiles to the tallest). Every
month gets a tile, current month open by default, past months folded. Year band
grey → blue.

### v2.9.0 — Unit lifecycle, removal history, shop reports, SIM roaming
Fitment reads current state from the latest change, distinguishing first fit /
swap / removed-and-not-refitted. Removed Units became the shop queue, with
findings fillable long after the removal. `simRoaming` added to `/aircraft`.

### v2.8.0 — Hardware tab
LRU catalogue in code, `/hardware/{lruId}` for what belongs to the unit, fitment
derived from `/activities`. Retrofit and linefit kept as separate entries.

### v2.7.x — Sticky header and tab strip
Header pinned (`.container` had to lose `overflow: hidden`), tab strip pinned under
it at `var(--header-h)`, published by a `ResizeObserver`.

### v2.7.0 — Timeline folding, filters, location codes
Month tiles for past months, a week of day cards behind Show more, JED/RUH station
codes, filter order Software/Hardware/Media. The Maintenance **filter pill** was
removed; the nav tab was removed by mistake in the same commit and restored in
`009bb94`.

### v2.6.x — Header clock
JED+UTC clocks, then reduced to a single calendar-style tile (weekday / day / month
/ `HH:MM Z`), brand left-aligned, subtitle centred on the title.

### v2.5.0 — Fleet-wide Timeline, two-panel Maintenance
Timeline became every connectivity activity derived from Software, Media and
`/activities`. Maintenance lost its table for a list/detail layout and gained Add
New Activity.

### v2.4.1 — System status bar
The old three-line footer became a live capsule strip with a system information
panel and a real visit counter on `/visits`.

### Earlier — Maintenance tab foundation
Maintenance tab, the `maintenance` flag feeding the global card, retrofit location,
WiFi visibility, activation date, and "Serviceable" replacing "Clear".

---

## Status

A working portal under active extension. Expect targeted asks — new modules, data
updates, UI polish — rather than rebuilds. **Do not rebuild from scratch; reuse the
existing table framework, filter pills, widget strips, status badges, the two-pane
shell and the auth-gated edit flow.**

Two working agreements from the user:

- **Deploy without being asked.** Rules first, then the page; verify by hash. The
  full checklist is in *Local dev workflow*.
- **Ask before removing anything major** — a tab, a page, a feature, a data node.
  This is the exception to the above. Additive and cosmetic changes just ship.
