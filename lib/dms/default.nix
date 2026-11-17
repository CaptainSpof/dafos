_:
{
  ## The DMS flake package, shared by the home module, greeter and gamemode.
  ##
  #@ AttrSet -> Package
  mkDmsShell =
    pkgs: inputs:
    inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell.overrideAttrs (_: {
      # shortcut: upstream vendorHash stale at a05abaf, drop once dux-shell fixes it
      vendorHash = "sha256-DinkXtyVURJ5I00B+j/otCcjm2MD9B0vessdqwd8zoU=";
    });
}
