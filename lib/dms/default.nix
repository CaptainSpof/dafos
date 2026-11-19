_: {
  ## The DMS flake package, shared by the home module, greeter and gamemode.
  ##
  #@ AttrSet -> Package
  mkDmsShell =
    pkgs: inputs: inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
}
