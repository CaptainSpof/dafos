{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.prowlarr;

  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types;
in
{
  options.${namespace}.services.prowlarr = {
    enable = mkEnableOption "Whether or not to configure prowlarr.";
    base-url = mkOpt types.str "prowlarr.daftdaf.dev" "The base url";
    port = mkOpt types.int 9696 "The port";
  };

  config = mkIf cfg.enable {
    users.groups.yahrr.members = [ "prowlarr" ];
    services.prowlarr = {
      enable = true;
      openFirewall = true;
      settings = {
        server = {
          inherit (cfg) port;
          urlbase = "localhost";
        };
      };
    };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };
  };
}
