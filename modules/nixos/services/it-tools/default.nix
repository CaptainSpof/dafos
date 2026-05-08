{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types getExe;

  cfg = config.${namespace}.services.it-tools;
in
{
  options.${namespace}.services.it-tools = {
    enable = mkEnableOption "Whether or not to enable it-tools";
    base-url = mkOpt types.str "tools.daftdaf.dev" "The base url";
    port = mkOpt types.int 8060 "The port";
  };

  config = mkIf cfg.enable {

    # virtualisation.oci-containers.containers."it-tools" = {
    #   autoStart = true;
    #   image = "corentinth/it-tools:latest";
    #   extraOptions = [ "--pull=always" ];
    #   ports = [ "${toString cfg.port}:80" ];
    # };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };
  };
}
