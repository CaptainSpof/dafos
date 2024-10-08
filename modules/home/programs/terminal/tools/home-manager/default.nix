{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.programs.terminal.tools.home-manager;
in
{
  options.${namespace}.programs.terminal.tools.home-manager = {
    enable = mkEnableOption "Whether or not to enable home-manager.";
  };

  config = mkIf cfg.enable {
    programs.home-manager = enabled;
  };
}
