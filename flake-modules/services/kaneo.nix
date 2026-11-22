# Kaneo (nps stack): project management, OIDC through Authelia, private.
# Runs on dafpi: its OIDC client and lldap group are served by dafoltop's
# Authelia/lldap through authelia-peers.
{ inputs, ... }:
{
  flake.modules.homeManager.kaneo =
    { config, lib, ... }:
    let
      domain = config.nps.stacks.traefik.domain;
      cfg = config.nps.stacks.kaneo;
      web = config.services.podman.containers.kaneo-web.traefik;
      api = config.services.podman.containers.kaneo-api.traefik;

      # `todo` is the frontend, `kaneo` an alias serving it too.
      webHosts = map (sub: "${sub}.${domain}") [
        "todo"
        "kaneo"
      ];
      origins = lib.concatMapStringsSep "," (h: "https://${h}") webHosts;
    in
    {
      options.dafos.services.kaneo.enable = lib.mkEnableOption "Kaneo";

      config = lib.mkIf config.dafos.services.kaneo.enable (
        lib.mkMerge [
          {
            sops.secrets = {
              "kaneo/auth-secret".sopsFile = inputs.self + "/secrets/dafoltop/kaneo.yaml";
              "kaneo/db-password".sopsFile = inputs.self + "/secrets/dafoltop/kaneo.yaml";
              "kaneo/authelia/client-secret".sopsFile = inputs.self + "/secrets/dafoltop/kaneo.yaml";
            };

            nps.stacks.kaneo = {
              enable = true;

              authSecretFile = config.sops.secrets."kaneo/auth-secret".path;
              db.passwordFile = config.sops.secrets."kaneo/db-password".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."kaneo/authelia/client-secret".path;
              };

              containers = {
                kaneo-web.traefik.subDomain = "todo";
                kaneo-api = {
                  port = 1337;
                  traefik.subDomain = "kaneo-api";
                };

                # Keep the database off the unattended Sunday registry pull:
                # `postgres:18` is a moving tag.
                kaneo-db.autoUpdate = "local";
              };
            };

            # Aliases serve the frontend directly. The web app runs on a different
            # origin from the API, so the API has to accept the alias origins for
            # CORS and for better-auth's origin check. nps only derives both from
            # KANEO_CLIENT_URL. The session cookie lives on the API host, so it is
            # shared by every alias. OIDC's post-login callbackURL is still built
            # from KANEO_CLIENT_URL, so a login started on an alias ends up on
            # `todo`.
            services.podman.containers = {
              kaneo-web.labels."traefik.http.routers.kaneo-web.rule" = lib.mkForce (
                lib.concatMapStringsSep " || " (h: "Host(`${h}`)") webHosts
              );
              kaneo-api.extraEnv = {
                CORS_ORIGINS = origins;
                BETTER_AUTH_TRUSTED_ORIGINS = origins;
              };
            };
          }

          # nps builds the discovery URL from the *local* authelia container,
          # which does not exist where Authelia is a peer's (see ./papra.nix).
          # It is a plain string, so overriding that one variable would still
          # evaluate it: the whole environment is restated instead. Recheck it
          # against nps's kaneo module after a bump.
          (lib.mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.kaneo-api = {
              wantsContainer = lib.mkForce [ "kaneo-db" ];
              extraEnv = lib.mkForce {
                AUTH_SECRET.fromFile = cfg.authSecretFile;
                KANEO_CLIENT_URL = web.serviceUrl;
                KANEO_API_URL = api.serviceUrl;
                DATABASE_URL.fromTemplate = "postgres://${cfg.db.username}:{{ file.Read `${cfg.db.passwordFile}` }}@kaneo-db/kaneo";
                DISABLE_GUEST_ACCESS = true;
                CUSTOM_OAUTH_CLIENT_ID = "kaneo";
                CUSTOM_OAUTH_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
                CUSTOM_OAUTH_DISCOVERY_URL = "https://auth.${domain}/.well-known/openid-configuration";
                CUSTOM_OAUTH_SCOPES = "openid,profile,email";
                DISABLE_PASSWORD_REGISTRATION = true;
                CORS_ORIGINS = origins;
                BETTER_AUTH_TRUSTED_ORIGINS = origins;
              };
            };
          })
        ]
      );
    };
}
