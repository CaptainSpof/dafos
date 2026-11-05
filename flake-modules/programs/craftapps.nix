# ArtCraft Crafting Apps (storytold's photocraft, vectorcraft, …) through
# olafkfreund/nix-craftapps: fourteen pre-1.0 apps repackaged from upstream's
# release binaries. Chosen over Devitek/artcraft-nixos (13 apps, no MCP) and
# nixpkgs (5 apps, months behind) on 2026-11-05.
#
# Upstream's NixOS module is imported on every host and stays inert until
# programs.craftapps.enable; it also links /usr/share/fonts, the only place the
# apps' text tools look for fonts.
{ inputs, ... }:
{
  flake.modules.nixos.craftapps =
    { config, lib, ... }:
    let
      cfg = config.dafos.programs.craftapps;
    in
    {
      imports = [ inputs.nix-craftapps.nixosModules.default ];

      options.dafos.programs.craftapps.enable = lib.mkEnableOption "the ArtCraft Crafting Apps";

      config = lib.mkIf cfg.enable {
        programs.craftapps = {
          enable = true;
          enableAll = lib.mkDefault true;
        };
      };
    };
}
