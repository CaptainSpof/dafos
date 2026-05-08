{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.send;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.send = {
    enable = mkEnableOption "Whether or not to configure send.";
  };

  config = mkIf cfg.enable {
    services.send = {
      enable = true;
      port = 1443;
    };
    services.caddy.virtualHosts = {
        "send.daftdaf.dev".extraConfig = ''
          reverse_proxy http://0.0.0.0:1443
          import cloudflare
        '';
    };
  };
}
