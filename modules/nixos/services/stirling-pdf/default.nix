{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.services.stirling-pdf;
in
{
  options.${namespace}.services.stirling-pdf = {
    enable = mkBoolOpt false "Whether or not to enable stirling-pdf";
    base-url = mkOpt types.str "pdf.daftdaf.dev" "The base url";
    port = mkOpt types.str "8060" "The port";
  };

  config = mkIf cfg.enable {
    services.stirling-pdf = {
      enable = true;
      environment = {
        SERVER_PORT = cfg.port;
      };
    };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${cfg.port}"
          import cloudflare
        '';
    };
  };
}
