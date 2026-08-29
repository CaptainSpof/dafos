# Bar Assistant — nps stack

Rootless [nix-podman-stacks](https://github.com/Tarow/nix-podman-stacks) port of the
old root-podman `dafos.services.bar-assistant` NixOS module (deleted in the same
change), upgraded from server `v5`/salt-rim `v4` to server `6.5.0`/salt-rim `5.4.0`.

Four containers on the `bar-assistant` podman network, all also joined to
`traefik-proxy`:

| Container | Image | Traefik host |
|---|---|---|
| `bar-assistant` | `barassistant/server:6.5.0` | `bar-api.daftdaf.dev` |
| `bar-assistant-salt-rim` | `barassistant/salt-rim:5.4.0` | `bar.daftdaf.dev` |
| `bar-assistant-meilisearch` | `getmeili/meilisearch:v1.50.0` | `bar-search.daftdaf.dev` |
| `bar-assistant-redis` | `redis:8` | — |

Salt Rim is a static SPA: the browser calls `API_URL + /api` and talks to
Meilisearch directly, so **all three** HTTP services must be reachable from
wherever the client runs. That replaces the old single-host path-based split
(`/`, `/bar/`, `/search/`) that `nginx.conf.old` documented.

The server runs as `www-data` = `33:33` (the `serversideup/php:8.4-fpm-nginx`
base is Debian), hence `UserNS=keep-id:uid=33,gid=33` so the bind-mounted
storage directory owned by `daf` stays writable.

## Data layout

    ~/stacks/bar-assistant/data          → /var/www/cocktails/storage/bar-assistant
                                           (database.ba3.sqlite, uploads/, backups/)
    ~/stacks/bar-assistant/meilisearch   → /meili_data (derived index, rebuildable)

## One-time migration from the old root-podman deployment

The old module stored everything in **root** podman named volumes
(`bar-assistant_bar_data`, `bar-assistant_meilisearch_data`). Those need to be
copied into `~/stacks/bar-assistant` and re-owned before the first switch.

### 1. Add the Meilisearch master key secret

The stack wants a *raw* key file (no `KEY=` prefix), unlike the old module's two
env-formatted secrets. The Meilisearch index is rebuilt from SQLite anyway, so
just generate a fresh key:

```bash
sops set secrets/daf/bar-assistant.yaml '["bar-assistant"]["meili-master-key"]' "\"$(openssl rand -base64 32)\""
```

Run it where an age identity that can decrypt `secrets/daf/` is available. This
step is not optional: sops-nix validates the key at build time, so
`nixos-rebuild` fails with `the key 'bar-assistant' cannot be found` until it exists.

The stale `meilisearch-key-env` / `meilisearch-master-key-env` entries in that
file are unused after this change and can be dropped.

### 2. Back up and copy the API storage (on dafoltop)

Confirm the old volume is still there:

```bash
sudo podman volume ls | grep bar-assistant
```

Then export it and unpack it as `daf` (a non-root `tar -x` writes the files as
`daf`, which is what `UserNS=keep-id:uid=33` expects):

```bash
sudo podman volume export bar-assistant_bar_data -o /tmp/bar_data.tar
sudo chown daf:users /tmp/bar_data.tar
mkdir -p ~/stacks/bar-assistant/data
tar -xf /tmp/bar_data.tar -C ~/stacks/bar-assistant/data
ls -l ~/stacks/bar-assistant/data/database.ba3.sqlite
```

Keep `/tmp/bar_data.tar` somewhere safe until the upgrade is confirmed good —
v6 runs schema migrations that cannot be rolled back.

**Do not copy `bar-assistant_meilisearch_data`.** Meilisearch 1.15 → 1.50 would
need `--experimental-dumpless-upgrade`, and the index is derived data: step 5
rebuilds it.

### 3. Switch

```bash
sudo nixos-rebuild switch --flake .#dafoltop
```

`bar-assistant`'s entrypoint runs `php artisan migrate --force` on every start.
All historical migrations back to the v2 era are still present in the v6.5.0
tree, so the jump straight from a 5.x database is fine — no intermediate 5.15.x
hop is needed, despite what the upstream "be on latest v5" prerequisite implies.

### 4. Watch the first start

```bash
journalctl --user -u podman-bar-assistant -f
```

Expect `migrate` output, `starter-media:publish`, then
`Setting up bar search tokens...` / `Meilisearch setup done!` — the latter
rewrites each bar's scoped search token, which is exactly what makes the fresh
Meilisearch instance work with the restored database.

### 5. Rebuild the search index

```bash
podman exec bar-assistant php artisan bar:refresh-search --clear
```

Until this runs, search and cocktail-availability filters come back empty.

### 6. Verify

- `https://bar.daftdaf.dev` loads and logs in with the existing account
- cocktails, ingredients, images and menus are all there
- search returns results

## Notes

- v6 dropped the `Moderator` role (migrated to Admin) and replaced per-user
  shelves with per-member inventories; the UI for the latter is still being
  finished upstream. See the [v6.0.0 release notes](https://github.com/karlomikus/bar-assistant/releases/tag/v6.0.0).
- `allowRegistration` is `true` in the dafos wrapper to match the old
  deployment. All three hosts are `expose = true` (public Traefik middleware),
  so anyone who finds the domain can create an account — worth flipping to
  `false` once every account that needs one exists.
- v6 gained a generic OIDC provider, so the stack could be wired to Authelia
  like `norish`/`reactive-resume` are. Not done here: it would change how
  existing accounts log in.
