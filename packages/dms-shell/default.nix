{
  inputs,
  pkgs,
  ...
}:

# DankMaterialShell's own flake package, with an upstream packaging bug worked
# around.
#
# Upstream's postInstall does `cp -r quickshell/. $out/share/quickshell/dms/`,
# and the repo keeps `quickshell/AGENTS.md` and `quickshell/CLAUDE.md` as
# symlinks to `../AGENTS.md` (the repo root). Copied into the output those
# resolve to `$out/share/quickshell/AGENTS.md`, which doesn't exist, so
# nixpkgs' `noBrokenSymlinks` fixup hook fails the build:
#
#   ERROR: noBrokenSymlinks: the symlink .../share/quickshell/dms/AGENTS.md
#   points to a missing target: .../share/quickshell/AGENTS.md
#
# They're agent docs with no runtime role, so just drop them. Delete this
# package (and the two `pkgs.dafos.dms-shell` references in
# modules/home/desktop/dms and modules/nixos/display-managers/dms-greeter) once
# upstream removes or dereferences them.
inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell.overrideAttrs
  (old: {
    postInstall = (old.postInstall or "") + ''
      rm -f $out/share/quickshell/dms/AGENTS.md $out/share/quickshell/dms/CLAUDE.md
    '';
  })
