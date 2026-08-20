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
5. Confirm: the app should show 42 aircraft and the tabs should populate.

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
