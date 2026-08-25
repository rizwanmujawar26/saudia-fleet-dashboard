# Saudia Connectivity Fleet Status — Project Handoff (v2.51.0, 2026-08-25)

Paste this whole document into a new chat to resume work with full context.

## Where things stand (read this first)

The last working session took the app **v2.30.3 → v2.50.0**. If you are picking this
up cold, these are the changes that alter how you should work on it — the rest of this
document is the detail.

**Four cross-cutting rules were established. They are not per-page decisions.**

| | where |
|---|---|
| **Filters are DECLARED**, never hand-written in markup — one entry in `FILTER_BARS` | *Filter bar* |
| **Dates are day-first everywhere**, and `<input type="date">` is banned | *Conventions* |
| **Every table opens on a date column, oldest first**, with sentinels for undated rows | *Table sorting* |
| **Widgets share one markup and one colour vocabulary**, and counts should sum | *Widget vocabulary* |

**What was built:** the 4G SIM register (new public tab, 53 cards), Activation as a
Timeline milestone, activity editing, the filter-bar component replacing every pill
row, frozen filter bars and table heads, full-bleed mobile layout.

**What changed about the data:** `/units` gained `roaming`, `lifecycle` and a fitment
`condition`; 41 SIM installation dates were cleared and 34 rewritten from activation
dates; `/aircraft/{tail}/simRoaming` is superseded and unread.

**Two long-standing caveats closed:** the `/units` client write path is proven, and
CWAP quantities are answered (A320-family ×3, A330 ×5, both fits).

⚠️ **The single most useful habit from that session:** every edit script asserted its
anchor was unique *before* writing, and several aborted mid-way because of it — losing
edits that had already printed "ok". **Always re-verify in the browser after a scripted
edit**, not just in the diff. Two real bugs were caught that way and would otherwise
have shipped: a table whose headers and rows disagreed, and a date handler that staged
`null` and would have wiped good dates.

---

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

Live data (read from the database **2026-08-25**, verified at session close):

- **44 aircraft** — 42 Active, 2 In Retrofit (ASD, ASO). AQB was activated 24-Aug-2026
- Of the 42 Active: **40 retrofit + 2 linefit** (ASBA/ASBB, the A321XLR HBC+ pair)
- **40 is the Software and Media denominator.** 38 on Middleware 2.1.0 — behind:
  **AS59, AS76** (2.0.0) — and 35 on the August 2026 media cycle
- `activatedDate` set on **42** — every aircraft except the two in retrofit
- 24 schedule entries, 11 activities, 1 hardware record, **67 units**, 1 allowlisted editor
- Of the 67 units, **53 are SIM cards**: 39 Active, 1 Fault, 5 Spare, 8 Removed.
  Roaming: 10 Global, 40 Local, 3 unset

⚠️ **These numbers move constantly — the user edits live.** Never quote them back as
fact; re-read the node. They are here to tell you the shape of the data, not its
current value.

`/hardware` is still lightly populated — a Hardware fitment reading "no record" is a
gap in the record, not a fault. The **SIM register is now the best-populated part of
`/units`**; the other LRUs' serials are still the main data-entry job outstanding.

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

**The worked example is SIM `899660 117003 092859`** (2026-08-25) — the only unit in
the register with more than one fitment, and the only one fitted to more than one
airframe. It was on **ASK** 18-Mar-2025 → 16-Apr-2025, came off, and is now on **ASC**
from 10-Apr-2026. Two fitments on one unit, and every surface reads it correctly
without a special case:

| surface | shows |
|---|---|
| 4G SIM register | **Active on ASC** — one row per *card*, from `simLatestFitment()` |
| Serials tab | **two rows** — one per *fitment*, ASC on-wing and ASK removed (29 days) |
| Hardware → SIM → ASK | current `…092828`, **removals 2**, changes 3, `firstFit: false` |
| Hardware → Removed Units | the ASK removal joins the shop queue |

⚠️ **A backfilled fitment must not flip the card's status**, and the reason it does not
is that `simLatestFitment()` sorts on `removedDate || fittedDate` — *not* on `loggedAt`.
Adding ASK's 2025 period today leaves the 2026 ASC fitment latest, so the card stays
Active on ASC. **Anything that picks a "latest" fitment must sort by the DATE**, or
entering history will rewrite the present.

⚠️ **`unitsAtSlot()` is the exception and sorts by `loggedAt`** — a fine proxy while
every fitment was entered in the order it happened, which a backfill breaks: ASK's slot
now lists its three cards in entry order, not chronological order. It is harmless today
because `hardwareFitment()` only ever calls `.find(on_wing)` and takes lengths off that
list, never renders its order. **Sort it by date before displaying it.**

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
(`title`, `detail`, `rootCause`, `resolution`, `status` open|resolved, `loggedAt`).

**An issue answers four questions in this order**: what is it (`title`), what happens
(`detail`), **why** (`rootCause`), what do we do (`resolution`). `rootCause` was added
in v2.51.0 because the SIM card's *SIM Missing / Failed* issue had a cause established
by DevOps while its detail still read "for unknown reason" — folding the two together
would have buried a cause inside a symptom and left the card contradicting itself.
It is where an engineering or DevOps finding goes; all four render only when non-empty.

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

**Fitment is derived, never stored.** `hardwareFitment(lru)` reads **`/units`** —
`unitsAtSlot()` collects every fitment at an aircraft-and-position, and `current` is
the one still marked `on_wing`. ⚠️ **It does NOT walk `/activities`**; that was the
pre-v2.13.0 implementation, which matched `details.partReplaced` against an alias, and
this document described it long after `/units` replaced it. `/activities` is the event
log; `/units` is the register. Three cases, all distinguished:

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
⚠️ It reads **`/units`** — `unitEntries()` then `unitFitments()` — and those fields
live on the **fitment**, not on an activity. The older note here said they lived on the
removal activity; that was true before `/units` existed. A removal recorded only as a
fitment (which is what the SIM backlog is) still reaches this queue. "Shop report" PATCHes
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

**Known issues are added AND edited through one modal.** `openIssueModal(lru, issue)`
builds it; `hwIssueEditingId` is the only difference between the two modes, exactly as
`addActEditingId` works on the Activity tab, so a correction cannot drift into a second
slightly different set of fields.

⚠️ **`hwIssueEditingId` must be cleared on close** — left set, the next **Add** would
overwrite whatever was last edited. `close()` does it, and it covers Cancel and the
backdrop alike.

**Add PUTs, edit PATCHes, and that difference is deliberate.** Add writes a whole
record and stamps `loggedAt`. An edit merges only the fields the form owns, so
`loggedAt` stays *when the issue was logged* rather than when a typo was fixed, and a
field added to the schema later is not silently dropped by a rebuild from the form
alone — the same reasoning as `ACT_FORM_DETAIL_FIELDS`. ⚠️ **An emptied box must write
`null`**: omitted from a PATCH it would simply leave the old value standing.

Before v2.51.0 an issue could only be added or deleted, so the only correction was
delete-and-retype — which threw away `loggedAt`, and would have left `rootCause`
unreachable on every issue logged before it existed.

The two-pane shell reuses the `.maint-*` classes — they style a generic
list/detail layout and the prefix is historical. Worth unifying under a neutral
name when something else needs the same shell.

---

## Timeline — derived, never stored

`timelineActivities()` is the one place the three sources are folded into a
single shape (`{ iso, kind, tail, type, location, title, sub }`):

| kind | source | date it uses |
|---|---|---|
| **Activation** | `/aircraft` — every Active aircraft that has one. Title is `Entered Service` | `activatedDate` |
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

Filter pills are **All / Activation / Software / Hardware / Media**. There is no
Maintenance pill for now — maintenance-kind activities still appear under All, they
just have no filter of their own until the categories settle.

### Activation is a milestone, and it is DERIVED

Entering service is the event the other three kinds are work towards, so it renders
differently: the row carries `.tl-milestone` — a Saudia-green left accent, a tinted
wash, the registration and title in green, and a ✈ mark.

⚠️ **The marker is on the ROW, not only the pill.** A kind pill is deliberately hidden
under a kind filter (it would only restate the filter), so a milestone that relied on
its pill would stop looking like one exactly when someone filtered to milestones.

**Nothing was written and nothing needed backfilling.** `activatedDate` has been on
`/aircraft` since the Fleet restructure, so all 42 activations — back to 01-Oct-2024 —
appeared the moment the source was added, and a date corrected on the Fleet or Activity
tab corrects the Timeline with it. Storing these as `/activities` records would have
duplicated a fact the roster already holds and let the two drift. **If a fourth
milestone is ever wanted, derive it the same way — do not write records for it.**

Because `TIMELINE_KINDS` is the one definition, adding the entry gave the pill row
*and* the collapsed mobile dropdown the new option with no other wiring.

Note the ✈ is deliberately **not rotated**: fonts orient that glyph differently, so a
fixed rotation points it sensibly in one and sideways in the next.

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

### Popovers are placed in the VISUAL viewport, not the layout one

⚠️ **This is the trap that broke the menu on a pinch-zoomed phone.** `position: fixed`
and `window.innerWidth`/`innerHeight` all resolve against the **layout** viewport,
which does not change when you pinch-zoom — the *visual* viewport shrinks to a window
into it. So a `bottom: 0` sheet sat at the bottom of the whole page, off-screen, while
the backdrop (also fixed, covering the layout viewport) still dimmed: the user saw a
flash and no menu, and the next tap hit the backdrop and dismissed it.

`fbVisualRect()` returns `window.visualViewport`'s offset and size (falling back to
the layout viewport where it is unsupported), and `fbPosition()` places everything in
those coordinates. Three things it must do, all of which were found by testing:

- **Set the sheet's `left`/`width`/`top` explicitly** and `right: auto`, or the CSS's
  `left: 0; right: 0` fights the width.
- **Override `min-width`.** `.fb-pop` has `min-width: 216px`, which held the sheet
  wider than the visible area at a deep zoom. `.fb-sheet` sets `min-width: 0`.
- **Cap `max-height` from the visual height before reading `offsetHeight`.** The
  panel's own cap is in `vh`, which is the layout viewport, so it can exceed what is
  visible; and reading the height before applying the cap gives a stale number.

**A viewport change repositions the menu, it does not dismiss it.** `window.resize`
used to call `fbClose()` — which also meant a mobile browser showing or hiding its URL
bar closed the panel the instant it opened. `resize` and `visualViewport`'s
`resize`/`scroll` all call `fbReposition()` now. Document scroll still closes an
*anchored* popover, because it would otherwise float away from its trigger; the sheet
is anchored to nothing and just follows.

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

### Quick pills — one click for the values that matter

A bar may declare a `quick` list beside its `filters`: one-click pills for the handful
of values worth reaching without opening a menu. The 4G SIM bar has **Active, Spare,
Global, Local**.

```js
quick: [
    { filter: 'simstatus', value: 'active', label: 'Active' },
    { filter: 'roaming',   value: 'global', label: 'Global' },
],
```

**They are not a separate filter.** Each pill toggles a value in the same `Set` its
dropdown drives, so the two can never disagree — clicking *Spare* turns the pill green
*and* the Status trigger reads `Status: Spare`. Toggling is additive, like the menus:
Active + Spare is both, Active + Global is the intersection.

⚠️ **Shown only above 980px, and that number is MEASURED.** Four pills (264px), three
dropdowns (267px) and three action buttons (268px) plus gaps and padding need 855px of
bar, and the bar is the viewport less 100. Below it the pills hide and the dropdowns
carry everything — nothing becomes unreachable. **A bar with more dropdowns than the
SIM one would need a higher threshold**; `.fb-filters` scrolls sideways rather than
breaking, but re-measure before giving another bar a `quick` list.

### Free-text search

A bar declares `search: 'placeholder text'` and gets a box in the row. A row opts in
by carrying **`data-search`** — anything without it is simply not searchable rather
than being hidden by a query it cannot answer.

**Every word must match**, so `asv 235` narrows rather than widens. The SIM rows put
the raw serial, its grouped form, the tail and the `ex-` tail in `data-search`, so
`235940`, `117002 235940`, `AS53` and `ex-AS53` all find what you would expect.

⚠️ **Typing must not re-render the bar** — the box would lose focus on every keystroke.
`fbSearchInput()` sets the query and re-filters the ROWS only. The box's value is
re-rendered from `fbQuery` when something else does rebuild the bar (a pill click), so
the text survives.

The query counts toward `fbActiveCount()`, so the collapsed mobile badge includes it,
and `fbClear()` clears it — Reset empties the box.

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

## Table sorting — one philosophy, four tables

Every data table opens on a **date column, oldest first**, placed second right after
`#`. That is deliberate: the question these pages answer is "what happened when", and
the oldest row is the one that has been waiting longest.

| table | opens on | constant |
|---|---|---|
| Software | Installation Date (`completionDate`) | `SW_DEFAULT_SORT` |
| Media | Loading Date (`media.loadedDateUTC`) | `MEDIA_DEFAULT_SORT` |
| Fleet | Activation Date (`activatedDate`) | `FLEET_DEFAULT_SORT` |
| 4G SIM | Installation Date (fitment `fittedDate`) | tiers — see below |

### Four rules that apply to every one of them

1. **A date column's `data-sort` MUST go through `dateSortKey()`.** `sortTable` tries
   `parseFloat` first, and `parseFloat('2026-05-19')` is `2026` — so a raw ISO key made
   every date within a year compare equal, and date columns silently sorted by year
   alone. `dateSortKey` strips the separators to give a real number (`20260519`).

2. **Undated rows sort to the END, never the front.** They carry a sentinel instead of
   an empty key. ⚠️ **The sentinel must have the same number of digits as a real key**:
   `99999999` for `DD-Mon-YYYY` (8 digits), but `99999999999999` for the Media table,
   whose `loadedDateUTC` is a full timestamp and produces 14. A short sentinel sorts
   undated rows to the front, which is exactly wrong and looks like a data bug.

3. **The default sort is RE-APPLIED on every rebuild**, not set once:
   ```js
   const s = lastSort['<table>'] || <TABLE>_DEFAULT_SORT;
   lastSort['<table>'] = s;
   applyTableSort('<table>', s.col, s.dir);
   ```
   These populate functions run again on every live update. Without this a teammate's
   edit hands the rows back in build order while the header still shows its arrow —
   which is what happened to the Fleet table the first time, and had been silently
   happening to any user sort on any table.

4. **Anything that changes which rows are visible, or their order, must call
   `renumberVisibleRows()`** — the `#` column is a position in the list, not an id.

### When one column is not enough: the SIM tiers

`applyTableSort()` sorts **one column** and has no concept of grouping. Where an order
needs more than that it becomes the **build** order in the populate function, and the
header calls its own handler rather than `sortTable()`.

The 4G SIM register is the case: only cards on an aircraft *with* a date can be
sorted by when they went on, so it is three tiers (`SIM_TIER`) —

| tier | rows | order |
|---|---|---|
| 0 | Active or Faulty **with** an install date | the chosen mode |
| 1 | Removed, **or** fitted but undated | oldest first, undated last |
| 2 | Spares | the absolute end |

— and Installation Date cycles four modes (`SIM_DATE_SORTS`) instead of toggling two:
Newest first → Oldest first → Most days → Fewest days. The header **names** the active
mode, because four states cannot be told apart by an arrow.

⚠️ **Days and date are the same fact for a card still on wing**, so Most days sorts
identically to Oldest first. Both exist because the questions differ, not the answers.

⚠️ **A build order and `lastSort` are mutually exclusive.** `populateSimTable()`
re-applies a column sort *only if the user clicked one*; the date header clears
`lastSort` so the tiers come back. Reset clears both.

---

## Widget vocabulary

### The rules that hold across every strip

1. **One markup, one set of variants.** Every card is `.media-widget` with a
   `media-widget-<variant>` modifier — `latest` green, `previous` blue, `older` amber,
   `alert` red, `no_media` grey. Fleet, Media and 4G SIM all use it, so the pages read
   as one system rather than three hand-rolled sets. **Do not write a new card shape.**

2. **Counts on a strip should SUM to their population.** A status with no card is a
   status counted nowhere, and the strip then misstates the total. This is why the SIM
   register gained a Fault card the moment Fault became a status.
   ⚠️ **The 4G SIM strip is the one deliberate exception**: Removed gave up its card
   (2026-08-25, user's call) so the strip shows what is *live*. 39 + 1 + 5 = 45 of 53;
   the other 8 are removed and one click away in the Status filter.

3. **A composition is a SPLIT, not another count.** Two shares of one track that always
   fill it, because it shows a ratio rather than progress towards anything —
   Fleet's **SSID Visibility** (public/hidden) and 4G SIM's **Roaming Plan**
   (global/local). A split answers a different question from the cards beside it and
   must not be read as a fourth one.

4. **Colour carries meaning, and it is the same meaning everywhere.** Green in service,
   blue available, amber closed-or-behind, red needs action, grey history. A green
   number, a green badge and the green widget all mean the same thing — which is why
   the SIM serial, its status badge and its widget share hues.
   ⚠️ Watch what red means on a given strip: on the SIM register **Fault** takes the
   alert red and **Removed** steps back to grey, because a removed card is settled and
   a faulty one is a job.

5. **Figure convention:** count at the left edge of the bar, percentage at the right
   (`margin-left: auto` on the percentage).

### Per-page

- **4G SIM** — Active Cards (green) / Faulty Cards (red) / Spare Cards (blue), plus the
  **Roaming Plan** split. The split counts only cards **still fitted** — one that came
  off has no live plan. Local takes slate rather than the SSID card's red: it is the
  other half of a composition, not an exception state.
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

## Tabs (9)

Public order: **Overview, Software, Media, Fleet, 4G SIM**. Behind sign-in:
**Activity, Hardware, Serials, Schedule**.

**Schedule became restricted on 2026-08-25** — it is forward-looking work planning and
the user does not want it public. **4G SIM went public the same day**, once it was
signed off; it was restricted only while it was being built. Editing it still needs
sign-in, like every other page — the tab gate governs who *browses*, never who writes.

### 4G SIM — the SIM card register

One row per SIM **card**, derived from `/units` where `lruId` is `sim` or `lf_sim`.
**There is no `/simcards` node, deliberately** — `/units` is already the single source
for a serial and its fitment history, and a second home for the same cards would drift
from it exactly the way the old duplicated status fields did.

Columns: `# | Installation Date | SIM Card # | Roaming | Aircraft | Type | Status |
Removal Date | Comments`. Two of those placements are deliberate: **Removal Date sits
beside Status**, so `REMOVED` and the day it came off read as one fact, and **Roaming
sits with the card number**, because the plan belongs to the card rather than to the
airframe. Installation Date is column 2 and the default sort, oldest first, like the
other tables; every column sorts, so the register reads by card or by aircraft.

**The register's own columns are centred**, headers included — it is short values, so
centring reads as columns rather than ragged edges. Comments stays left: it is a
sentence, and a centred sentence is hard to scan.

**The installation pill is colour-coded by what it is saying.** Green while the card is
Active and the count is running, amber once it is closed, and **neutral for a Fault** —
the days are real but the card is not healthy, and the colour must not say it is. The
green is scoped to this table; the Fleet, Software and Media pills stay neutral, where
an age is context rather than a health signal.

**The installation pill measures time on wing, and changes meaning when the card comes
off.** While it is fitted the span is open-ended and counts to today; once a removal
date exists the pill shows the **closed** span install→removal and takes
`.age-pill-closed` (amber), because that number will never change again and should not
look like one that is still moving. `activationAge()` is now a thin wrapper over
`dateSpan(from, to)`, where a blank `to` means "until today" — the Fleet, Software and
Media columns are unaffected.

**A fitted card with no removal date shows an `On-Wing` pill** in the Removal Date
column rather than an em dash: the absence of a date *is* the statement that it is
still on the aircraft.

**Serials render grouped in sixes** (`899660 117002 235903`) — 18 digits in one run
cannot be checked against a physical card. Two functions, and the difference matters:

| | |
|---|---|
| `formatSimSerial(v)` | plain text. Used for `data-search` and anywhere a string is needed |
| `simSerialHTML(v, status)` | the CELL. Promotes the **last six digits** and tints the whole serial by status |

**The last six are what actually identify a card here** — every serial on the programme
shares its opening digits — so they are bolder and a shade larger, with the leading
groups dimmed to 0.55 rather than dropped, since reading a number off a physical card
still needs them.

**The serial carries the card's state as colour**, the same hues as the badges and
widgets: Active green, Fault red, Removed dark amber, Spare blue. A green number, a
green badge and the green widget all mean the same thing.

⚠️ **`simSerialHTML()` returns MARKUP, so it is for the cell only.** `data-search` must
keep using the plain form — markup in a search haystack would make a query like "span"
match every row. Verified: it matches none.

Display only either way: the stored serial, the `data-sort` key and the duplicate check
all use the raw value.

**There is no Fit column.** Every aircraft in this programme is retrofit by default, so
the column and its filter said nothing.

**`SIM_STATUSES` is the one definition** — badges, edit dropdown and filter together.
**All three are DERIVED from fitments; nothing about a card's status is stored**, so it
cannot go stale against its own history.

| status | condition | Aircraft column |
|---|---|---|
| Active | latest fitment is `on_wing` | the registration |
| **Fault** | `on_wing` **and** `condition: 'fault'` — fitted but inoperative, needs replacing | the registration |
| Spare | no fitment at all — never flown, in hand with the team | *Not fitted* |
| Removed | latest fitment is `removed` | **`ex-ASV`** — where it came off |

⚠️ **Fault is still `on_wing`** — that is the whole point of it. It is the fitment's
`condition`, not its `state`, so a faulty card is not pretending to have been removed.
**Removed wins over Fault** in the derivation: once a card is off the aircraft it is
history, not a job.

**Sorting the register is THREE TIERS, not one order** (`SIM_TIER`):

| tier | rows | order |
|---|---|---|
| 0 | Active or Faulty **with** an install date | the chosen mode |
| 1 | Removed, **or** fitted but undated | oldest first, undated last |
| 2 | Spares | the absolute end |

A spare has never been fitted so it has nothing to sort *by*; a removed card's install
date is history and would otherwise push current cards down the list. A fitted card
with no date drops to tier 1 for the same reason — a blank in the middle of a
date-ordered list is worse than a blank at the end.

**Clicking Installation Date cycles four modes** (`SIM_DATE_SORTS`): Newest first →
Oldest first → Most days → Fewest days. The header names the active one, because four
modes cannot be told apart by an arrow.

⚠️ **`applyTableSort()` cannot express any of this** — it sorts one column with no
concept of tiers. So this is the **build** order and the date header calls
`cycleSimDateSort()` rather than `sortTable()`. Every *other* header still goes through
`sortTable()`, and doing so drops the tiers for that sort, which is what you want when
you ask for "by serial". Reset clears both.

⚠️ **Days and date are the same fact for a card still on wing** — days is today minus
the date — so Most days sorts identically to Oldest first, and Fewest to Newest. Both
are offered because "which has been on longest" and "which went on first" are different
questions to ask, even when the answer happens to be the same list.

Widgets are **Active Cards / Faulty Cards / Spare Cards**, in the shared
`.media-widget` markup and variants the Fleet and Media strips use, plus a **Roaming
Plan** split.

The three counts are states a card can be in; the split is a different axis — which
plan the fitted cards are on — so it is drawn as two shares of one track, the same
shape as the Fleet tab's SSID card, rather than a fourth count. It counts everything
that is **not removed**, because a card that came off has no live plan.

⚠️ **The counts no longer sum to the register**: Removed lost its widget on
2026-08-25 at the user's request. Removed cards are still reachable from the Status
filter — they are history rather than a number to watch. Local takes slate rather than
the SSID card's red: it is the other half of a composition, not an exception state.

⚠️ **A `Retired` status was added in v2.42.0 and removed again in v2.43.0** at the
user's request — status is just Active and Removed for a fitted card now. The
`lifecycle` field is still declared in `database.rules.json` and nothing writes it; no
record ever carried it, so the rule is inert rather than orphaning data. Drop it from
the rules whenever, or reuse it if the idea comes back.

**Edit mode covers both dates, Status, Roaming and Comments.** Status is two writes
wearing one control, and `handleSimEdit()` is where that is resolved:

- **Status writes the fitment's `state`, plus `condition` for Fault.** Active writes
  `on_wing` and clears the fault; Fault writes `on_wing` *and* the flag; Removed writes
  `removed`.
- **Only reachable states are offered.** A fitted card gets Active/Removed; a spare's
  status is read-only, because Spare means "no fitment" and going back to it would mean
  deleting history, which is Record Removed's job.
- **A spare's date cells are not editable** and say why on hover — dates belong to a
  fitment, and it has none.

**A spare is assigned to an aircraft from the table itself.** In Edit mode the
Aircraft cell is a picker on every row and a spare's installation date is typeable —
choosing a tail and saving **creates the fitment**, in the same shape Record Installed
writes (`aircraft`, `state: 'on_wing'`, `loggedAt`, `fittedDate`), so the card reads
identically on the Serials and Hardware tabs. The row flips Spare → Active on save.

- ⚠️ **An installation date with no aircraft is refused, not dropped.** There is no
  fitment for it to belong to, so the save stops with a message naming the card and
  keeps Edit mode open rather than silently discarding what was typed.
- **On a card that already has a fitment the picker CORRECTS which tail it names.** It
  is not a way to move a card between aircraft — that is a removal and a refit, two
  fitments, and belongs on the Serials tab.
- **The picker is the only field that repaints the table on change**, because Type is
  derived from the aircraft and the row would otherwise show a new tail against the old
  type. Everything else is a text box, where re-rendering would pull the cursor out
  mid-typing.
- A spare's **removal** date stays uneditable — there is nothing to remove yet.

**Add SIM adds a card either way.** Choosing *Spare* writes a bare unit with no
fitment; choosing *Active* asks for an aircraft and an installation date and writes a
fitment in the same shape Record Installed uses, so the card reads identically on the
Serials and Hardware tabs. The aircraft picker is the whole roster, not just the active
fleet — a SIM often goes in while the aircraft is still in retrofit.

⚠️ **All 41 SIM installation dates were cleared on 2026-08-25 at the user's request.**
39 of them read `24-Aug-2026` and 2 read `16-Aug-2026`: they were the timestamp of the
bulk baseline entry, not when the cards actually went on. The 13 non-SIM `fittedDate`
values and all 7 SIM `removedDate` values were left untouched. Snapshot before the
change: `~/Documents/fleet-backups/2026-08-25-before-sim-date-clear`.

⚠️ **Roaming lives on the CARD** (`/units/{id}/roaming`, `global` \| `local`), not on
the aircraft. A spare with no aircraft still has a plan, which
`/aircraft/{tail}/simRoaming` cannot express. That field is **superseded**: it holds
one stale record (AQJ `active`) and nothing reads it for the SIM page. It is left in
place rather than deleted — clearing it is a data decision, not a side effect of this
change.

**Edit mode covers Roaming and Comments only.** Fitting and removing a card are
*fitment* writes, and Record Installed / Record Removed on the Serials tab already own
those — doing them from here as well would be a second write path to the same history.
**Add SIM** creates a spare with **no fitment**, which is exactly what makes it read as
Unused.

Widgets: Installed / Unused / Removed, counted from the same derivation.

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
   **Every activity card carries ✏️ Edit as well as 🗑 Delete.** Edit reuses the same
   modal — `prepareActivityModal()` builds it and `setActivityModalMode(id|null)` is
   the only difference between the two — so a correction can never drift into a
   second, slightly different set of fields. `addActEditingId` carries the mode and is
   cleared on cancel, on backdrop close and on success, because leaving it set would
   make the next **Add** overwrite whatever was last edited.

   ⚠️ **An edit PRESERVES the detail fields the form does not own.**
   `ACT_FORM_DETAIL_FIELDS` lists the seven it does (`lruId`, `position`,
   `removalReason`, `softwareName`, `version`, `modemType`, `commissioningResult`);
   everything else on `details` is copied forward untouched. Rebuilding `details` from
   the form alone would silently drop `shopStatus`/`shopRef`/`shopFinding` — written
   weeks later by the Shop report — and would lose `recordType: 'baseline'`, which
   would promote a serial record onto the Timeline. `loggedAt` is preserved too: it is
   when the work was logged, not when the typo was fixed.

   ⚠️ **Editing never writes `/units`.** The serial inputs are disabled in edit mode
   with a note pointing at the Serials tab. A serial is one physical box in the
   register, and changing a fitted one is a *swap* needing a reason and a removed
   unit — not a text correction. Re-running `unitWritesForActivity()` on an edit would
   also mint duplicate units against an `activityId` the register already holds.
   No rules change was needed: `.write` on `/activities/$id` is per-record, so a PUT
   to an existing id was already allowed.
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

## Full bleed on a phone

The dashboard is a rounded white card floating on the green gradient — `body`
padding 20, `.container` radius 12 and a drop shadow, `.content` padding 30. That is
the intended look on a laptop. On a phone it cost **100px of a 375px screen (27%)**,
leaving 275px of usable width.

**Below 768px the frame is dropped entirely**: body padding 0, container radius and
shadow off, `.header` and `.sysbar` square, `.content` padding 30 → 12. Usable width
goes **275px → 351px (+28%)**, and 20px comes back at the top.

- **`.container` gets `min-height: 100vh` there.** The gradient behind it is no longer
  part of the design, so the white has to reach the bottom of a short page itself.
- **Scoped to phones deliberately.** Above 768px the frame costs the same 100px, but
  that is a small share of the width and the card-on-gradient *is* the design. A phone
  in landscape is ~812px and keeps it.
- The 768px cut matches the media query the mobile layout already uses; there is one
  block, not two.

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

### Pinned layers

There are two stacks, sharing the first two layers:

| page | stack |
|---|---|
| tables | header → tab strip → **filter bar** → table head |
| Overview | header → tab strip → **`.tl-controls`** → **`.cal-strip`** |

On the Overview the kind filter, the sort and the calendar all stay put and the
timeline runs behind them, so the date navigation is reachable from anywhere in the
list. `--tlctrl-h` is published for the offset the strip pins at, the same way
`--filterbar-h` is.

- **The strip needs its own opaque background** (`#fff`) — it had none, and rows
  showed through it as they passed behind.
- **The separation is a `box-shadow`, not a border.** A border would sit on the
  layout at rest as well, adding a line the design never had.
- **A horizontal scroll container can still be sticky itself.** `.cal-strip` scrolls
  sideways; that only governs where its own *descendants* would anchor, not whether
  the strip sticks.
- ⚠️ It costs **38% of a phone viewport** with the header and tabs (305px of 812px,
  leaving ~507px of list). That is the deliberate trade — the calendar is the
  navigation, so it earns the room.

The table stack is **header → tab strip → filter bar → table head**, each pinned under
the one above. Every offset below the first is a SUM, so `publishStickyHeights()` measures
and publishes `--header-h`, `--tabs-h` and `--filterbar-h`, and `--sticky-top` adds the
first two. **It runs on every tab switch as well as on resize**: at load the Overview
tab is active and every `.filterbar` is `display:none`, so a measurement then finds
nothing to measure.

⚠️ **The table head cannot simply be `position: sticky`.** `.table-scroll-wrapper`
carries `overflow-x: auto` for wide tables, and CSS turns the *other* axis `auto` with
it — so the wrapper, not the viewport, becomes the scrollport a sticky `thead` anchors
to, and the head just scrolls away with the page. `syncTableFreeze()` measures each
table against its wrapper and sets `.is-overflowing`; a table that **fits** gets
`overflow: visible` and a frozen head, one that does not keeps its horizontal scroll
and an ordinary head. `.table-freeze` marks the **eight** page-level tables
(Software, HBC+, Media, Serials, both Schedule stations, 4G SIM, Fleet) — the Installed
Equipment and Hardware fitment tables sit inside detail panels and are left alone.

⚠️ **A capped, internally-scrolling pane was tried first and rejected.** Giving the
wrapper a `max-height` does make the head stick — but the page can still scroll past
the pinned filter bar, dragging the pane and its head up behind the header, and making
the pane sticky as well only moved the problem to the end of the page, where it is
released by its containing block and the head disappears under the filter bar. That is
the exact failure the freeze was meant to fix. Page-level stickiness keeps one scroll
for the document, and the head releases naturally when the table ends and the next
section begins.

**A sticky `th` drops out of border collapsing**, so rows show through a hairline at
its foot. The rule draws that line with a `::after` strip instead.

**A table too wide to fit gets a floating copy of its head instead.** There is no CSS
that pins a head inside a horizontal scroll container, so `syncFrozenHeads()` holds a
copy of the live `<thead>` at the pin line, clipped to the wrapper and slid sideways by
`-wrapper.scrollLeft` so the columns stay over their data. That is what gives a phone a
frozen head on a 1055px table in a 351px window.

- **The copy is made from the live `<thead>`**, so its sort arrows and `onclick`
  attributes are the real ones — clicking the copy sorts the table it belongs to, and
  the arrow updates.
- **Each `th` is given the live head's measured width and the copy is
  `table-layout: fixed`**, or it would size to its own content and drift.
- ⚠️ **Do not force `white-space: nowrap` on it.** With the widths copied, the copy has
  to wrap exactly as the original does; forcing one line pushed "INSTALLATION DATE"
  straight through the next column.
- It is rebuilt only when the head's markup or widths change — a scroll must reposition
  it, never rebuild it — and the work is batched into a frame.

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
- **Dates are always `DD-Mon-YYYY`** stored (e.g. `17-Aug-2026`) and **`dd-mm-yyyy`
  while being typed**. Never month-first — `03-04-2026` read the American way is a
  different day, silently, and that format appears nowhere in this project.

  ⚠️ **`<input type="date">` must not be used, anywhere.** Its display format follows
  the BROWSER's locale, so every date box was rendering `mm/dd/yyyy` on a US-locale
  machine no matter what the page stored — there is no attribute or CSS that overrides
  it. All 13 date fields are **text inputs** with a `dd-mm-yyyy` placeholder.

  Three functions carry this, and nothing else should parse a date:

  | | |
  |---|---|
  | `fmtDate(v)` | anything → stored `DD-Mon-YYYY`, or **null** when it is not a real date. Accepts the stored form, ISO, and day-first `dd-mm-yyyy` (also `/` and `.`). Round-trips through a real `Date`, so `31-02` and `29-02` in a common year are rejected rather than rolling into the next month |
  | `toDMY(v)` | stored → the `dd-mm-yyyy` an input shows |
  | `readDateField(el)` | what every handler uses: `''` for empty, the stored form when valid, and **`false`** when the box holds a non-date |

  ⚠️ **On `false`, a handler must return without staging.** A typo must never clear a
  date that was already good — that is why the check happens *before* the pending
  record is touched, not after.

  `parseScheduleUTC()` and `toISODate()` remain for sort keys and date maths and are
  unchanged.
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
- **The serial backlog for the non-SIM LRUs.** The SIM cards are done — 53 of them in
  `/units` with fitments, dates and roaming. The other nine LRUs (IFE Server, MODMAN,
  KANDU, KRFU, RX/TX Antenna, Waveguide Adapter, Coax Cable J12, CWAP) have almost
  nothing: 14 non-SIM units against ~400 positions. **Record Installed Serials** on
  the Hardware tab is the tool for it and is built.

### Ideas raised but not built

- **Assigning a Spare from the table is one-way.** The Aircraft picker creates a
  fitment; it cannot *move* a fitted card to another aircraft, because that is a
  removal plus a refit and belongs on the Serials tab. If the SIM page is to be the
  full hub, that flow needs designing rather than bolting the second write onto the
  picker.
- **A `Retired` / unsubscribed status** was built in v2.42.0 and removed in v2.43.0.
  The `lifecycle` rule is still declared and inert if it comes back.
- **A picker for dates.** Date fields are typed now — `<input type="date">` had to go
  because it renders in the browser's locale. An in-page picker would restore the
  convenience without the format problem; nobody has asked for one yet.
- **`Fault` has no reason field.** It is a flag; why a card is faulty lives only in
  Comments.

### Closed this session — do not re-raise

✅ **The client write path to `/units` is PROVEN** (2026-08-25). The user added SIM
`899660117002235940` through Add SIM — the stored record carries the `addedAt` and
`roaming` that dialog writes — and edited a fitment's removal date from the SIM table.
Both landed against the live rules engine. The caveat that stood since v2.12.0 is
closed; `roaming`, `condition` and the fitment date/state writes all go through it.

✅ **CWAP quantities** — A320-family ×3, A330 ×5, **both fits**. Encoded as a family
rule, not a subtype list.

✅ **Activation dates** — all 42 activated aircraft carry `activatedDate`, and the
Timeline derives an Activation milestone from it.

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

### v2.51.0 — Known issues gain a Root Cause, and can be edited
`issues/{id}` gained **`rootCause`** (rules first), rendered between Detail and
Resolution because that is the order the questions are asked in: what is it, what
happens, **why**, what do we do. Written for the SIM card's *SIM Missing / Failed*
issue, whose detail said "for unknown reason" while DevOps had already established
that a provider change or a PIN on the SIM blocks the card after repeated attempts.
Each issue card also gained **✏️ Edit** beside its 🗑, reusing the add modal — without
it a field added today would be unreachable on every issue logged before it, and the
only correction available was delete-and-retype, which throws away `loggedAt`.
Add still PUTs and stamps `loggedAt`; an edit PATCHes only what the form owns, and an
emptied box writes `null`.

### v2.50.0 — SIM serials coloured by state, and the page goes public
The serial now carries the card's state as colour — Active green, Fault red, Removed
dark amber, Spare blue — matching the badges and widgets, and its **last six digits**
are promoted, since those are the part that distinguishes one card from another on this
programme.

**4G SIM is public.** It was restricted only while it was being built. Editing still
needs sign-in.

### v2.49.0 — Centred columns, green service pill, four-mode date sort
The register's columns and headers are centred (Comments excepted), the days pill is
green while a card is Active and still counting, and Installation Date cycles four sort
modes instead of two.

Sorting became three tiers: only cards on an aircraft with a date take part, removed
and undated rows pin behind them oldest-first, and spares sit at the absolute end — so
a date-ordered list is never interrupted by rows that have no date to order by.

### v2.48.0 — Search box, and a roaming split widget
The filter bar gained a free-text box that matches SIM number or aircraft — raw or
grouped serial, tail or `ex-` tail, every word required so two terms narrow. It is part
of the shared component: a bar declares `search` and its rows carry `data-search`.

Widgets renamed to Active Cards / Faulty Cards / Spare Cards, and Removed gave up its
card to a Roaming Plan split showing Global against Local across the cards still
fitted.

### v2.47.0 — One-click filter pills on a wide screen
On a laptop the 4G SIM filters were all behind dropdowns even with room to spare.
Active, Spare, Global and Local are now pills in the bar itself above 980px — a measured
threshold, not a device size — and collapse back into the dropdowns below it. A pill
toggles the same Set its dropdown drives, so the two always agree.

### v2.46.0 — Assign a spare SIM to an aircraft from the table
A spare could be added but not put on an aircraft without going to the Serials tab. The
Aircraft cell is now a picker in Edit mode and a spare's installation date is typeable;
saving creates the fitment in the same shape Record Installed writes, and the row flips
Spare → Active. A date with no aircraft is refused with a message rather than dropped,
because there is no fitment for it to belong to.

### v2.45.0 — Day-first dates everywhere, and no native date pickers
Every date box was rendering American `mm/dd/yyyy`. The cause was `<input type="date">`,
whose format follows the browser's locale and cannot be overridden — so all 13 of them
became text inputs showing `dd-mm-yyyy`. Display is unchanged at `DD-Mon-YYYY`.

`fmtDate()` now parses day-first numeric input and returns null for anything that is
not a real date, `toDMY()` renders the input value, and `readDateField()` lets a
handler reject a typo without clearing the date that was already there. Verified across
Software, Fleet, 4G SIM, Schedule and Serials.

### v2.44.0 — SIM register: closed spans, On-Wing, FAULT
The installation pill now changes meaning when a card comes off: install→removal as a
closed span in amber, rather than counting up from an install date that no longer
matters. A fitted card with no removal date says **On-Wing** instead of showing a dash.

New **Fault** status for a card that is fitted but not working — still `on_wing`, with
a `condition` flag beside it, so it is visibly a job without pretending to have been
removed. It gets the alert-red widget and Removed steps back to grey.

The table opens Active → Fault → Spare → Removed, oldest install first within each, and
serials render grouped in sixes so they can be read against a physical card.

### v2.43.0 — SIM register: column order, days pill, Add SIM status
Removal Date moved beside Status so the two read together, Roaming moved next to the
card number, and the Fit column and filter are gone — every aircraft here is retrofit,
so it said nothing. Installation Date gained the same days-since pill the Fleet and
Media date columns carry; the removal date deliberately does not.

Status is back to the two states a fitted card moves between, Active and Removed —
Retired was dropped. Add SIM now sets status: a Spare with no fitment, or Active with
an aircraft and installation date, written in the same shape Record Installed uses.

### v2.42.0 — SIM register: removal dates, Retired, and editable status
Installation dates cleared — they were all the bulk-entry timestamp rather than real
fit dates — and a **Removal Date** column added beside them. Both dates are editable in
Edit mode, as is Status.

New **Retired** status for an unsubscribed card. It is the only one of the four that is
stored (`lifecycle` on the unit) because no fitment history can express it, and it
overrides the derived value. The widgets moved to the shared `.media-widget` markup so
the SIM, Fleet and Media strips match, and now read Active Cards / Spares in Hand /
Removed / Retired — four, so they sum to the register.

### v2.41.0 — 4G SIM register, and Schedule goes private
New **4G SIM** tab: one row per SIM card with its aircraft, fit, status, roaming plan
and comments, three widgets (Installed / Unused / Removed), the shared filter bar, the
frozen head and Add SIM. It reads `/units` — the 47 cards already in the register
appeared with nothing to import — and derives status from fitments, so a removed card
reads `ex-ASV` rather than claiming an aircraft it is no longer on.

Roaming moved onto the card (`/units/{id}/roaming`), because a spare with no aircraft
still has a plan. Rules deployed ahead of the page, as a new field requires.

Tab order is now Overview, Software, Media, Fleet, then the signed-in tabs. **Schedule
joined them** — it is work planning and not for public view. 4G SIM is restricted too
while it is being settled.

### v2.40.0 — Overview filters and calendar stay put
The kind filter, the sort and the calendar strip now pin under the tab strip and the
timeline scrolls behind them, so a date can be picked from anywhere in the list rather
than only from the top. Most useful on a phone, where reaching the calendar meant
scrolling all the way back up. The strip gained an opaque background — rows were
showing through it — and a soft shadow so a row passing underneath reads as passing
rather than being clipped. It stays fully interactive while pinned.

### v2.39.0 — Activation is a Timeline milestone
Putting an aircraft into service is the milestone the whole programme works towards and
it was not on the Overview at all. It is now a fourth Timeline kind with its own
Activation filter pill, and its rows stand out — green accent, tinted wash, ✈ mark —
rather than reading as one more line of work.

Derived from `activatedDate`, not stored: all 42 activations back to October 2024
appeared at once with nothing written and nothing to backfill, and a corrected date
corrects the Timeline with it.

### v2.38.1 — Frozen head on a phone too
v2.38.0 froze the head only where the table fits, which left a phone — the case that
needs it most — with a scrolling head. A table that must scroll sideways now gets a
floating copy of its head held at the pin line and slid in step with the columns
beneath it. Verified aligned to within 0.8px at every horizontal scroll position, and
the copy sorts the real table because it *is* the real head, cloned.

### v2.38.0 — The filter bar and table head stay put
Scrolling a long table lost the column headers. The filter bar now pins under the tab
strip and the table head pins under the filter bar, so the headers are readable at the
last row as easily as the first. Three heights are measured and published rather than
assumed, because each layer's offset is the sum of the ones above it.

The head can only pin while no ancestor is a scroll container, and the table wrapper is
one whenever `overflow-x: auto` applies. `syncTableFreeze()` measures each table and
drops the overflow only where the table actually fits — so a wide table on a phone
keeps its horizontal scroll and an ordinary head instead of getting a broken one.

### v2.37.0 — Activities can be corrected, not just deleted
An activity was write-once: the only way to fix a typo was to delete it and retype the
whole record. Every card now has ✏️ Edit beside 🗑 Delete, reusing the Add modal so
there is one form rather than two.

The care is in what an edit does *not* touch. Only the seven detail fields the form
owns are replaced; `recordType`, the serials, the part number and the shop's verdict
are copied forward, so a correction cannot drop a shop finding or promote a baseline
serial record onto the Timeline. `loggedAt` keeps its original value, and `/units` is
never written — serials are corrected on the Serials tab, and the disabled inputs say
so.

### v2.36.0 — Full bleed on a phone
The rounded card and its green surround cost 100px of a 375px screen — 27%, leaving
275px of usable width. Below 768px the frame is gone: no body padding, square corners,
no shadow, and `.content` padding down from 30px to 12px. Usable width 275px → 351px
(+28%), plus 20px back at the top. Desktop is untouched. Dead `.filter-groups` and
`.filter-group-block` rules, orphaned since v2.32.0, were removed at the same time —
`.filter-group-label` stays, it still labels the widget strips.

### v2.35.1 — Filter menus were unusable when pinch-zoomed
Tapping a filter button on a zoomed-in phone flashed the backdrop and showed no menu.
`position: fixed` resolves against the layout viewport, which pinch-zoom does not
change, so the bottom sheet was rendering at the bottom of the full page — outside the
visible area — and the next tap hit the backdrop and closed it. Popovers are now placed
in `visualViewport` coordinates, with the sheet's min-width and max-height overridden
so it can fit a small visible area. Separately, `window.resize` no longer closes an
open menu (it repositions), which also fixes it closing when a mobile browser shows or
hides its URL bar.

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
