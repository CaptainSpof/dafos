# ArtCraft Crafting Apps (storytold's photocraft, vectorcraft, …) through
# olafkfreund/nix-craftapps: fourteen pre-1.0 apps repackaged from upstream's
# release binaries. Chosen over Devitek/artcraft-nixos (13 apps, no MCP) and
# nixpkgs (5 apps, months behind) on 2026-11-05.
#
# Upstream's NixOS module is imported on every host and stays inert until
# programs.craftapps.enable; it also links /usr/share/fonts, the only place the
# apps' text tools look for fonts.
#
# The apps are winit, which ignores Wayland's tablet protocol: a pen does
# nothing natively (storytold/photocraft#7707). Through Xwayland
# (xwayland-satellite on niri) it draws, so the GUIs drop WAYLAND_DISPLAY.
{ inputs, ... }:
let
  src = inputs.nix-craftapps;
in
{
  flake.modules.nixos.craftapps =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dafos.programs.craftapps;
      upstream = import "${src}/default.nix" { inherit pkgs; };
      names = builtins.attrNames (lib.importJSON "${src}/apps.json");
      viaXwayland =
        name:
        upstream.${name}.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            wrapProgram $out/bin/${name} --unset WAYLAND_DISPLAY
          '';
        });
    in
    {
      imports = [ src.nixosModules.default ];

      options.dafos.programs.craftapps = {
        enable = lib.mkEnableOption "the ArtCraft Crafting Apps";
        xwayland = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run the GUIs through Xwayland, where graphics tablets work.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.craftapps = {
          enable = true;
          enableAll = lib.mkDefault true;
          apps = lib.mkIf cfg.xwayland (
            lib.genAttrs (builtins.filter (n: upstream ? ${n}) names) (name: {
              package = viaXwayland name;
            })
          );
        };
      };
    };
}
