{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.tandoor;

  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types;
in
{
  options.${namespace}.services.tandoor = {
    enable = mkEnableOption "Whether or not to configure tandoor.";
    base-url = mkOpt types.str "tandoor.daftdaf.dev" "The base url";
    port = mkOpt types.int 9010 "The port";
  };

  # TODO/MAYBE: create and setup a user
  config = mkIf cfg.enable {

    services.tandoor-recipes = {
      enable = true;
      address = "0.0.0.0";
      inherit (cfg) port;
      extraConfig = {
        ALLOWED_HOSTS = "*";
        GUNICORN_MEDIA = "1";
        MEDIA_URL = "/media/";
        STATIC_URL = "/static/";
      };
    };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };

    networking.firewall.allowedTCPPorts = [
      9090
    ];
  };
}
