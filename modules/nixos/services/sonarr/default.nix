{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types;

  cfg = config.${namespace}.services.sonarr;
  username = config.${namespace}.user.name;
in
{
  options.${namespace}.services.sonarr = {
    enable = mkEnableOption "Whether or not to configure sonarr.";
    base-url = mkOpt types.str "sonarr.daftdaf.dev" "The base url";
    port = mkOpt types.int 8989 "The port";
  };

  config = mkIf cfg.enable {
    users.groups.yahrr.members = [ "sonarr" ];
    services.sonarr = {
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
