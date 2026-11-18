---
name: dafos-add-service
description: Add a new self-hosted service to the dafos homelab. Use when asked to host, install or expose an app on dafoltop or dafpi, when wiring a service behind traefik or Authelia SSO, when a new container stack or NixOS service module needs creating, or when an existing service needs a domain, OIDC login or an lldap group.
---

# Adding a self-hosted service

Services run on `dafoltop` (the live house) or `dafpi` (lighter apps, relayed by
dafoltop's Traefik and served by its Authelia/lldap). Read
`systems/x86_64-linux/dafoltop/AGENTS.md` (or
`flake-modules/hosts/dafpi/AGENTS.md`) and `modules/home/services/AGENTS.md`
first: this skill is the ordered procedure, those hold the reasoning.

## 1. Decide where it lives

New modules are dendritic aspects in `flake-modules/`, never new directories in
`modules/` (see `modules/AGENTS.md`).

| Situation                               | Module                                                                                           |
| --------------------------------------- | ------------------------------------------------------------------------------------------------ |
| nix-podman-stacks has a stack           | `flake-modules/services/<name>.nix`, `flake.modules.homeManager.<name>` over `nps.stacks.<name>` |
| Container exists, nps does not cover it | stack in `modules/home/stacks/<name>` + wrapper aspect `flake-modules/services/<name>.nix`       |
| A maintained NixOS module exists        | `flake-modules/services/<name>.nix`, `flake.modules.nixos.<name>`                                |
| Neither; it is a plain program          | package in `packages/<name>`, NixOS aspect as above                                              |

Most of the fleet is the first row. The choice matters for OIDC (step 5).

## 2. Write the aspect

Follow `flake-modules/AGENTS.md`: plain `lib.mkOption` / `mkEnableOption`, no
`lib.dafos` helpers, no `namespace`. The option path stays
`dafos.services.<name>`. Worked example:
[flake-modules/services/norish.nix](../../../flake-modules/services/norish.nix)
(nps stack, sops secrets, OIDC, alias redirects, Authelia-peer fallback).

```nix
{ inputs, ... }:
{
  flake.modules.homeManager.<name> =
    { config, lib, ... }:
    let
      cfg = config.dafos.services.<name>;
    in
    {
      options.dafos.services.<name> = {
        enable = lib.mkEnableOption "<name>";
        subDomain = lib.mkOption { type = lib.types.str; default = "<name>"; description = "Subdomain under the traefik base url."; };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets."<name>/db-password".sopsFile = inputs.self + "/secrets/dafoltop/<name>.yaml";

        nps.stacks.<name> = {
          enable = true;
          db.passwordFile = config.sops.secrets."<name>/db-password".path;
          containers.<name> = {
            expose = true; # public; leave false for LAN/tailnet only
            traefik.subDomain = cfg.subDomain;
          };
        };
      };
    };
}
```

An image ahead of nps: `services.podman.containers.<name>.image = lib.mkForce …`
with the Kaneo task that drops it (rule in `modules/home/services/AGENTS.md`).
Pin images by digest only when upstream re-pushes tags, and say why.

A local stack (row two) follows `modules/home/stacks/AGENTS.md`, with
[bar-assistant](../../../flake-modules/services/bar-assistant.nix) as the worked
example. The stack takes secret _file_ options and never touches sops; the
wrapper aspect feeds it sops paths. Pin images as inline `image = "repo:tag";`
for Renovate, and ship a `vm-test.nix`; build that test before you commit.

## 3. Wire the aspect into its host

An aspect nobody imports evaluates and does nothing.

- **dafoltop** (and the other legacy hosts): add `"services/<name>" = <name>;`
  to the `migrated.home` (or `migrated.nixos`) map in
  [flake-modules/snowfall-compat.nix](../../../flake-modules/snowfall-compat.nix),
  under the comment
  `# New aspect, no legacy module behind it: the key only places it.`
- **dafpi**: add `<name>` to the `homeManager` (or `nixos`) imports in
  [flake-modules/hosts/dafpi/default.nix](../../../flake-modules/hosts/dafpi/default.nix),
  plus `<name>-stack` for a local stack (see
  `flake-modules/services/local-stacks.nix`).

## 4. Secrets

Create `secrets/dafoltop/<name>.yaml`. A dafpi service whose OIDC secret is
hashed on dafoltop needs its file readable by both hosts: add it to the shared
list in `.sops.yaml` (`secrets/AGENTS.md` names it). Use the `dafos-secrets`
skill for the mechanics; never create a file only the admin key opens.

## 5. Authelia SSO

**nps stack**: `nps.stacks.<name>.oidc` generates the client, policies and lldap
group. On dafpi that lands in a stack that is not running there;
`authelia-peers` on dafoltop picks it up from dafpi's config, nothing to copy.
The app usually needs its issuer restated when Authelia is a peer's: see the
`mkIf (!config.nps.stacks.authelia.enable)` block in `norish.nix`.

**Native NixOS service**: it cannot use that, since Authelia and lldap are
home-manager stacks. Register it by hand and keep both halves in sync:

- client, `claims_policies`, `authorization_policies` →
  `modules/home/services/authelia`
- group → `modules/home/services/lldap`
- app-side config → the NixOS aspect
- one shared `secrets/dafoltop/` entry, readable by the user _and_ the host key

`clients.home-assistant` (public + PKCE) and `clients.immich` (confidential) are
the worked examples. lldap: **one freeform custom attribute per user**.

## 6. Expose it

nps stacks get their router from their container labels (`expose`,
`traefik.subDomain`). Extra hostnames go through
`dafos.services.traefik.redirects.<alias> = { to = cfg.subDomain; expose = true; };`.

A native service of the host (not a container) is routed with
`dafos.services.traefik.hostRoutes.<subdomain> = { port = …; expose = …; };` in
the home of the host it runs on (example: `hostRoutes.gatus` in
`flake-modules/hosts/dafpi/default.nix`); its port must be open to the podman
networks. Both options live in
[flake-modules/services/traefik.nix](../../../flake-modules/services/traefik.nix).
A dafpi hostname is relayed by dafoltop's Traefik through `traefik.peers`.

## 7. Enable and verify

Turn it on with `dafos.services.<name>.enable = true;` in
`homes/x86_64-linux/daf@dafoltop/default.nix` (dafoltop) or in the
`home-manager.users.daf` block of `flake-modules/hosts/dafpi/default.nix`
(dafpi); a NixOS aspect is enabled in the host's own file. An image with an
embedded database is not picked up by `backup-dumps`; handle it before deploy.
Then follow `dafos-rebuild` and hand daf the deploy command.

Container that cannot resolve a hostname
(`dial tcp: lookup <host> on 10.89.x.1:53: i/o timeout`)? That is the
root-podman firewall issue, already fixed fleet-wide: see
[flake-modules/virtualisation/AGENTS.md](../../../flake-modules/virtualisation/AGENTS.md).
Rootless stacks are never affected by it, so look elsewhere.
