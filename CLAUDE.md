# Saudia Connectivity Fleet Status — working instructions

A single-file HTML dashboard (`index.html`, ~7,700 lines, vanilla, no build step,
no external scripts) for Saudia's wireless IFEC fleet, on GitHub Pages with a
Firebase Realtime Database behind it.

---

## The two code words

### RESUME — start of session

When the user says **RESUME** (alone or in a sentence), it means: *bring yourself
fully up to speed on this project and tell me where things stand.* Do all of it
without asking, in this order:

1. **Read the two context documents, in this order** — they are the full context:
   - `PROJECT_HANDOFF.md` — start at *Where things stand*
   - `DISASTER-RECOVERY.md`
2. **Run the state check.** One command does all of it:
   ```bash
   ./scripts/resume.sh
   ```
   It reports the release, git state, all 12 deployment checks, the live-vs-local
   `index.html` hash, live figures read fresh from the database, the latest
   snapshot, and the open items. It only reads — nothing is written or deployed.
3. **Report back briefly**: version and commit, whether the tree is clean and
   pushed, the check result, hash match, current live figures, and the open items
   that are waiting on the user. Then ask what to work on.

⚠️ **Never quote the figures from the handoff as fact.** The user edits live;
`resume.sh` reads them fresh for exactly this reason.

⚠️ **If `resume.sh` reports anything needing attention, say so first** and do not
start changing things until it is understood.

### CHECKPOINT — end of session

Wrap the session up so it resumes cleanly in a fresh chat. Four steps, in order,
without asking — the full protocol is under `## "CHECKPOINT"` in
`PROJECT_HANDOFF.md`:

1. `FLEET_BACKUP_DIR="$HOME/Documents/fleet-backups/$(date -u +%F)-session-close" ./scripts/backup.sh`
   — check the output lists **every** node.
2. Bring `PROJECT_HANDOFF.md` and `DISASTER-RECOVERY.md` current — *Where things
   stand*, data model, affected tabs, change log, and any ⚠️ lesson that cost real
   debugging time.
3. `./scripts/verify-deployment.sh`, clean tree, everything pushed, live hash ==
   local. **Never report a deploy from build status alone.**
4. Tell the user the next session starts with the word **RESUME**.

CHECKPOINT is a close-out, not a stopping point: finish what is in flight, or say
plainly what is unfinished.

---

## Working agreements

- **Deploy without asking.** Rules first, then the page, and prove it by **hash**,
  never by build status. Additive and cosmetic changes just ship.
- **Ask before removing anything major** — a tab, a page, a feature, a data node.
- **Never US month-first dates, anywhere.** Stored `DD-Mon-YYYY`, typed
  `dd-mm-yyyy`. `<input type="date">` is banned outright: its display format
  follows the browser locale and nothing overrides it.
- **Don't guess at open items.** They are listed under *Open items* in the handoff
  and most are waiting on a decision from the user.

## The rules that cost real debugging time

| | |
|---|---|
| A new node needs **four edits** — the rules, and the node lists in `backup.sh`, `restore.sh`, `verify-deployment.sh` | Backups |
| A "view" that changes what a row **means** must **rebuild**, not re-filter | Media / Modem |
| A write to a **polled** node must be mirrored locally, or the save looks like it vanished | Media / Modem |
| Style a frozen-head table **by class** — the floating copy inherits `className`, never `id` | Sticky header |
| `dir` in a sort is a numeric **multiplier** — `'asc'` makes every comparison `NaN` | Table sorting |
| A date column's `data-sort` must go through `dateSortKey()`, and the undated sentinel needs the **same digit count** as a real key | Table sorting |

⚠️ **Verify in the browser, and verify the thing the USER sees.** Three bugs
shipped or nearly shipped in one session that every diff and syntax check passed.

⚠️ **Before concluding data is gone, `curl` the node.** A save that redraws from a
stale local store looks identical to data loss, and never is.

## Local dev

```bash
python3 -m http.server 8765
```

Use the Browser tool's `preview_start {name: "dashboard"}` — direct `navigate` to
localhost is blocked by policy. There is **no build, lint or type tooling, and
that is deliberate.** Don't add a toolchain unasked. The checks that stand in for
it are under *Local dev workflow* in the handoff; run all of them before a deploy.

Rules deploy separately and **must land before the page** when a change adds a
field:

```bash
npx --yes firebase-tools deploy --only database --project saudia-fleet-dashboard
```
