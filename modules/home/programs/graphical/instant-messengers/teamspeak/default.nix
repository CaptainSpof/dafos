{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.instant-messengers.teamspeak;
in
{
  options.${namespace}.programs.graphical.instant-messengers.teamspeak = {
    enable = mkBoolOpt false "Whether or not to enable teamspeak.";
  };

  config = mkIf cfg.enable { home.packages = [ pkgs.teamspeak6-client ]; };
}
