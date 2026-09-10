# Self-hosted services (home-manager)

Most of the homelab runs here as
[nix-podman-stacks](https://github.com/tarow/nix-podman-stacks) stacks in daf's
_home-manager_ config, not as NixOS services. That single fact drives most of
the rules below. Everything in this directory lands on `dafoltop` — read
[../../../systems/x86_64-linux/dafoltop/AGENTS.md](../../../systems/x86_64-linux/dafoltop/AGENTS.md)
before deploying.

## Choosing where a service lives

| Situation                                      | Where                                                |
| ---------------------------------------------- | ---------------------------------------------------- |
| Upstream ships a container and nps has a stack | nps stack here                                       |
| Upstream has a maintained NixOS module         | `modules/nixos/services/<name>`                      |
| Neither, and it is a plain program             | package it in `packages/`, run it as a NixOS service |

## OIDC: native NixOS services must be wired by hand

Authelia and lldap are nps stacks in home-manager, so a service that runs as a
**NixOS** service cannot be registered through `nps.stacks.<name>.oidc`. Home
Assistant and Immich are registered manually instead, and the two halves must
stay in sync:

- client, claims/authorization policies and lldap groups → [authelia](authelia)
  and [lldap](lldap)
- app-side config → `modules/nixos/services/<name>`
- both halves read the same `secrets/daf/*.yaml` entry, which therefore has to
  be decryptable by the user key _and_ the host key.

For Immich the module mirrors what `nps.stacks.immich.oidc` would have
generated: a custom `immich` scope, `immich_role` / `immich_quota` claims, and
`immich_{admin,user}` groups. Its client secret reaches immich through
`settings.oauth.clientSecret._secret` — systemd `LoadCredential`, never the nix
store.

## lldap

- **One freeform custom attribute per user.** Declaring a second errors with
  "defined multiple times"; use the declared options for everything else.
- Avatars need two forms: a blob for the lldap UI, and a URL for Authelia's
  `picture` claim. The URL is served by a small nginx container at
  `avatars.daftdaf.dev`.

## Secrets

A stack reads `secrets/daf/*.yaml`. Prefer systemd `LoadCredential` over reading
`/run/secrets` directly, which is what lets a unit keep `DynamicUser`. See
[../../../secrets/AGENTS.md](../../../secrets/AGENTS.md).

## Known upstream noise

`Obsolete option nps.stacks.ittools` appears on every dafbox and daftop build.
It comes from nix-podman-stacks, not from dafos, and cannot be fixed here.

## Adding one

Use the `dafos-add-service` skill (`.claude/skills/dafos-add-service`).
