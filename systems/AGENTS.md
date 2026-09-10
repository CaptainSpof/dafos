# Host configurations

`systems/<arch>/<host>/default.nix` owns hardware facts, hostname and network
identity, boot configuration, archetype selection, and host-only overrides.
Anything reusable belongs in `modules/`. Generated hardware output stays in the
host's `hardware.nix`; where a host uses disko, the filesystem declarations live
in its `disko.nix` and `hardware.nix` must not also declare them.

```nix
let
  inherit (lib.dafos) enabled;
in
{
  dafos = {
    archetypes.workstation = enabled;
    services.ollama.enable = true; # host-only override
  };
}
```

## stateVersion

`system.stateVersion` is migration state, not a release marker. It is set when
the host is first built and changed only with an explicit migration plan.

## Validation

```bash
nix build '.#nixosConfigurations.<host>.config.system.build.toplevel'
```

Build the host you changed; do not evaluate the whole fleet by default. The
`dafos-rebuild` skill covers deploy-rs and closure diffing.

## Per-host guidance

- [x86_64-linux/dafbox/AGENTS.md](x86_64-linux/dafbox/AGENTS.md)
- [x86_64-linux/dafoltop/AGENTS.md](x86_64-linux/dafoltop/AGENTS.md)
