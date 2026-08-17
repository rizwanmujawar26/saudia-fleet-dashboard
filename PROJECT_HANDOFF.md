# Saudia Fleet Dashboard — Project Handoff (v1.0)

Paste this whole document into a new chat to resume work with full context.

## What this is

A single-file HTML dashboard tracking Saudia Airlines' Middleware 2.1.0 software
rollout + HBC+ SBC config update across a 42-aircraft fleet. Hosted free on
GitHub Pages, live-synced via Firebase Realtime Database so the whole team sees
the same data instantly.

- **Live site:** https://rizwanmujawar26.github.io/saudia-fleet-dashboard/
- **GitHub repo:** https://github.com/rizwanmujawar26/saudia-fleet-dashboard (public)
- **Local path:** `/Users/rizwanmujawar/Downloads/saudia-fleet-dashboard/index.html`
- **Firebase project:** `saudia-fleet-dashboard` (Realtime Database, us-central1)
  DB URL: `https://saudia-fleet-dashboard-default-rtdb.firebaseio.com`
- Single file, ~4000 lines, vanilla HTML/CSS/JS. No build step, no framework,
  and **no external scripts at all** — the html2canvas/jsPDF CDN libs went with
  the Downloads tab, so the page has no third-party runtime dependency.

`gh` CLI and `firebase` CLI (via `npx firebase-tools`) are already authenticated
on this Mac — no login needed to keep working.

## ⚠️ Read this first: how editing is secured

**Public read, authenticated write.** Anyone can view the dashboard; only a
signed-in account that is explicitly allowlisted can change data. The check
lives in the database rules, so bypassing the UI with a raw REST call gains
nothing.

Short history: the original edit gate was a shared PIN checked in JavaScript —
not a database rule — so anyone could bypass it with one REST call. Commit
`d055b5f` locked the database to read-only on 2026-08-16; `4587c27` stripped
the resulting dead UI; `460f6e3` rebuilt editing properly on Firebase Auth.

**Rules** (`database.rules.json`, deployed via `firebase deploy --only database`):
- `/aircraft` — world-readable; writable only when
  `auth != null && root.child('editors').child(auth.uid).val() === true`.
- Every field is `.validate`d by type and allowed value; `$other` is `false`,
  so unknown keys (like the old `pinHash`) can no longer be written at all.
- `/editors/$uid` — readable only by that uid, never client-writable. Manage
  the allowlist from the CLI:
  ```bash
  firebase database:update /editors --project saudia-fleet-dashboard --data '{"<uid>": true}'
  ```
  Get a uid from Firebase Console → Authentication → Users.

**Auth is REST, not the SDK** — `identitytoolkit.googleapis.com` for sign-in and
`securetoken.googleapis.com` for refresh, keeping the page a single file with no
Firebase SDK. Tokens live in `sessionStorage` (so closing the tab signs you out)
and refresh a minute before expiry. Writes carry `?auth=<idToken>`.
`FIREBASE_API_KEY` is embedded in the page on purpose: Firebase web API keys are
public client config that identify the project, not secrets — the rules are what
grant access.

**Where editing appears:** the Software, Media and Schedule tabs. The actions row shows
`🔒 Sign in to edit` until a signed-in editor is present, then `✏️ Edit` /
`💾 Save` plus the account email and Sign out. The ✏️ comment button renders
only for signed-in editors. **The Overview timeline only ever displays
comments** — this is deliberate, don't add editing there.

`canEdit()` shapes the UI only. The rules decide; tampering with it client-side
still earns `Permission denied`.

Admin changes that skip auth entirely still work from the CLI
(`firebase database:update`), since the CLI is admin-authenticated.

A pre-lockdown data snapshot is saved at `aircraft-backup-2026-08-16.json` in
the repo root, in case anything needs restoring.

## Architecture

**Data has two layers, merged at runtime into a single `aircraftData` array:**

1. **Fleet roster** — Firebase `/fleet/{tail}` =
   `{ type, station, fit, fleetStatus, comments }`, the single source of truth
   for which aircraft exist. Managed entirely from the **Fleet** tab
   (signed-in editors only): add, edit and remove and every table, filter pill and
   metric picks it up — scope numbers are counted from the roster by
   `projectScope()` / `hbcScope()` / `middlewareScope()` / `mediaScope()`, not
   hardcoded. The `aircraftStatic` array in `index.html` is now only a fallback
   for when `/fleet` is empty or unreachable.
2. **Live fields** — Firebase `/aircraft/{tailId}`. Each one is constrained by
   a `.validate` rule, so the allowed values below are enforced, not just
   conventions:
   - *(`status` was removed — it duplicated facts now held by `swVersion` and
     `fit`. See "Single sources" below.)*
   - `completionDate`: string, format `'DD-Mon-YYYY'` (e.g. `'13-Aug-2026'`)
   - `completionLocation`: `'Jeddah' | 'Riyadh' | null`
   - `iphoStatus`: `'completed' | null`
   - `mg101Status`: `'' | 'provisioned' | 'done'` (SES Migration to MG 101)
   - `note`: free-text comment string (Software page comments)
   - `swVersion`: the aircraft's middleware level, e.g. `'2.0.0'` / `'2.1.0'`.
     Drives the Middleware column, the version widgets and the top metric card.
     `SW_VERSIONS` in `index.html` is ordered oldest-first; the last entry is
     "latest". Add a version there and it gains a widget and an edit option.
   - `media`: `{ mediaCycle, mediaDisplay, mediaSource, loadedDateUTC, comments }`
     — see the Media tab below; `media.comments` is separate from `note`
   - `beamcfgStatus` (ASBA/ASBB only): anything other than `'done'` renders as
     Pending (ASBA/ASBB currently hold `'pending'`).

## Widget vocabulary

- **Global widgets** — a fixed 2 x 2 grid above the tab bar, `.global-widgets`,
  showing fleet-wide programme health on every tab. Top row is the two software
  streams (Retrofit / Middleware, Linefit / SBC Configuration A.13), bottom row
  is Media Loading and Maintenance. Figures follow the local-widget reading
  order: count at the left edge of the progress bar, percentage at the right.
- **Local widgets** — the `.media-widget-strip` rows inside a tab, showing that
  tab's own breakdown (version progress, media months, fleet composition...).

## Maintenance widget (placeholder wiring)

`maintenanceOpen(a)` reads `a.maintenance && a.maintenance.open`. Nothing writes
that yet — the Maintenance tab will — so the widget shows 0 today and lights up
on its own once flags exist, with no further wiring. Its denominator is the
**active** fleet (`fleetStatus === 'active'`), so stored/retired aircraft drop
out. The card is grey while the count is zero (`.alert-clear`) and turns light
red once anything is open; verified both states, and that storing an aircraft
moves the denominator 42 -> 41.

Note `/aircraft` rules do **not** yet allow a `maintenance` field — `$other` is
`false`, so building the tab means adding its schema there first. Deliberately
not guessed in advance.

## Single sources — do not reintroduce duplicates

Two facts were each stored twice, which meant an editor could change one and
leave the dashboard self-contradictory. Both are now derived from exactly one
field:

- **Linefit / HBC+ scope** — `fit === 'linefit'` on `/fleet` is the only marker.
  Use `isLinefit(a)`. The old `/aircraft` `status === 'excluded'` is gone.
- **Completion** — `isCompletedStrict(a)` is
  `swVersionOf(a) === latestSwVersion() && completionLocation`. The Status
  column is a *view* of this via `aircraftStatusOf(a)`, not an editable field;
  the old stored `status` is gone and the rules now reject it.

So an editor sets **Middleware version** and **Completion Location**, and the
Status column, row highlight, type cards, station cards, Timeline and the top
metric cards all follow. Verified: upgrading one aircraft moved completed rows,
the metric, the total card, the station count, the version widget and the
Timeline together, 24 -> 25.

Note the metric card counts aircraft *on the latest middleware* (software
level), while completion additionally requires a location — so they can
legitimately differ by the aircraft still showing "⚠ needed to count as done".

**Project scope math (also used everywhere):**
`42 total = 40 Middleware-scope aircraft + 2 HBC+ SBC-config aircraft (ASBA, ASBB)`

**Live sync:** plain `fetch()` for the initial load + a native `EventSource`
(SSE) subscription to Firebase's REST streaming endpoint — deliberately no
Firebase JS SDK, to keep the page a single lean file. Known quirk: the local
`aircraftLive` mirror can occasionally desync if many rapid writes happen
back-to-back (only observed during heavy scripted testing); a page reload
always self-heals it.

## Tabs (5 total — System Tracking and By Station were removed earlier)

1. **Overview** — starts with the Timeline. The Fleet Completion Overview and
   Completed Aircraft by Station blocks moved to the Software tab. Timeline (calendar-strip of completion dates with hover
   tooltips + Oldest First/Latest First sort toggle, grouped-by-date list
   with type/location tag-pill rows and inline comments), 5 Project
   Objectives (Consolas for technical values, scope chips, nothing
   collapsed).
   The Timeline draws **one divider per day and nothing between aircraft** —
   `.timeline-date-group` owns that border (suppressed on the last group).
   Beware `.timeline-items li`: it must stay `.timeline-items > li`, or the
   descendant match hits the nested per-aircraft `<li>`s and the double rules
   come back.
   Each Fleet Completion Overview card lists **only completed** aircraft, or
   "None yet" — never its full scope.

2. **Software** (tab id is still `aircraft`) — Main Fleet table (40 aircraft, all columns) + HBC+
   table (2 aircraft, simplified BEAMCFG-only columns). Quick-filter pill
   groups: Aircraft Type / Location / Status. Default sort alphabetical by
   registration with a Reset button; sortable columns show ↑/↓. **This is the
   only tab where data can be edited**, and only by a signed-in allowlisted
   editor (see the security section above).
3. **Media** — monthly media-loading status for the main fleet only
   (`status !== 'excluded'`, so the HBC+ pair is out of media scope). Columns:
   `# | Aircraft | Type | Status | Media Loaded | Date UTC | Comments`.
   Everything on this page derives from one stored object per aircraft at
   `/aircraft/{tail}/media`:
   ```
   mediaCycle    "0826"                  MMYY
   mediaDisplay  "August 2026"
   mediaSource   "ME-SVA-UGO-0826"
   loadedDateUTC "2026-08-16T04:22:00Z"
   comments      free text (separate from the Software page's `note`)
   ```
   Editors type one string — `2026-08-16 04:22:00 (ME-SVA-UGO-0826)` — and
   `parseMediaEntry()` derives all four fields. Seconds are optional.
   **mediaStatus is never stored.** It is relative to the newest cycle in the
   fleet, so it is computed on every render by `mediaStatusType()`: equal to the
   newest cycle = `latest` (green), one calendar month behind = `previous`
   (blue), anything older = `older` (amber), absent = `no_media` (grey).
   Storing it would go stale the moment a newer cycle lands.
   Cycles are compared via `cycleSortKey()` (MMYY → YYYYMM) so January sorts
   above the previous December; `previousCycle()` rolls the year likewise.
   The month widgets and the Media Month filter pills are both built from the
   cycles actually present, newest first — a new cycle creates its own widget
   and pill with no code change, and months with no aircraft never appear.

4. **Schedule** — standalone forward-looking plan, deliberately **not**
   linked to `aircraftData` completion status (an aircraft can be
   "Completed" for Middleware but still have a separate, unrelated
   upcoming workpackage here). Entries whose date has passed are filtered
   out automatically at render time — the list self-prunes, no manual
   cleanup needed. Currently holds 5 upcoming entries, all Jeddah.

## Branding

Actual Saudia SVG logo (`/Users/rizwanmujawar/Downloads/saudia-vector-logo-seeklogo/saudia-seeklogo.svg`)
embedded as a base64 data URI in the header, recolored white via
`filter: brightness(0) invert(1)` (the source SVG is solid green with no
white variant, so this CSS trick was needed for contrast against the green
header). Palette: `#0a5c34` primary / `#137a49` gradient partner, plus a thin
multi-color geometric accent stripe under the header. Kept deliberately
restrained — green used for headers/buttons/active-states only, not
saturating every element.

## Local dev workflow

```bash
cd "/Users/rizwanmujawar/Downloads/saudia-fleet-dashboard"
python3 -m http.server 8765
```
Then use the Browser tool's `preview_start` (not direct `navigate` —
`localhost` gets blocked by policy that way) to open `http://localhost:8765/index.html`.

Before every deploy:
1. Extract the `<script>` block and run `node --check` on it.
2. Test the actual change in the local browser preview.
3. `git add/commit/push` — GitHub Pages auto-deploys, takes ~1-3 min to
   reflect (poll with `curl` for new content before declaring it live).

Rules changes deploy separately from the page:
```bash
firebase deploy --only database --project saudia-fleet-dashboard
```
After changing rules, re-check enforcement with plain `curl` — an anonymous
read of `/aircraft.json` should be `200`, and an anonymous write, a read of
`/editors.json`, and a read of root should all be `401 Permission denied`.

For **data-only** changes (not code): skip git entirely and write straight to
Firebase via `firebase database:update` (admin-authenticated, so it bypasses
the rules). Always read current state first and patch only the deltas — never
blind-overwrite a record, since teammates or other flows may have touched other
fields. This is not hypothetical: a record was edited by another admin path
mid-session on 2026-08-16 while this doc was being written.

## Status: v1.0, feature-complete

The user considers this done and stable — expect small, targeted asks going
forward (data tweaks, minor UI polish) rather than large rebuilds.

Verified as of 2026-08-16: rules reject anonymous writes and anonymous reads of
`/editors` and root while keeping `/aircraft` public; Email/Password sign-in is
provisioned; one uid is allowlisted under `/editors`.

Open todo: nobody has yet signed in and saved an edit end to end. That last hop
can't be checked from here — it needs either a real password or the RTDB
emulator, and the emulator needs Java, which isn't installed on this Mac
(`emulators:start` fails with "Unable to locate a Java Runtime"). Installing a
JDK would let a future session test rules properly with
`auth_variable_override`, which is worth doing before the rules change again.

5. **Fleet** — owns the roster. Columns `# | Aircraft | Type | Fit | Status |
   Comments`, plus a remove button in edit mode. `fit` is `retrofit` (the 40)
   or `linefit` (ASBA/ASBB); `fleetStatus` is `active | stored | retired`.
   Removing an aircraft deletes only its `/fleet` entry — its `/aircraft`
   software and media history survives, so re-adding the registration restores
   it. NOTE: HBC+ separation elsewhere still keys off `/aircraft` `status ===
   'excluded'`, not `fit`; the two are seeded consistently but are not yet a
   single source. Worth unifying.
