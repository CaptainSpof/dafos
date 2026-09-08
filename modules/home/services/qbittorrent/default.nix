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

          # nps e44f684 moved gluetun/qbittorrent/qui into their own
          # `qbittorrent` stack and prowlarr into `prowlarr`; the streaming
          # stack now pulls them in through these two flags.
          useProwlarr = false;
          useQbittorrent = true;

          bazarr = disabled;
          jellyfin = disabled;
          radarr = disabled;
          sonarr = disabled;
        };

        qbittorrent = {
          # The qbittorrent container itself no longer has an `enable` flag —
          # it always comes up with the stack, which qui needs anyway.
          gluetun = disabled;
          qui = enabled;
        };
      };
    };
  };
}
