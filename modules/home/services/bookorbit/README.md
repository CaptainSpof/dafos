# BookOrbit

Self-hosted reading platform (epub/pdf/cbz/audiobooks, Kobo + KOReader sync).
Upstream: <https://github.com/bookorbit/bookorbit>, docs at
<https://bookorbit.app>.

The containers come from the nix-podman-stacks `bookorbit` stack. This wrapper
adds sops secrets, the subdomain, and a set of overrides that keep the
deployment exactly as it was under the local stack dafos ran before nps shipped
one (removed 2026-10-04).

## Overrides on top of nps, and why

| Override                                                                                             | Why                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bookorbit-db` mounts `~/stacks/bookorbit/db` at `/var/lib/postgresql/data`, `PGDATA=…/pgdata`       | The cluster predates the nps stack, which mounts `~/stacks/bookorbit/postgres` at `/var/lib/postgresql`. Dropping this starts an empty database.       |
| `volumeMap.books` forced to `/mnt/bookorbit:/libraries`, plus `/audiobooks`, `LIBRARY_BROWSE_ROOT=/` | Library paths are stored in the database by container path; nps mounts a single tree at `/books`.                                                      |
| `EMAIL_` / `MIGRATION_` / `BOOK_REQUEST_ENCRYPTION_KEY`                                              | Encrypt credentials BookOrbit stores in its database. Removing one leaves what is stored unreadable.                                                   |
| `OIDC_ALLOW_LOCAL_ISSUERS=true`                                                                      | Authelia resolves to a LAN address from inside the container, which BookOrbit refuses by default.                                                      |
| OIDC client forced `public`, no secret; `offline_access` + refresh tokens; `groups` in the id_token  | The provider in BookOrbit's UI is configured as a public PKCE client. nps registers a confidential one, so `clientSecretHash` is an empty placeholder. |
| Book dock, `TRUST_PROXY`, read-only rootfs, `autoUpdate = "local"` on the db                         | Kept from the local stack.                                                                                                                             |

nps also creates an empty `bookorbit_admin` LLDAP group and registers the
`bookorbit://oauth2-callback` redirect for the mobile app; neither is used yet.

## One-time setup

Two steps happen in the web UI; neither can be expressed in Nix.

### 1. The setup wizard

The first admin account is created through `/auth/setup`, guarded by the
`SETUP_BOOTSTRAP_TOKEN` header. Read the token with:

```bash
ssh dafoltop -- sops -d ~/.config/dafos/secrets/dafoltop/bookorbit.yaml
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

Access is gated on the `bookorbit_user` LLDAP group by an Authelia authorization
policy, because BookOrbit itself will happily auto-provision any user the IdP
hands it.

Group mappings (BookOrbit permissions ← `groups` claim) are re-synced on every
login; the "permissions for auto-provisioned users" list is applied once, at
account creation.

`DISABLE_LOCAL_AUTH` stays `false`. Only once an administrator account is linked
to the provider is it safe to flip it; BookOrbit refuses to start if that would
lock everyone out, and flipping it back is the recovery path when Authelia is
down.

## Notes

- The database image must ship `pgvector`; a stock `postgres` image is missing
  the `vector` extension the migrations need (`uuid-ossp` and `pg_trgm` too).
- `/mnt/bookorbit/{books,livres}` is a **copy** of
  `/mnt/grimmory/{books,livres}` taken on 2026-09-06. Both apps write to their
  libraries — metadata write-back, kepubify conversions, file renaming — so
  sharing one tree has them undoing each other's work. The two copies drift.
  Audiobooks are shared (`/mnt/data/Audio/Audiobooks`), since nothing here
  writes to them.
- Both containers carry `wants = [ "sops-nix.service" ]`. On a _first_ start,
  `create-extra-files` can otherwise read the secrets before sops-nix has
  written them; postgres then aborts initdb with "superuser password is not
  specified". This bit on the initial dafoltop deploy.
