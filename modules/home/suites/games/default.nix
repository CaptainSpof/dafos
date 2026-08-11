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
      Clausewitz/Jomini engine games (CK3, Stellaris, HOI4, EU4/V, Victoria 3).
      CK3 ships Windows-only now (the install is just ck3.exe, no ELF), so its
      mods and launcher DB live in the Proton prefix — for us
      steamapps/compatdata/1158310/pfx/drive_c/users/steamuser/Documents/Paradox
      Interactive/Crusader Kings III, which is what Irony autodetects. Any stale
      ~/.local/share/Paradox Interactive tree is a leftover, not the live one.
    '';
    lutris.enable = mkBoolOpt false "Whether or not to enable lutris.";
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
        ryubing
      ]
      ++ lib.optionals cfg.bottles.enable [ bottles ]
      ++ lib.optionals cfg.ftl.enable [ slipstream ]
      ++ lib.optionals cfg.irony.enable [ pkgs.${namespace}.irony-mod-manager ]
      ++ lib.optionals cfg.lutris.enable [ lutris ]
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
