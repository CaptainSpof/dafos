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

  cfg = config.${namespace}.programs.graphical.apps.handy;
in
{
  options.${namespace}.programs.graphical.apps.handy = {
    enable = mkBoolOpt false "Whether or not to install Handy, a speech-to-text dictation app.";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.handy ];
  };
}
