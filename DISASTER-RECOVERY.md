# Disaster recovery & portability

Everything here is deliberately runnable by someone who was not part of building
this. Commands assume you are in the repo root.

---

## What exists

| Piece | Where it lives | How it is protected |
|---|---|---|
| The app | `index.html`, one self-contained file | Git history |
| Security rules | `database.rules.json` | Git history, and a copy inside every snapshot |
| The data | Firebase Realtime Database | `scripts/backup.sh` -> a **private** location, gitignored |
| Editor allowlist | `/editors` in the database | **Not backed up — see below** |

A snapshot folder holds one JSON file per node, a copy of the rules, and a
`manifest.json` with a SHA-256 of each file so corruption is detectable rather
than discovered during a restore.

### What a snapshot now holds

`/units` is no longer a small node — it carries the **SIM register**, which is the
best-populated operational data in the project (53 cards with fitments, dates, roaming
plans and fault flags as of 2026-08-25). A restore that skips `/units` loses the SIM
history entirely; there is no second copy of it anywhere.

Fields added to `/units` during 2026-08-25 that a restore must therefore carry:
`roaming` (`global|local`, on the unit), `lifecycle` (declared, currently unused — see
the handoff), and `condition` (`fault`, on a **fitment**).

⚠️ **`/mediaLoads` is a NODE OF ITS OWN and holds the entire media history** — one
record per load, and the only record that a given aircraft ever took a given cycle. It
was added on 2026-08-26 and, for a day, was **missing from every node list in these
scripts**: a restore would have dropped the whole history silently. Adding a node means
four edits — the rules, `backup.sh`, `restore.sh` and `verify-deployment.sh`. Check a
fresh snapshot lists it.

A fitment also gained **`roaming`** (v2.53.0), and its long-declared **`notes`** is now
in use: roaming and the SIM comment moved from the unit to the fitment so two periods of
service stay independent. A restore that carries units but drops fitment fields would
silently merge them back.

`/hardware` gained one the same day: **`rootCause`** on `issues/{id}` (v2.51.0), which
carries the engineering or DevOps explanation of why an issue happens. `/hardware` is a
small node, so it is easy to overlook in a partial restore — `--only aircraft,fleet`
would silently leave the known-issue register behind.

A snapshot taken before that write is at
`2026-08-25-before-issue-rootcause`.

### The one gap: `/editors`

`/editors` is readable only by the account it belongs to. That is the point — it
stops the allowlist being enumerable — but it also means an anonymous backup
cannot capture it. **Keep the editor uid list somewhere outside this repo**
(a password manager note is fine). To rebuild it:

```bash
npx --yes firebase-tools database:update /editors \
  --project saudia-fleet-dashboard --data '{"<uid>": true}'
```

uids come from Firebase Console → Authentication → Users.

---

## Backups

Snapshots contain the **entire operational dataset**. They are deliberately kept
out of this repository: it is public, and anything committed to git history is far
harder to walk back than a live database. `backups/` is gitignored.

**Take one before any bulk or destructive write.** That is not a formality: two
data operations on 2026-08-25 cleared 41 SIM installation dates and then backfilled
34 of them, and the snapshot taken first is the only thing that could have undone
either. Snapshots from that day:

| folder | taken before |
|---|---|
| `2026-08-25-before-sim-date-clear` | clearing all SIM `fittedDate` values |
| `2026-08-25-before-sim-install-backfill` | writing 34 install dates from activation dates |
| `2026-08-28-before-ota-patch` | writing `otaPatchUTC` to 40 aircraft |
| `2026-08-28-before-install-date-fix` | moving 6 `completionDate` values back one day |

⚠️ **Why six install dates moved on 2026-08-28.** AS56, AS62, AS63, AS64, ASI and ASR
each had a `completionDate` one day *after* their OTA patch, which cannot happen — the
patch follows the load. Every one of the six patches landed between 22:16 and 23:53
UTC, so the install had been recorded against the local day rather than the UTC one.
**The OTA stamp is the accurate record** (user, 2026-08-28), so the install date was
corrected to match, not the other way round. All six now read install and patch on the
same UTC day.

⚠️ **That change also moved the Modem tab**, because `MSP 5.2.2 Install Date` is
DERIVED from `completionDate` (`mspDate: a.completionDate`) rather than stored. That is
the single-source design working as intended — but it means a `completionDate` edit is
never local to the Software tab. Completion counts are unaffected: `isCompletedStrict`
reads version and location, never the date.

Take one locally at any time — no credentials needed, it reads the database
anonymously:

```bash
./scripts/backup.sh
```

Send it somewhere private with `FLEET_BACKUP_DIR`:

```bash
FLEET_BACKUP_DIR="$HOME/Documents/fleet-backups/$(date -u +%F)" ./scripts/backup.sh
```

Snapshots are ~60 KB, so a year of dailies is about 20 MB wherever they land.

### Automating it privately

A scheduled job needs somewhere private to write. In rough order of effort:

1. **A private GitHub repo.** Create one, add a fine-grained PAT with contents
   write on it as a secret in *this* repo, and have a workflow here push snapshots
   there. Keeps the free scheduling without publishing anything.
2. **A local cron job** on a machine that is reliably on:
   ```bash
   # crontab -e   — 02:15 daily, into a private folder
   15 2 * * * cd /Users/rizwanmujawar/Downloads/saudia-fleet-dashboard && \
     FLEET_BACKUP_DIR="$HOME/Documents/fleet-backups/$(date -u +\%F)" ./scripts/backup.sh
   ```
3. **After the move to private access** (below), anonymous reads stop working and
   the backup will need a service account instead. Plan that as part of the move,
   not after it.

> **Already public:** snapshots were briefly committed to this public repo on
> 2026-08-20 and removed the same day. They duplicated data the database was
> already serving publicly, so nothing was exposed that was not already reachable
> — but the commits remain in history until it is rewritten. See *Making this
> private* below.

---

## Restore

`restore.sh` is dry-run by default and will not write anything without `--apply`.

```bash
# 1. See what a restore would do — writes nothing
./scripts/restore.sh backups/2026-08-20

# 2. Do it. Prompts for the project id, and takes a safety
#    backup of the CURRENT state first, into its own folder.
./scripts/restore.sh backups/2026-08-20 --apply

# 3. Or just one node
./scripts/restore.sh backups/2026-08-20 --apply --only aircraft,fleet
```

It verifies every checksum in the manifest before it will proceed, so a corrupt
snapshot fails loudly instead of half-restoring.

Rules are **not** restored automatically — restoring data and silently changing
who can write it are different decisions. If the rules also need rolling back:

```bash
cp backups/<date>/database.rules.json database.rules.json
npx --yes firebase-tools deploy --only database --project saudia-fleet-dashboard
```

### "Someone deleted everything"

1. Don't panic and don't write anything — a fresh backup now would capture the
   damage. The nightly snapshot already holds yesterday's state.
2. `./scripts/restore.sh backups/<last good date>` and read the dry run.
3. `--apply` when the numbers look right.
4. Re-add editors if `/editors` was hit (above).
5. Confirm: the app should show **44 aircraft** and the tabs should populate. The
   4G SIM tab is the quickest sanity check that `/units` came back whole — it should
   list ~53 cards with their statuses, not an empty table. The **Media** tab checks
   `/mediaLoads`: its widget strip should show a card per cycle with a "N loaded" pill,
   not a single No Media card.

---

## Moving to another host or another Firebase project

The app is one static file with no build step, so hosting is trivial and the
only real work is the database.

### Different static host (Netlify, S3, nginx, anything)

Serve `index.html`. That is the whole deployment. Keep `.nojekyll` if you stay on
GitHub Pages; it is meaningless elsewhere.

### Different Firebase project

1. Create the project and a Realtime Database instance.
2. Point the app at it — **two constants, both near the top of the `<script>`**:

   ```js
   const FIREBASE_DB_URL  = 'https://<new-project>-default-rtdb.firebaseio.com';
   const FIREBASE_API_KEY = '<new web api key>';
   ```

   These are the only host-coupled values in the file. The auth endpoints
   (`identitytoolkit`, `securetoken`) are Google-wide and need no change.
3. Deploy the rules:
   ```bash
   npx --yes firebase-tools deploy --only database --project <new-project>
   ```
4. Load the data from a snapshot:
   ```bash
   FLEET_PROJECT=<new-project> ./scripts/restore.sh backups/<date> --apply
   ```
5. Enable Email/Password sign-in and add editor uids to `/editors`.
6. Verify enforcement — anonymous read of `/aircraft.json` should be `200`;
   anonymous write, and reads of `/editors.json` and root, should all be `401`.

Both scripts honour `FLEET_DB_URL` and `FLEET_PROJECT`, so they work against a
new project without editing them.

### Leaving Firebase entirely

The client only ever speaks REST: `GET/PUT/PATCH/DELETE` on `<base>/<path>.json`,
plus `EventSource` on the same URLs for live updates. Anything that serves that
shape can replace it. The pieces to reimplement are the per-path validation in
`database.rules.json` and the token exchange in `promptSignIn()` / `getIdToken()`.

---

## Making this private

**Gating the page does not gate the data.** The database is a separate origin with
its own URL, and that URL is in the page source. Put the site behind SSO but leave
`.read: true` and anyone who has ever seen the URL can still read everything with
`curl`. Private access means doing both halves.

### Half 1 — the database (the part that actually matters)

1. Change `.read` on every node from `true` to an auth check. Reuse `/editors`, or
   add a broader `/viewers` list if some people should read but not write.
2. **The app must sign in before it reads.** `connectLiveSync()` currently fires on
   page load with no token; it would have to run after authentication, behind a
   sign-in gate. This is the real work in the migration — not the rules change.
3. `EventSource` cannot set headers, but Firebase REST accepts `?auth=<idToken>` in
   the URL, so the live streams keep working. They must be re-established when the
   token refreshes.
4. `/visits` currently accepts anonymous writes. It either gains auth or goes.
5. **`scripts/backup.sh` stops working**, because it reads anonymously. It would
   need a service account. Sort this out *as part of* the migration — a period with
   no working backup is exactly the risk this document exists to avoid.

### Half 2 — the hosting

| Option | Private how | Cost | Notes |
|---|---|---|---|
| **Cloudflare Pages + Access** | SSO / email OTP in front of the whole site — the HTML itself is unreachable | Free ≤ 50 users | Strongest. Custom domain. No app changes. |
| **Firebase Hosting** | Page is public but shows only a login screen; privacy comes entirely from Half 1 | Free | Simplest, stays in one project |
| **Azure Static Web Apps** | Built-in auth on the route | Free tier | Heavier setup |

Recommended: **Cloudflare Access for the page + auth-required rules on the
database.** Either alone leaves a hole; together, an outsider cannot load the page,
and could not read the data even if they had the HTML.

### Prepared: moving to a new Firebase project

This is the chosen route. The tooling is built and rehearsed — when you are ready
it is one command plus a short list of console steps.

```bash
# 1. Console: create the project + a Realtime Database instance. Nothing else.
# 2. Rehearse — writes nothing, checks the target exists, shows the plan:
./scripts/migrate-project.sh <new-project-id>

# 3. Do it. Deploys rules, restores data, verifies enforcement.
./scripts/migrate-project.sh <new-project-id> --apply
```

Then the handful of things that cannot be scripted safely — enabling
Email/Password, creating accounts, adding the **new** uids to `/editors`, and
updating the two constants in `index.html`. The script prints them with the exact
commands filled in.

**Passwords are not carried across, deliberately.** `firebase auth:export` can move
hashes, but it also needs the source project's hash parameters from the console,
and moving password material around is worse than a reset when there are only a
few editors. Accounts are recreated; everyone sets a new password once.

**uids differ between projects.** `/editors` holds uids, so the old allowlist is
meaningless in a new project — it must be rebuilt from the new ones. Capture the
current mapping first, so you know who is supposed to be on it:

```bash
./scripts/backup-secrets.sh ~/Documents/fleet-backups/secrets
```

That writes the allowlist and an account list **without password material**, and
refuses to write anywhere inside this repo.

### Verifying any project

```bash
./scripts/verify-deployment.sh <project-id>     # defaults to the current one
```

For a full picture rather than just enforcement — release, git state, these checks,
the live-vs-local page hash, live record counts and the latest snapshot — use the
session-start script, which wraps this one and only ever reads:

```bash
./scripts/resume.sh
```

It is also the quickest way to confirm a snapshot exists and is verifiable
(manifest present) **before** doing anything destructive.

Checks reachability, record counts, and that enforcement holds — `/editors` and
root not anonymously readable, anonymous writes and unknown nodes rejected. It also
guards against the over-escaped-regex bug that once blocked every Software save, so
it is worth running after any rules change, not just after a migration.

### A clean-slate option worth considering

The current database URL is in public git history permanently. Standing up a **new
Firebase project** gives a URL that never was, and the move is cheap because the
scripts already take `FLEET_PROJECT`:

```bash
npx --yes firebase-tools deploy --only database --project <new-project>
FLEET_PROJECT=<new-project> ./scripts/restore.sh <snapshot> --apply
```

Then update the two constants in `index.html` and re-add editors. Full steps under
*Moving to another host or another Firebase project* above.
