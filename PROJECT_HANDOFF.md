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
- Single file, ~3000 lines, vanilla HTML/CSS/JS. No build step, no framework.
  CDN libs: html2canvas + jsPDF (for the Downloads tab exports only).

`gh` CLI and `firebase` CLI (via `npx firebase-tools`) are already authenticated
on this Mac — no login needed to keep working.

## ⚠️ Read this first: this is a read-only dashboard

On 2026-08-16 the Realtime Database security rules were changed to
**block all writes**:

```json
{
  "rules": {
    ".read": false,
    ".write": false,
    "aircraft": {
      ".read": true,
      ".write": false
    }
  }
}
```

Commit `d055b5f` (`git log`) explains why: the PIN-gated editing UI was
**client-side only** — a JS conditional, not a real database rule — so anyone
could bypass it entirely with a raw REST call. That commit locked the database
to read-only and states editing is intentionally moving to a separate,
properly-authenticated project called the **NSG IFEC Fleet Portal** (a
different, more serious Firebase/Firestore app — not this repo).

**The dead editing UI was then stripped out** (see `git log`), so the page is
now consistently read-only end to end. Removed: the Aircraft Status Edit/Save
button, the PIN modal and 30-minute PIN session, `saveAircraftField` /
`commitEditChanges` and the staged-changes machinery, every `editMode` branch
in the two table renderers, the comment modal, and the ✏️ comment buttons on
both the Timeline and the Aircraft Status table. Notes still **display**
(the ⚠️ line under a registration, and 💬 pills in the Timeline) — only the
authoring path is gone.

**Practical effect right now:**
- The dashboard displays live data fine (reads work) and nothing in the UI
  promises an edit it can't perform.
- To change data, use `firebase database:update` from the CLI (admin-
  authenticated, bypasses the rules) or the NSG IFEC Fleet Portal.
- If write access ever needs to come back here, it needs real auth — the old
  PIN gate was a client-side JS conditional, bypassable with a raw REST call,
  which is exactly why the lockdown happened.

A pre-lockdown data snapshot is saved at `aircraft-backup-2026-08-16.json` in
the repo root, in case anything needs restoring.

## Architecture

**Data has two layers, merged at runtime into a single `aircraftData` array:**

1. **Static/structural** — `aircraftStatic` JS array embedded directly in
   `index.html` (id, type, station). Rarely changes; edit via code + git push.
2. **Live fields** — Firebase `/aircraft/{tailId}`, currently read-only:
   - `status`: `'scheduled' | 'in-progress' | 'completed'`
   - `completionDate`: string, format `'DD-Mon-YYYY'` (e.g. `'13-Aug-2026'`)
   - `completionLocation`: `'Jeddah' | 'Riyadh' | null`
   - `iphoStatus`: `'completed' | null`
   - `mg101Status`: `'' | 'provisioned' | 'done'` (SES Migration to MG 101)
   - `note`: free-text comment string
   - `beamcfgStatus` (ASBA/ASBB only): anything other than `'done'` renders as
     Pending (ASBA/ASBB currently hold `'pending'`).

**"Completed" is defined consistently everywhere on the page as:**
`status === 'completed' AND completionLocation is set`. Don't compute it any
other way — several widgets rely on this exact definition matching.

**Project scope math (also used everywhere):**
`42 total = 40 Middleware-scope aircraft + 2 HBC+ SBC-config aircraft (ASBA, ASBB)`

**Live sync:** plain `fetch()` for the initial load + a native `EventSource`
(SSE) subscription to Firebase's REST streaming endpoint — deliberately no
Firebase JS SDK, to keep the page a single lean file. Known quirk: the local
`aircraftLive` mirror can occasionally desync if many rapid writes happen
back-to-back (only observed during heavy scripted testing); a page reload
always self-heals it.

## Tabs (4 total — System Tracking and By Station were removed earlier)

1. **Overview** — top 4 metric cards (Middleware 23/40, HBC+ SBC 0/2, Project
   Completion %, Remaining), Fleet Completion Overview (6 cards: Total
   Completed, A320, A321, A321neo, A321XLR/SBC Config, A330 — each lists its
   aircraft), Completed Aircraft by Station (Jeddah OEJN/JED, Riyadh
   OERK/RUH), Timeline (calendar-strip of completion dates with hover
   tooltips + Oldest First/Latest First sort toggle, grouped-by-date list
   with type/location tag-pill rows and inline comments), 5 Project
   Objectives (Consolas for technical values, scope chips, nothing
   collapsed).
2. **Aircraft Status** — Main Fleet table (40 aircraft, all columns) + HBC+
   table (2 aircraft, simplified BEAMCFG-only columns). Quick-filter pill
   groups: Aircraft Type / Location / Status. Default sort alphabetical by
   registration with a Reset button; sortable columns show ↑/↓. Read-only —
   the Edit Mode toggle was removed (see warning above).
3. **Schedule** — standalone forward-looking plan, deliberately **not**
   linked to `aircraftData` completion status (an aircraft can be
   "Completed" for Middleware but still have a separate, unrelated
   upcoming workpackage here). Entries whose date has passed are filtered
   out automatically at render time — the list self-prunes, no manual
   cleanup needed. Currently holds 5 upcoming entries, all Jeddah.
4. **Downloads** — PDF/PNG/JPEG export per tab + full dashboard + square
   metrics format, via html2canvas + jsPDF.

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

For **data-only** changes (not code): skip git entirely, write straight to
Firebase — the database is read-only to the browser, so admin writes go
through `firebase database:update` (bypasses rules since it's
CLI-admin-authenticated). Always read
current state first and patch only the deltas — never blind-overwrite a
record, since teammates or other flows may have touched other fields.

## Status: v1.0, feature-complete

The user considers this done and stable — expect small, targeted asks going
forward (data tweaks, minor UI polish) rather than large rebuilds. No open
todos.
