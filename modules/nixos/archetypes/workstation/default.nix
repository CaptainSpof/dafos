{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkDefault mkIf;
  inherit (lib.${namespace}) enabled mkBoolOpt;

  cfg = config.${namespace}.archetypes.workstation;
in
{
  options.${namespace}.archetypes.workstation = {
    enable = mkBoolOpt false "Whether or not to enable the workstation archetype.";
  };

  config = mkIf cfg.enable {
    dafos = {

      services = {
        logiops = enabled;
      };

      suites = {
        common = mkDefault enabled;
        desktop = enabled;
        development = enabled;
      };
    };
  };
}
