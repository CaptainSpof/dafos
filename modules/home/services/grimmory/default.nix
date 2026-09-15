{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.grimmory;
in
{
  options.${namespace}.services.grimmory = {
    enable = mkEnableOption "Whether or not to configure grimmory.";
    subDomain = mkOpt types.str "grimmory" "The subdomain for the service.";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "grimmory/db-user-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/grimmory.yaml";
      "grimmory/db-root-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/grimmory.yaml";
    };

    nps.stacks = {
      grimmory = {
        enable = true;

        containers.grimmory = {
          expose = true;
          traefik.subDomain = cfg.subDomain;

          volumes = lib.mkForce [
            "/mnt/grimmory/livres:/livres"
            "/mnt/grimmory/books:/books"
            "/mnt/audio/Audiobooks:/audiobooks"
            "${config.nps.storageBaseDir}/grimmory/bookdrop:/bookdrop"
            "${config.nps.storageBaseDir}/grimmory/data:/app/data"
          ];
        };

        # `services.podman.autoUpdate` is on by default upstream and pulls every
        # container from its registry on Sunday at 00:00. `mariadb:11` is a
        # moving tag, so that rolls the major line's point releases in
        # unattended and restarts the database with it. `local` keeps the
        # container pinned to the image already on disk; upgrades land on a
        # rebuild instead, where they are reviewable.
        containers.grimmory-db.autoUpdate = "local";

        oidc.registerClient = true;

        db = {
          userPasswordFile = config.sops.secrets."grimmory/db-user-password".path;
          rootPasswordFile = config.sops.secrets."grimmory/db-root-password".path;
        };
      };
    };
  };
}
