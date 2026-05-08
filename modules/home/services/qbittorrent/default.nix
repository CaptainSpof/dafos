{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) enabled disabled;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.qbittorrent;
in
  {

    options.${namespace}.services.qbittorrent = {
      enable = mkEnableOption "Whether or not to configure qbittorrent.";
      base-url = mkOpt types.str "qbittorrent.daftdaf.dev" "The base url";
      port = mkOpt types.int 2283 "The port";
    };

    config = mkIf cfg.enable {
      sops.secrets."cloudflare-api-token" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
      };

      nps = {
        externalStorageBaseDir = "/mnt/nps";
        hostIP4Address = "192.168.0.10";
        stacks = {
       
          streaming = {
            enable = true;

            bazarr = disabled;
            gluetun = disabled;
            jellyfin = disabled;
            prowlarr = disabled;
            qbittorrent = disabled;
            qui = enabled;
            radarr = disabled;
            sonarr = disabled;
          };
        };
      };
    };
  }
