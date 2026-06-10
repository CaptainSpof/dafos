{
  config,
  lib,
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
    dafos = {
      programs = {
        graphical = {
          apps = {
            games = {
              steam = enabled;
              gamemode = enabled;
              gamescope = enabled;
            };
          };
        };
      };
    };
  };
}
