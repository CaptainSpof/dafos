# flake-modules — the dendritic tree

dafos is migrating from [Snowfall Lib](https://github.com/snowfallorg/lib) to
[flake-parts](https://flake.parts) +
[import-tree](https://github.com/vic/import-tree) following the
[dendritic pattern](https://github.com/mightyiam/dendritic), with no extra
framework on top (den, unify, … were considered and declined: dafos is a
single-user fleet, and leaving Snowfall should not mean adopting another
framework).

`flake.nix` imports every `.nix` file under this directory via import-tree
(paths with a `_`-prefixed component are ignored). Every file is a
flake-parts module; most define one aspect.

## Layout

- `<category>/<name>.nix` — an aspect: `flake.modules.nixos.<name>` and/or
  `flake.modules.homeManager.<name>`, both sides of one feature in one file.
  Categories mirror the legacy `modules/` taxonomy (`services/`, `system/`,
  `security/`, `virtualisation/`, `hardware/`).
- `hosts/<host>/*.nix` — dendritic hosts. Each file contributes to
  `configurations.nixos.<host>.module`.
- `configurations.nix` — turns `configurations.nixos.*` into
  `nixosConfigurations`, adding the `base` aspect (disko, home-manager,
  sops-nix, FUP registry options, unfree) that legacy hosts get from the
  compat layer.
- `snowfall-compat.nix` + `_lib/` + `_compat/` — the compat layer that keeps
  the legacy trees (`modules/`, `systems/`, `homes/`, `packages/`,
  `overlays/`, `lib/`, `shells/`, `checks/`) evaluating as Snowfall did.

## Status

| Phase | State |
| --- | --- |
| 1. Compat layer replaces snowfall-lib | done (2026-10-06, replayed onto main) |
| 2. Aspects migrate out of `modules/` | in progress: nix, user, home, sops, openssh, tailscale, avahi, locale, time, networking, podman |
| 3. Hosts switch to `configurations.nixos`, compat layer removed | dafpi is native; dafbox, dafoltop, daftop still legacy |

## Migrating an aspect

1. Move the module into `flake-modules/<category>/<name>.nix` as
   `flake.modules.nixos.<name> = { config, lib, pkgs, ... }: { ... };`
   (and/or `homeManager`). Keep its `dafos.*` options: host files don't
   change, and the gate below stays clean.
2. Replace Snowfall-isms: `${namespace}` → `dafos`; `lib.dafos.mkOpt` &
   co. → `lib.mkOption`/`lib.mkEnableOption`; `lib.snowfall.fs.get-file
   "x"` → `inputs.self + "/x"`; the `host` arg → `config.networking.hostName`;
   `inputs` → the flake-parts `inputs` the file closes over.
3. Delete the legacy module and add it to `migrated` in
   `snowfall-compat.nix`, keyed by its old path under `modules/{nixos,home}`.
4. Gate: evaluate each legacy host's
   `config.system.build.toplevel.drvPath` before and after and `nix-diff`
   them. Only leaves that follow from the commit itself are allowed:
   `nixos-version` (configurationRevision), `etc-nix-registry.json` and
   sops `manifest.json` (self's store path).

Two compat details the gate depends on:

- Aspects are unwrapped to their defining modules before being slotted in
  (`unwrap-aspect`). A `flake.modules` value is three import levels deep and
  the module system collects imports breadth-first, so a wrapped aspect
  would land after every legacy module and reorder list options.
- Legacy sort keys strip `"${root}"`, not `toString root`: interpolating the
  modules root copies it to its own store path, and the keys must be
  relative for migrated aspects to sort into the same slot.

## Phase 1 verification (2026-07-20, re-run 2026-10-06)

`nix-diff` between the Snowfall-built and flake-parts-built toplevels on
dafbox, dafoltop and daftop: every difference traces to the input-set change
(registry and `/etc/nix/inputs` gain flake-parts/import-tree; sops manifests
follow `self`'s store path) or to configurationRevision.

`_compat/repl.nix` must stay byte-identical to flake-utils-plus' copy (it is
excluded from treefmt for that reason): its store path ends up in every
system closure through fup-repl.

## Phase 3 (cleanup)

Remove the `snowfall-lib` input (kept only to minimize the registry diff),
`_compat`/`_lib`, the `namespace` indirection and the `migrated` map; switch
`dafos.*.enable` options to import-based composition where an option no
longer has a reason to exist; rename `flake-modules/` to `modules/`.
