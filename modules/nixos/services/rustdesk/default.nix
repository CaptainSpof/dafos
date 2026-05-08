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

  cfg = config.${namespace}.services.rustdesk;
in
{
  options.${namespace}.services.rustdesk = {
    enable = mkEnableOption "Whether or not to enable rustdesk";

    base-url = mkOpt types.str "rustdesk.daftdaf.dev" "The base url";
    port = mkOpt types.int 21118 "The port";
  };

  config = mkIf cfg.enable {
    services.rustdesk-server.enable = true;
    services.rustdesk-server.relay.enable = true;
    services.rustdesk-server.signal.relayHosts = [ "127.0.0.1" ];
    services.rustdesk-server.openFirewall = true;

    # environment.systemPackages = with pkgs; [
    #   rustdesk
    # ];

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };
  };
}
