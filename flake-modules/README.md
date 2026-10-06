# flake-modules — dendritic migration (phase 1)

dafos is migrating from [Snowfall Lib](https://github.com/snowfallorg/lib) to
[flake-parts](https://flake.parts) +
[import-tree](https://github.com/vic/import-tree) following the
[dendritic pattern](https://github.com/mightyiam/dendritic).

`flake.nix` imports every `.nix` file in this directory via import-tree (paths
with a `_`-prefixed component are ignored). Current layout:

- `snowfall-compat.nix` — the single flake-parts module that reproduces every
  output Snowfall's `mkFlake` used to generate (nixosConfigurations, packages,
  devShells, checks, formatter, deploy, `pkgs`, `lib`).
- `_lib/` — the compat layer itself: channel instantiation, `lib.dafos` /
  `lib.snowfall` construction, the module wrapper that injects Snowfall's
  `namespace`/`format`/`host`/... args, and the home-manager embedding. Heavily
  commented; read it before touching anything Snowfall-shaped.
- `_compat/` — modules vendored from snowfall-lib and flake-utils-plus (MIT):
  the `snowfallorg.users` NixOS/HM options, FUP's registry/NIX_PATH options
  (`nix.generateRegistryFromInputs` & co., used by `modules/nixos/nix`), and
  `fup-repl` (wrapped by a home module in the common suite).

## Verification (2026-07-20)

Phase 1 was gated on `nix-diff` between the Snowfall-built and flake-parts-built
`system.build.toplevel` derivations for all three hosts. Result: dafbox,
dafoltop and daftop each differ in exactly the same 10 derivations, all
attributable to the input-set change itself (registry.json and `/etc/nix/inputs`
gain flake-parts/import-tree; sops manifest paths follow `self`'s changed store
hash). No functional drift. `virt` (`virtualboxConfigurations`) fails eval with
the same pre-existing `dafos.apps.firefox` error under both flakes.

## Phase 2 — how to migrate an aspect

New dendritic modules land as siblings of `snowfall-compat.nix`: one file per
aspect, defining `flake.modules.nixos.<aspect>` /
`flake.modules.homeManager.<aspect>` (or plain `perSystem` for packages), with
`${namespace}` replaced by the literal `dafos`. Hosts pick them up once
`snowfall-compat.nix`'s module lists reference `config.flake.modules.*`; until
then the legacy trees under `modules/`, `systems/`, `homes/`, `packages/`,
`overlays/`, `lib/`, `shells/` and `checks/` keep working unchanged through the
compat layer.

Phase 3 (cleanup) removes the `snowfall-lib` input (kept only to minimize the
registry diff), `_compat`/`_lib`, and the `namespace` indirection once nothing
uses them.
