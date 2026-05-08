{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types;

  cfg = config.${namespace}.services.karakeep;
in
{
  options.${namespace}.services.karakeep = {
    enable = mkEnableOption "Whether or not to enable karakeep";
    base-url = mkOpt types.str "karakeep.daftdaf.dev" "The base url";
    port = mkOpt types.int 8070 "The port";
  };

  config = mkIf cfg.enable {
    services.karakeep = {
      enable = true;
      meilisearch.enable = true;
      extraEnvironment = {
        PORT = toString cfg.port;
        DISABLE_NEW_RELEASE_CHECK = "true";
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
