{ config, lib, pkgs, ... }:

with lib;
with lib.dafos;
let
  cfg = config.dafos.apps.steam;
in
{
  options.dafos.apps.steam = with types; {
    enable = mkBoolOpt false "Whether or not to enable support for Steam.";
    uiScaling = mkBoolOpt false "Whether or not to enable UI scaling for Steam.";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.steam.remotePlay.openFirewall = true;

    hardware.steam-hardware.enable = true;

    environment.systemPackages = with pkgs.dafos; [
      steam
    ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
      STEAM_FORCE_DESKTOPUI_SCALING = lib.optional (cfg.uiScaling) "2";
    };
  };
}
