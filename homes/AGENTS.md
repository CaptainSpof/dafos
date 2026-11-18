# Home configurations

`homes/x86_64-linux/daf@<host>/default.nix` is daf's Home Manager config on a
legacy host (dafbox, dafoltop, daftop), loaded by the Snowfall compat layer.
dafpi and dafrelay have no directory here: their home is the
`home-manager.users.daf` block of `flake-modules/hosts/<host>/default.nix`.

A home owns the per-user, per-host choices; reusable behaviour belongs in
`modules/home/` or a `flake-modules/` aspect (see
[../modules/AGENTS.md](../modules/AGENTS.md)).

- **What lives here**: the home suites (`dafos.suites.*`), toggling a
  `dafos.services.*` or `dafos.programs.*` module on this host, and host layout
  data: DMS bars, sidebar, display names
  ([../modules/home/desktop/dms/AGENTS.md](../modules/home/desktop/dms/AGENTS.md),
  "Bars"), the Niri screencast output, `dms-widget-positions.json`.
- **Enabling a service on dafoltop** is one line in `daf@dafoltop/default.nix`;
  the service itself is written as described in
  [../flake-modules/services/AGENTS.md](../flake-modules/services/AGENTS.md).
- **dafoltop's home turns the desktop off** with `mkForce` (Niri, DMS,
  dankcalendar, vicinae, espanso): a desktop module enabled by a suite stays off
  there, so check this file before assuming it runs on the server.
- **`dms-widget-positions.json` is generated**: `dms-save-widget-positions`
  writes it from the live session. Never edit it by hand.
- To know what a home actually enables, evaluate it rather than reading the
  file. The flake has no `homeConfigurations`; a home is reached through its
  host:
  `nix eval '.#nixosConfigurations.<host>.config.home-manager.users.daf.dafos.<path>' --json`
  (`dafos-rebuild` skill).
