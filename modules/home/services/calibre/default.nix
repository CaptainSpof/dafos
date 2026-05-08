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
            expose = true;
            traefik.subDomain = "livre";

	        volumes = lib.mkForce [
              "/mnt/livres.bak:/calibre-library"
	          "${config.nps.storageBaseDir}/calibre/ingest:/cwa-book-ingest"
	          "${config.nps.storageBaseDir}/calibre/config:/config"
            ];
	      };
        };
      };
    };
  }
