# Bar Assistant — nps stack

Rootless [nix-podman-stacks](https://github.com/Tarow/nix-podman-stacks) port of
the old root-podman `dafos.services.bar-assistant` NixOS module (deleted in the
same change), upgraded from server `v5`/salt-rim `v4` to server `6.5.0`/salt-rim
`5.4.0`.

Four containers on the `bar-assistant` podman network, all also joined to
`traefik-proxy`:

| Container                   | Image                          | Traefik host             |
| --------------------------- | ------------------------------ | ------------------------ |
| `bar-assistant`             | `barassistant/server:6.5.0`    | `bar-api.daftdaf.dev`    |
| `bar-assistant-salt-rim`    | `barassistant/salt-rim:5.4.0`  | `bar.daftdaf.dev`        |
| `bar-assistant-meilisearch` | `getmeili/meilisearch:v1.50.0` | `bar-search.daftdaf.dev` |
| `bar-assistant-redis`       | `redis:8`                      | —                        |

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

The stack wants a _raw_ key file (no `KEY=` prefix), unlike the old module's two
env-formatted secrets. The Meilisearch index is rebuilt from SQLite anyway, so
just generate a fresh key:

```bash
sops set secrets/daf/bar-assistant.yaml '["bar-assistant"]["meili-master-key"]' "\"$(openssl rand -base64 32)\""
```

Run it where an age identity that can decrypt `secrets/daf/` is available. This
step is not optional: sops-nix validates the key at build time, so
`nixos-rebuild` fails with `the key 'bar-assistant' cannot be found` until it
exists.

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

Keep `/tmp/bar_data.tar` somewhere safe until the upgrade is confirmed good — v6
runs schema migrations that cannot be rolled back.

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

## Authelia SSO

`oidc.enable` registers a confidential OIDC client in Authelia and points the
server's first-class `authelia` Socialite driver at it. The flow:

1. Salt Rim's login page calls `GET /api/auth/sso/providers`; Authelia shows up
   as a button once `AUTHELIA_CLIENT_ID` is set.
2. Clicking it stores the provider in `sessionStorage` and sends the browser to
   `https://bar-api.daftdaf.dev/api/auth/sso/authelia/redirect`, which redirects
   to Authelia.
3. Authelia redirects back to **Salt Rim** at
   `https://bar.daftdaf.dev/oauth/callback` — that is the `redirect_uri`, not an
   API route.
4. Salt Rim hands the `code` to `GET /api/auth/sso/authelia/callback`, and the
   API exchanges it and reads `/api/oidc/userinfo` server-side.

Three things the client registration has to get right, all of them consequences
of Laravel Socialite driving the flow:

- **`token_endpoint_auth_method = "client_secret_post"`** — Socialite puts the
  credentials in the token request body; Authelia defaults to
  `client_secret_basic` and would reject them.
- **`require_pkce = false`** with an empty `pkce_challenge_method` — the
  controller calls `stateless()` and never generates a verifier.
- **`scopes` includes `groups`** — the driver asks for it, and Authelia rejects
  an authorization request for a scope the client isn't registered for.

No `claims_policy` is needed (unlike the Home Assistant client): the driver
reads the userinfo endpoint rather than the id_token.

### Account linking

`SSOService::findOrCreateCredential` looks up an existing local user **by
email** and attaches the oauth credential to it; only if no user has that email
does it register a new one. The LLDAP `daf` user and the existing Bar Assistant
account share `dafonseca.cedric@gmail.com`, so the first SSO login lands on the
existing account with its bars and recipes intact.

Bar Assistant itself has no group-based RBAC, so access is gated on the Authelia
side: the `bar-assistant` authorization policy denies by default and allows only
`group:bar-assistant_user`, which the dafos lldap module grants to `daf`.

### Enabling it

Add the client secret (nps hashes it for Authelia and passes the raw value to
the server):

```bash
cd ~/.config/dafos && sops set secrets/daf/bar-assistant.yaml '["bar-assistant"]["authelia"]["client-secret"]' "\"$(openssl rand -hex 32)\""
```

Then switch, and expect the same first-activation race as in Troubleshooting
below — a brand-new secret means the container may need one manual start.

`enablePasswordLogin = false` hides the email/password form and leaves only the
SSO button. Don't set it until an SSO login has actually worked: with no
password form and a broken OIDC client there is no way back in through the UI.
`oidc.redirectToSso = true` goes further and skips the login page entirely when
Authelia is the only provider.

## Notes

- v6 dropped the `Moderator` role (migrated to Admin) and replaced per-user
  shelves with per-member inventories; the UI for the latter is still being
  finished upstream. See the
  [v6.0.0 release notes](https://github.com/karlomikus/bar-assistant/releases/tag/v6.0.0).
- `allowRegistration` is `true` in the dafos wrapper to match the old
  deployment. All three hosts are `expose = true` (public Traefik middleware),
  so anyone who finds the domain can create an account — worth flipping to
  `false` once every account that needs one exists.
- Authelia SSO is wired up (see above). `enablePasswordLogin` is still `true`,
  so the password form remains as a fallback.

## Troubleshooting

**`podman-bar-assistant.service` dead with
`Job ... failed with result 'dependency'` right after the first switch.** On the
activation that _introduces_ a new sops secret, home-manager can start the
quadlets before `sops-nix.service` has materialised it. `create-extra-files`
then logs

    create-extra-files: line 34: /home/daf/.config/sops-nix/secrets/bar-assistant/meili-master-key: No such file or directory

and Meilisearch exits with
`The master key must be at least 16 bytes in a
production environment. The provided key is only 0 bytes.`
Meilisearch's own `Restart=always` recovers it seconds later, but
`bar-assistant` failed as a _dependency_ failure, which systemd does not retry.
Just start it:

```bash
systemctl --user start podman-bar-assistant podman-bar-assistant-salt-rim
```

This is a first-activation race only — the secret exists from then on, and no
other sops-consuming stack on dafoltop has hit it across a month of boots.
