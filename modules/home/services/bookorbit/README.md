# BookOrbit

Self-hosted reading platform (epub/pdf/cbz/audiobooks, Kobo + KOReader sync).
Upstream: <https://github.com/bookorbit/bookorbit>, docs at
<https://bookorbit.app>.

nix-podman-stacks has no BookOrbit stack, so this module declares the two
containers (`bookorbit`, `bookorbit-db`) itself on top of the nps podman
extension. Everything else — Traefik routing, the stack network, Glance and
Homepage entries, `extraEnv.*.fromFile` secret injection — comes from nps, and
the module is laid out like `nps/modules/grimmory` so it could be upstreamed
mostly as-is.

## One-time setup

Two steps have to happen in the web UI; neither can be expressed in Nix.

### 1. The setup wizard

The first admin account is created through `/auth/setup`, guarded by the
`SETUP_BOOTSTRAP_TOKEN` header. Read the token with:

```bash
ssh dafoltop -- sops -d ~/.config/dafos/secrets/daf/bookorbit.yaml
```

### 2. OIDC / SSO

BookOrbit stores its OIDC providers in the database, not in the environment, so
the Authelia side is declared here but the app side is filled in by hand under
**Settings → Admin → OIDC / SSO → Add Provider**:

| Field         | Value                                    |
| ------------- | ---------------------------------------- |
| Slug          | `authelia`                               |
| Issuer URI    | `https://auth.daftdaf.dev`               |
| Client ID     | `bookorbit`                              |
| Client secret | _(empty — this is a public PKCE client)_ |
| Scopes        | `openid profile email groups`            |

The redirect URI BookOrbit sends is `<serviceUrl>/oauth2-callback`, which is
what `oidc.registerClient` registers with Authelia. Access is gated on the
`bookorbit_user` LLDAP group by an Authelia authorization policy, because
BookOrbit itself will happily auto-provision any user the IdP hands it.

Group mappings (BookOrbit permissions ← `groups` claim) are re-synced on every
login; the "permissions for auto-provisioned users" list is applied once, at
account creation.

Only once an administrator account is actually linked to the provider is it safe
to set `disableLocalAuth = true`. BookOrbit refuses to start if that would lock
everyone out, and flipping it back off is the recovery path when Authelia is
unavailable.

## Notes

- The database image must ship `pgvector`; a stock `postgres` image is missing
  the `vector` extension the migrations need (`uuid-ossp` and `pg_trgm` too).
- `libraries` points at `/mnt/bookorbit/{books,livres}`, a **copy** of
  `/mnt/grimmory/{books,livres}` taken on 2026-09-06. Both apps write to their
  libraries — metadata write-back, kepubify conversions, file renaming — so
  sharing one tree has them undoing each other's work. The consequence is that
  the two copies drift: a book added to one is not in the other, and roughly 2
  GB is stored twice. Audiobooks are still shared, since `/mnt/audio` is the
  Freebox CIFS share and nothing here writes to it.
- The three `*-encryption-key` secrets protect credentials BookOrbit stores in
  its own database (SMTP, migration sources, download clients). They must exist
  before the first credential is saved — adding one later leaves what is already
  stored unreadable — so all three are provisioned up front.
- The app container runs `--read-only` with a tmpfs `/tmp`, matching upstream's
  compose file: everything it writes goes to the `/data` bind mount or to
  `$HOME`, which its entrypoint points at `/tmp`.
- Both containers carry `wants = [ "sops-nix.service" ]`. nps orders containers
  after nothing but their network, so on a _first_ start — the activation that
  also creates the secrets — `create-extra-files` can read
  `~/.config/sops-nix/secrets/bookorbit/*` before sops-nix has written it. The
  variable then comes out empty and postgres aborts initdb with "superuser
  password is not specified". This bit on the initial dafoltop deploy; the
  ordering edge is the fix. Every other nps stack that injects sops secrets has
  the same latent race, it just never loses it because those containers were
  already running before their secrets were rotated in.
