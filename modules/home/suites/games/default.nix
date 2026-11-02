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
    nexusmods.enable = mkBoolOpt true ''
      Whether or not to enable the Nexus Mods App, a mod manager handling Nexus collections
    '';
    ryubing.enable = mkBoolOpt false "Whether or not to enable ryubing.";
    remote-play.enable = mkBoolOpt true "Whether or not to enable remote-play.";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        mangohud
        # nixpkgs' pince passes each makeWrapperArgs flag as one spaced string,
        # which only word-splits with structured attrs off.
        # Default signal table stops on SIGPIPE: Unity's telemetry thread hits
        # one on every failed upload, freezing Proton games until detach. This
        # only seeds new/reset settings; an existing PINCE.conf keeps its table.
        (pince.overrideAttrs (old: {
          __structuredAttrs = false;
          postPatch = (old.postPatch or "") + ''
            substituteInPlace GUI/Settings/settings.py \
              --replace-fail '["SIGPIPE", True, True]' '["SIGPIPE", False, True]'
          '';
        }))
        protontricks
        protonup-ng
        protonup-qt
        protonplus
      ]
      ++ lib.optionals cfg.bottles.enable [ bottles ]
      ++ lib.optionals cfg.ftl.enable [ slipstream ]
      ++ lib.optionals cfg.irony.enable [ pkgs.${namespace}.irony-mod-manager ]
      ++ lib.optionals cfg.lutris.enable [ lutris ]
      # unfree variant bundles 7-Zip with RAR support; many mods ship as .rar
      ++ lib.optionals cfg.nexusmods.enable [ nexusmods-app-unfree ]
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
