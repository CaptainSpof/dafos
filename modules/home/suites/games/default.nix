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
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      bottles
      lutris
      proton-caller
      protontricks
      protonup-ng
      protonup-qt

      # slipstream # FTL
      # sunshine
      # moonlight-qt #for testing purposes.
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
