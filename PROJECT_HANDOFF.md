# Saudia Connectivity Fleet Status — Project Handoff (v2.68.1, 2026-08-27)

**To resume work in a new chat, type one word: `RESUME`.** That triggers the protocol
under *"RESUME"* below — read this document and `DISASTER-RECOVERY.md`, run
`./scripts/resume.sh`, and report where things stand. Nothing needs pasting.

## Where things stand (read this first)

The last session took the app **v2.78.0 → v2.79.0**. Everything below is detail; these
are the things that change how you work on it.

**Quick pills are single-select now, everywhere (v2.79.0).** The one change that reaches
beyond Satcom: a quick pill no longer toggles its value into the set additively — a click
shows ONLY that value, replacing whatever its axis held (per-axis: Active↔Spare↔Removed
replace each other), and re-clicking the lit pill clears its axis. Pills on *different*
axes still combine (Active + To-Do, Active + Global). `fbQuickToggle` is the whole change;
the dropdowns (`fbPick`) are untouched and remain the place for multi-select within an
axis. Read *Filter bar → Quick pills* before touching any bar's pills.

**Satcom: IPHO moved into the Commissioning box, and To-Do broadened (v2.79.0).** IPHO
Mode was renamed **IPHO** and folded into the **Commissioning Status** box as its leftmost
column, which now spans three (IPHO · Taurus · Hughes) — header/border only, no body cell
reordered, so every `data-col` is unchanged. The Commissioning `comm` axis now reads
**To-Do** when either antenna is To-Do **OR** the aircraft has IPHO Disabled, so a
fully-commissioned box with IPHO still off surfaces under To-Do; both the pill and the
dropdown pick this up (one `rowValue`). ⚠️ **Still open:** Satcom is to become the single
source of truth for IPHO — the Software IPHO control and the whole Modem tab are to be
**removed** (not done yet). Read the Satcom tab section before touching.

**Satcom Removal Date, filter bar and IPHO Mode (v2.77.2–v2.78.0).** Three Satcom changes:
(1) **Removal Date** moved to the front of MODMAN Details, between Install and Eclipse S/N,
head wrapping to two lines. (2) **Filter bar reworked** — quick pills are now Active/Spare/
Removed/To-Do; the two per-antenna commissioning filters collapsed into one combined
**Commissioning** dropdown (To-Do/Done, derived). (3) **IPHO Mode column** added, showing
the aircraft's existing top-level `iphoStatus` (same field as Software/Modem — not new),
editable from Satcom via a **cross-entity write to `/aircraft`**, with a grey N/A for
linefit/not-yet-active/off-wing rows and an IPHO dropdown filter. ⚠️ **User direction:**
Satcom becomes the single source of truth for IPHO — the Software IPHO control and the
Modem tab are to be **removed** (not done yet). Read the Satcom tab section before touching.

**Satcom now tracks commissioning (v2.77).** The old Comments column is gone; in its place
a boxed **Commissioning Status** double column (Taurus · Hughes), each a tiny Done/To-Do
pill editable in place, backed by two new `/modmans` fields `commTaurus`/`commHughes`
(`done|todo`, allowlisted in the rules). Spare/removed boxes derive a static grey **N/A**
(commissioning does not apply off-wing) and cannot be edited; `na` is never stored. Widgets
are one row (Active/Spare/Removed + Taurus/Hughes Comm.), and a **TID ↔ Chassis-ID mismatch
check** flags rows where Taurus-New TID and the Hughes Chassis ID disagree. Read the Satcom
tab section before touching it.

**There is now an eleventh tab — 📡 Satcom, the MODMAN register — on a new `/modmans`
node.** It is modelled on the 4G SIM register (one row per physical box: on-wing, spare,
faulty, removed) but is a DIFFERENT shape from everything else: `/modmans` is a
**dedicated, authoritative** node whose records STORE status/aircraft/dates directly,
rather than deriving them from a `/units` fitment the way SIM does. It carries fields
`/units` has no home for — two Taurus identifier sets (Old + New) and a Hughes MAC —
which is why it earns its own node despite the project's "no duplicate nodes" rule. It
was populated once from the user's JSON (87 boxes). ⚠️ **A removal date DERIVES Removed
status** — see the Satcom tab section. Read the `/modmans` data-model entry and the tab
section before touching it.

⚠️ **Two follow-on phases were chosen by the user but NOT built** (2026-08-31): (1) make
the **Modem tab read Kontron/Eclipse from `/modmans`** so those serials have one source,
and (2) **two-way fitment sync** between Satcom dates and `/units` fitments. Both touch
the (fragile) Modem tab and were deferred; #2 is moot until install dates are entered.
See *Open items*.

**Before that** the last session took the app **v2.68.1 → v2.72.0**:

**The Fleet tab now answers whether an aircraft is FLYING, not just where it is in the
WiFi programme.** `ops.state` on `/aircraft/{tail}` is a second, independent axis to
`fleetStatus` — eight values from AOG to Cabin Modification, each with a start date, an
optional reason and an optional expected return. Read *Operational state* before
touching it; the two things that surprise people are that **In Service is stored as
nothing at all** and that history lives in a *second, disjoint* node (`opsLog`) that
holds only closed periods, so the pair cannot drift.

**The Timeline gained a pinned block** above the day list, showing what is out of
service right now. **Nothing is pinned by hand** — `out: true` on the state is the whole
rule — and it deliberately ignores the kind filter, because filtering to Media must not
be able to hide two aircraft on the ground.

**Before that: sideways strips became reachable with a mouse (v2.71.0)**, the Software
tab was renamed and refiltered (v2.70.0), and the OTA Patch Date column landed
(v2.69.0). Six install dates were corrected where they post-dated their own OTA patch.

**Session-start cost is now ~1.2% of the window, not 25%.** `CLAUDE.md` is the whole
briefing; this file is a ~40,000-token reference pulled one section at a time with
`./scripts/doc.sh`, and `CHANGELOG.md` holds the release history. **Do not read this
file whole.** `./scripts/fn.sh` does the same job for `index.html`.

**The rules that cost real debugging time are tabulated in `CLAUDE.md`** — that table is
the canonical list and it grows most sessions. Read it there rather than keeping a
second copy here that drifts.

⚠️ **The most expensive habit, now three sessions running: verify in the browser, and
verify the thing the USER sees.** Three bugs shipped or nearly shipped in one session
that every diff and syntax check passed.

⚠️ **And its sharper form, learned on the Operational State work: for anything that
WRITES, verify the PATCH BODY, not the screen.** Two bugs were caught by stubbing the
network layer and reading what would have been sent — a period inheriting the previous
period's reason, and a column silently overflowing the table. Neither was visible on
screen, and both would have shipped.

⚠️ **Before concluding data is gone, `curl` the node.** A save that redraws from a stale
local store looks exactly like data loss, and never is.

**Current live figures**: don't trust this line — `./scripts/resume.sh` reads them fresh
at every session start, because the user edits constantly. As of 2026-08-30 it was 44
aircraft (42 Active, 2 In Retrofit), 42 retrofit + 2 linefit, 2 aircraft AOG, 40 media
load records and 106 units.

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
| `type` | e.g. `A320-214`, `A321-253NYXLR`. ⚠️ **Never contains a space** — see *Conventions* |
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
| `otaPatchUTC` | full ISO stamp, `2026-08-17T14:56:00Z`. When the over-the-air patch that follows the middleware load reached the aircraft. **Absent = not patched** |
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
| `ops` | `{ state, since, reason, expectedReturn }` — the CURRENT out-of-service period. **Absent = In Service.** See *Operational state* |
| `opsLog` | `{ [periodKey]: { state, since, until, reason } }` — CLOSED periods only, written once when a period ends |
| `modem` | `{ taurus: {commissionedDate, mgId, tid, se4, se2c, notes}, hughes: {commissionedDate, chassisId, esn, notes} }` — **both** modems, see the Modem tab |
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
| `fitments/{id}` | `aircraft`, `position`, `state`, `condition`, `fittedDate`, `removedDate`, `removalReason`, `shopStatus`, `shopRef`, `shopFinding`, `activityId`, **`roaming`**, `notes`, `loggedAt` |

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
| 4G SIM register | **two rows** — ACTIVE on ASC, and REMOVED `ex-ASK` (29d closed span) |
| Serials tab | **two rows** — one per *fitment*, ASC on-wing and ASK removed (29 days) |
| Hardware → SIM → ASK | current `…092828`, **removals 2**, changes 3, `firstFit: false` |
| Hardware → Removed Units | the ASK removal joins the shop queue |

⚠️ **A backfilled fitment must not flip the card's status**, and the reason it does not
is that `simLatestFitment()` sorts on `removedDate || fittedDate` — *not* on `loggedAt`.
Adding ASK's 2025 period today leaves the 2026 ASC fitment latest, so the card still
reads Active on ASC — which is what the register's *status* derivation depends on even
now that the table lists every fitment. **Anything that picks a "latest" fitment must sort by the DATE**, or
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

### `/modmans/{id}` — the MODMAN register, one record per physical box

**The Satcom tab's node, and a deliberate exception to "no duplicate nodes".** Unlike
the SIM register (which has no node and derives from `/units`), a MODMAN carries
identifiers `/units` has no field for — two Taurus sets and a Hughes MAC — so it gets a
dedicated, **authoritative** home. Everything is STORED on the record, not derived:

| field | notes |
|---|---|
| `kontronSn` | Kontron S/N — the identity; unique in the register (the Add-MODMAN duplicate check keys on it) |
| `eclipseSn` | Eclipse S/N |
| `taurusOldMgId`, `taurusOldTid`, `taurusNewMgId`, `taurusNewTid` | the two Taurus identifier sets |
| `hnsChassisId`, `hnsEsn`, `hnsMac` | the Hughes trio |
| `aircraft` | bare tail; shown `ex-TAIL` once removed |
| `status` | `active` \| `fault` \| `spare` \| `removed` — see the ⚠️ derivation below |
| `installDate`, `removalDate` | `DD-Mon-YYYY`; drive the days pill and the removed derivation |
| `commTaurus`, `commHughes` | commissioning per antenna, `done` \| `todo` (v2.77) — stored only as an OVERRIDE; see the ⚠️ below |
| `notes`, `addedAt` | comment (no longer shown — the Comments column became Commissioning in v2.77.0); ISO stamp |

⚠️ **A removal date DERIVES Removed status.** `satcomRows()` returns `status: 'removed'`
(and `ex-TAIL`) whenever `removalDate` is present, regardless of what is stored — so a
box that has come off reads correctly even if its stored `status` still says `fault`.
The three legacy `removed` entries have no dates and keep their stored value. Anything
picking a status off a Satcom row must read the DERIVED status, never the raw field.

⚠️ **Commissioning is mostly DERIVED, and stores only an override.** `satcomRows()`
returns `commTaurus`/`commHughes` = `na` for a spare or removed box (a box not on an
aircraft has no commissioning state — this WINS over any stored value), else the stored
value, else the default (`active` → `done`, otherwise `todo`). Only an on-wing box is
editable, so **`na` is never written** and the rules stay `done|todo`. ⚠️ Adding these
two fields needed a `database.rules.json` edit **first** — `/modmans/$modman` ends with
`"$other": { ".validate": false }`, so any field not in the allowlist is rejected and
the save fails with Permission denied. A new MODMAN field = a rules edit, deployed
before the page.

Polled with the other low-traffic nodes; saves are one PATCH of leaf paths to
`/modmans.json` and are **mirrored locally** (the node is polled, not streamed).
Registered in all four node lists (rules + backup/restore/verify).

### `/mediaLoads/{id}` — every media load ever, one record per load

`aircraft`, `cycle` (MMYY, absent on a DEV load), `loadedAt` (ISO), `source`, `loggedAt`.

⚠️ **This is the source of truth for media.** `/aircraft/{tail}/media` used to hold the
current load and was *overwritten* on every update, so the previous load — and its
Timeline entry — vanished. A load is an **event**, and events are kept.

**Current media is DERIVED**, in `rebuildAircraftData()`, as the newest record for that
tail. That one seam is why the change was small: fourteen places read `a.media` and
they all read the object that function builds. It falls back to the stored value while
the log is still loading, so a slow poll shows the last known load rather than a blank.

⚠️ **`/aircraft/{tail}/media` is SUPERSEDED but not deleted** — nothing reads it for
current media now. Left in place rather than cleared, like `simRoaming`.

⚠️ **Polled, not streamed** — the page already holds three streams and the budget
allows no seventh. **It must be in the INITIAL fetch as well as the poll**: it was left
to the poll alone once, and since the Media widgets are built from it, every monthly
card was missing for the first 25 seconds of each page load.

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

⚠️ **The one deliberate exception: `/modmans` (Satcom, 2026-08-31).** It stores Kontron
and Eclipse serials that also live in `/units` for the 40 fitted boxes — a knowing
duplicate, taken because `/modmans` must also hold two Taurus sets and a MAC that
`/units` cannot, and the user chose a dedicated authoritative node over extending
`/units`. The duplication is **not yet resolved**: the plan is to have the **Modem tab
read Kontron/Eclipse from `/modmans`** (Ideas raised but not built), which restores a
single source. Until then, do not "fix" the two by writing one from the other — that is
the pending design decision, not a bug.

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
type strings today (`A320-214`, `A321-211`, `A321-251NX`, `A321-253NYXLR`, `A330-343`);
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

## Operational state — the second axis, and why it is not a third status

`fleetStatus` says where an aircraft is in the **WiFi programme**. `ops.state` says
whether the **airframe is available today**. They are genuinely independent — an
Active aircraft can go AOG this morning and be back tonight without its programme
status moving — so this is not the "one field, not two" situation above. `OPS_STATES`
defines all eight in one place: In Service, AOG, A-Check, C-Check, Scheduled
Maintenance, Storage / Parked, Painting, Cabin Modification.

⚠️ **In Service is the ABSENCE of a value, not a stored one.** 42 of 44 aircraft are
normal at any moment; writing `in_service` to all of them would mean 44 records to
keep true instead of the two that are actually out. The rules enforce it — the stored
enum has no `in_service` — and going back in service writes **`ops: null`**.

**`out: true` on the state is the whole definition of "unavailable".** It is what
gives the Fleet column its badge, the Timeline its pinned entry and the Fleet
Composition strip its red card. A new state joins all three by being added to
`OPS_STATES` with that flag — there is nothing else to wire.

### History: two disjoint nodes, so they cannot drift

`ops` holds the OPEN period. `opsLog` holds CLOSED ones. Nothing is ever in both, so
the pair cannot disagree — which is why this is not the duplicate-field trap. A period
is archived into `opsLog` by the same PATCH that overwrites or clears `ops`, keyed by
its own start (`19_aug_2026_aog`), so saving twice rewrites one record instead of
adding a second.

⚠️ **A CHANGED STATE IS A NEW PERIOD.** The reason and expected return on record
describe the period being *left*, so they must not fall through into the one being
started — an aircraft moving from AOG into a C-Check would otherwise inherit "Engine
borescope finding". Three places enforce it and they must agree: `populateFleetTable`
(what the cell shows), `handleFleetEdit` (what is staged) and `commitFleetChanges`
(what is written). This was a real bug, caught by inspecting the PATCH body rather
than the screen.

⚠️ **`ops: null` and `ops/<field>` are never in the same PATCH** — Firebase rejects a
multi-path update where one path contains another. `ops` and `opsLog` are *siblings*,
so archiving beside the clear is fine.

### Where it shows

| | |
|---|---|
| Fleet tab | **Operational State** column, 8th, after Status. Badge, then the since-date with a days pill, the reason (clipped, full text in the tooltip) and the expected return. Edit mode offers the date, reason and return **only** while a state that means "out" is chosen, and dates a new period today |
| Fleet filter bar | **Operational** — In Service plus only the states actually in use, via `fbPresentOptions` |
| Fleet Composition | a red **Out of Service** card, rendered only when something is out |
| Timeline | a pinned block above the day list, plus dated `operational` entries — see below |

⚠️ **The Fleet table fitted its viewport exactly before this column** — 1165px inside a
1165px wrapper at 1280 — and an eighth column took it to 1180. `.fleet-compact` trims
the side padding from 15px to 11px, reclaiming 80px. **Styled by class, not by
`#fleetTable`**: the frozen head is a floating copy that inherits `className` and never
the `id`.

---

## Timeline — derived, never stored

`timelineActivities()` is the one place the three sources are folded into a
single shape (`{ iso, kind, tail, type, location, title, sub }`):

| kind | source | date it uses |
|---|---|---|
| **Activation** | `/aircraft` — every Active aircraft that has one. Title is `Entered Service` | `activatedDate` |
| **Operational** | `/aircraft/{tail}/ops` for the open period, `opsLog` for closed ones. A closed period yields **two** rows — going out, and `Returned to service` on its `until` | `ops.since` · `opsLog.since` / `.until` |
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

Filter pills are **All / Activation / Software / Hardware / Media / Operational**.
There is no Maintenance pill for now — maintenance-kind activities still appear under
All, they just have no filter of their own until the categories settle.

### Pinned — what is out of service right now

`#timelinePinned` sits between the calendar strip and the day list and lists every
Active aircraft whose `ops.state` is an `out: true` state, **longest out first**.

⚠️ **It is built from the roster, NOT from the filtered items**, and is deliberately
**not subject to the kind filter**. It is a standing banner rather than one of the
day's activities, so filtering to Media must not be able to hide the fact that two
aircraft are on the ground.

**Nothing is pinned by hand.** `out: true` on the state is the entire rule, so an
aircraft pins itself the moment it goes AOG and unpins itself when it is back — there
is no pin to set, and no stale pin to clear. That was a deliberate call (user,
2026-08-30) over a manual pin flag.

The same aircraft also appears as a dated row in the list, on the day it went out.
That is not duplication: the pinned block answers *what is out now*, the dated row
answers *what happened that day*, and only the second one survives the aircraft
returning.

⚠️ **Going out and coming back must not read alike.** Under a kind filter the pill is
hidden, so the two are marked on the ROW — `tl-ops-out` takes a red accent and ⚠,
`tl-ops-back` takes green and ✔ — the same reasoning as the Activation milestone.

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
particular filter. Multi-select in the **dropdowns** falls out of it for free. (The
quick **pills** are deliberately single-select on top of the same Set — see *Quick
pills* below — so the two surfaces read one state but behave differently.)

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

**They are not a separate filter.** Each pill drives a value in the same `Set` its
dropdown drives, so the two can never disagree — clicking *Spare* turns the pill green
*and* the Status trigger reads `Status: Spare`.

⚠️ **Pills are single-select PER AXIS (v2.79.0, user).** A click shows ONLY that value,
*replacing* whatever the axis held — so `Active` then `Spare` lands on just Spare in one
click, not two (the old additive toggle made you deselect Active first, which the user
called out as friction). Re-clicking the lit pill clears its axis (back to All). Pills on
*different* axes still combine — `Active` + `Global`, `Active` + `To-Do` — because
`fbQuickToggle` only ever clears the ONE axis it was given. **Multi-select within an axis
now lives only in the dropdowns** (`fbPick`, unchanged), which is the whole point of the
split: pills for a fast single jump, the checkbox menu for combining values.

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

⚠️ **Two tabs are deliberate exceptions.** **Modem** opens on *MSP 5.2.2 install date,
newest first* and **Media** on *loading date, newest first* — both ask what has just
arrived rather than what has waited longest.

⚠️ **Neither could be a column sort, for the same reason**: descending on a date column
puts the "no value" sentinel at the TOP, because that sentinel is built for the
ascending default. Both are **build orders** with `lastSort` applied only when the user
clicks a header — the move the SIM tiers already made.

| table | opens on | constant |
|---|---|---|
| Software | Installation Date (`completionDate`) | `SW_DEFAULT_SORT` |
| Media | Loading Date, **NEWEST first** — a build order, not a column | `mediaLoadKey()` |
| Fleet | Activation Date (`activatedDate`) | `FLEET_DEFAULT_SORT` |
| 4G SIM | Installation Date (fitment `fittedDate`) | tiers — see below |
| Modem | **MSP 5.2.2 Install Date, NEWEST first** — a build order | `modemMspKey()` |

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

3. ⚠️ **`dir` is a numeric MULTIPLIER, not a string.** `applyTableSort()` does
   `dir * (a - b)`, so `{ dir: 'asc' }` makes **every comparison `NaN`** and the rows
   come back in build order — with no error anywhere. It cost a debugging pass on the
   Modem table, where the roster is alphabetical so the result looked plausibly
   sorted. **Use `1` or `-1`**, like all four other `*_DEFAULT_SORT` constants.

4. **The default sort is RE-APPLIED on every rebuild**, not set once:
   ```js
   const s = lastSort['<table>'] || <TABLE>_DEFAULT_SORT;
   lastSort['<table>'] = s;
   applyTableSort('<table>', s.col, s.dir);
   ```
   These populate functions run again on every live update. Without this a teammate's
   edit hands the rows back in build order while the header still shows its arrow —
   which is what happened to the Fleet table the first time, and had been silently
   happening to any user sort on any table.

5. **Anything that changes which rows are visible, or their order, must call
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
   blue available, **amber closed-or-behind**, red needs action, grey nothing set. A
   green number, a green badge and the green widget all mean the same thing — which is
   why the SIM serial, its status badge and its widget share hues.

   ⚠️ **This rule is checkable, and it had silently broken.** Until v2.52.1 the SIM
   register's `REMOVED` and `SPARE` badges were `#eef1f3`/`#6b747c` — *byte for byte
   identical* — so two different states rendered the same and neither matched the
   serial two columns away. **When you add or change a status, put the badge, the
   serial and the widget side by side and check they agree**; nothing enforces it.

   **Removed is amber, not grey** (user, 2026-08-25). Grey reads as *switched off*
   rather than *taken off*; a removed card is a **closed span**, which is what amber
   already says on that very row's days pill. Grey now means only "nothing set".
   Red still belongs to Fault alone — a faulty card is a job, a removed one is history.

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

## Tabs (11)

Public order: **Overview, Software, Media, Fleet, 4G SIM, Satcom**. Behind sign-in:
**Modem, Activity, Hardware, Serials, Schedule**.

**Satcom went in public** (2026-08-31), like the 4G SIM register it is modelled on — it
carries serials, but so does SIM, and `/units`/`/modmans` are public-read anyway. To
gate it: add `data-restricted="1"` to its tab button and `'satcom'` to `RESTRICTED_TABS`.

**Schedule became restricted on 2026-08-25** — it is forward-looking work planning and
the user does not want it public. **4G SIM went public the same day**, once it was
signed off; it was restricted only while it was being built. Editing it still needs
sign-in, like every other page — the tab gate governs who *browses*, never who writes.

**Every tab below is its own `###` heading**, so one can be pulled without the other
nine: `./scripts/doc.sh modem`. They were a numbered list until 2026-08-28, which
meant any tab question cost the whole 667-line section (~10.7k tokens); Media is now
~320 and Modem ~3.8k. ⚠️ **Keep them as headings.** Folding one back into a list
takes the granularity away from all of them.

### 4G SIM — the SIM card register

One row per **FITMENT**, derived from `/units` where `lruId` is `sim` or `lf_sim`.
**There is no `/simcards` node, deliberately** — `/units` is already the single source
for a serial and its fitment history, and a second home for the same cards would drift
from it exactly the way the old duplicated status fields did.

⚠️ **It was one row per CARD until v2.52.0**, and that hid history: the table read only
`simLatestFitment()`, so a card that moved between airframes showed its current posting
and silently dropped every aircraft it had been on. Searching `ASK` returned two rows
when three cards had served it. A card now appears **once per period it served** —
`899660 117003 092859` is ACTIVE on ASC *and* REMOVED `ex-ASK` with its closed 29-day
span. **A spare has no fitment and is still exactly one row**; there is nothing to
expand and it must not fall out of the register.

Three functions, and the split between them is the point:

| | |
|---|---|
| `simRowFor(id, u, fit, byTail)` | shapes ONE row from a card and one of its fitments (`null` for a spare) |
| `simCards()` | one entry per **card**, state from the latest fitment — the inventory view |
| `simRows()` | one entry per **fitment** — what the table lists |

**The widgets and the Type filter read `simCards()`, deliberately.** Active / Faulty /
Spare are counts of physical cards, so they stay against **53 cards** rather than 54
rows however much history accumulates. The footer names both when they differ
(`3 of 54 entries · 53 cards`) and falls back to the plain card wording when they agree.

⚠️ **Staging is keyed by ROW, not by unit** — `${unitId}:${fitmentId}`, or the bare
unit id for a spare. `pendingSim` used to be keyed by unit id and `commitSimChanges()`
resolved the fitment through `byId[id].fitmentId`, *the latest one*. The moment a
second row existed that was a live corruption path: editing the history row's dates
would have written them onto the current fitment. Every edit control binds `data-sim`
to `c.key` and the commit resolves through `byKey`.

⚠️ **A card cannot be on wing twice.** Editable history rows put "set this old fitment
back to Active" within reach, which would leave one physical box reading as fitted to
two aircraft. `commitSimChanges()` refuses it by name and leaves Edit mode open, the
same way an installation date with no aircraft already was.

**Roaming** and **Comments** are per-fitment as of v2.53.0 — each row edits its own,
and only a spare's go to the unit. See the `/units` section above.

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
widgets: Active green, Fault red, Removed dark amber, Spare blue. **The whole row
agrees** — serial, `ex-TAIL`, status badge and the closed days pill are one colour per
state, and all four badges are bordered like the `On-Wing` pill beside them so they
read as pills rather than flat washes. Tokens are reused, not invented:
`#fdf3e3`/`#8a5a12`/`#efd9ae` is the amber `.ver-behind` and `.fit-in-retrofit` already
use, and every pairing clears WCAG AA (removed 5.38:1, spare 6.1:1, active 7.06:1,
fault 6.23:1, `ex-TAIL` 4.83:1 on white — **check this when picking a new one**, the
first amber tried for `ex-TAIL` came in at 4.05:1 and had to be darkened). A green number, a
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

⚠️ **Roaming and the comment live on the FITMENT** (`fitments/{id}/roaming`,
`global` \| `local`, and `fitments/{id}/notes`) — **not on the card**, and not on the
aircraft. They describe one *period of service*: the same SIM can run a different plan
on the next airframe, and a removal note is about that removal rather than about the
card for ever.

**A spare has no fitment to hold them**, so an unfitted card keeps them at unit level
(`/units/{id}/roaming`, `/units/{id}/notes`). That is now the *only* thing unit-level
roaming and notes mean, and assigning a spare **carries both onto the new fitment** —
without that, assigning a card would silently blank them.

⚠️ **A fitted row does NOT fall back to the unit, deliberately.** A fallback cannot
express *explicitly not set*: the ASK period on `…092859` has no plan on record and
would inherit ASC's, which is the exact bug this replaced — until v2.53.0 both fields
were card-level, so editing either row of a two-fitment card changed both.

⚠️ **Unit-level values were left in place on the 44 fitted cards** when the 45 values
were migrated onto their fitments (2026-08-25). Nothing reads them for a fitted card,
so they are inert — but they are a **duplicate that can drift**, and clearing them is a
data decision rather than a side effect. Snapshot:
`~/Documents/fleet-backups/2026-08-25-before-fitment-roaming-notes`.

`/aircraft/{tail}/simRoaming` is **superseded** twice over: it holds one stale record
(AQJ `active`) and nothing reads it. Left in place for the same reason.

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

### Satcom — the MODMAN register

One row per **physical MODMAN box**, read from `/modmans` (see that node's data-model
entry). Modelled on the 4G SIM register — on-wing, spare, faulty and removed boxes all
appear, so a spare in the store and a box that came off an airframe are both accounted
for — but it is a **different shape**: status/aircraft/dates are STORED on the record,
not derived from a fitment. `satcomRows()` builds the rows (applying any staged edit);
`populateSatcomTable()` renders them; `renderSatcomWidgets()` draws the one widget row;
`commitSatcomChanges()` saves; `openAddModman()`/`initAddModmanModal()` add a box.

Columns (v2.79): `# | Install Date (days pill) | Removal Date | Eclipse S/N | Kontron S/N
| Taurus Old (MG ID · TID) | Taurus New (MG ID · TID) | Hughes (Chassis ID · ESN · MAC) |
Aircraft | Status | Commissioning Status (IPHO · Taurus · Hughes)`. Comments was
**removed** (v2.77) and replaced by the Commissioning pair. **Removal Date moved**
(v2.77.2) from the far end to the front of MODMAN Details, between Install Date and Eclipse
S/N, so install → removal reads left to right; its head wraps to two lines
(`.satcom-rem-head`) to stay as narrow as a date. **IPHO** (added v2.78.0 as a standalone
"IPHO Mode" column) **moved INTO the Commissioning Status box** (v2.79.0, user) as its
leftmost sub-column and was renamed just "IPHO" — the box now spans **three** columns
(IPHO · Taurus · Hughes); see its own paragraph below. **Grouped two-row headers** name
the modules with the `.has-grouphead` machinery — Taurus Old a muted slate, Taurus New
Gilat indigo, Hughes `#005DAC`, plus two v2.77 masters: **MODMAN Details**
(`.satcom-group-details`, `#08492a`, now `colspan=5` over `#`/install/removal/serials) and
**Commissioning Status** (`.satcom-group-comm`, teal `#0f766e`, now `colspan=3`).
`publishGroupHeadHeight()` measures whichever grouped table is on the **active** tab.
⚠️ **`data-col` must equal the DOM cell index** — `sortTable()` uses it directly — so the
body td order is authoritative (0-indexed): Install 1, Removal 2, Eclipse 3, Kontron 4,
Taurus-Old 5/6, Taurus-New 7/8, Hughes 9/10/11, Aircraft 12, Status 13, IPHO 14, then the
two commissioning cells 15/16 (those two are NOT sortable — no `data-col`; IPHO at 14 IS
sortable). v2.79 moved IPHO's *header* into the Commissioning box but did **not** reorder
any body cell, so every `data-col` is unchanged. Any column insert/move re-numbers every
`data-col` and `sortTable(...)` arg after it.

The **group dividers** are a left border on the first column of each group
(`.satcom-group-start`); the Hughes block is closed on its right by that same class on the
**Aircraft** column. The **Commissioning Status is a boxed triple column** (v2.79, was a
double before IPHO joined): `.satcom-group-start` on its left edge — now the **IPHO** cell,
moved there from the Taurus cell in both head and body — and `.satcom-comm-end` (a right
border) on the Hughes cell, with the Taurus cell borderless between them: one box, three
inner columns (IPHO sortable, the two commissioning pills not).

⚠️ **A removal date DERIVES Removed status** (v2.76.4). `satcomRows()` returns
`removed`/`ex-TAIL` whenever a removal date is present, whatever the stored status — the
user asked for a removal date to mark a box removed rather than having to also set the
Status dropdown. In edit mode, `handleSatcomEdit()` auto-marks Removed when a removal
date is typed (and repaints), and clears the removal date when a non-removed status is
picked, so the two can never contradict. The three legacy `removed` entries have no
dates and are untouched. **Removed wins over Fault**, the same convention as SIM: a dead
box that was removed reads REMOVED, with the fault in the comment.

Status colours reuse the SIM badge classes (`sim-active`/`sim-fault`/`sim-unused`/
`sim-removed`); the active status is labelled **ACTIVE** while the Removal Date column
shows a small **On-Wing** pill (scoped `#satcomTable .sim-onwing`, `nowrap`, 9px) meaning
"no removal date yet, still on the aircraft" — the two used to both say On-Wing and read
as one fact twice. Install Date is the three-tier build order + four date modes the SIM
register uses; every other column goes through `sortTable()`. **Public** (see Tabs).

**Commissioning (v2.77).** Two pills per box, one per antenna, tiny (the ON-WING scale).
`SATCOM_COMM` is the two EDITABLE states (`done` green, `todo` amber); a third, `na` grey
(`SATCOM_COMM_NA`, via `satcomCommMeta()`), is **derived** for spare/removed boxes and
wins over any stored value — a box off an aircraft has no commissioning state, so it shows
a static N/A pill and offers no dropdown (only an on-wing box is editable). It is
**never written**, so the rules stay `done|todo`. `renderSatcomWidgets()` is now **one row**
of five: Active/Spare/Removed (/register) and Taurus Comm./Hughes Comm. (/active) — Fault
and Both were dropped at the user's request.

**Filter bar (v2.77.3).** Reworked at the user's instruction. Quick pills are now
**Active · Spare · Removed · To-Do**; the two per-antenna commissioning filters/pills
(`commtaurus`/`commhughes`, `Taurus ✓`/`Hughes ✓`) were **dropped** for one combined
**Commissioning** dropdown — a derived `comm` axis (`rowValue`): `todo` if EITHER antenna
is To-Do **OR the aircraft has IPHO Disabled** (v2.79, user — so To-Do surfaces anything
not fully commissioned *and* anything with IPHO still off, including a box whose antennas
are both Done), else `done`, else `na`; the dropdown offers To-Do/Done and `na` rows match
neither. Because the To-Do quick pill and this dropdown both read the one `rowValue`, the
broadened rule drives both. Bar filters are now **Status + Commissioning + IPHO** (see
below); the quick pills are single-select per axis (see *Filter bar → Quick pills*).

**IPHO (v2.78.0 as "IPHO Mode"; moved into the Commissioning box and renamed "IPHO" in
v2.79.0).** A column showing the **aircraft's top-level `iphoStatus`** (the
SAME field the Modem tab uses — one source of truth, not a modman field; the Software
tab's own IPHO Mode column was removed on 2026-09-01, see below). It is now the leftmost column of the Commissioning Status box (see the box
paragraph above), still `data-col=14` and still sortable. `satcomRows()` looks up the
box's tail in `aircraftData`: a tiny green
**ENABLED** / amber **DISABLED** pill (`#satcomTable .status-badge.ipho-on/off`, auto-9px)
only for an **active retrofit** aircraft; **grey N/A** (`.ipho-na`) for linefit (HBC+),
not-yet-active (In Retrofit), and off-wing (spare/removed/unassigned) rows. Editable in
Edit mode (Disabled/Enabled dropdown, `data-field="iphoStatus"`); a staged value overrides
the aircraft value so the pill updates before Save. ⚠️ **Cross-entity write:**
`commitSatcomChanges()` splits `iphoStatus` out of the `/modmans` PATCH into a **second
`/aircraft` PATCH** keyed by tail (Enabled→`completed`, Disabled→`null`), mirrors it onto
`aircraftLive`, `rebuildAircraftData()`s, and repaints the Software + Modem tabs — the same
pattern the Modem tab uses. Filter: an **IPHO** dropdown (`ipho`, Enabled/Disabled) beside
Commissioning; `na` rows match neither. **No data migration was needed** — the 4 tails the
user wants Disabled (AS56, AS59, ASR, ASI) were already null and every other active
retrofit aircraft already `completed`. ⚠️ **User direction (2026-09-01):** Satcom is to
become the single source of truth for `iphoStatus`; the **Software IPHO control was
removed on 2026-09-01** (with the SES column, when the Software tab became
software-only). The **whole Modem tab** is still to be removed (not done yet).

⚠️ **TID ↔ Chassis-ID check (v2.77).** Taurus-New TID and Hughes Chassis ID encode the
same unit number; `satcomIdNum()` reads the significant digits (leading zeros ignored, the
run before `HNS` for a chassis) and `satcomTidMismatch()` flags a disagreement. When they
differ both cells render bold + underlined red (`.satcom-mismatch`) with a "TID and Chassis
ID Mismatch" hover note. Read-view only. Real mismatches exist (AS66, ASAC, ASAD).

**Column width (v2.77).** To cut horizontal scroll the STATUS badge was shrunk to the pill
scale (`#satcomTable .status-badge`, 9px) and Removal/Aircraft/Status/IPHO Mode/Commissioning
were pulled to content width with `.satcom-tight` (`white-space:nowrap; width:1%`); table
cell padding is `7px 9px`. The Removal Date and IPHO Mode heads override that nowrap
(`.satcom-rem-head`, `.satcom-ipho-head`, `white-space:normal`) so the head wraps to two
lines while the body pill/date stays on one. ⚠️ `width:1%` + `nowrap` is the
shrink-to-content idiom — it does not mean 1% wide.

### 1. Overview

starts with the Timeline (calendar strip + grouped-by-date
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
### 2. Software

 (tab id is still `aircraft`) — **one** widget row of three cards:
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
Main table only — the retrofit active fleet's software. `SW_VERSIONS` is ordered
oldest-first and the **last entry is "latest"** — add a version there and it gains a
widget, an edit option, retitles the global card and demotes the previous one. No
other change needed.
⚠️ **The HBC+ table was pulled off this tab on 2026-09-01** (user) for a future
dedicated HBC+ page. The `<h3>` heading and `#hbcTable` markup are gone and the
`populateHbcTable()` call was dropped from the render path — but `populateHbcTable()`
and `hbcFleet()` are **kept**, the `#hbcTable` CSS is **kept**, and the `/fleet`
linefit data is untouched. Re-add a `<table id="hbcTable">` on the new page and the
renderer fills it unchanged.
**Middleware Install Date is column 1** (renamed from *Installation Date*,
2026-08-28) and **Install Location is column 7** (renamed from *Base*; it was column
9 before IPHO/SES were removed on 2026-09-01). The field behind each is unchanged —
`completionDate` and `completionLocation`.

⚠️ **The table opens NEWEST middleware install first** (user, 2026-08-28), not oldest
— it now answers "what was just done". **It is a BUILD order, not a column sort**, for
the reason Media and Modem are: descending on a date column floats the "no value"
sentinel to the TOP, because that sentinel is built for an ascending default. No row
in this table lacks a `completionDate` today, but **ASD and ASO do**, and they join it
the moment they go Active. `SW_DEFAULT_SORT` was deleted rather than left pointing at
an order the table no longer opens in.

**With no column sorted there is no arrow, so the header says `Newest first`** in
8.5px under the label, and stops saying it the moment a column sort is active. That
needs the headers to call **`sortAircraftTable()`** rather than `sortTable()` — the
generic one knows nothing about this note, the same shape as `sortModemTable()`.

⚠️ **The note is RE-CREATED, not just toggled.** `updateSortIndicators()` does
`th.textContent = label + arrow`, which destroys every child of the header — so a span
placed in the markup is gone the first time indicators run. `syncAircraftOrderNote()`
rebuilds it and must therefore run **after** `updateSortIndicators()`. It is keyed by
**class, never id**: `syncFrozenHeads()` clones the live `<thead>`, and an id in there
would exist twice in the document.

**Filters are Type and Location, plus a free-text search box** (IPHO and SES were
removed on 2026-09-01). ⚠️ **Status was removed at the user's request (2026-08-28)** —
the whole fleet is completed, so it could only filter to everything or to nothing. The
Status **column** stays; `row.dataset.status` is left in place and is now read by
nothing. ⚠️ **The IPHO and SES filters and their columns went on 2026-09-01** (user):
this tab now tracks only the software components. `sesMigrationValue()` was deleted with
them. IPHO stays filterable/editable on the Modem and Satcom tabs; `mg101Status` (the
SES/MG101 field) is left in the data but has **no editor anywhere now** — it awaits a
home on a future modem/SES page.
The **search box** is `search:` on the aircraft bar; rows carry `row.dataset.search`
(registration + software version + type + install location), the same mechanism the
SIM/Satcom/Modem bars use. `fbPresentOptions()` stays — the Fleet bar still uses it.

⚠️ **Cell padding on this table is 8px, not the 10px `#hbcTable` keeps.** It dates from
when the table had **eleven** columns and measured **1197px against a 1165px wrapper**;
dropping IPHO/SES on 2026-09-01 left **nine** columns with room to spare, so the 8px is
no longer needed for fit but is **kept** so the table and its frozen-head copy match.
⚠️ **It is written TWICE on purpose**: `#aircraftTable` for the table (an id beats a
class, and an id rule was already there) and `.sw-compact` for the **floating
frozen-head copy**, which inherits className and never id. Change them together or the
copy pads differently from the data under it.

Installation date carries a `25d` age pill from the same `activationAge()` the
Fleet tab uses — deliberately the identical treatment, so the two tables read the
same way. The field behind it is **`completionDate`**, unchanged; only the column's
label and position moved. Undated aircraft sort to the end on `99999999` and read
*Not set*, which today is exactly the four still behind on middleware.
**OTA PATCH#2 is column 2** (renamed from *OTA Patch Date* on 2026-09-01),
immediately after Middleware Install Date, because the patch is pushed over the air
*after* the middleware load — the two read as one sequence. Only the label changed;
the field is still **`otaPatchUTC`** on `/aircraft/{tail}`, top level beside
`completionDate` rather than nested, for the same reason `ugoVersion` is.

⚠️ **It is a full ISO stamp, so it carries the Media table's two traps**, which the
other date columns on this tab do not: `activationAge()` parses `DD-Mon-YYYY` or
`YYYY-MM-DD` only, so the stamp is **sliced to its first 10 characters** or the pill
silently never draws; and `dateSortKey()` returns **14 digits**, so the undated
sentinel is `99999999999999` — an 8-digit one sorts unpatched aircraft to the FRONT.

**Stored ISO, displayed and typed DAY-FIRST.** `parseOtaStamp` / `toOtaInput` /
`readOtaField` mirror `fmtDate` / `toDMY` / `readDateField` exactly, and nothing else
parses this value. `parseOtaStamp` round-trips through a real `Date`, so `31-02` and
`25:00` are rejected rather than rolled forward, and **`08-17-2026` is rejected** —
a month-first entry cannot get in. ⚠️ On `false` the handler returns **without
staging**, so a typo cannot clear a stamp that was already good.

⚠️ **The age pill sits BELOW the date, beside the time — not inline after it.**
Inline, the column measured 140px and pushed the table from exactly fitting its
wrapper (1165px at a 1280px viewport) to 1198px, so a laptop gained a sideways
scroll it never had. Stacked it is 102px and the table fits again. This is the same
fix, for the same reason, as the Modem tab stacking its dates above their pills.
**Re-measure if anything is added to this table** — it fits with 0px to spare.

40 aircraft carry a patch, which is exactly `swFleet()`. The four without are the two
linefit (own table) and the two In Retrofit — so the column has no blanks today, and
the "Not set" branch is what a newly activated aircraft will show.

⚠️ **The label says "Installation" but the field is the software COMPLETION date.**
On this tab that reads correctly — it is when the middleware was installed — but do
not confuse it with the Fleet tab's **Install Site** (`retrofitLocation`, where the
physical equipment went on) or with `retrofitStart`/`retrofitEnd`, the grounding
window. Three different facts; only this one is about software.
### 3. Media

monthly media loading for the main fleet only (linefit excluded).
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
### 4. Modem

satellite modem commissioning.

⚠️ **The MODMAN carries TWO modems and every aircraft has both** (user,
2026-08-25) — a Taurus *and* a Hughes, commissioned on their **own dates** and
identified by completely different numbers. An earlier build had a single `type`
field choosing between them, which could not represent an aircraft at all.

**A row is an AIRCRAFT**, with each modem's columns under its own **master head**
— a two-row `<thead>`: **MODMAN** over `Installed / Kontron S/N / Eclipse S/N`,
Taurus over `Commissioned Date / IPHO / MG ID / TID`, Hughes over
`Commissioned Date / Chassis ID / ESN`, and `# / MSP 5.2.2 Install Date / Aircraft /
Type` spanning both rows. **Comments were removed from both modems** (user,
2026-08-26); the `notes` fields stay declared and inert like `se4`/`se2c`.

⚠️ **Scope is `swFleet()` — Active RETROFIT only** (user, 2026-08-26). The A321XLR
linefit pair carry their own equipment and are configured by SBC, not by this
MODMAN-and-two-modems arrangement, so they were two rows that could never be filled
in. It was `activeFleet()` until then.

⚠️ **MODMAN reads `/units`, NOT `/aircraft`** — and that is the point. It is a
physical box with serials and a fitment, exactly what `/units` is the single source
for, and boxes were **already on record there** (serial `44` on AQB, `226` on ASBB).
Storing them under `/aircraft/{tail}/modem` would have been a second home for data
the register already held, with the page showing blanks beside it.

| column | field |
|---|---|
| Kontron S/N | `unit.serial` |
| Eclipse S/N | `unit.altSerial` — declared for exactly this, unused until now |
| Installed | the fitment's `fittedDate` |

Editing writes back: an aircraft that already has a MODMAN patches that unit, one
that does not gets a unit **and** fitment minted in the shape Record Installed uses.
⚠️ **The save is therefore TWO PATCHes**, one per node, split on whether the staged
key starts `modman/`. The local mirror skips those keys — the poll brings `/units`
back.

**MODMAN is placed FIRST**, before Taurus: it is the chassis and the two modems sit
inside it. It also keeps the Kontron blue clear of the Hughes blue, which are closer
than the other pairing (ΔE 17.8 against 35.3), with the Gilat indigo between them —
and it stays visible under either single-modem view, because filtering to Taurus
does not stop the box being the box.

⚠️ **SE4 and SE2c are NOT tracked here** (user, 2026-08-25). They are **fleet-wide
settings**, not per-aircraft facts — the Overview's *Project Objectives* already
states them once (`SE2c: 8c = 101 · b0 = 101K · 4c = 0`, `SE4: No changes`), so a
column would have been 42 identical cells. The rules keep `se4`/`se2c` **declared
and inert**, the way `lifecycle` is: no record ever carried them, so nothing is
orphaned and bringing them back would be a UI change only.

**The group heads wear their MAKER's brand colour**, sampled from the official logo
artwork rather than eyeballed. Taurus is **Gilat's SkyEdge IV** aero modem — the
line Hughes competes with — so it takes Gilat's indigo **`#1B115D`** (the wordmark
in commons `Gilat_logo.svg`); Hughes takes **`#005DAC`** (commons
`Hughes_Communications_logo.svg`, which the published brand palettes agree on); the
MODMAN is Kontron's, so it takes **`#005083`** with **`#46b294`** as its left accent
(both from commons `Kontron_logo.svg`). The teal edge is a second cue that does not
depend on telling two blues apart. White on them is 16.34:1, 6.64:1 and 8.48:1 —
all past AA.
⚠️ **Colours only, never logo artwork.** The page carries **no external assets** by
design, so a mark could only be inlined as a data URI — and third-party trademarks
are not ours to embed on that basis. **Each modem keeps its own commissioning
date.** Scope is `modemFleet()` (currently `activeFleet()`). ⚠️ **The blanks are
the point**: a modem with no date is what the page exists to surface, the same way
the Software tab shows *Not set* rather than hiding the aircraft. To include the
two still In Retrofit, `modemFleet()` is the one line.

⚠️ **There is deliberately no Modem column.** MG ID and TID say Taurus; Chassis ID
and ESN say Hughes. A badge repeating what the columns already state is a column of
noise — the same reasoning that hides the Timeline's kind pill under a kind filter.

⚠️ **IPHO is the EXISTING top-level `iphoStatus`**, not a new modem field. It is
already on 34 aircraft and already edited on the **Software** tab, so a second home
would drift exactly the way the old duplicated status fields did. This page is a
second *view* of one fact, like `activatedDate` on Fleet and Activity — which is
why a save here also repaints the Software table. **Staged edits are keyed by the
path relative to the aircraft** (`modem/taurus/mgId`, `iphoStatus`), so one handler
covers both modems and the top-level field with no branching, and the save is a
join.

Stored at **`/aircraft/{tail}/modem`**, so the page rides the `/aircraft` stream
that already exists — the connection budget allows no seventh `EventSource`, and a
node of its own would have needed one or a poll. Every field belongs to the modem,
so they **nest**: clearing writes `modem: null` and correctly takes all of them.
That is the opposite of `ugoVersion`/`tilesVersion`, which sit at top level
precisely because clearing `media` must not take them.
⚠️ Never put `modem` and `modem/<field>` in the same PATCH — Firebase rejects a
multi-path update where one path contains another. `commitModemChanges()` emits
field paths only.

**`MODEM_TYPES` is the one definition** — badges, edit dropdown and filter
together — and **`MODEM_FIELDS`** says which identifiers each vendor carries:
Taurus `mgId`, `tid`, `se4`, `se2c`; Hughes `chassisId`, `esn`.

**The filter bar is Type and the search box, and nothing else** (user, 2026-08-26).
Which columns are on screen is **not a filter** and is deliberately not declared in
`FILTER_BARS`.

**Three eye toggles — MODMAN / Taurus / Hughes.** 👁 when that group is on screen,
🚫 greyed and struck through when it is not. `MODEM_COL_GROUPS` is the definition;
`modemColsHidden` records **only what is hidden**, so the default is everything
visible with no state to initialise, and Reset restores it. They are
**independent**, which the old single-select "view" could not be — MODMAN with
Hughes alone, or all three off, are now expressible. One class per hidden group
(`.modem-hide-<id>`) drives it in **CSS**, and the frozen-head copy inherits them
because that copy is cloned from the live `<thead>` with its classes intact.

**The search box matches MODMAN serials too**, and keeps matching while that column
is hidden — the haystack is the data, not the columns.

⚠️ **Widgets do NOT follow the toggles.** They describe the data; hiding a column
does not uncommission a modem.

**Modem Output** is stored as a BARE NUMBER on the fitment beside `fittedDate` —
measured for this installation, so moving the box re-measures rather than inherits.
The unit is **typography, not data**: entering `8` reads back as `8 dBm` with the
unit quieter than the figure. The rules take an optional sign and up to two decimals
and **reject `8dBm`**, so the unit can never be stored.
⚠️ `data-sort` carries the raw number — `sortTable` parseFloats it, and a zero-padded
key turned `-8` into `000000-8`, which reads as 0.

⚠️ **Saving a MODMAN edit writes /units, and that write MUST be mirrored.** It was
not, so a saved serial appeared to vanish: the write succeeded, the table redrew from
a `unitsLive` that had not heard about it, and `/units` is polled. **The data was
never lost.** `unitOps` records what the unit write did and replays it locally.

⚠️ **A new MODMAN is written as ONE object.** Writing `<unit>/fitments/<fit>` and
`<unit>/fitments/<fit>/fittedDate` together is a multi-path update where one path
contains another, which Firebase rejects — it would have failed the whole save the
first time anyone typed a serial and a date together.

**Column widths are a MIN-WIDTH on the body cells**, sized to the values.
⚠️ `width` on a `<th>` under `table-layout: auto` is only a hint and was overridden —
a 16-character chassis id ended up in an 88px column. And **not** a `<colgroup>`: the
eye toggles can remove three column groups and a colgroup is a fixed list of columns.
`nth-child` counts DOM position, so a hidden group does not shift them.

**One type scale**: 10px headers, 11.5px values, 8.5px qualifiers, 12px registration,
and a 1.08em bump on an identifier's promoted digits. Everything centred.

**Compact layout** (user, 2026-08-26). Thirteen columns have to fit a laptop, and
the Hughes group was falling off the right. **1195px → 977px**, which fits from
1152px of viewport upward. What bought it, in order of size:

| | saving |
|---|---|
| cell padding 15px → 8px each side | ~180px across the row |
| each date stacked ABOVE its days pill instead of beside it | ~60px × 4 columns |
| the Type column removed | ~71px |
| `Commissioned` → `Comm. Date` on the two sub-heads | ~38px × 2 |
| type 14px → 12px, headers → 10.5px | the rest |

⚠️ **A single long word cannot wrap**, so `Commissioned` forced its column 117px
wide against a 60px date. Giving the label a space lets it break onto two short
lines inside a head that is already two rows tall.

⚠️ **`fmtDateShort()` is DISPLAY ONLY.** `DD-Mon-YYYY` → `DD-Mon-YY`; the stored
value, the sort key and every handler keep the full form. It is still **day-first** —
shortening the year is not an excuse to reorder the parts.

⚠️ **The Type column is gone but the Type FILTER is not.** The row still carries
`data-type`; the type shows as a tiny pill under the registration, beside the
in-service age.

**`MSP 5.2.2 Install Date` is the first column, between `#` and Aircraft**, in the
ungrouped section so it sits outside both modem groups and spans the two header
rows. ⚠️ **It is DERIVED from `completionDate`, not stored.** MSP 5.2.2 shipped as
part of Middleware 2.1.0, so its install *is* the software completion date — the
field the Software tab labels *Installation Date*. A second stored date for one
event could only drift. It is **read-only here** and says so on hover; the Software
tab stays the one place it is edited.

⚠️ **This table opens on MSP INSTALL DATE, NEWEST FIRST** (user, 2026-08-26) —
deliberately *not* the "date column, oldest first" rule the other tables follow. MSP
is the software that talks to the modem, so its install is the reference point for
major software activity here, and the most recent leads. (It opened on *activation*
date from 2026-08-25 until the MSP column arrived; the activation pill stays on the
Aircraft cell, since the two dates answer different questions.)

It is the **build order** rather than a column sort, for the reason it always was:
descending on the column would float the "Not set" sentinel to the **top**, since
that sentinel is built for an ascending default. ⚠️ **A build order and `lastSort` are mutually
exclusive**: a column sort is re-applied only if the user clicked a header, and both
Reset and a view change drop back to activation order. That is also why there is no
per-view default any more — activation is an aircraft-level order, identical in
every view.

⚠️ **With no column sorted there is no arrow to explain the order**, so the footer
says it: `· newest activation first`, dropped the moment a column sort is active.
Keeping that honest needs the headers to call **`sortModemTable()`**, not
`sortTable()` — the generic one knows nothing about this page's footer. Wrapping
locally beats giving the other eight tables a hook they do not need, the same shape
as the SIM date header calling `cycleSimDateSort()`.

⚠️ **Two header rows cannot share one sticky `top`** — they pin on top of each
other. The second sits below the first by `--grouphead-h`, measured and published by
`publishGroupHeadHeight()`; a hardcoded number is wrong the moment the label wraps.
The head's hairline `::after` is scoped to `thead tr:last-child`, or the group row
draws a line through the middle of the header.

⚠️ **`.modem-group` must out-specify `.aircraft-table th`** (0,1,1), which sets the
header background and a left text-align. A bare class loses, and the master head
renders left-aligned in the plain header green. White on the two group tints
measures 4.77:1 and 5.73:1 — both AA.

⚠️ **`applyModemFilters()` must tell a view change from a search keystroke.**
`fbSearchInput()` calls the bar's `apply` on **every character**, and a rebuild
there would pull focus out of the search box; a view change, by contrast, *must*
rebuild because the columns differ. It is guarded on `modemViewRendered`.

⚠️ **The row's dataset key must be `data-view`, matching the filter's id.**
`fbRowMatch()` reads `data-<id>` off the row, so naming it anything else leaves the
View filter matching nothing and **hiding every row** — which is what it did, with
the footer reading "0 of 42" while 42 rows sat in the DOM.

**The aircraft cell carries the Fleet tab's activation age pill** — the same
`activatedDate` and the same `activationAge()`, so the two pages cannot disagree.

**IPHO is a pill**, green `ENABLED` / amber `DISABLED`. Amber rather than red: not
yet set is work outstanding, not a fault. ⚠️ Only this page — the **Software** tab's
IPHO column keeps the dot-and-text convention it shares with its neighbours.

**`modemIdHTML()` promotes the unit number inside TID and Chassis ID.** A chassis
reads `AERSVA00064HNSJ3` and its TID is `64`: the run of digits before `HNS`
identifies the unit and everything around it repeats across the fleet, so it goes
bold and a shade larger while the leading zeros **dim rather than disappear** —
reading the value off a label still needs them. The same treatment
`simSerialHTML()` gives a SIM serial's last six digits.
⚠️ **Only TID and Chassis ID, and that is the point**: they carry the *same* number,
so emphasising both is what lets the eye pair them across the row. MG ID (`101`) and
ESN (`17501546`) are bare numbers with nothing to pick out — promoting those too
would leave every cell bold and nothing standing out at all.
⚠️ It returns **markup**, so it is for the cell only; `data-sort` and `data-search`
keep the raw value.

**Widgets follow the view**, so every figure counts the population beneath it: per
modem, **Commissioned** and **Awaiting**, which sum to the fleet. Under *both*,
**Both Commissioned / One Outstanding / Neither Started**, which **partition the
aircraft** rather than double-counting an airframe under each modem.
⚠️ Neither Started takes **grey, not alert red** — it is the un-started backlog,
not a fault, and red would put the largest number on an unfilled page in alarm
colours.

**Commissioned means a DATE is on record**, not merely identifiers typed — the same
reasoning that makes Software completion require a location as well as a version.

⚠️ **Restricted for now at the user's request** (2026-08-25) while the page
settles. It is an ordinary public-shaped page; moving it out is one edit to
`RESTRICTED_TABS`.

### 5. Activity

 (tab id is still `maintenance`, like Software's is still `aircraft`)
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
### 6. Hardware

the LRU catalogue on the left in two fit groups, the selected unit
on the right: profile, known issues, fitment, removed units. See *Hardware tab*
above. Serials are derived from `/activities` and never stored here.
### 7. Serials

the data-gathering surface for `/units`. One flat table, one row
per *fitment*, with **Record Installed** and **Record Removed** above it and CSV
export. Deliberately not another two-pane shell: the job is getting serials in
and completing dates later, not navigating a hierarchy. The date fields are
editable in place — that is where the backlog gets finished — and the "Dates
Outstanding" widget is the progress bar for it.
### 8. Schedule

standalone forward-looking plan, deliberately **not** linked
to completion status. Entries drop off automatically 24h past their slot
(`SCHEDULE_GRACE_MS`); in that window they show `⚠ Overdue` so they can be
rescheduled rather than vanishing.
### 9. Fleet

owns the roster: add / edit / remove, incl. linefit. The **Operational State** column
is the 8th, after Status — see *Operational state* for the field, the eight values and
why In Service is stored as nothing at all. The
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

⚠️ **A source ending in `DEV` is accepted and carries NO cycle** (user,
2026-08-26) — `ME-SVA-UGO-DEV` is the development/default load. There is nothing
to age it against, so it reads as **NO MEDIA**, but the **date is kept**: the day the
default load was activated is a real fact. `MEDIA_DEV_SOURCE` is the one test.
It therefore **sorts by its date, not to the end** — the end of the table is for
aircraft with no loading event at all, and a DEV aircraft had one.

⚠️ **`commitMediaChanges()` gates on `loadedDateUTC`, NOT on `mediaCycle`.** It used
to gate on the cycle, which meant a record without one was **silently dropped** — the
entry staged, Save reported success and wrote nothing. The cycle fields are written as
`null` for a DEV record, so an aircraft moving from a dated load to the default one
clears them rather than keeping a stale month.

- A cycle is **MMYY** (`0826`). `cycleSortKey()` maps it to YYYYMM so January
  correctly outranks the previous December; `previousCycle()` rolls the year.
  **Never compare cycle strings directly.**
- ⚠️ **Cycle `0526` is LIGHT MEDIA — the baseline, not a stale May load** (user,
  2026-08-25). It is the mini package carrying just enough for the wireless IFE to
  work, put on at installation before the aircraft joins the monthly cycle. Calling it
  *May 2026 / older* claimed a newly installed aircraft was months behind when it is
  simply not on the cycle yet.

  `MEDIA_LIGHT_CYCLE` is the one definition, `isLightMediaCycle()` the one test.
  `mediaStatusType()` returns **`light`**, checked **before** the latest/previous
  comparison so the baseline keeps its identity even in a month where it would
  otherwise count as current. **Keyed on the CYCLE**, so it follows the source string
  on its own — any record whose `mediaSource` is `ME-SVA-UGO-0526` parses to `0526` and
  is baseline.

  It ranks **second last, above only No Media**, in the widget strip *and* in the Month
  filter: it is not a point in the monthly sequence, so listing it between two months
  would misplace it. **Violet**, deliberately clear of the green/blue/amber
  progression, because the aircraft is not behind.
  ⚠️ The two records still store `mediaDisplay: 'May 2026'`. Nothing reads it for
  display — `cycleToDisplay()` derives the label — so it is superseded rather than
  wrong, the same way `simRoaming` is.

- **`MEDIA_CYCLES` defines each cycle's release date**, and that is all that is
  stored: `{ '0826': { size: '791 GB', start: '26-Jul-2026' } }`. ⚠️ **The END is
  DERIVED** as the day before the next cycle's start — September opening on 25-Aug is
  exactly what makes August run 26-Jul to 24-Aug. Storing both would let them
  contradict each other. Code, not data, like `SW_VERSIONS`: one line a month.

- **Two figures per cycle widget, and the difference is the point.** The figure and bar
  track the **live** count — aircraft on that media right now, which falls as they move
  on. Below the bar sit the window and a pill counting every aircraft that **ever** took
  it, which only rises. August will read fewer and fewer live while "35 loaded" stays
  true.
  ⚠️ **A missing log must never empty the strip.** A cycle any aircraft currently
  carries gets a card even with no log at all, its total falling back to the live count.

- **The Cycle view** (`cycleview`, `single: true`) is a VIEW, not a row filter. Empty
  means current media. Pick a cycle and every in-scope aircraft is listed against *that*
  cycle — takers with their date, the rest reading `NOT LOADED`, because the blanks are
  how a missed month is spotted. Read-only in that view: a save there would write a new
  load rather than correct the historical one being looked at.
  ⚠️ **A view change must REBUILD, not re-filter.** `applyMediaFilters()` only toggled
  row visibility, so picking a cycle did *nothing* — the rows still showed current
  media. Guarded on `mediaViewRendered`, exactly as the Modem table is.
  ⚠️ **Only cycles declared in `MEDIA_CYCLES`** are offered, plus the two out-of-cycle
  kinds. An older month with no release date has no window to view against — but its
  records, its count and its **widget** all remain.

- ⚠️ **The DEV load has no cycle code**, because the rules accept four digits only. It
  takes a **pseudo-cycle** (`MEDIA_DEV_VIEW`) used for views and counts and **never
  stored**; `loadCycleKey()` is the one place that mapping lives.

- **Missed months** come from `missedCycles(tail)` — the cycles between an aircraft's
  first load and now that it never took. July straight to September reports August.

- **The Timeline emits one row per LOAD**, not one per aircraft, which is what makes
  past entries persist. A derived **cycle-closed** row lands on each cycle's end date
  with the total and percentage — never stored, like the Activation milestone.
  ⚠️ Because a late load still counts toward its cycle (user's call), that figure can
  **rise after the close date**: it is the cycle's total, not a frozen snapshot.

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
The same fact is still stated in the Project Objectives list, so nothing was lost.
(The Software tab's HBC+ table, which also carried it, was removed on 2026-09-01 for
a future dedicated HBC+ page.)

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

## Horizontal strips — reachable without a touch screen

Seven things in this app scroll sideways: `.tabs`, `.cal-strip`, `.tl-kind-pills`,
`.table-scroll-wrapper`, `.media-widget-strip`, `.fb-filters`, `.quick-filters`.

⚠️ **Until v2.71.0 they were unreachable with a mouse.** They are swipeable on a
touch screen, which is why it went unnoticed for so long — but a wheel scrolls
vertically, and **five of the seven set `scrollbar-width: none`** so a phone shows a
clean row. On a laptop that left no scrollbar to drag and no gesture to make, so
whatever a strip hid simply could not be got at: the right-hand columns of the Modem
table, and the **Schedule and Sign in tabs** once eleven tabs no longer fit
(reproduced at 700px — both were off-screen with no way to reach them).

Two halves, and the first is the one that matters:

| | |
|---|---|
| `initHorizontalWheelScroll()` | turns a vertical wheel into horizontal scroll while the pointer is over a strip. Works with any mouse, changes no layout |
| the `@media (any-pointer: fine)` block | gives the scrollbar back on anything with a mouse, for discoverability |

⚠️ **A new sideways-scrolling strip must be added to BOTH** — `HSCROLL_SELECTOR` in
the script and the selector lists in that media query — or it is unreachable with a
mouse all over again. This is the same shape of trap as a new node needing four edits.

⚠️ **The wheel must be handed back at the ends.** If the handler swallowed every
event, a pointer resting over a table would trap the page and it would feel frozen.
It calls `preventDefault()` **only** while the strip can still move that way; at
either end the event passes through and the page scrolls. Verified on all eight
overflowing strips across five tabs.

⚠️ **A horizontal-intent wheel is left completely alone** (`|deltaX| >= |deltaY|`) —
a trackpad swipe and a tilt wheel already do the right thing, and intercepting them
would fight the browser.

⚠️ **`deltaMode` is not always pixels.** A wheel reporting LINES (`1`) or PAGES (`2`)
would crawl one pixel per notch; both are scaled.

⚠️ **The gate is `any-pointer: fine`, NOT `(hover: hover) and (pointer: fine)`.**
The latter asks about the *primary* pointer, so a touchscreen laptop — where the
mouse is exactly the problem being fixed — reports coarse and would have been left
with no scrollbar. `any-pointer` asks whether a fine pointer exists at all.

**The frozen table head follows for free.** The handler sets `scrollLeft`, which is
what a scrollbar drag does, and `window.addEventListener('scroll', scheduleFrozenHeads,
true)` is capture-phase precisely so a wrapper scrolling sideways is heard. No new path.

⚠️ **The in-app browser pane reports a COARSE pointer and no hover**, so the
scrollbar half of this cannot be verified there — `matchMedia('(any-pointer: fine)')`
is false in it. The wheel half is verifiable and was verified; the scrollbars need a
real mouse.

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
- ⚠️ **A GROUPED head cannot be sized cell by cell.** `table-layout: fixed` takes its
  column widths from the **first row**, and a master head's `colspan` cell is divided
  **equally** across the columns it spans — which put the Modem copy up to **65px** out
  of step with its data. A **`<colgroup>`** of real widths, measured from a **body
  row** (the only row with exactly one cell per column), overrides that inference. It
  is guarded on `head.rows.length > 1`, so the eight single-row tables keep the per-`th`
  path they already work with. Verified at 0px drift on both.
- ⚠️ **`syncFrozenHeads` copies a table's className, NOT its id.** Style a table by
  `#id` and the floating copy gets none of it — it renders at the default font and
  padding, wraps differently, and is then clipped by a host sized to the live head. The
  Modem table's sub-headers lost their second line to exactly this. **Style a
  frozen-head table by CLASS.**
- ⚠️ **HIDDEN columns must be SKIPPED when building that colgroup, not measured as
  zero.** `display: none` removes a cell from the table structure outright — a table
  with four hidden columns has four fewer **columns**, not four zero-width ones — so a
  `<col>` per hidden cell puts the colgroup out of step with the copy and **every
  column after the hidden run collapses to zero**, leaving the floating head
  overlapping the live one. This stayed invisible until the Modem eye toggles gave
  something the ability to hide a column.
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
- ⚠️ **An aircraft type never contains a space** (user, 2026-08-25), stored or
  displayed. The XLR pair were stored `A321-253NY XLR` and shown `A321 XLR`; both lost
  the space — stored `A321-253NYXLR`, shown **`A321XLR`**. The full Airbus designation
  is kept, because every other type carries its own (`-214`, `-211`, `-251NX`, `-343`).

  **Three places hardcode a type string and must move together**: the fallback roster,
  `TYPE_PILL_COLORS` and `TYPE_SHORT_LABEL`. Nothing else does — every type dropdown
  and filter builds its options from the roster's own distinct values, so they follow
  the data on their own.

  ⚠️ **`typeFamily()` is the thing to check when a type is renamed**, because CWAP
  quantity hangs off it. It matches on the **A32x prefix**, not a subtype list, so a
  rename within a family cannot disturb it — but a rename that changed the prefix
  would silently drop the aircraft to `qty` (1), which is why the family rule exists.
- All times UTC/Zulu.
- No external scripts. Keep it that way.

---

## "RESUME" — the one-word session start

CHECKPOINT's bookend. When the user says **RESUME** (alone or in a sentence), it
means: *bring yourself fully up to speed on this project and tell me where things
stand.* Do all three without asking:

0. ⚠️ **`cd` here first — a session does not open in this repo.** New chats open in
   `/Users/rizwanmujawar/Downloads/Claude Projects/Saudia Reports`, the **NSG IFEC
   Fleet Portal** — a different app, with its own `index.html` and `scripts/` to
   mislead you. Nothing below is reachable until you move:
   ```bash
   cd /Users/rizwanmujawar/Downloads/saudia-fleet-dashboard
   ```
   ⚠️ **This is why RESUME failed on 2026-08-30**, on a checkpoint that was otherwise
   perfect. A close-out being complete does not make it *reachable*; the `cd` is what
   makes it so, which is why it is step zero in all three places the protocol lives —
   here, `CLAUDE.md`, and the assistant's memory.
1. **Read `CLAUDE.md`** — that is the entire briefing.
2. **Run the state check.** One read-only command covers all of it:
   ```bash
   ./scripts/resume.sh
   ```
   Release · git state · the 12 deployment checks · live-vs-local `index.html`
   hash · live figures read fresh from the database · latest snapshot · open items.
3. **Report briefly** — version and commit, tree clean and pushed, check result,
   hash match, current figures, and the open items waiting on the user. Then ask
   what to work on.

⚠️ **DO NOT READ THIS DOCUMENT AT SESSION START.** It is a reference manual —
~38,000 tokens, a quarter of a context window gone before any work begins, which
is what this instruction exists to stop. RESUME used to read it whole and that was
the single biggest waste in the project. Pull the one section the work needs:

```bash
./scripts/doc.sh --list           # every section, with its token cost
./scripts/doc.sh "media module"   # ~1.7k tokens instead of ~38k
```

⚠️ **The same applies at CHECKPOINT.** Update the sections you touched, reading
each with `doc.sh` first. Opening the whole file to edit one paragraph costs the
same quarter-window.

⚠️ **The figures in this document are a shape, not a value.** The user edits live,
which is exactly why `resume.sh` re-reads them; never quote the doc as fact.

⚠️ **If the script flags anything, say so before changing anything.** It exits
non-zero when the tree is dirty, the branch is out of sync, a check fails, the live
hash differs, or there is no verifiable snapshot.

**Where the trigger is recorded.** A fresh session only knows what it auto-loads, so
RESUME is written down in three places deliberately:

| | covers |
|---|---|
| `CLAUDE.md` in this repo | any session started **in** the repo — and it is committed, so it survives a clone. **It is also the briefing itself** |
| the user's project memory (`resume-code-word`) | sessions started from the user's usual working directory |
| this section | the human-readable source both of those point at |

⚠️ **Keep the three in step.** They are one protocol written three times because
each is loaded in a different situation; a change to the steps has to land in all
three, the same way a new node is four edits.

### Why the briefing is CLAUDE.md and not a fourth document

The obvious move was a new `BRIEFING.md`. It was rejected: `CLAUDE.md` is already
auto-loaded when a session starts in the repo, so a separate briefing would have
been a **second home for the same content** — the exact duplication this project
removes everywhere else. One file, loaded automatically in the repo and read
explicitly from anywhere else.

**Session-start cost, measured 2026-08-28:**

| | before | after |
|---|---|---|
| documents read | handoff + runbook, whole | `CLAUDE.md` only |
| tokens | **~52,000 (25% of a 200k window)** | **~2,500 (~1.2%)** |

The saving came from three things: the change log left for `CHANGELOG.md` (~10k,
and `git log` already had it), the runbook became on-demand (~3.4k, it is a
break-glass procedure), and the handoff stopped being read at all in favour of
`doc.sh` (~38k).

## "CHECKPOINT" — the one-word session close

When the user says **CHECKPOINT** (alone or in a sentence), it means: *wrap this session
up so it can be resumed cleanly in a fresh chat.* Do all four, in order, without asking:

0. ⚠️ **`cd` here first** — see the same step under *"RESUME"*. A session opens in the
   NSG IFEC Fleet Portal directory, not this one.
   ```bash
   cd /Users/rizwanmujawar/Downloads/saudia-fleet-dashboard
   ```

1. **Back up the data.**
   ```bash
   FLEET_BACKUP_DIR="$HOME/Documents/fleet-backups/$(date -u +%F)-session-close" ./scripts/backup.sh
   ```
   Check the output lists **every** node — a node missing from `backup.sh` is a silent
   hole in the snapshot.

2. **Bring the documentation current — section by section, not file by file.**
   ```bash
   ./scripts/doc.sh "data model"     # read just what you are about to edit
   ```
   Update *Where things stand* (in `CLAUDE.md` if the shape of the project changed),
   the data model, the affected tab sections, `CHANGELOG.md`, and — most valuable —
   any ⚠️ lesson that cost real debugging time. Write what would have saved that time.

   ⚠️ **Do not open the whole handoff to edit one paragraph.** It is ~38,000 tokens;
   that is the cost this whole arrangement exists to avoid, and it is just as real at
   close-out as at start.

   ⚠️ **A change to the RESUME or CHECKPOINT steps lands in THREE places** —
   `CLAUDE.md`, the user's project memory (`resume-code-word`), and this section.

3. **Verify and deploy.** `./scripts/resume.sh` must come back **All clear** — that
   covers the 12 checks, a clean tree, everything pushed, and the live `index.html`
   hash matching local. Never report a deploy from build status alone.

4. **Say that the next session starts with the word RESUME**, and name anything
   left unfinished. Nothing else needs to be carried across by hand — the protocol,
   the working agreements and the state check all live in the repo now.

⚠️ **CHECKPOINT is a close-out, not a stopping point.** Finish whatever is in flight
first, or say plainly what is unfinished so the next session picks it up.

## Resuming in a new chat

**The user types one word: `RESUME`.** The protocol is under *"RESUME"* above and is
auto-loaded from `CLAUDE.md` and the user's project memory, so nothing has to be
pasted and nothing goes stale between sessions.

⚠️ **The old paste-block is retired.** It carried the version, commit and live
figures inline, which meant every one of them was wrong the moment the user edited
anything — and it had to be regenerated at each CHECKPOINT to stay even roughly
true. `resume.sh` reads all of it live instead. The block below is kept only as a
**fallback for a session with no repo access**, where the protocol cannot load:

```
Resuming the Saudia Connectivity Fleet Status dashboard. Read these two files first,
in this order — they are the full context:
/Users/rizwanmujawar/Downloads/saudia-fleet-dashboard/PROJECT_HANDOFF.md
then /Users/rizwanmujawar/Downloads/saudia-fleet-dashboard/DISASTER-RECOVERY.md
Start with "Where things stand".

Then confirm the current state before changing anything:
cd /Users/rizwanmujawar/Downloads/saudia-fleet-dashboard && ./scripts/resume.sh

Working agreements:
- Deploy without asking me — rules first, then the page, and prove it by hash, never
  by build status.
- Ask me before removing anything major (a tab, page, feature or data node). Additive
  and cosmetic changes just ship.
- Never use US month-first dates anywhere.
- When I say CHECKPOINT, do the four-step close-out in the handoff.

Open items are under "Open items" in the handoff — don't guess at those.
```

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
- ⚠️ **A NEW NODE MUST BE ADDED TO `scripts/backup.sh`, `restore.sh` AND
  `verify-deployment.sh`.** Each carries its own hardcoded node list. `/mediaLoads` was
  created and backed up for a day without being in any of them — a restore would have
  silently dropped the entire media history. Adding a node is four edits: the rules,
  and those three lists.
- **`/editors` is not in the backups** — it is not anonymously readable, by design.
  Keep the uid list outside the repo or a restore leaves nobody able to edit.

Nine scripts, all dry-run-first where they can write:

| script | does |
|---|---|
| `resume.sh` | **the RESUME state check** — release, git, the 12 checks, live hash, live figures, latest snapshot. Read-only |
| `check.sh` | **the pre-deploy checklist** — syntax, rules JSON, duplicate ids, handler existence, the mechanical project rules, and a diff against HEAD. Read-only |
| `doc.sh` | pull ONE documentation section instead of reading a ~38k-token manual |
| `fn.sh` | pull ONE function or constant instead of reading a ~178k-token page |
| `backup.sh` | snapshot public nodes — no credentials needed |
| `backup-secrets.sh` | `/editors` + account list (no password material), private dirs only |
| `restore.sh` | put a snapshot back, checksum-verified |
| `migrate-project.sh` | move to a new Firebase project |
| `verify-deployment.sh` | health + enforcement check for any project |

⚠️ **`resume.sh` deliberately carries NO node list** — it delegates node coverage to
`verify-deployment.sh`. Hardcoding one would have made a new node *five* edits
instead of four, which is exactly the trap `/mediaLoads` already fell into once.

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

There is no build, lint or type tooling. **`./scripts/check.sh` runs every
mechanical check in one command** — run it before every deploy. It covers:

1. The `<script>` block extracted and `node --check`ed.
2. `database.rules.json` parses as JSON.
3. **No duplicate DOM ids** — checked against the MARKUP only. Run against the whole
   file it reports `id="${a.id}"`, which is JS building markup, not a duplicate.
4. **Every inline `onclick`/`onchange`/`oninput`/`onsubmit` handler is defined.**
5. **The project rules that can be checked mechanically** — no `<input type="date">`,
   no string sort directions (`dir` is a multiplier), no external assets,
   `APP_VERSION` present. Each is a rule this document states and nothing enforced.
6. **A diff against `HEAD`** — line count and function count. That is what caught the
   scripted edit that deleted 19 functions and the one that produced a
   17-million-line file.

⚠️ **Fault-inject before trusting a checker.** All six were verified by feeding
`check.sh` a deliberately broken copy of the page — a syntax error, a duplicate id,
an undefined handler, a native date picker and a string sort direction. A check that
has never failed is not a check.

Then, and this is the part no script can do:

7. **Test in the local browser preview and read the console.** The bugs that cost
   this project real time all passed every mechanical check.
8. `git add/commit/push` — GitHub Pages auto-deploys.

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

- **⚠️ Exercise one Operational State save from the page.** The ASV/ASAD AOG records
  were written with the **Firebase CLI, which writes as admin and bypasses
  `.validate`** — so the data is proven correct but the *page-side* write path has
  never been exercised against the new `ops` rules. The regexes were validated directly
  against every value written (including confirming `08-19-2026` is rejected), so this
  is a low-risk loose end, not a suspected fault. Closing it takes one edit-and-save on
  the Fleet tab: green means proven, `Permission denied` means one rules deploy.
  Nothing is at risk either way — a rejected save changes nothing.
- **Whether the `[AOG] Grounded from …` comments on ASV and ASAD should be cleared.**
  They predate the Operational State column and now duplicate it, which is exactly how
  two copies of one fact start to drift. The user said they would edit these later
  (2026-08-30), so they were left alone. `reason` is `Grounded` on both, also a
  placeholder the user intends to replace.
- **Media cycle release dates.** `MEDIA_CYCLES` has August (26-Jul-2026) and September
  (25-Aug-2026). Earlier months have none, so they show a widget and a count but no
  window, no cycle-closed Timeline row, and no entry in the Cycle view. Each new month
  is one line, alongside the load size the user already supplies.
- **Whether the Kontron serial should be the unit's primary serial.** MODMAN writes
  Kontron to `/units.serial` and Eclipse to `altSerial`, so AQB now reads `484569029`
  on the Serials and Hardware tabs where it used to read `44`. A one-line swap if the
  short Eclipse number should be primary.
- **Whether `/aircraft/{tail}/media` should be cleared.** Superseded by `/mediaLoads`
  and unread, left in place rather than deleted.
- **Whether the cycle-closed Timeline figure should freeze.** It currently rises when a
  late load lands, per the user's call that a late load still counts toward its cycle.

- **The Modem backlog.** One aircraft (**AQB**) carries a full record; the other 41
  are empty. That is the data-entry job, and the page is built to show it — every
  undated modem reads *Not set* rather than being hidden.
- **Whether the Modem tab should stay behind sign-in.** Restricted at the user's
  request while it settles; it is built as an ordinary public page and moving it out
  is one edit to `RESTRICTED_TABS`.
- **Whether Modem scope should include the two aircraft In Retrofit.** It is
  `activeFleet()` today, matching the other operational pages — but commissioning is
  retrofit-time work, so the argument for `fleetRoster` is real. `modemFleet()` is the
  one line.

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

- **Satcom → Modem: authoritative read (chosen, not built).** The user chose to make
  `/modmans` the single source and have the **Modem tab read Kontron/Eclipse from it**
  rather than from `/units`. Deferred because the Modem tab is keyed by aircraft and its
  save writes `/units` + `/aircraft/modem`; reconciling needs a concrete call — does its
  MODMAN section become read-only-from-Satcom, and what happens to the 40 `/units` modman
  units (retire, or leave)? Ask before starting.
- **Satcom ↔ fitment two-way sync (chosen, not built).** Setting aircraft + install/
  removal on Satcom should also write the `/units` fitment the Serials/Modem tabs use.
  Moot until the user starts entering install dates, so parked with the item above.
- **Faulty-and-removed reads REMOVED, not FAULT.** By the "removed wins" rule a dead box
  that came off (e.g. m036, "no power, completely dead") shows REMOVED with the fault in
  the comment. The user was offered the opposite precedence and has not asked for it.
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

✅ **The client write path to `/aircraft/{tail}/modem` is PROVEN** (2026-08-25). The
user entered AQB — both modems, dates, `mgId`, `tid`, `chassisId`, `esn` — through the
UI, and it landed against the live rules engine. The nested `modem/{slot}/{field}`
shape and the leaf-path PATCH both work.

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

**Moved to [`CHANGELOG.md`](CHANGELOG.md)** — ~664 lines of release history that
nothing at session start needs, and that `git log` already carries in the commit
bodies. Nothing was lost; every entry is there verbatim.

```bash
./scripts/doc.sh "v2.68"      # one release
```

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
