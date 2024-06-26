{ config, lib, namespace, ... }:

with lib;
with lib.${namespace};
let cfg = config.${namespace}.suites.social;
in {
  options.${namespace}.suites.social = with types; {
    enable = mkBoolOpt false "Whether or not to enable social configuration.";
  };

  config = mkIf cfg.enable {
    dafos = {
      programs.graphical.instant-messengers = {
        discord = enabled;
        element = disabled;
        telegram = enabled;
        teamspeak = enabled;
      };
    };
  };
}
