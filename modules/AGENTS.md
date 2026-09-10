# Reusable modules

## Wrapper shape

```nix
{ config, lib, namespace, ... }:
let
  inherit (lib.${namespace}) mkBoolOpt enabled;
  cfg = config.${namespace}.category.name;
in
{
  options.${namespace}.category.name = {
    enable = mkBoolOpt false "Whether or not to enable <name>.";
  };

  config = lib.mkIf cfg.enable {
    # implementation
  };
}
```

- Take `namespace` from the module arguments rather than hardcoding `dafos`;
  Snowfall passes it.
- Keep `cfg` aligned with the option path the module owns, and keep that path
  aligned with the directory taxonomy
  (`modules/home/programs/terminal/tools/<name>` →
  `dafos.programs.terminal.tools.<name>`).
- Check `lib.dafos.*` before writing a local helper. See
  [../lib/AGENTS.md](../lib/AGENTS.md).

## Option ownership

- Add a `dafos.*` wrapper option when the behaviour has to vary across hosts or
  users, or needs an explicit toggle. Configure upstream NixOS or Home Manager
  options directly when there is no repository-level choice to make — do not
  wrap for visual consistency.
- Emit only intentional deltas from the pinned upstream default. Check that
  default before adding a setting.
- Fixed repository policy belongs in a local `let` binding, not an option nobody
  will flip.

## Composition

`archetypes` turn on `suites`; `suites` turn on `services`/`programs`/`apps`.
Host and home files mostly toggle suites and override specifics with
`lib.mkForce`. When answering "is X enabled on host Y", follow that chain — the
host file alone will not tell you.

## File layout

Roughly 200 lines, or two independently owned programs in one file, is a signal
to split. Keep `default.nix` as the owner/router and move cohesive pieces into
named siblings — `shells/` and the DMS submodules already do this.
