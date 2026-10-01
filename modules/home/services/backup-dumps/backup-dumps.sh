# Consistent dumps of every database the stack keeps, written to a staging
# directory that the system-level restic job backs up afterwards.
#
# - Postgres and MariaDB containers are found by image name, so a new database
#   container is covered without touching this file.
# - SQLite files are copied with the online backup API, never with cp, from
#   inside `podman unshare` so files owned by a container's uid are readable.
# - A failed item keeps yesterday's copy and the unit ends non-zero, so one
#   broken dump neither freezes the others nor goes unnoticed.

out="${STAGING_ROOT:-$HOME/backup-staging}"
new="$out/.new"
failed=0
dumped=()

rm -rf "$new"
mkdir -p "$out" "$new/postgres" "$new/mariadb" "$new/sqlite"
chmod 700 "$out" "$new"

fail() {
  echo "FAILED: $1" >&2
  failed=$((failed + 1))
}

# Keep the previous copy of one item when today's dump of it fails.
keep_previous() {
  if [ -e "$out/current/$1" ]; then
    cp -p "$out/current/$1" "$new/$1"
    echo "  kept the previous copy of $1" >&2
  fi
}

# --- Postgres and MariaDB, dumped inside their own container -----------------
while read -r name image; do
  case "$image" in
  *postgres* | *pgvector*)
    rel="postgres/$name.dump"
    echo "postgres: $name"
    dumped+=("$name")
    # shellcheck disable=SC2016  # the variables belong to the container's shell
    if podman exec "$name" sh -c 'pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-$POSTGRES_USER}" -Fc' \
      </dev/null >"$new/$rel.tmp" &&
      podman exec -i "$name" pg_restore --list <"$new/$rel.tmp" >/dev/null; then
      mv "$new/$rel.tmp" "$new/$rel"
    else
      rm -f "$new/$rel.tmp"
      fail "pg_dump $name"
      keep_previous "$rel"
    fi
    ;;
  *mariadb* | *mysql*)
    rel="mariadb/$name.sql"
    echo "mariadb: $name"
    dumped+=("$name")
    # shellcheck disable=SC2016
    if podman exec "$name" sh -c 'mariadb-dump --single-transaction -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' \
      </dev/null >"$new/$rel.tmp" &&
      tail -n 1 "$new/$rel.tmp" | grep -q 'Dump completed'; then
      mv "$new/$rel.tmp" "$new/$rel"
    else
      rm -f "$new/$rel.tmp"
      fail "mariadb-dump $name"
      keep_previous "$rel"
    fi
    ;;
  esac
done < <(podman ps --format '{{.Names}} {{.Image}}')

# --- SQLite ----------------------------------------------------------------
# exit codes of the inner script: 0 copied and verified, 3 not an SQLite file
# (skipped), anything else a failure.
# shellcheck disable=SC2016
sqlite_one='
  f="$1"; d="$2"
  [ "$(head -c 15 "$f")" = "SQLite format 3" ] || exit 3
  sqlite3 -cmd ".timeout 30000" "$f" ".backup \"$d\"" || exit 1
  [ "$(sqlite3 "$d" "PRAGMA integrity_check;")" = "ok" ] || exit 2
'

copied=0
: >"$new/sqlite/MANIFEST.txt"
for root in "$HOME/stacks" /mnt/calibre /mnt/grimmory /mnt/bookorbit; do
  [ -d "$root" ] || continue
  while IFS= read -r -d '' file; do
    safe="${file#/}"
    safe="${safe//\//__}"
    rel="sqlite/$safe"
    rc=0
    podman unshare sh -c "$sqlite_one" _ "$file" "$new/$rel" </dev/null || rc=$?
    case "$rc" in
    0)
      copied=$((copied + 1))
      echo "$safe <- $file" >>"$new/sqlite/MANIFEST.txt"
      ;;
    3) echo "  skipped (not SQLite): $file" >&2 ;;
    *)
      rm -f "$new/$rel"
      fail "sqlite backup $file (exit $rc)"
      keep_previous "$rel"
      ;;
    esac
  done < <(podman unshare find "$root" -type f \
    \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) \
    ! -name logs.db ! -path '*/booklore/*' ! -path '*/karakeep/*' \
    ! -path '*.bak/*' -print0)
done
echo "sqlite: $copied file(s) copied and verified"

# --- Coverage guard ---------------------------------------------------------
# Every database data directory under the stacks must sit under a mount of a
# container that was dumped above (or be the known stale booklore one). Anything
# else would only ever be backed up as raw files from under a running server, so
# fail loudly now rather than discover it on the day of a restore.
covered=()
for c in "${dumped[@]}"; do
  while read -r src; do
    # tmpfs and anonymous mounts have an empty source, and "" + /* would match
    # every path and silently disable this check.
    if [ -n "$src" ]; then covered+=("$src"); fi
  done < <(podman inspect "$c" --format '{{range .Mounts}}{{println .Source}}{{end}}')
done
while IFS= read -r -d '' marker; do
  dir="$(dirname "$marker")"
  ok=0
  for src in "${covered[@]}"; do
    case "$dir/" in "$src"/*) ok=1 ;; esac
  done
  case "$dir" in */booklore/*) ok=1 ;; esac
  [ "$ok" -eq 1 ] || fail "database data directory not covered by any dump: $dir"
done < <(podman unshare find "$HOME/stacks" -maxdepth 6 \( -name PG_VERSION -o -name ibdata1 \) -print0)

# --- Swap in the new set --------------------------------------------------
rm -rf "$out/previous"
[ -d "$out/current" ] && mv "$out/current" "$out/previous"
mv "$new" "$out/current"
rm -rf "$out/previous"

echo "done: $failed failure(s)"
[ "$failed" -eq 0 ]
