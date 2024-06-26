{ config, lib, pkgs, namespace, ... }:

with lib;
with lib.dafos;
let
  cfg = config.${namespace}.programs.graphical.apps.games.steam;
in
{
  options.dafos.programs.graphical.apps.games.steam = with types; {
    enable = mkBoolOpt false "Whether or not to enable support for Steam.";
    uiScaling = mkBoolOpt false "Whether or not to enable UI scaling for Steam.";
  };

  config = mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      extraCompatPackages = [
        pkgs.proton-ge-bin
      ];
    };

    hardware.steam-hardware.enable = true;

    environment.systemPackages = with pkgs; [
      steamtinkerlaunch
    ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
      STEAM_FORCE_DESKTOPUI_SCALING = lib.optional (cfg.uiScaling) "2";
    };
  };
}
