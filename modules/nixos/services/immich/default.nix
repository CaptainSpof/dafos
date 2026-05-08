{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.immich;
in
{

  options.${namespace}.services.immich = {
    enable = mkEnableOption "Whether or not to configure immich.";
    base-url = mkOpt types.str "immich.daftdaf.dev" "The base url";
    port = mkOpt types.int 2283 "The port";
  };

  config = mkIf cfg.enable {

    users.groups.yahrr.members = [ "immich" ];

    services.immich = {
      enable = true;
      redis.enable = true;
      machine-learning.enable = true;
      inherit (cfg) port;
      host = "0.0.0.0";
      settings.server.externalDomain = "http://daftop"; # FIXME?
      openFirewall = true;
    };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
        "photos.daftdaf.dev".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };
  };
}
