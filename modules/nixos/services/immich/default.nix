{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.immich;
in
{

  options.${namespace}.services.immich = {
    enable = mkEnableOption "Whether or not to configure immich.";
  };

  config = mkIf cfg.enable {

    users.groups.yahrr.members = [ "immich" ];

    services.immich = {
      enable = true;
      machine-learning.enable = true;
      port = 2283;
      host = "0.0.0.0";
      settings.server.externalDomain = "http://daftop";
      openFirewall = true;
    };
  };
}
