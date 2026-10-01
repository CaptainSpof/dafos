# Backups (restic)

Nightly, encrypted, to the Samsung 1 TB in the dock's second bay (`/mnt/backup`).
Two stages, because the databases live in rootless containers and the state
directories are root-only:

| When  | What | Owner |
| ----- | ---- | ----- |
| 03:00 | `backup-dumps` (user timer): `pg_dump`, `mariadb-dump`, `sqlite3 .backup` into `~/backup-staging/current` | [home module](../../../home/services/backup-dumps/default.nix) |
| 03:30 | `restic-backups-local` (root): Immich `pg_dump`, then the paths in [default.nix](default.nix) | this module |

Retention 7 daily, 4 weekly, 6 monthly; every run also reads back 2 % of the
repository (`restic check --read-data-subset=2%`). A failed run alerts through
Home Assistant (`alert-failure@`).

## What is deliberately not backed up

The 600 GB of media on `/mnt/data` (re-acquirable), container images, ollama
models, Immich `thumbs/` and `encoded-video/`, Home Assistant's recorder database
(history only), caches. Stale directories (`~/stacks/booklore`, `karakeep`,
`qui.bak`) are excluded by name.

## Rules that are easy to break

- **Embedded databases are special-cased, and a guard catches new ones.** Dispatcharr is
  an all-in-one image with its own Postgres 17, so image-name matching cannot find it; it has
  its own case in `backup-dumps.sh`. After the dumps, the script scans `~/stacks` for any
  Postgres or MariaDB data directory (`PG_VERSION`, `ibdata1`) that is not under a dumped
  container's mount and fails the job if it finds one. That guard was proven to fire by
  planting a fake data directory (see the git history for the bug that first disabled it:
  tmpfs mounts have an empty source, and `"" + /*` matches every path).
- **A stale or failing dump never stops the file backup**, but it alerts. Postgres
  and MariaDB data directories are excluded from restic; their dumps are the
  backup of record. A new database container is picked up by image name.
- **The job requires the mount** (`RequiresMountsFor`). Without it, restic would
  initialise a repository on the NVMe root under an empty `/mnt/backup`.
- **Never hot-add or hot-remove a drive in the dock** while the other is in use;
  it drops the dock (see `systems/x86_64-linux/dafoltop`).
- The password is generated once and lives only in
  `secrets/dafoltop/restic.yaml`. **Keep a copy outside this host**
  (`sops -d --extract '["restic"]["password"]' secrets/dafoltop/restic.yaml`).

## Look at it

```bash
sudo systemctl start backup-dumps   # as the user: systemctl --user start backup-dumps
sudo systemctl start restic-backups-local
sudo restic-local snapshots         # wrapper with the repository and password set
sudo restic-local check
```

## Restore

```bash
# files into a scratch directory, then compare or copy back
sudo restic-local restore latest --target /tmp/restore --include /home/daf/stacks/lldap

# a Postgres app: start an empty container of the same image, then
podman exec -i <empty-db> pg_restore -U <user> -d <db> --clean --if-exists < postgres/<name>.dump

# MariaDB
podman exec -i grimmory-db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' < mariadb/grimmory-db.sql

# SQLite: sqlite/MANIFEST.txt maps each dumped file back to its original path
```

On a rebuilt host, restore `/etc/ssh/ssh_host_*` and `~/.ssh/daf@dafoltop.pem`
**first**, or the system secrets (including this repository's password, which
dafbox can still decrypt) stop decrypting: see
[secrets/AGENTS.md](../../../../secrets/AGENTS.md).
