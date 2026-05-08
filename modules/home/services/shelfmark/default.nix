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
              extraEnv = {
                BOOK_LANGUAGE = "en,fr";
                CALIBRE_WEB_URL = "book.daftdaf.dev";
                AUDIOBOOK_LIBRARY_URL = "audibook.daftdaf.dev";
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
