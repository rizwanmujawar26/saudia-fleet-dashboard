# Change log — Saudia Connectivity Fleet Status

Split out of `PROJECT_HANDOFF.md` on 2026-08-28. It is ~10,000 tokens of history
and was being read in full at every session start, where it is never needed —
`git log` carries the same reasoning in the commit bodies.

Pull one release without reading the file:

```bash
./scripts/doc.sh "v2.68"
```

Newest first. Each entry is one deployed commit; `git log` has the full reasoning
in the commit bodies.

### v2.69.0 — OTA Patch Date on the Software tab
The middleware load is followed by a patch pushed over the air; that date and time is
now a column, `otaPatchUTC` on `/aircraft/{tail}`, with the same age pill the other
date columns carry. Stored as a full ISO stamp because the minute matters, displayed
and typed day-first like everything else. 40 records loaded — exactly `swFleet()`.
Rules first, then the page. The pill is stacked under the date rather than inline:
inline it pushed the table 33px past its wrapper and reintroduced a sideways scroll.

### v2.68.1 — Media widgets vanishing on load
`/mediaLoads` was not in the initial fetch, only the 25-second poll, so every monthly
card was missing for the first 25 seconds of each page load. It joins the initial fetch,
and the strip can no longer blank even with no log at all. Nothing was deleted; the
cycle FILTER drops undeclared months while their records, counts and widgets remain.

### v2.68.0 — Cycle filter fixed; Light Media and No Media become cycles
The cycle selector did nothing — `applyMediaFilters` only toggled visibility, and a view
change has to rebuild. Light Media and the DEV default now have their own filter entry,
counts and history. Widget footers gained the cycle window and a cumulative "N loaded"
pill under the bar, with the figure above tracking the live count.

### v2.67.0 — Media becomes a load history
New `/mediaLoads` node, one record per load, backfilled from the 40 current records.
Current media is derived from the newest record, so past loads and their Timeline
entries persist. Cycles gained release dates and derived windows, plus a derived
cycle-closed Timeline row and a past-cycle view on the Media page.

### v2.66.0 — Modem: one type scale, centred, Modem Output
The days pill leaves the Aircraft column, everything centres, six font sizes become
four, and a Modem Output column stores a bare number rendered as `8 dBm`. Also fixed the
frozen-head copy inheriting className but not id, which was clipping the sub-headers.

### v2.65.2 — Type beside the registration, toggles into the filter bar
`FILTER_BARS` gained an `extra` slot so a bar can carry its own controls and have them
survive a repaint.

### v2.65.1 — MODMAN save fix and value-sized columns
The save wrote correctly but was not mirrored locally, so it looked like it vanished;
a new MODMAN was also written with a nested path Firebase rejects. Column widths became
a min-width on the body cells.

### v2.65.0 — Compact Modem layout, 1195px to 977px
The table now fits a laptop with every column visible. Padding was the biggest cost,
not content. Dates read `dd-mmm-yy` and sit above their days pill rather than beside
it; the Type column became a pill under the registration, with its filter untouched.

### v2.64.0 — Retrofit only, and eye toggles per column group
The Modem page drops the linefit pair (scope is `swFleet()`), keeps only Type and the
search box as filters, and gains three independent 👁/🚫 toggles for the MODMAN, Taurus
and Hughes column groups. The search now matches MODMAN serials. Building this exposed
a latent bug in `syncFrozenHeads()`: it measured hidden columns as zero-width instead
of skipping them, which collapsed every column after a hidden run in the floating head.

### v2.63.0 — MODMAN section, Comments removed
A third column group for the MODMAN chassis — Installed, Kontron S/N, Eclipse S/N — in
Kontron's own blue and teal, placed first because the two modems sit inside it. It
reads and writes **`/units`**, where two MODMAN boxes were already on record, so both
appear without any data entry; `altSerial` finally has the use it was declared for. The
save became two PATCHes, one per node. Comments left both modem groups.

### v2.62.0 — Modem gains an MSP 5.2.2 install date column
A new first column between `#` and Aircraft, derived from `completionDate` rather than
stored — MSP shipped inside Middleware 2.1.0, so it is the same event and a copy could
only drift. The table now opens on it, newest first, replacing the activation-date
order; the activation pill stays on the Aircraft cell. Adding a column shifted every
`data-col` after `#`, so the checks now assert the sequence is contiguous and the
colspans still sum to the sub-row.

### v2.61.0 — Media accepts ME-SVA-UGO-DEV
A source ending in `DEV` is the default load: no monthly cycle, so it reads as **NO
MEDIA**, but its date is kept and shown because that is the day the default load was
activated. The save had to stop gating on `mediaCycle` — it was silently dropping any
record without one, reporting success and writing nothing.

### v2.60.0 — Media opens newest-first, and 0526 is Light Media
The Media table opens on the most recent load with the unloaded aircraft last — a build
order, since descending on the date column would float the no-load sentinel to the top.
Cycle `0526` is now **Light Media**, a status of its own ranked second last before No
Media in both the widget strip and the Month filter, because it is the baseline package
an aircraft carries before joining the monthly cycle. *Older Media* no longer sweeps
those aircraft up as months behind.

### v2.59.1 — Aircraft types carry no space
`A321-253NY XLR` becomes `A321-253NYXLR`, displaying as `A321XLR`. Only the XLR pair
broke the rule. The three hardcoded type strings moved with the data; every filter and
dropdown builds from the roster and followed on its own. `typeFamily()` matches on the
A32x prefix, so CWAP stays ×3 on the pair.

### v2.59.0 — Modem opens on activation date, newest first
AQB, activated yesterday, now opens the table. Activation has no column, so this is the
build order rather than a column sort — which retires the per-view default and means a
column sort applies only when the user clicks one. The footer names the order, and the
headers call a local `sortModemTable()` so that note stops claiming it the moment a
column sort takes over.

### v2.58.0 — Activation pill, IPHO pill, promoted unit number
The aircraft cell carries the Fleet tab's activation age pill on every row. IPHO reads
as a green/amber pill instead of a dot and a word. TID and Chassis ID promote the unit
number they share — `AERSVA000`**`64`**`HNSJ3` against TID **`64`** — bold and a shade
larger, leading zeros dimmed. MG ID and ESN stay plain so the promoted number is the
thing that stands out.

### v2.57.0 — SE4/SE2c dropped, dates named, group heads branded
SE4 and SE2c leave the Taurus group — they are fleet-wide settings the Overview already
states once, so a column was 42 identical cells. Both date headers now read
*Commissioned Date*. The two group heads take their maker's real brand colour, sampled
from the official logo files: Gilat indigo `#1B115D` for Taurus, Hughes blue `#005DAC`.
Colours only — the page carries no external assets and third-party marks are not ours
to embed.

### v2.56.0 — Grouped headers, no modem column, IPHO from iphoStatus
A row is an aircraft again, with each modem's columns under its own master head and its
own commissioning date. The Modem column is gone — the identifiers already say which
modem it is. IPHO reads the existing top-level `iphoStatus` rather than minting a
second home for it. Also taught `syncFrozenHeads()` to size a grouped head with a
`<colgroup>`, without which the floating copy sat 65px out of step with its data.

### v2.55.0 — Both modems per aircraft, and three views
Corrects the model: the MODMAN carries **two** modems and every aircraft has both,
each with its own commissioning date and identifiers. A row is now a modem rather than
an aircraft, and the View filter switches Taurus / Hughes / both — swapping which
columns exist, not just which rows show. Widgets follow the view; under *both* they
partition the aircraft instead of double-counting it.

### v2.54.0 — Satellite modem commissioning page
New 🛰️ **Modem** tab, restricted for now: one row per aircraft with its modem vendor,
that vendor's identifiers (Taurus MG ID/TID/SE4/SE2c, Hughes Chassis ID/ESN) and the
commissioning date. Stored under `/aircraft/{tail}/modem`, so it rides the existing
`/aircraft` stream rather than needing a seventh connection. One table rather than one
per vendor, because the vendor does not follow fit — ASBB is linefit-Taurus, ASC is
retrofit-Hughes — and a split would hide the uncommissioned aircraft the page exists to
surface. Also fixed `signOut()` never clearing `simEditMode`.

### v2.53.0 — Roaming and the comment move to the fitment
Editing either row of a card with two fitments changed both, because both fields were
stored on the unit. They are per-fitment now, so two periods of service stay
independent; a spare keeps them at unit level because it has no fitment, and assigning
one carries them forward. **No fallback from fitment to unit** — a fallback cannot say
"explicitly not set", which is the whole ask. 45 values were migrated onto their
fitments; unit-level copies were left in place rather than deleted.

### v2.52.1 — REMOVED goes dark amber, and every SIM badge takes its own colour
`REMOVED` and `SPARE` were the same grey, byte for byte, and neither matched its own
serial. Removed now takes the dark amber of its serial, its `ex-TAIL` and its closed
days pill — grey said *switched off* where the fact is *taken off* — and Spare takes
the blue its serial and widget already had, leaving grey to mean nothing set. All four
badges gained a border to match the `On-Wing` pill. Contrast checked to AA throughout.

### v2.52.0 — The SIM register lists fitments, not cards
A card that moved between airframes only ever showed its current posting, so ASK's
SIM history read two rows instead of three. A row is now a **fitment**, so
`899660 117003 092859` appears twice — ACTIVE on ASC and REMOVED `ex-ASK` — and the
tiers keep history below the cards in service. 54 rows, 53 cards.
Staging was rekeyed from unit id to `${unitId}:${fitmentId}`, without which an edit to
a history row would have written onto the current fitment; and setting an old fitment
back to Active is refused, since one card cannot be on wing twice. Widgets and the Type
filter still read `simCards()`, so every count stays a count of cards.

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
