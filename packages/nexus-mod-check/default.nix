{ writeShellScriptBin, ... }:

# shortcut: thin alias kept while daf@dafbox still lists this package; the
# check now lives in `modctl check DIR --game DOMAIN` (same arguments),
# installed by dafos.programs.modctl (flake-modules/programs/modctl.nix).
writeShellScriptBin "nexus-mod-check" ''exec modctl check "$@"''
