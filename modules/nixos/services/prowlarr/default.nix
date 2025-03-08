{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.prowlarr;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.prowlarr = {
    enable = mkEnableOption "Whether or not to configure prowlarr.";
  };

  config = mkIf cfg.enable {
    users.groups.yahrr.members = [ "prowlarr" ];
    services.prowlarr = {
      enable = true;
      # port = 9696; # For reference
      openFirewall = true;
    };
  };
}
