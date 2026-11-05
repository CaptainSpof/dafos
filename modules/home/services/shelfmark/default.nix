{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.shelfmark;
  bookorbitUrl = "https://${
    config.${namespace}.services.bookorbit.subDomain
  }.${config.nps.stacks.traefik.domain}";
in
{

  options.${namespace}.services.shelfmark = {
    enable = mkEnableOption "Whether or not to configure shelfmark.";
    subDomain = mkOpt types.str "shelfmark" "The base url";
  };

  config = mkIf cfg.enable {
    nps.stacks = {
      shelfmark = {
        enable = true;

        downloadDirectory = "${config.nps.storageBaseDir}/grimmory/bookdrop";

        containers = {
          shelfmark = {
            # nps runs shelfmark with AUTH_METHOD=none, and it can queue
            # torrent downloads; the private chain alone let anyone on the
            # LAN or tailnet drive it.
            forwardAuth.enable = true;

            extraEnv = {
              BOOK_LANGUAGE = "en,fr";
              # The "go to library" buttons: BookOrbit holds both the books
              # and the audiobooks.
              CALIBRE_WEB_URL = bookorbitUrl;
              AUDIOBOOK_LIBRARY_URL = bookorbitUrl;
              METADATA_PROVIDER = "openlibrary";

              # TODO: setup prowlarr
              PROWLARR_TORRENT_CLIENT = "qbittorrent";
              QBITTORRENT_URL = "http://gluetun:8080";
            };
          };
        };
      };
    };
  };
}
