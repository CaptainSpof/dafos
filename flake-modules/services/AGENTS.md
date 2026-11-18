# Service aspects

Where new services are written: one aspect per file, NixOS
(`flake.modules.nixos.<name>`), Home Manager
(`flake.modules.homeManager.<name>`, most nps stacks) or both. Read
[../AGENTS.md](../AGENTS.md) for the aspect rules; the step-by-step for a new
app is the `dafos-add-service` skill.

- **Open with a header comment** in the existing shape:
  `# <App> (nps stack | local nps stack, modules/home/stacks/<name>): <what it
  does>, OIDC through Authelia, public | private.`
  then the host it runs on and anything that host implies. A cold reader learns
  the service from that line.
- **Options stay at `dafos.services.<name>`**, so a migrated module keeps its
  callers. A file-local `opt` helper is fine; `lib.dafos` is not.
- **An aspect reaches a host only when imported.** Legacy hosts (dafoltop,
  dafbox, daftop) through the `migrated` map in
  [../snowfall-compat.nix](../snowfall-compat.nix); dafpi and dafrelay through
  their `hosts/<host>/default.nix`. Each is then enabled per home or host.
- **Apps on dafpi depend on dafoltop**: their OIDC client and lldap group reach
  dafoltop's Authelia through [authelia-peers.nix](authelia-peers.nix), their
  route through `traefik.peers`, and an app whose issuer nps derives from a
  local Authelia restates it when Authelia is a peer's (`norish.nix`,
  `kaneo.nix`, `papra.nix`). A change here can need a dafoltop deploy too.
- **Routing** lives in [traefik.nix](traefik.nix): `redirects` for alias
  hostnames, `hostRoutes` for a host's native services, `nativeRouters` for
  dafoltop's hand-written ones. Never hand-write a router elsewhere.
- **Local stacks** (`modules/home/stacks/<name>`) are exposed as `<name>-stack`
  aspects by [local-stacks.nix](local-stacks.nix); only pure dendritic hosts
  import those.
- Non-module helpers of one service sit next to it with a `_` prefix
  (`litellm/_settings.nix`); longer rationale goes in a `README.md` beside the
  aspect ([backup](backup/README.md), [ollama](ollama/README.md)).
