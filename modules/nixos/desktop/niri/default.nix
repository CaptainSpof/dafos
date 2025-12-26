{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.desktop.niri;
in
{
  options.${namespace}.desktop.niri = {
    enable = mkBoolOpt true "Whether or not to use niri as the desktop environment.";
  };

  config = mkIf cfg.enable {

    environment.etc."xdg/menus/plasma-applications.menu".source =
      "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
    
    programs = {
      niri = {
        enable = true;
        package = pkgs.niri-unstable;
      };
      kdeconnect.enable = true;
    };
  };
}
