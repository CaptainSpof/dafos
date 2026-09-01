{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt enabled;

  cfg = config.${namespace}.suites.games;
in
{
  options.${namespace}.suites.games = {
    enable = mkBoolOpt false "Whether or not to enable common games configuration.";
    bottles.enable = mkBoolOpt false "Whether or not to enable bottles.";
    ftl.enable = mkBoolOpt false "Whether or not to enable ftl.";
    irony.enable = mkBoolOpt true ''
      Whether or not to enable Irony Mod Manager, a mod manager for Paradox
    '';
    lutris.enable = mkBoolOpt false "Whether or not to enable lutris.";
    ryubing.enable = mkBoolOpt false "Whether or not to enable ryubing.";
    remote-play.enable = mkBoolOpt true "Whether or not to enable remote-play.";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        mangohud
        pince
        protontricks
        protonup-ng
        protonup-qt
        protonplus
      ]
      ++ lib.optionals cfg.bottles.enable [ bottles ]
      ++ lib.optionals cfg.ftl.enable [ slipstream ]
      ++ lib.optionals cfg.irony.enable [ pkgs.${namespace}.irony-mod-manager ]
      ++ lib.optionals cfg.lutris.enable [ lutris ]
      ++ lib.optionals cfg.ryubing.enable [ ryubing ]
      ++ lib.optionals cfg.remote-play.enable [
        sunshine
        moonlight-qt
      ];

    dafos = {
      programs = {
        terminal = {
          tools = {
            wine = enabled;
          };
        };
      };
    };
  };
}
