{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.radarr;

  inherit (lib.${namespace}) mkOpt;
  inherit (lib) types mkEnableOption mkIf;
in
{
  options.${namespace}.services.radarr = {
    enable = mkEnableOption "Whether or not to configure radarr.";
    dataDir = mkOpt types.str "/var/lib/radarr" "The directory where Radarr stores its data files.";
    base-url = mkOpt types.str "radarr.daftdaf.dev" "The base url";
    port = mkOpt types.int 7878 "The port";
  };

  config = mkIf cfg.enable {
    users.groups.yahrr.members = [ "radarr" ];
    services.radarr = {
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
