# Saudia Connectivity Fleet Status — Project Handoff (v2.35.0, 2026-08-23)

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
- Single file, ~7,700 lines, vanilla HTML/CSS/JS. No build step, no framework,
  and **no external scripts at all** — nothing to fetch from a CDN.
- **There is no build, lint or type tooling, deliberately.** The checks that do
  exist are in *Local dev workflow* below. Don't add a toolchain unasked.

`gh` CLI and `firebase` CLI (via `npx firebase-tools`) are already authenticated
on this Mac — no login needed to keep working.

Live data (read from the database **2026-08-23**, verified at session close):

- **44 aircraft** — 41 Active, 3 In Retrofit (AQB, ASD, ASO)
- Of the 41 Active: **39 retrofit + 2 linefit** (ASBA/ASBB, the A321XLR HBC+ pair)
- **39 is the Software and Media denominator.** 35 on Middleware 2.1.0 — behind:
  **AS59, AS76, ASAB, ASJ**. 35 on the August 2026 media cycle
- `ugoVersion` 6.3.1 and `tilesVersion` 2.0 on all 39
- `wifiVisibility`: 38 public, 6 hidden (AQA, AQJ, AS51 + the three In Retrofit)
- `retrofitLocation`: 37 Jeddah, 2 Malta, 2 Qatar, 1 Jordan, 2 Airbus (linefit).
  `retrofitStart`/`retrofitEnd` set on the five outstation only
- 24 schedule entries, 9 activities, 1 hardware record, **5 units**, 1 allowlisted editor

`/activities`, `/hardware` and `/units` are still lightly populated — a Hardware
fitment reading "no record" is a gap in the record, not a fault. The serial backlog
is the main data-entry job outstanding.

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
| `fit` | `retrofit` (42) \| `linefit` (2 — ASBA, ASBB). **How WiFi got onto the airframe, not where it is in the programme** — an aircraft can be `fit: retrofit` *and* `fleetStatus: In Retrofit` |
| `fleetStatus` | **WiFi installation status** — one of `Planned`, `In Retrofit`, `Installed`, `Commissioned`, `Active`, `Decommissioned`. Exact strings, defined once in `FLEET_STATUSES` |
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
| `retrofitLocation` | free text ≤ 60: where the equipment was installed (Jeddah, Malta, Airbus…). Labelled **Install Site** on both the Fleet column and the Activity profile — the field name is historical, the label covers linefit too |
| `retrofitStart` / `retrofitEnd` | `DD-Mon-YYYY` — the grounding window for that modification. **Stored but given no column**; they surface as the Location cell's tooltip |
| `wifiVisibility` | `public` \| `hidden` |
| `activatedDate` | `DD-Mon-YYYY` |
| `simRoaming` | `active` \| `inactive` — the SIM subscription, not the card |
| `ugoVersion` | e.g. `6.3.1`. **Absent = not installed** |
| `tilesVersion` | e.g. `2.0`. **Absent = not installed** |

`ugoVersion` and `tilesVersion` are shown on the **Media** tab but stored at the top
level, *not* under `media`: clearing an aircraft's media writes `media: null`, which
would take them with it every time. They are software on the aircraft, not a property
of one month's load. `UGO_LATEST` / `TILES_LATEST` in the page decide the badge —
green on the latest build, amber when behind, and *Not installed* when the field is
absent, which is the state to leave an aircraft in when it has no tiles at all.

Fleet-wide as of 2026-08-23: `wifiVisibility` is `public` on all 44 aircraft except
**AQA, AQJ and AS51**, which are `hidden`.

`retrofitLocation` is `Jeddah` on the 37 retrofit aircraft done at base, `Airbus` on
the linefit pair, and five outstation: **AS60 Malta, AS59 Jordan, AS67 Qatar,
AS61 Qatar, AQL Malta** — those five also carry `retrofitStart`/`retrofitEnd`.
Start/end dates for the Jeddah aircraft are still to come.

**`LOCATION_FLAGS` maps a location to its flag**, so the cell needs only one word —
never "Doha, Qatar". Unlisted locations still render, with a 📍. **`LOCATION_HOME`
decides what is unremarkable**, and is a Saudi base only. Everything else — an
outstation MRO *and* the `Airbus` line — reads bold amber via `isOutstation()`, because
neither happened at base. `ksa` is kept as a synonym so that value still resolves.
The Location column also sorts away-first, so the exceptions group instead of
scattering alphabetically among 37 Jeddahs.

`retrofitLocation`, `wifiVisibility`, `activatedDate` and `simRoaming` are stored
at the **top level**, deliberately *not* under `maintenance` — clearing a flag
writes `maintenance: null`, which would take them with it every time an aircraft
was marked serviceable. `activatedDate` is editable on **both** the Maintenance
profile and the Fleet page's Activation Date column; a Fleet save therefore writes
roster fields to `/fleet` and this one to `/aircraft`.

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

`details.recordType` is `baseline` on records written by **Record Installed
Serials** and absent on everything else. It marks the record as *inventory* — a
statement of what is fitted — rather than a day's work, and that is the only
thing that keeps a few hundred of them off the Timeline. `isBaselineRecord()` is
the one place it is read.

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

### `/units/{unitId}` — the unit register: one physical box, and its life

**This is the single source for serial numbers and fitment history.** `/hardware`
holds what is true of an equipment *type*; `/units` holds what is true of an
individual box.

| field | notes |
|---|---|
| `lruId` | catalogue id — which equipment this is |
| `serial` | the identity. Unique **within** an `lruId`; two different LRUs may share a number |
| `partNumber`, `altPartNumber`, `altSerial`, `revision`, `modDots`, `vendor`, `notes` | per-unit attributes. **Declared in the rules and deliberately unused** — they are where mod dots, revisions and alternates go when there is a UI for them |
| `addedAt` | ISO stamp |
| `fitments/{id}` | `aircraft`, `position`, `state`, `fittedDate`, `removedDate`, `removalReason`, `shopStatus`, `shopRef`, `shopFinding`, `activityId`, `notes`, `loggedAt` |

A **fitment** is one box, on one aircraft, for one period. A unit fitted twice has
two fitments, which is what makes total time on wing and change counts add up
across airframes.

**`state` (`on_wing` \| `removed`) is what says a unit came off — not the presence
of a removal date.** That distinction is the whole point: the historical backlog is
known by serial now and the dates are dug out later. Everything undated still
counts, sorts last, and is listed as outstanding on the Serials tab.

Derived, never stored: what is fitted at a slot (`fittedUnitAt`), days on wing
(`fitmentDaysOnWing`, needs both ends and returns `null` rather than guessing),
total time on wing (`unitDaysOnWing`), and change counts (`unitsAtSlot(...).length`).

**Why not more fields on an activity.** An activity is an *event*; a part number,
revision or mod dot belongs to the *box*. Storing them on the event would repeat
them on every event for that unit and let the copies drift — and an activity cannot
meaningfully carry a serial with no date, which is exactly what the backlog needs.

`/activities` keeps its role as the event and shop log and links to a fitment by
`activityId`. **Serials are no longer stored on an activity at all**: Add New
Activity's Old/New part fields now write to `/units` via `unitWritesForActivity()`.

### `/hardware/{lruId}` — what belongs to the unit, not to an aircraft

`swVersion`, `partNumber`, `vendor`, `notes`, and `issues/{id}`
(`title`, `detail`, `resolution`, `status` open|resolved, `loggedAt`).

**Serial numbers are deliberately NOT here.** They live in `/units` — see above.

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

## Fleet status — one field, not two

`fleetStatus` on `/fleet/{tail}` is the **only** status field. A request once came
in for a separate `installationStatus` with a richer enum; rather than run two
status fields that would drift, the existing one was widened to those exact six
values. `FLEET_STATUSES` defines them once — value and label are the same string
because those strings are what the database stores.

`activeFleet()` is `fleetStatus === 'Active'`. **An aircraft mid-retrofit is in the
programme but is not operational**, so it is out of Maintenance and Hardware scope
by definition. The Fleet page opens on the Active view (`FLEET_DEFAULT_STATUS`).

Note `fit: 'retrofit'` and `fleetStatus: 'In Retrofit'` mean different things and
can both be true: `fit` is how WiFi got onto the airframe (retrofitted vs linefit
from the factory), `fleetStatus` is where it is in the programme *right now*.

**The Fleet page opens on everything.** `FLEET_DEFAULT_STATUS` is `''` — no status is
preselected, because this page is the whole roster rather than an operational view.
`FLEET_DEFAULT_SORT` orders it by **Activation Date, oldest first**; that column is
second, right after `#`. Undated aircraft sort to the end (`dateSortKey` gives them
`99999999`).

**Both Fleet pill rows filter more than one axis, and the values say which.**

| row | pills | resolves to |
|---|---|---|
| FIT | All Fit / Retrofit / Linefit / **In Retrofit** | `fit`, except `status:In Retrofit` → `fleetStatus` |
| STATUS | All / Active / **Inactive** / Hidden / Public | `fleetStatus`, except `ssid:*` → `wifiVisibility` |

**The Fit and Status columns are VIEWS, like the Software tab's Status column.**

| column | shows | derived from |
|---|---|---|
| Fit | `RETROFIT` / `LINEFIT` / **`IN RETROFIT`** | `fleetStatus === 'In Retrofit'` wins, else `fit` |
| Status | `ACTIVE` / **`INACTIVE`** | `fleetStatus === 'Active'` |

The exact stored status is in the Inactive badge's tooltip. Each row carries
`data-fitview` — what its Fit cell actually says — and the Fit pills match **that**, so
a filter always selects exactly the rows whose cell reads the same label. The three
fits therefore sum to the roster: 39 + 2 + 3 = 44.

**Edit mode still shows the real fields**: Fit is `Retrofit`/`Linefit` and Status is the
full `FLEET_STATUSES` enum. Set an aircraft to `In Retrofit` there and its Fit column
switches on its own — and switches back when it goes Active, because `fit` never
changed. Nothing to remember.

⚠️ **`fit` is still only ever `retrofit` or `linefit` in the data.** The In Retrofit
button filters on `fleetStatus` rather than making "In Retrofit" a third fit. That was
a deliberate call (2026-08-23): an aircraft being retrofitted *is* a retrofit
aircraft, so a third fit value would turn `fit` from a permanent fact into a progress
field somebody has to advance by hand — and, because `fitOf()` treats anything
non-linefit as retrofit, forgetting would break nothing visibly. Keeping it as-is also
keeps **FIT → Retrofit answering 42**, the in-progress aircraft included.

`Inactive` is derived as `fleetStatus !== 'Active'`, not a stored value, so the four
statuses nobody uses today still land in the right bucket. `FLEET_STATUSES` is
untouched — all six remain settable from the edit dropdown.

**The Status pill row filters two axes.** `All / Active / In Retrofit / Hidden / Public`
— the first two are `fleetStatus`, the last two are `wifiVisibility`, namespaced as
`ssid:hidden` / `ssid:public` so one filter variable can carry both without `Active`
and `public` ever being mistaken for each other. `FLEET_STATUSES` still defines all six
statuses for the **edit dropdown**; only the filter row was trimmed.

**`activationAge()`** renders the `1y 26d` pill beside each activation date. Calendar
aware — whole anniversaries, then days since the last one — not days/365, so an
aircraft activated on 1 Oct reads `1y 0d` on 1 Oct. It returns `''` for no date or a
future date, so no pill is drawn rather than one reading `-3d`.

⚠️ **`sortTable()` is now the click handler only.** `applyTableSort(tableId, col, dir)`
does the work without touching the recorded direction, and `populateFleetTable()`
re-applies `lastSort['fleetTable']` on every rebuild. Without that, a live update
rebuilt the rows in roster order while the header kept showing its arrow — which is
what happened to the default sort the first time, and had been silently happening to
any user sort on any table.

**Activation date is `activatedDate` on `/aircraft/{tail}`**, not on the fleet
record — the same field the Maintenance tab edits. The Fleet page shows it as the
Activation Date column and can edit it there too, which is why a Fleet save writes
to two nodes: the roster fields to `/fleet`, `activatedDate` to `/aircraft`. It is
never inferred; blank shows as "Not set".

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

### Three populations, one definition each

Two axes decide who counts, and **both** matter:

| | meaning |
|---|---|
| `fleetStatus` | only `Active` is operational. In Retrofit has no middleware and no media yet, so counting it drags every percentage down against work that has not started |
| `fit` | the A321XLR linefit pair (ASBA/ASBB) run different software, carry no media and have their own hardware — tracked by SBC configuration, never mixed into retrofit figures |

```
projectScope()  44   whole programme  — Fleet page only
activeFleet()   41   Active, any fit  — Maintenance, Hardware, Timeline
swFleet()       39   Active + retrofit — Software, Media, and every widget of theirs
hbcFleet()       2   Active + linefit  — HBC+ / SBC only
```

`middlewareScope()`, `mediaScope()` and `hbcScope()` are just the lengths of those.
**There are no inline `isLinefit` filters left** — every caller goes through a
helper, so the definition cannot drift page to page. Scope numbers are counted,
never hardcoded: changing an aircraft's status moves every table, filter and
percentage at once.

**Timeline rows carry no repeated words.** Two rules do it:

- The **kind pill is hidden under a kind filter** — every row is that kind, so the
  pill only restates the selected filter. It returns under "All".
- The grey subtitle is the **most specific fact**, never the category:
  `activitySubtitle()` gives the part for a hardware job (with position when there
  is one), software + version for a load, modem + result for a commissioning. The
  category is the fallback only where it still varies row to row.
  `dedupeSubtitle()` then drops it if the title already says it — substring, not
  equality, so "Modman Replacement" swallows "MODMAN".

The Add Activity form is where this is won or lost: its Title placeholder used to
read "e.g. KRFU Replacement", which taught people to put the part in the title and
guaranteed it read twice. It now prompts for the symptom or task per category, with
a hint saying the part is captured separately.

**The Timeline is Active-only too**, on all three of its sources. `inScope()` in
`timelineActivities()` is the single line to relax if retrofit-in-progress work
should ever be visible before activation.

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

**Quantity varies by aircraft FAMILY, not by subtype.** `lruQtyFor(lru, type)` tries
exact `qtyByType` first, then `qtyByFamily` keyed on `typeFamily(type)`, then `qty`
(default 1). Any LRU fitted more than once anywhere in its fleet becomes
**position-tracked** — the fitment list shows one row per aircraft *per position*
and the activity carries `details.position`.

**CWAP is three on every A320-family narrow body and five on the A330** (user,
2026-08-23), and that holds **regardless of fit** — the linefit A321 XLR pair carry
three like everything else in the family, so `lf_cwap` exists as well as `cwap`.

`typeFamily()` maps `A318/A319/A320/A321` → `A320_FAMILY` and `A33x` → `A330`.
⚠️ **It is deliberately a family rule and not a list of subtypes.** The fleet runs five
type strings today (`A320-214`, `A321-211`, `A321-251NX`, `A321-253NY XLR`, `A330-343`);
enumerating them is exactly what left the two A321 variants silently falling back to 1,
and a sixth variant would have done it again. Anything outside the two families still
falls back to `qty` — an A350 reads 1, obviously wrong rather than plausibly wrong.
`qtyByType` still wins where one subtype genuinely differs.

**The part is picked, not typed.** The Add Activity form's Part dropdown is built
from `HARDWARE_LRUS`, filtered to the selected aircraft's fit and rebuilt when the
aircraft changes — add a part to the catalogue and it appears there with no other
wiring. New records store `details.lruId`, so the link to the Hardware tab is exact;
`activityMatchesLru()` falls back to alias matching only for records typed as free
text before the picker existed. Part number is **not** asked for on the activity:
it belongs to the unit and is defined once on the Hardware tab.

**Baseline serials are entered in bulk, not one modal at a time.** Recording what
is already fitted across ~40 aircraft x ~10 LRUs is ~400 trips through a form
built for logging one replacement. **Record Installed Serials** on the Hardware
tab is a grid for it, offered two ways because a baseline is collected both ways:

- **By Aircraft** — a tail expands to every LRU it carries, one blank per unit,
  position-tracked units split per position (CWAP 1/5 … 5/5).
- **By Equipment** — one unit straight down the fleet: all the SIM cards, then
  all the MODMANs.

The draft is keyed `lru|tail|position` and **survives switching between the two**,
so a half-finished pass is never lost. Three things are load-bearing:

- **Typing must never re-render** — the field being typed into would lose focus.
  `blType()` moves the draft, that input's own class and the counters, nothing else.
- **Rows are built once into `blRowCache` on open.** Recomputing fitment per
  keystroke would re-walk `/activities` for every aircraft on every character.
- **The tool is additive only.** A position with a serial already on record is
  read-only — changing a fitted serial is a *swap*, it needs a reason and a
  removed unit, and that is Add New Activity's job. A record that named the part
  but captured no serial does **not** lock the row: the position is genuinely
  unknown and has to stay fillable. Duplicate serials — typed twice, or typed
  against one already on record — block the save and are named, because a serial
  is one physical unit in one place.

Every entry is written as an **ordinary first-fit `hardware_rr` activity**
(`details.newPart`, no `oldPart`), so there is still exactly one place serials
live and `hardwareFitment()` reads them unchanged. Save is a **single multi-path
PATCH** to `/activities`; the rules validate each child on its own.

A blank batch Location falls back to `retrofitLocation` and then to nothing —
deliberately **not** to `completionLocation` the way the Add Activity form does.
That is where the *software* load finished, and copying it onto a few hundred
fitment records would invent the install location instead of leaving it blank.

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

⚠️ **The linefit list is still mostly a placeholder.** Seven of its eight entries
mirror the original retrofit set because the real linefit equipment list has never been
supplied. **`lf_cwap` is the one confirmed entry** — the user stated the A32x rule
covers linefit — and is commented as such in the array so a later pass does not sweep
it away with the guesses. Retrofit has 10 units to linefit's 8: Waveguide Adapter and
Coax Cable J12 stay retrofit-only, unconfirmed either way. Correcting the rest is an
edit to `HARDWARE_LRUS` and nothing else.

Retrofit units, in RF-chain order: SIM Card, IFE Server, MODMAN, KANDU, KRFU,
RX Antenna, TX Antenna, Waveguide Adapter, Coax Cable J12, CWAP.

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

**Baseline serial records are excluded** (`isBaselineRecord()`). They state what
is fitted rather than describing a day's work, and there is one per unit per
aircraft — letting them in would bury whatever day they were entered on under a
few hundred rows.

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

## Filter bar — the one way to build a filter

**Every filter in the app is declared in `FILTER_BARS` and rendered by one
component.** Hand-writing a pill row in markup is not a thing any more. This is
the pattern for current and future filters, at the user's explicit instruction
(2026-08-23).

The old shape was a `.filter-groups` block — one wrapping row of `.qf-btn` pills
per axis — sitting above a separate `.table-actions-row` for Edit/Reset. On a
phone that came to **218px of filters plus 30px of actions before a single row of
data**, about a third of the screen. It is now **one 46px row** carrying both:
filters on the left, that page's actions on the right.

```
[Type ▾] [Fit ▾] [Status ▾] [SaudiaWiFi ▾] ········· [🔒 Edit] [↺ Reset]
```

### Declaring one

```js
{ id: 'fitview', label: 'Fit', options: [
    { v: 'retrofit', l: 'Retrofit' },
    { v: 'linefit',  l: 'Linefit' },
] },
```

- `id` — doubles as the row's `data-<id>` attribute, which is where the value is
  read from unless `rowValue` says otherwise.
- `label` — the short word on the trigger. Keep it short; it shares a row.
- `options` — an array, **or a function** evaluated at render time. Aircraft
  types and media cycles are functions, so they follow the data with no wiring.
- `rowValue(row)` — only where the matched value is not the dataset attribute.
  Software's Status uses it to collapse "anything not completed" to `pending`.

That one entry gets you the trigger, the popover, the filtering, the trigger
summary, the mobile count badge and the Reset behaviour. Before, each filter cost
a pill row in markup **plus** a `set*Filter()` **plus** a state variable **plus** a
branch in `apply*Filters()` **plus** a branch in `reset*()` — five places to keep
in step, which is why the axes had started to drift into each other.

### Selection is a Set, and empty means All

`fbSel(bar, id)` returns a `Set`. **Empty = All.** Encoding "no filter" as an
empty set rather than a magic `''` value is what lets `fbActiveCount()`, the
`has-value` styling and the badge all work without knowing anything about a
particular filter. Multi-select falls out of it for free — which is the feature
that was asked for.

Two call shapes:

- `fbRowMatch(barId, row)` — every filter on the bar against a table row. The
  table pages' `apply*Filters()` are now three lines each.
- `fbMatch(barId, filterId, value)` — one filter against a value, for the
  Activity tab, which filters the model rather than DOM rows.

### Responsive: one row at every width

Both control sets are always in the DOM and **CSS picks one**, so there is no
resize listener to keep in step. Below **700px** `.fb-groups` is hidden and a
single `Filters` trigger with a count badge shows instead; its popover renders as
a bottom sheet with every group stacked and a Clear all / Done footer.

⚠️ **`display: contents` on `.fb-groups` must stay in the stylesheet, not inline
on the element.** It was inline first, which outranked the media query, and both
the individual triggers and the collapsed one rendered at once.

### Things that are load-bearing

- **A pick updates the popover in place; it never rebuilds it.** An `innerHTML`
  rebuild detaches every other checkbox in the panel — a second click then lands
  on a node no longer in the document and does nothing — and it throws away the
  scroll position of a long list. `fbSyncOpen()` touches only the group's All box
  and the trigger behind the panel.
- **`fbClose()` repaints the whole bar.** Only the open trigger is kept current
  while a panel is up, so the others (and the collapsed/expanded twin) are stale
  until it closes.
- **`fbRender()` under an open panel repaints the trigger only.** Calling the
  full sync there would take the clear-all branch and untick the panel the user
  is standing in.
- **The mobile sheet is exempt from close-on-scroll.** An anchored popover is
  positioned in viewport coordinates and must close when the page moves under it;
  the sheet is pinned to the bottom and anchored to nothing, so dismissing it on
  a stray scroll would be a bug.
- **`fbTypeOptions()` guards against a non-array.** The scope helpers are a mix:
  `swFleet()`/`activeFleet()` return arrays but **`projectScope()` returns a
  COUNT**. Passing the number in threw inside the popover build, which left the
  trigger looking open with nothing under it. The Fleet bar uses `fleetRoster`.

### Single-select filters

A filter declared `single: true` is an exclusive choice: the popover renders
**radios**, and a pick REPLACES the set instead of adding to it. The set is still
the state — size 0 is All, size 1 is the answer — so the trigger text, the badge
and `fbMatch()` need no special case.

⚠️ **A radio never reports `on: false`** — the browser just moves the dot — so
`fbPick()` cannot treat a single-select pick as a toggle. It clears and adds.

**A bar with exactly one filter names it on the collapsed trigger.** `Filters ▾`
with a count is right when there are several axes to summarise; with one there is
nothing to summarise, so `fbCompactLabel()` returns that filter's own trigger text
instead — `Show`, then `Show: Media`.

### What is not converted

- **Serials and Schedule** still use native `<select>`s and a search input. They
  were never part of the space problem, and Schedule filters whole station
  *sections* rather than table rows, so it needs its own match. Bringing them onto
  the component is the obvious next step.

### Fleet gained an axis

SSID visibility used to be smuggled into the Fleet Status pill row as
`ssid:hidden` / `ssid:public`, because one variable had to carry two axes. With a
set per filter that is unnecessary: **SaudiaWiFi is its own dropdown**, and Status
and SSID can now be combined (Active *and* Hidden), which the old row could not
express.

---

## Widget vocabulary

- **Fleet widgets** — Active Fleet, In Retrofit, and **SSID Visibility**: a single
  track split between public (from the left) and hidden (from the right), the two
  shares always filling it, because it shows a composition rather than progress
  towards anything. Hidden takes the **Maintenance card's red** everywhere it appears —
  the split bar, its figure, and the `wifi-hidden` badge on both the Fleet table and
  the Activity profile — because it is an exception state, not a category of its own. It counts the **Active** fleet only — an aircraft still in retrofit
  has no SSID on air to be public or hidden.
- **Global widgets** — four KPI cards above the tab bar (`.global-widgets`),
  fleet-wide, on every tab: Software Loading ×2 — `Retrofit` (Middleware) and
  `Linefit` (SBC Configuration A.13, the HBC+ pair) — then Media Loading and
  Maintenance.

  **Three levels, in this order:** programme chip (`.metric-fit`) → category
  (`.metric-label`) → specific item (`.metric-sublabel`) → figures → bar.

  **The category is the quiet one, deliberately.** `.metric-label` is 10.5px, 700,
  +1.3px tracking, and the *same* neutral grey on all four cards — it classifies the
  card. `.metric-sublabel` is 15px, 600, sentence case, and carries the card's own
  colour, because it is the line that says what is actually being tracked. They used
  to be the same size and weight, which is why they read as one block.

  **The pill takes the CARD's colour, not the programme's** (`.metric-card.X
  .fit-chip`). `Retrofit` therefore looks green on the software card and teal on
  media — the programme is identified by the word, and the colour's job is to belong
  to the card. A blue pill on a green card was the thing that looked bolted on. The
  progress track is tinted the same way, so the bar reads as part of the card rather
  than sitting on a grey wash. The chip
  row is rendered **even when empty** so the headings line up across all four cards;
  on a phone the cards are stacked with nothing to line up against, so an empty one
  collapses (`.metric-fit:empty`).

  **`margin: auto 0 9px` on `.metric-figures` is load-bearing.** It pins the figures
  and the bar to the bottom of the card, so a heading that wraps to two lines costs
  the alignment nothing — every card's numbers and bar stay on one line without
  reserving blank space for the wrap. Verified with a 32-character media label.

  **All four carry a programme pill**, because the scope differs and the reader
  should not have to know that: `Retrofit` on Software and on **Media** (both count
  `mediaScope()`/`swFleet()` — Active retrofit), `Linefit` on SBC, and **`Fleet Wide`**
  on Maintenance, which counts `activeFleet()` — every Active aircraft, both
  programmes. "Retrofit + Linefit" says the same thing in 18 characters and stops
  reading as a subtle label on a 165px card; `Fleet Wide` is ~62px and states the
  scope outright.

  **Columns follow card width, not device.** Content width is the viewport less 40
  (body) and 60 (content). Four cards break at **960px** — set by
  "SOFTWARE LOADING" splitting to two lines below ~200px of card, not by the
  figures, which hold one line far lower. Two cards break at **440px**, chosen so a
  phone zoomed to 85% (~460 CSS px) still gets 2×2 rather than four tall cards.

  **The card height is `min-height: 166px` and nothing more.** An earlier version
  forced 190px, and `clamp(190px, 25vw, 260px)` when two-up, chasing a square
  proportion — which opened a 40–80px band of dead space between the labels and the
  figures, because the content only needs ~131px. A card that is full at 1.9:1 reads
  better than one that is square with a hole in it. Ratio is now an *outcome* of the
  column count, not a target.

  ⚠️ Two cascade traps here, both already bitten: the grid rules must be
  `.dashboard-grid.global-widgets` (0,2,0), because the generic `.dashboard-grid`
  collapses to one column at 768px later in the sheet and would win at equal
  specificity; and the two-up `min-height` override must sit **after** the base
  `.global-widgets .metric-card` rule, for the same reason.
- **Local widgets** — `.media-widget-strip` rows inside a tab, showing that
  tab's own breakdown. All strips scroll sideways in one row; they never wrap.

Figure convention everywhere: **count at the left edge of the progress bar,
percentage at the right edge** (`margin-left: auto` on `.metric-pct`).

---

## Tabs (8)

**Activity, Hardware and Serials are shown only to a signed-in editor.**
`RESTRICTED_TABS` lists them, `canViewRestricted()` is the test — currently just
`canEdit()`, so the editor allowlist is the boundary — and `applyTabVisibility()`
runs from `updateAuthUI()`, i.e. on every auth transition. The buttons are
`display:none` **in the markup**, not only by script, so they never flash on screen
for an anonymous visitor. `switchTab()` refuses a restricted tab when signed out and
falls back to Overview, which also covers signing out while sitting on one; it now
takes the button as an argument instead of reading the global `event`, which is what
lets the gate redirect programmatically. A `🔓 Sign in` item sits in the strip where
the hidden tabs would be, because that is where someone looks for them.

⚠️ **This is a UI gate and nothing more.** `/activities`, `/hardware` and `/units`
are still `.read: true`, so anyone with the database URL can still read every serial
and every activity with one `curl`. Hiding the tabs changes who *browses* the data,
not who *can* read it. Actually restricting it means changing `.read` in the rules
and signing in before the first read — the migration written up under *Making this
private* in `DISASTER-RECOVERY.md`, which also has to deal with `connectLiveSync()`
firing before authentication and with `backup.sh` losing anonymous access.

1. **Overview** — starts with the Timeline (calendar strip + grouped-by-date
   list). One divider per day, nothing between aircraft. Beware
   `.timeline-items li`: it must stay `.timeline-items > li`, or the descendant
   match hits nested per-aircraft `<li>`s and double rules return.
   **The kind filter and the sort direction share one field** (`.tl-controls`),
   styled as the tables' `.filterbar` so the two read as one component. They were
   two stacked rows, and on a phone the sort pair alone wrapped to a full row —
   108px of chrome above the calendar, now 90px, and far less visually heavy.
   **The row sheds width in four steps instead of wrapping**, each a media query:
   `Oldest First` → `Oldest` → `Old` → a bare arrow in a circle, and at the last
   step the four kind pills give way to the dropdown.
   ⚠️ **Those breakpoints are MEASURED, not device sizes.** The row is
   `viewport - 100`, the pill set is a fixed 312px, and the steps need
   582 / 516 / 483 / 428px including padding, gap and divider — so each query
   fires exactly where the level above stops fitting. **Changing a label or adding
   a pill invalidates them: re-measure, do not nudge.** Verified with no clipping
   at 700 / 660 / 600 / 560 / 500 / 348px.
   **The pills and the dropdown are two views of one value.** `setTimelineKind()`
   and `applyTimelineKindFromBar()` each write `timelineKindFilter` and repaint the
   other, and `renderTimeline()` renders both whatever the width — nothing is
   rebuilt on resize, so the hidden one has to be correct already.
2. **Software** (tab id is still `aircraft`) — **one** widget row of three cards:
   a Middleware split (Completed left, Pending right, the two shares filling the track
   — the same shape as the Fleet tab's SSID card) plus Jeddah and Riyadh. The version
   each side accounts for sits **under** the bar in that share's colour, so neither
   figure has to carry a version string beside it.
   The split card lists the registrations still behind, which is the actionable part
   and also matches the station cards' height. **Completion by Aircraft Type was
   removed** (2026-08-23) — six cards restating what the table below already says.
   ⚠️ The strip holds two wrapper spans set to `display: contents`, because the version
   card and the station cards come from different render functions; that is what makes
   all three direct flex children so they size as one row.
   Main table (40) + HBC+ table (2). `SW_VERSIONS` is ordered oldest-first and
   the **last entry is "latest"** — add a version there and it gains a widget,
   an edit option, retitles the global card and demotes the previous one. No
   other change needed.
   **Installation Date is column 2 and the default sort**, oldest first
   (`SW_DEFAULT_SORT`), with a `25d` age pill from the same `activationAge()` the
   Fleet tab uses — deliberately the identical treatment, so the two tables read the
   same way. The field behind it is **`completionDate`**, unchanged; only the column's
   label and position moved. Undated aircraft sort to the end on `99999999` and read
   *Not set*, which today is exactly the four still behind on middleware.
   ⚠️ **The label says "Installation" but the field is the software COMPLETION date.**
   On this tab that reads correctly — it is when the middleware was installed — but do
   not confuse it with the Fleet tab's **Install Site** (`retrofitLocation`, where the
   physical equipment went on) or with `retrofitStart`/`retrofitEnd`, the grounding
   window. Three different facts; only this one is about software.
3. **Media** — monthly media loading for the main fleet only (linefit excluded).
   Columns: `# | Loading Date | Aircraft | Type | Status | Media Loaded | UGO | TILES | Comments`.
   **Loading Date is column 2 and the default sort**, oldest first
   (`MEDIA_DEFAULT_SORT`), with the same `activationAge()` pill the Software and Fleet
   date columns carry. The field is `media.loadedDateUTC`, unchanged.
   ⚠️ **Two traps here that the other two date columns do not have**, both because this
   value is a full timestamp rather than `DD-Mon-YYYY`:
   `activationAge()` parses only `DD-Mon-YYYY` or `YYYY-MM-DD` and returns `''` for
   anything else, so the stamp is **sliced to its first 10 characters** before being
   passed — without that the pill silently never renders. And the undated sentinel is
   **fourteen** nines, not eight: `dateSortKey()` turns a real value into a 14-digit
   number like `20260808123319`, so a shorter sentinel would sort aircraft with no
   media to the FRONT instead of the end.
   The cell keeps its `YYYY-MM-DD HH:MM UTC` format rather than the `DD-Mon-YYYY` used
   everywhere else — the load time is operationally meaningful here, and that predates
   this change.
   UGO and TILES are editable in the tab's Edit mode; an empty box clears the field,
   which is how an aircraft is marked as not having it at all. A value that does not
   match the rules' pattern is refused at the input and never staged, so it cannot take
   the atomic save down with it.
4. **Activity** (tab id is still `maintenance`, like Software's is still `aircraft`)
   — the **active** fleet only (`fleetStatus === 'active'`), the same
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
   **Installed Equipment** sits between the profile and the history: every LRU
   this aircraft carries with the serial currently fitted, from
   `aircraftFitment(a)` — the same derivation `hardwareFitment()` does, pivoted
   from one-unit-across-the-fleet to one-aircraft-across-its-units. Baseline
   records are **folded out of that aircraft's activity history** behind a
   "Show N" control, so ten of them cannot bury one real event.
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
6. **Serials** — the data-gathering surface for `/units`. One flat table, one row
   per *fitment*, with **Record Installed** and **Record Removed** above it and CSV
   export. Deliberately not another two-pane shell: the job is getting serials in
   and completing dates later, not navigating a hierarchy. The date fields are
   editable in place — that is where the backlog gets finished — and the "Dates
   Outstanding" widget is the progress bar for it.
7. **Schedule** — standalone forward-looking plan, deliberately **not** linked
   to completion status. Entries drop off automatically 24h past their slot
   (`SCHEDULE_GRACE_MS`); in that window they show `⚠ Overdue` so they can be
   rescheduled rather than vanishing.
8. **Fleet** — owns the roster: add / edit / remove, incl. linefit. The
   **SaudiaWiFi** column shows `wifiVisibility` (Public / Hidden) and edits it, so a
   Fleet save now writes **three** kinds of field: roster fields to `/fleet`, and
   `activatedDate` *and* `wifiVisibility` to `/aircraft`. The Maintenance profile edits
   the same `wifiVisibility` — one fact, two places to change it, one place stored.
   The select offers only Public and Hidden; a blank option appears **only** when
   nothing is set yet, so it can never silently claim Public for an aircraft nobody has
   decided about. Removing
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
- Widgets are built from cycles actually present, newest first, and so is the Month
  filter's option list. A new cycle creates its own widget and filter option with no
  code change (verified with a simulated September).
- **`MEDIA_CYCLE_SIZES`** maps a cycle (MMYY) to its load size — `'0926': '884 GB'` —
  and is the one place to add next month. It does two jobs: it puts the size in a pill
  on that cycle's widget, and **a cycle listed there gets a widget before any aircraft
  carries it**, so a prepared load shows at 0/39 while it is being deployed. Sizes are
  optional; a cycle with no entry simply has no pill.
- ⚠️ **It must never feed `latestMediaCycle()`.** That stays derived from what is
  actually loaded — declaring September otherwise marks the whole August fleet a month
  behind, and `mediaStatus` is relative to the newest cycle *in the fleet*. An
  undelivered cycle renders as `upcoming` (violet), deliberately not `older` (amber),
  is left out of the Month filter's options (it could only filter to an empty table), and
  flips to `latest` on its own once the first aircraft takes it.

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

## Header title fitting

`fitHeaderTitles()` measures the space the titles block actually gets — the header
minus the logo, the clock and four paddings — and scales the title and subtitle so
each stays on **one line**. A font size per breakpoint could not do this: the space
depends on more than the viewport, and "CONNECTIVITY FLEET STATUS" broke after the
second word on a phone.

Three things make it work and are easy to undo by accident:

- **Letter-spacing on `.header h1` is in `em`, not px.** Text width then scales
  exactly linearly with font size, so one pass lands on the answer. In px the fit
  would need to iterate.
- **`.header-titles` is `overflow: hidden` with `flex: 1 1 0`.** `overflow` is what
  lets `scrollWidth` report the text's full width while the box stays the width flex
  gave it. **Basis `0`, not `auto`** — with `auto` the block's base size is its whole
  nowrap text width, which makes the header wrap a line the moment it overflows.
- **It re-fits only when the available WIDTH changes.** Changing a font size changes
  the header's height, which fires the header's own `ResizeObserver`; without that
  guard the two drive each other.

**The titles are a direct child of `.header`, not of `.header-brand`.** That is what
lets them take a row of their own below **372px**, where the logo, the clock and 25
characters cannot share a row without the title dropping under 13px and clipping.
Stacking buys back ~100px of width — at 320px the title goes from a clipped 13px to
17.7px. `flex-wrap` is set **only** inside that media query, never by default.

Sizes are clamped: title 13–28px, subtitle 9–16px and never more than 0.68 of the
title, so it cannot grow to compete with it.

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

## The `#` column counts visible rows

`renumberVisibleRows(tableId)` rewrites the first cell of every **visible** row as
1..N. The number is a position in the list, not an identifier tied to an aircraft —
filtering the Software table to four aircraft numbers them 1-4 rather than leaving the
11, 24, 25, 33 they happened to occupy unfiltered, and sorting renumbers top to bottom
for the same reason.

Four tables have a `#` column: `aircraftTable`, `hbcTable`, `mediaTable`, `fleetTable`.
**Anything that changes which rows are visible, or their order, has to call it** — the
three `apply*Filters()` and `sortTable()` do. A row whose first cell has `colspan` is
skipped, so an empty-state row is never numbered.

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

## Edit buttons — one implementation, one way in

`applyEditButton(btnId, editing, idleLabel, activeLabel)` renders **every** page's Edit
button. Three states, and the difference between the second and third is the whole
point:

| state | button | |
|---|---|---|
| signed out | `🔒 Edit` | grey, still clickable — the click is what explains where to sign in |
| signed in, viewing | `🔓 Edit` | green, and clicking enters Edit Mode |
| signed in, editing | `💾 Save` (`✓ Done` where the page saves as it goes) | amber |

**Signing in never opens Edit Mode.** It only unlocks the buttons; a page stays
read-only until its own Edit is pressed. Seven pages use this — Software, Media,
Activity, Hardware, Serials, Schedule, Fleet.

**Authentication lives in exactly two places, neither of them a page:**

| | |
|---|---|
| tab bar button | the **control** — `🔒 Sign in` / `🔓 Signed in`, the sole caller of `promptSignIn()` and the only way to sign out |
| status bar chip | the **readout** — `updateSysUserChip()` shows the signed-in address on every tab |

**No page has an authentication control or an identity label.** The per-page
`Sign out` button and all seven `signed-in-as` spans were removed in v2.16.0; a page
knows only whether its Edit button is unlocked. A locked page button calls
`requireSignIn()`, which messages the status bar and pulses the tab-bar button rather
than opening a second door.

`signOut()` clears **every** page's Edit Mode, so a tab left mid-edit cannot come back
showing inputs nobody can save.

The markup carries `edit-locked` and `🔒` as the default, so the buttons render grey
immediately instead of flashing the old wording before auth is applied. Geometry is
inherited from `.qf-btn` — the same pill as the `↺ Reset` button beside it — and only
the colour changes between states.

⚠️ A new page with its own Edit button must call `applyEditButton()` and guard its
toggle with `if (!canEdit()) { requireSignIn(); return; }`. Do not reintroduce a
per-page `promptSignIn()`.

## Live streams — `put` and `patch` are different events

Firebase REST streaming sends two event types and they do **not** mean the same thing:

| event | meaning |
|---|---|
| `put` | **replace** whatever is at `path` with `data` |
| `patch` | **merge** the entries of `data` into `path` — and **each key is itself a path** |

Both used to be routed through one handler that replaced the whole node whenever the
path was `/`. **A Save is exactly a root patch**: `commitEditChanges()` and four other
save paths send a multi-path `PATCH /aircraft.json` with keys like
`"ASI/completionDate"`, so Firebase echoed back `path: "/"` with those keys — and the
handler replaced all 42 aircraft with the two fields that had just changed, stored
under literal slash-bearing keys. `rebuildAircraftData()` then found no aircraft and
every figure on the page read **zero** until someone reloaded by hand.

`applyStreamEvent(store, type, path, data)` is now the one implementation, used by
both `/aircraft` and `/schedule`: a `patch` applies each key as its own path, a `put`
replaces at the path, and `null` deletes rather than storing null.

**`aircraftStoreLooksBroken()` is the backstop.** If a stream event ever leaves the
store empty while the roster has aircraft, or holding a key containing `/`, the node
is re-read instead of rendering zeros. A genuinely empty collection just comes back
empty and costs one request.

⚠️ Five save paths depend on this — Software, Media, Activity, Fleet, Hardware roaming.
Any new handler must take the event **type**, not just the path.

## Connection budget — do not add a seventh stream

A browser allows about **six concurrent connections per origin** over HTTP/1.1, and
every `EventSource` holds one open for as long as the page lives. Reads at load
happen before the streams establish, so page load looks fine — it is the *writes
afterwards* that queue and hang, with no error, because they were never sent.

The page currently holds **three** streams (`/aircraft`, `/fleet`, `/schedule`) and
polls the rest. Keep it there. If a node needs live sync, retire a stream or fold it
into `pollLowTrafficNodes()`.

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
- **Scripted edits to `index.html` must be guarded.** Two separate near-misses this
  session, both silent:
  - A block replacement built from two `s.index()` calls came out **negative-length**,
    so the "old" string was empty and `str.replace('')` inserted between every
    character — a **17-million-line file** from one edit. Assert `end > start`, and
    assert the needle is non-empty and unique before every replace.
  - A brace-matching "replace this whole function" helper treated the apostrophe in
    `// Don't yank...` as opening a string, ran past the function end and **deleted 19
    functions**. Any such scanner must skip `//` and `/* */` comments before it looks
    at quotes.
  Both were caught by checking the line count and diffing the function list against
  `git show HEAD:index.html` immediately after writing. Do that every time.

- **Back up before bulk edits.** `cp index.html` to a scratch path before any
  scripted multi-block deletion; a section-comment-based removal once cut 3,256
  lines instead of ~600 and the backup was the only thing that made it a
  non-event.

---

## Open items

### Waiting on the user — ask, don't guess

- **The linefit equipment list is still a placeholder** — 7 of its 8 entries. CWAP
  is now confirmed (`lf_cwap`, ×3); the other seven mirror the retrofit set so the
  pane is usable. Whether the linefit pair carry a Waveguide Adapter or Coax Cable
  J12 is also unanswered — those two stay retrofit-only. One-array fix.
- **What should drive the maintenance flag.** Today it is a manual editor toggle.
  Deriving it from SSID and the other checks — the way completion derives from
  version + location — is the better shape, but the criteria have not been agreed.
- **Retrofit start/end dates for the 37 Jeddah aircraft.** The user said these would
  follow. `retrofitStart`/`retrofitEnd` already exist and are already surfaced in the
  Install Site tooltip, so this is a data write only.
- **The serial backlog itself.** Record Installed / Record Removed are built and the
  `/units` register is live with 5 units; the fleet's installed and removed serials
  have not been entered yet.

⚠️ **Unproven: the CLIENT write path to `/units` and `details.recordType`.** Every
`/units` write so far went through the admin CLI, which bypasses rules, and browser
testing stubbed `fetch`. The rules mirror shapes `/activities` already uses and a
rejection surfaces loudly rather than silently — but **enter one serial through the UI
and confirm it saves before a bulk run**.

### Known gaps and cleanups

- **The client write path to `/units` has not been proven against the live rules
  engine.** The migration used the admin CLI, which bypasses rules, and browser
  testing stubbed `fetch`. The rules mirror the shapes `/activities` already uses,
  so the risk is low and a rejection surfaces loudly in the UI rather than silently
  — but **enter one serial first** and confirm it saves before doing a bulk run.
  The same caveat applies to `details.recordType` from v2.12.0.

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

### v2.35.0 — Timeline controls: one field, four width steps
The Overview's kind filter and sort direction now share a single field instead of
occupying two stacked rows, and the sort buttons shed text in steps as the row
narrows — `Oldest First` → `Oldest` → `Old` → an arrow in a circle — with the pills
giving way to a dropdown at the last step. On a phone the block went from 108px to
90px, and the two oversized sort buttons that dominated the view are now a pair of
30px circles.

The shared filter component gained `single: true` (radio semantics, a pick replaces
rather than adds) so the Timeline's exclusive four-way choice could reuse it, and a
one-filter bar now names that filter on its collapsed trigger rather than saying
"Filters".

### v2.34.0 — Media table opens on Loading Date
Date UTC renamed **Loading Date**, moved from sixth to second, default sort oldest
first, with the same age pill as the Software and Fleet tables — all three date columns
now read identically. Presentation only; `media.loadedDateUTC` is untouched. Two things
differ under the hood because this field is a full timestamp: the value is sliced to
its date part before `activationAge()` sees it, and the undated sort sentinel is 14
nines rather than 8. See the Media tab notes above.

### v2.33.0 — Software table opens on Installation Date
The Date column was renamed **Installation Date**, moved from eighth to second, and
became the default sort, oldest first, with the same `activationAge()` pill the Fleet
tab's Activation Date carries. Presentation only: the stored field is still
`completionDate` and nothing about the completion maths changed. `SW_DEFAULT_SORT` is
re-applied on every rebuild, the way the Fleet table does it, so a live update cannot
hand the rows back in registration order under an unchanged arrow.

### v2.32.0 — Filters: one declared component, one row, multi-select
The per-axis pill rows are gone. Every filter is now an entry in `FILTER_BARS`,
rendered as a multi-select dropdown in a single bar that also carries the page's Edit
and Reset buttons, directly above the table. On a phone the dropdowns collapse behind
one Filters button with a count, so the bar is one row at every width: the Software
tab went from 248px (31% of the screen, ~4 data rows visible) to 46px (6%, 12 rows).

Selection is a Set per filter with empty meaning All, which is where multi-select comes
from. 11 setter functions, 5 pill builders and 10 state variables were deleted; the four
`apply*Filters()` are three lines each. Fleet's SSID filter, previously namespaced into
the Status row as `ssid:*`, became its own axis and can now be combined with Status.

Serials and Schedule keep their native selects for now — see the section above.

### v2.31.0 — CWAP quantities: a family rule, and linefit carries them too
Every A320-family narrow body carries three CWAPs and the A330 five, whichever way the
WiFi got on board. `qtyByType`'s two exact subtypes became `qtyByFamily` behind a new
`typeFamily()`, fixing the 14 A321s and A321neos that had been silently falling back to
1, and `lf_cwap` was added so the linefit XLR pair get three as well. CWAP position rows
went 41 → 129 on retrofit and 0 → 6 on linefit. No data migration: no CWAP serial had
been recorded yet, so no position label changed under anyone.

### v2.30.3 — Equal widths in the Software row
All three cards fixed at 320px. The station cards were sizing to their registration
lists and running to their 460px cap. The lists clamp to three lines with the
click-to-expand `statList()` already wires up, so a long one cannot set the row's
height.

### v2.30.2 — Registration lists sized
The tail lists in the Software row had no size of their own — `.stat-list` is styled
only inside `.simple-stat-card` — so they inherited the 16px body default and read
larger than the figures above them. Now 12px, level with the rest of the card.

### v2.30.1 — Middleware card wording
Pill drops the percentage. The figures read Completed and Pending, and the two version
numbers moved under the bar, each in its own share's colour.

### v2.30.0 — Software tab: one widget row
Completion by Aircraft Type removed. Middleware's per-version cards became a single
split card, now sharing one row with Jeddah and Riyadh at equal height. The station
ICAO/IATA code became a small pill instead of running on at the label's size.

### v2.29.0 — Install Site
The Fleet tab's Location column and the Activity profile's "Retrofit Location" both
became **Install Site** — one name for one field, and one that covers the linefit pair.

### v2.28.0 — Flags on Location, and outstation stands out
Each location carries its country flag and the five flown-away aircraft render bold
amber. Jeddah and Airbus stay plain — both are where the work belongs, so emphasising
them would have made the linefit pair look like exceptions.

### v2.27.0 — Location column, and the retrofit grounding window
The Fleet tab shows where each aircraft was modified, reusing the existing
`retrofitLocation` rather than adding a field. New `retrofitStart`/`retrofitEnd` store
the grounding window per aircraft; they have no column and appear in the Location
tooltip. Seeded Jeddah for 37, five outstation with dates, linefit left blank.

### v2.26.0 — In Retrofit and Inactive in the columns, not just the filters
The Fit column now shows a third value, `IN RETROFIT`, and the Status column collapses
to `ACTIVE` / `INACTIVE`. Both are derived at render time; `fit` and `fleetStatus` are
untouched in the database and in edit mode. The Fit filter matches the displayed value,
so the three fits sum to 44.

### v2.25.0 — In Retrofit on the FIT row, Inactive on the Status row
FIT gained an In Retrofit button and Status swapped In Retrofit for Inactive. Both are
filter-level only: `fit` stays `retrofit`/`linefit` in the data and `Inactive` is
derived, so no migration and no rules change. See the note above for why "In Retrofit"
was kept out of the `fit` field itself.

### v2.24.0 — Activation age pill, SSID filters, hidden goes red
Each activation date carries a quiet `1y 326d` pill. The Status filter row is now
All / Active / In Retrofit / Hidden / Public, mixing fleet status and SSID visibility
in one row. Hidden switched from violet to the Maintenance red wherever it appears.

### v2.23.0 — Fleet tab: activation-first ordering and a new widget row
Activation Date moved to the second column and is the default sort, oldest first. No
status filter is preselected any more. The widget row was replaced with Active Fleet,
In Retrofit and a split SSID Visibility bar (38 public / 3 hidden of the 41 active).
Fixed alongside it: a table rebuild silently dropped whatever sort was applied.

### v2.22.0 — SaudiaWiFi column on the Fleet tab
`wifiVisibility` set across the whole roster — public everywhere except AQA, AQJ and
AS51 — and surfaced as a **SaudiaWiFi** column on the Fleet tab, editable with the two
options. It saves to `/aircraft` alongside `activatedDate`, not to the roster record.

### v2.21.1 — The `#` column counts visible rows
It used to keep the row's index in the unfiltered table, so a filtered Software list
read 11, 24, 25, 33. It now reads 1, 2, 3, 4 — and renumbers on sort as well as on
filter, across all four numbered tables.

### v2.21.0 — UGO and TILES columns; September greyed until it lands
The Media table gained UGO and TILES version columns, seeded to 6.3.1 and 2.0 across
the 39 aircraft it covers, editable per aircraft, with *Not installed* for an absent
value. July's size pill was removed (no published figure), and the announced-but-not-
loaded September cycle is now grey and recessed rather than violet, so it cannot be
mistaken for progress.

### v2.20.0 — Media load sizes, and announcing next month's cycle
Each media cycle widget carries its load size as a pill (July and August 791 GB,
September 884 GB), and September now appears at 0/39 ahead of deployment. Both come
from one map, `MEDIA_CYCLE_SIZES`. The declared cycle is styled `upcoming` rather than
`older` and does not touch `latestMediaCycle()`, so August stays the fleet's current
media until September is actually loaded.

### v2.19.1 — Saving emptied the page (put vs patch)
Every Save blanked the dashboard until a manual reload. The live-stream handler treated
`patch` like `put`, so the root patch that a multi-path save echoes back replaced the
whole aircraft collection with the two changed fields. Fixed by implementing the two
events properly, with a self-healing re-read as a backstop. No auto-refresh was added —
with the protocol handled correctly the stream already delivers the new values.

### v2.19.0 — Header title fits its space instead of guessing
"CONNECTIVITY FLEET STATUS" wrapped to two lines on a phone. The title and subtitle
are now measured against the room they actually have and scaled to one line each, at
every width. Below 372px the titles take a row of their own — which needed them moved
out of `.header-brand` — because the logo, the clock and the title cannot share a row
that narrow without clipping.

### v2.18.0 — Widget typography and colour system
"SBC Configuration A.13" became "SBC A.13". The category and the item were the same
size and weight and read as one block; the category is now small, spaced and neutral,
and the item is larger, sentence case and tinted to the card. Pills and progress tracks
take the card's hue instead of a flat palette. Counts and percentages use tabular
figures so the four cards share a rhythm, and the denominator steps back.

### v2.17.1 — Widget pills completed, and the dead space removed
Media gained a `Retrofit` pill and Maintenance a `Fleet Wide` one, so all four cards
carry their scope. The forced card height went: it was padding the cards out well past
what the content needs and opening a visible gap in the middle, worst on a zoomed-out
phone. Height now follows content (`min-height: 166px`), and the column breakpoints
moved to 960px and 440px so a phone at 85% zoom gets a compact 2×2 instead of four
tall cards — the widget strip at ~460px went from 622px tall to 275px.

### v2.17.0 — Global widgets: four KPI cards, responsive by card width
The 2×2 grid of wide panels became four near-square cards in a row, with a three-level
hierarchy (programme → category → item) above the figures. 4 / 2 / 1 columns at 1080px
and 620px, chosen from the card width the content actually needs rather than device
sizes. Card heights, figure baselines and bar positions stay aligned across all four
cards even when a label wraps. Markup restructured only — all 19 metric element ids
are unchanged, so `updateMetrics()` was not touched.

### v2.16.0 — Authentication leaves the pages entirely
The per-page `Sign out` button on Software and all seven `signed-in-as` email labels
are gone. The tab bar's button is the only auth **control**; a new status bar chip is
the only identity **readout**, and it shows on every tab. `updateAuthUI()` no longer
touches any page-level auth element, and each `update*EditUI()` now does exactly one
job — its page's Edit button. `.table-actions-row` is `justify-content: flex-end`, so
removing the spans (which carried `margin-right: auto`) left the button alignment
unchanged.

### v2.15.0 — One edit-button implementation, one sign-in control
Every page's Edit button now renders through `applyEditButton()` with three states —
`🔒 Edit` grey when signed out, `🔓 Edit` green when signed in, `💾 Save` while
editing — and signing in no longer makes anything editable on its own. The six
per-page `promptSignIn()` calls are gone: the tab bar's button is the only way in, and
a locked button calls `requireSignIn()` to point at it.

The **Serials** tab gained an Edit Dates toggle; its date fields used to go live the
moment you signed in, which was the one place that broke the rule. `signOut()` now
clears every page's Edit Mode.

### v2.14.1 — Saves could hang: stream budget, and write timeouts
**A save could sit on "Saving..." forever and never write.** Every `EventSource` is
a long-lived connection and a browser allows only ~6 per origin over HTTP/1.1. The
page had grown to **six** streams (aircraft, fleet, schedule, hardware, units,
activities — the sixth added with `/units` in v2.13.0), spending the whole budget on
listening, so a save — an ordinary `fetch()` to the same origin — could queue behind
them and never be sent. Nothing was rejected, so nothing was reported.

`/hardware`, `/units` and `/activities` now share **one poll**
(`startLowTrafficPoll`, 25s) instead of a stream each: three persistent connections
instead of six. They are low-traffic and edited one person at a time, so the
trade is worth it; `/aircraft`, `/fleet` and `/schedule` still stream.

**Every write now goes through `fetchWithTimeout()`** (20s, 22 call sites — all the
authenticated ones). A stall becomes a real error instead of an endless "Saving...",
and Edit Mode keeps the staged changes so Save can simply be pressed again.

⚠️ **Adding another `EventSource` puts this straight back.** If a node needs live
sync, take one out or fold it into the poll.

### v2.14.0 — Restricted tabs, Maintenance renamed to Activity
Activity, Hardware and Serials are hidden from anonymous visitors and appear on
sign-in. UI only — the data stays world-readable, see the note under *Tabs*. The
Maintenance tab is now **Activity**; the tab id, `renderMaintenancePage()`, the
`maintenance` flag field and the global Maintenance widget all keep their names,
because they are about maintenance *state*, which is still the right word.

### v2.13.0 — The unit register: `/units`, removals, and the Serials tab
**New node `/units/{unitId}`** — one physical box with a serial, per-unit attributes
and a list of fitments. It is now the single source for serials; `hardwareFitment()`,
`aircraftFitment()` and `hardwareRemovals()` all read it, and the three serials that
were in `/activities` were migrated by `scripts/migrate-serials-to-units.sh`
(alias-resolving the one legacy free-text record on the way).

**Record Removed Serials** — bulk entry for units that came off and were never
logged. Any number per aircraft and unit, with a paste box for one-per-line lists.
**Dates and reasons are optional**: `state: 'removed'` is what marks a unit as off,
so the backlog goes in by serial now and the dates are filled in later.

**Serials tab** — one row per fitment, filters, in-place date completion, days on
wing, change counts, CSV export.

**Record Installed Serials now writes `/units`** instead of baseline activities, and
its installed date became optional. **Add New Activity** no longer stores serials on
the activity — `unitWritesForActivity()` sends them to the register and links back by
`activityId`. `lruChangesFor()` and `activityMatchesLru()` were deleted with the
activity-derived model they served.

### v2.12.0 — Bulk baseline serial entry, Installed Equipment
**Record Installed Serials** on the Hardware tab: a grid for entering what is
already fitted, By Aircraft or By Equipment, sharing one draft. Entries are
written as ordinary first-fit `hardware_rr` activities in a single multi-path
PATCH, so no second home for serials was created. Additive only — a fitted
serial is read-only and duplicates block the save.

**Installed Equipment** on the Maintenance tab shows each aircraft's LRUs and
their current serials via the new `aircraftFitment()`. `details.recordType:
'baseline'` keeps these records off the Timeline and folded out of the activity
history. Rules deployed ahead of the page, as a new field requires.

### v2.11.0 — Timeline rows, equipment list, fleet scope
**Timeline rows carry no repeated words.** The kind pill is hidden under a kind
filter (it only restated the filter), and the grey subtitle is now the most
specific fact rather than the category — the part for a hardware job, software +
version for a load. `dedupeSubtitle()` drops it when the title already says it.
The Add Activity title placeholder was the root cause and now prompts for the
symptom, not the part.

**Equipment list** gained Waveguide Adapter and Coax Cable J12, both retrofit,
placed in RF-chain order.

### Scope split — Active only, retrofit and linefit apart
Software and Media now count 39 (Active retrofit), the SBC widget 2 (Active
linefit), Maintenance 41 (Active). In Retrofit aircraft appear on the Fleet page
and nowhere else, Timeline included.

### Fleet restructure — 44 aircraft, installation statuses, activation date
`fleetStatus` widened to the six canonical programme statuses. AQB reclassified to
In Retrofit; ASD and ASO added. Fleet page gained an Activation Date column
(reading the existing `activatedDate`) and status filters, opening on Active.

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
existing table framework, the FILTER_BARS filter bar, widget strips, status badges, the two-pane
shell and the auth-gated edit flow.**

Two working agreements from the user:

- **Deploy without being asked.** Rules first, then the page; verify by hash. The
  full checklist is in *Local dev workflow*.
- **Ask before removing anything major** — a tab, a page, a feature, a data node.
  This is the exception to the above. Additive and cosmetic changes just ship.
