_: {
  ## The DMS flake package, shared by the home module, greeter and gamemode.
  ##
  #@ AttrSet -> Package
  mkDmsShell =
    pkgs: inputs:
    inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell.overrideAttrs (_: {
      # shortcut: upstream vendorHash lags its go.mod (stale at a05abaf and b3aac9b), drop once dux-shell keeps it current
      # On "hash mismatch ... dms-shell ... go-modules": paste the "got" hash here (see lib/AGENTS.md).
      vendorHash = "sha256-xbuXniDsdGZU41t34ar5tJvzK2LNgABwQJx5UIGSNkg=";
    });
}
