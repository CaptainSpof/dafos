---
name: dafos-add-service
description: Add a new self-hosted service to the dafos homelab. Use when asked to host, install or expose an app on dafoltop, when wiring a service behind traefik or Authelia SSO, when a new container stack or NixOS service module needs creating, or when an existing service needs a domain, OIDC login or an lldap group.
---

# Adding a self-hosted service

Everything self-hosted lands on `dafoltop`. Read
`systems/x86_64-linux/dafoltop/AGENTS.md` and `modules/home/services/AGENTS.md`
first — this skill is the ordered procedure, those hold the reasoning.

## 1. Decide where it lives

| Situation                               | Where                                                        | Shape                               |
| --------------------------------------- | ------------------------------------------------------------ | ----------------------------------- |
| nix-podman-stacks has a stack           | `modules/home/services/<name>`                               | `nps.stacks.<name>`                 |
| Container exists, nps does not cover it | `modules/home/services/<name>`                               | `services.podman.containers.<name>` |
| A maintained NixOS module exists        | `modules/nixos/services/<name>`                              | upstream options                    |
| Neither; it is a plain program          | package in `packages/`, service in `modules/nixos/services/` | systemd unit                        |

Most of the fleet is the first row. The choice matters for OIDC — see step 4.

## 2. Write the module

Follow the shape in `modules/AGENTS.md`. A stack module looks like
[modules/home/services/norish/default.nix](../../../modules/home/services/norish/default.nix):

```nix
{ lib, config, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;
  cfg = config.${namespace}.services.<name>;
in
{
  options.${namespace}.services.<name> = {
    enable = mkEnableOption "Whether or not to configure <name>.";
    subDomain = mkOpt types.str "<name>" "Subdomain under the traefik base url.";
  };

  config = mkIf cfg.enable {
    sops.secrets."<name>/db-password".sopsFile =
      lib.snowfall.fs.get-file "secrets/daf/<name>.yaml";

    nps.stacks.<name> = {
      enable = true;
      # ...
    };
  };
}
```

Pin container images by digest when upstream is known to re-push tags, and say
why in a comment — the norish module is the reference for how much detail that
deserves.

## 3. Secrets

Create `secrets/daf/<name>.yaml` and reference it with
`lib.snowfall.fs.get-file`. Use the `dafos-secrets` skill for the mechanics and
for which key group applies.

## 4. Authelia SSO

**If the service is an nps stack**, use `nps.stacks.<name>.oidc` and let it
generate the client.

**If the service is a native NixOS service, it cannot use that** — authelia and
lldap are home-manager stacks, so there is nothing for the NixOS module to hook
into. Register it by hand, keeping both halves in sync:

- client, `claims_policies` and `authorization_policies` →
  `modules/home/services/authelia`
- group → `modules/home/services/lldap`
- app-side config → `modules/nixos/services/<name>`
- one shared secrets entry in `secrets/daf/`, decryptable by both the user key
  and the host key

`clients.home-assistant` (public + PKCE) and `clients.immich` (confidential,
mirroring what `nps.stacks.immich.oidc` would generate) are the two worked
examples in the authelia module.

lldap caveat: **one freeform custom attribute per user**. A second one errors
with "defined multiple times".

## 5. Expose it

Add a router to `modules/home/services/traefik`:

```nix
dynamicConfig.http.routers.<name>-nix = {
  rule = "Host(`${cfg.subDomain}.${base-url}`)";
  service = "<name>-service";
  entryPoints = [ "websecure" ];
  middlewares = [ "public@file" ];      # or the authelia middleware
  tls.certResolver = "letsencrypt";
};
```

nps stacks usually get their router from the stack itself; the `-nix` suffixed
routers exist for native NixOS services traefik cannot discover.

## 6. Enable and verify

Turn it on in `homes/x86_64-linux/daf@dafoltop/default.nix` (or the host file
for a NixOS service), then follow `dafos-rebuild`.

Container that cannot resolve a hostname
(`dial tcp: lookup <host> on 10.89.x.1:53: i/o
timeout`)? That is the
root-podman firewall issue, already fixed fleet-wide — see
`modules/nixos/virtualisation/podman/AGENTS.md`. Rootless stacks are never
affected by it, so look elsewhere.
