# flake-modules

Dendritic tree (flake-parts + import-tree). Read [README.md](README.md)
before migrating anything.

- Every `.nix` file here is a flake-parts module, imported automatically;
  `_`-prefixed paths are not. Non-module helpers go under `_lib/` or
  `_assets/`.
- New aspects: `flake.modules.{nixos,homeManager}.<name>`, both sides of a
  feature in one file, plain `lib.mkOption` (no `lib.dafos` helpers, no
  `namespace`, no Snowfall special args).
- Migrating a legacy module: follow the README recipe, including the
  `migrated` map and the nix-diff gate on dafbox, dafoltop and daftop.
- Never reformat `_compat/repl.nix` (treefmt excludes it).
- An aspect shared with legacy hosts must not import upstream modules the
  compat layer already injects (home-manager, sops-nix, disko, …); pure
  hosts get those from the `base` aspect in `configurations.nix`.
