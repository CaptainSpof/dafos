{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.kaneo;

  webHosts = map (sub: "${sub}.${config.nps.stacks.traefik.domain}") (
    [ cfg.subDomain ] ++ cfg.aliases
  );
in
{

  options.${namespace}.services.kaneo = {
    enable = mkEnableOption "Whether or not to configure kaneo.";
    subDomain = mkOpt types.str "todo" "The subdomain of the web frontend.";
    aliases = mkOpt (types.listOf types.str) [
      "kaneo"
    ] "Extra subdomains that also serve the web frontend.";
    apiSubDomain = mkOpt types.str "kaneo-api" "The subdomain of the backend API.";
    expose = mkBoolOpt false "Whether to reach the instance from outside the LAN/tailnet.";
  };

  config = mkIf cfg.enable {
    # Aliases serve the frontend directly. The web app runs on a different
    # origin from the API, so the API has to accept the alias origins for
    # CORS and for better-auth's origin check. nps only derives both from
    # KANEO_CLIENT_URL. The session cookie lives on the API host, so it is
    # shared by every alias. OIDC's post-login callbackURL is still built
    # from KANEO_CLIENT_URL, so a login started on an alias ends up on
    # `subDomain`.
    services.podman.containers = {
      kaneo-web.labels."traefik.http.routers.kaneo-web.rule" = lib.mkForce (
        lib.concatMapStringsSep " || " (h: "Host(`${h}`)") webHosts
      );
      kaneo-api.extraEnv = rec {
        CORS_ORIGINS = lib.concatMapStringsSep "," (h: "https://${h}") webHosts;
        BETTER_AUTH_TRUSTED_ORIGINS = CORS_ORIGINS;
      };
    };

    sops.secrets = {
      "kaneo/auth-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kaneo.yaml";
      };
      "kaneo/db-password" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kaneo.yaml";
      };
      "kaneo/authelia/client-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kaneo.yaml";
      };
    };

    nps.stacks = {
      kaneo = {
        enable = true;

        authSecretFile = config.sops.secrets."kaneo/auth-secret".path;
        db.passwordFile = config.sops.secrets."kaneo/db-password".path;

        oidc = {
          enable = true;
          clientSecretFile = config.sops.secrets."kaneo/authelia/client-secret".path;
        };

        containers = {
          kaneo-web = {
            inherit (cfg) expose;
            traefik.subDomain = cfg.subDomain;
          };

          kaneo-api = {
            inherit (cfg) expose;
            port = 1337;
            traefik.subDomain = cfg.apiSubDomain;
          };

          # Keep the database off the unattended Sunday registry pull (see the
          # grimmory module for the full reasoning): `postgres:18` is a moving
          # tag.
          kaneo-db.autoUpdate = "local";
        };
      };
    };
  };
}
