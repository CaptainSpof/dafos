{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.calibre;

in
{
  options.${namespace}.services.calibre = {
    enable = mkEnableOption "Whether or not to configure calibre.";
    subDomain = mkOpt types.str "livre" "The base url";
  };

  config = mkIf cfg.enable {
    nps.stacks = {
      calibre = {
        enable = true;

        containers.calibre = {
          # calibre-web has no SSO and upstream seeds admin/admin123, so keep
          # it off the public chain; LAN and tailnet still reach it.
          traefik.subDomain = cfg.subDomain;

          volumes = lib.mkForce [
            "/mnt/calibre:/calibre-library"
            "${config.nps.storageBaseDir}/calibre/ingest:/cwa-book-ingest"
            "${config.nps.storageBaseDir}/calibre/config:/config"
          ];
        };
      };
    };
  };
}
