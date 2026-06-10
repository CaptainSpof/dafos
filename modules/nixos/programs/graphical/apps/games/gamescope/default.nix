{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.apps.games.gamescope;
in
{
  options.${namespace}.programs.graphical.apps.games.gamescope = {
    enable = mkBoolOpt false "Whether or not to enable gamescope.";
  };

  config = mkIf cfg.enable {
    programs.gamescope = {
      enable = true;
      # Keep capSysNice OFF. The CAP_SYS_NICE wrapper makes gamescope abort with
      # "failed to inherit capabilities: Operation not permitted" when launched
      # nested from inside Steam (Steam's no_new_privs launch context forbids
      # raising the capability into the ambient set). The cap is only meant for
      # running gamescope as the session compositor (Gaming Mode), not as a
      # per-game launch-option wrapper, which is how we use it here.
      capSysNice = false;
    };
  };
}
