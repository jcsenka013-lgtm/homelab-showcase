# Backups and restore

Designed so a dead disk, a bad deploy, or a lost server does not mean lost
passwords, documents, or photo indexes. Media originals on a separate NAS are
covered by that NAS's own redundancy plus an optional second copy of the photo
tree onto local pool storage.

## What is backed up

| Item | How | Retention (example) |
|---|---|---|
| Immich Postgres | `pg_dumpall` → `immich/immich-YYYY-MM-DD.sql.gz` on `/srv/backup` | 14 days |
| `/DATA/AppData` | Hard-linked rsync snapshot under `/srv/backup/snapshots/<date>/AppData` (excludes regenerable caches and raw Postgres data dirs) | 14 days |
| `/opt/stacks` (including `.env`) | Same snapshot tree under `…/stacks` | 14 days |
| SQLite DBs inside AppData | After rsync, each `.db` / `.sqlite*` is re-copied with SQLite's backup API so mid-write files are consistent | with snapshot |
| Photo originals (optional) | rsync from NAS photo root → local pool, with `--backup-dir` for deletes | 60 days of deleted/changed |
| Off-box copy | Today's snapshot + Immich dump pushed to a second host | 60 days (pruned on the receiver) |

Media thumbs / encoded video that Immich can regenerate are skipped.

## How it runs

1. `scripts/server-prep backup` installs `server-backup` plus a systemd timer
   (default: ~03:30 with a small random delay).
2. `scripts/server-backup` refuses to run if `/srv/backup` is not a mount
   (avoids filling the root filesystem).
3. Failures trip `OnFailure=notify-failure@%n.service`, which pushes the last
   journal lines to ntfy.
4. Off-box push uses a dedicated SSH key limited with `rrsync -wo -no-del`:
   the server can add files but cannot read or delete what is already there.
   The off-box host prunes old copies itself.

Prepare the receiver with `scripts/offbox-setup` after the backup key exists
at `/etc/server-backup/offbox.pub`.

## Restore test (generic procedure)

Run this after any major change, and at least once after first setup. Record
the date you last tested.

### 1. Immich database

```bash
# Stop Immich, restore dump into a throwaway Postgres, or restore into place
# after renaming the live pgdata directory.
gunzip -c /srv/backup/immich/immich-YYYY-MM-DD.sql.gz \
  | docker exec -i immich_postgres psql -U postgres
# Start Immich; confirm library count and a recent upload.
```

### 2. AppData snapshot (Paperless / Vaultwarden / ntfy / …)

```bash
# Example: restore Vaultwarden data from yesterday's snapshot into a temp dir
# and point a one-off compose override at it; unlock with a known vault item.
SNAP=/srv/backup/snapshots/YYYY-MM-DD/AppData/vaultwarden
# … verify login, then tear down the test.
```

### 3. Off-box copy

From a third machine (not the server), confirm the off-box host still has
`snapshots/<date>/` and `immich/*.sql.gz`, and that the server key cannot
`rm` or `cat` arbitrary files under the offbox home (rrsync restrictions).

### 4. Full server loss drill (tabletop or spare disk)

1. Install Ubuntu, Docker, and copy `/opt/stacks` from the off-box snapshot.
2. Restore `/DATA/AppData` from the snapshot; restore Immich SQL into fresh Postgres.
3. Remount NAS paths; bring stacks up; verify Vaultwarden unlock and Immich library.

## What this does *not* claim

- Continuous replication / zero RPO
- Immutable object-lock / ransomware-proof storage (off-box is write-only from
  the server, which raises the bar but is not a WORM vault)
- Backup of every NAS share — only the photo tree called out above, unless you
  extend the script
