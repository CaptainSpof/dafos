{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkDefault mkIf;
  inherit (lib.${namespace}) enabled disabled mkBoolOpt;

  cfg = config.${namespace}.archetypes.workstation;
in
{
  options.${namespace}.archetypes.workstation = {
    enable = mkBoolOpt false "Whether or not to enable the workstation archetype.";
  };

  config = mkIf cfg.enable {
    dafos = {

      services = {
        logiops = disabled;
      };

      suites = {
        common = mkDefault enabled;
        desktop = enabled;
        development = enabled;
      };
    };
  };
}
