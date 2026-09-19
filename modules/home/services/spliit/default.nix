{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.spliit;
in
{

  options.${namespace}.services.spliit = {
    enable = mkEnableOption "Whether or not to configure spliit.";
    subDomain = mkOpt types.str "split" "The subdomain of the web app.";
    # Spliit has no accounts: a group is shared by sending its link, so the
    # people it is shared with need to reach it from outside the LAN/tailnet.
    # The flip side is that anyone who can reach it can create groups.
    expose = mkBoolOpt true "Whether to reach the instance from outside the LAN/tailnet.";
  };

  config = mkIf cfg.enable {
    sops.secrets."spliit/db-password" = {
      sopsFile = lib.snowfall.fs.get-file "secrets/daf/spliit.yaml";
    };

    nps.stacks.spliit = {
      enable = true;

      db.passwordFile = config.sops.secrets."spliit/db-password".path;

      containers = {
        spliit = {
          inherit (cfg) expose;
          traefik.subDomain = cfg.subDomain;
        };

        # Keep the database off the unattended Sunday registry pull (see the
        # grimmory module for the full reasoning): `postgres:18` is a moving
        # tag.
        spliit-db.autoUpdate = "local";
      };
    };
  };
}
