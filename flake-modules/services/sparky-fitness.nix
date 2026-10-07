# SparkyFitness (nps stack): fitness and nutrition tracking, OIDC through
# Authelia, private. Runs on dafpi: its OIDC client and lldap groups are
# served by dafoltop's Authelia/lldap through authelia-peers.
{ inputs, ... }:
{
  flake.modules.homeManager.sparky-fitness =
    { config, lib, ... }:
    let
      cfg = config.nps.stacks.sparky-fitness;
      secret = name: {
        "sparky-fitness/${name}".sopsFile = inputs.self + "/secrets/dafoltop/sparkyfitness.yaml";
      };
    in
    {
      options.dafos.services.sparky-fitness.enable = lib.mkEnableOption "SparkyFitness";

      config = lib.mkIf config.dafos.services.sparky-fitness.enable (
        lib.mkMerge [
          {
            sops.secrets = lib.mkMerge [
              (secret "better-auth-secret")
              (secret "api-encryption-key")
              (secret "db-password")
              (secret "authelia/client-secret")
            ];

            nps.stacks.sparky-fitness = {
              enable = true;

              betterAuthSecretFile = config.sops.secrets."sparky-fitness/better-auth-secret".path;
              apiEncryptionKeyFile = config.sops.secrets."sparky-fitness/api-encryption-key".path;
              db.passwordFile = config.sops.secrets."sparky-fitness/db-password".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."sparky-fitness/authelia/client-secret".path;
              };

              # Keep the database off the unattended Sunday registry pull:
              # `postgres:18` is a moving tag.
              containers.sparky-fitness-db.autoUpdate = "local";
            };
          }

          # nps builds the issuer from the *local* authelia container, which
          # does not exist where Authelia is a peer's (see ./papra.nix). It is
          # a plain string, so overriding that one variable would still
          # evaluate it: the whole environment is restated instead (as in
          # ./kaneo.nix). Recheck it against nps's module after a bump.
          (lib.mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.sparky-fitness-backend = {
              wantsContainer = lib.mkForce [ "sparky-fitness-db" ];
              extraEnv = lib.mkForce (
                {
                  SPARKY_FITNESS_DB_USER = cfg.db.username;
                  SPARKY_FITNESS_DB_HOST = "sparky-fitness-db";
                  SPARKY_FITNESS_DB_NAME = "sparkyfitness";
                  SPARKY_FITNESS_DB_PASSWORD.fromFile = cfg.db.passwordFile;
                  SPARKY_FITNESS_APP_DB_USER = "sparkyfitness";
                  SPARKY_FITNESS_APP_DB_PASSWORD.fromFile = cfg.db.passwordFile;

                  BETTER_AUTH_SECRET.fromFile = cfg.betterAuthSecretFile;
                  SPARKY_FITNESS_API_ENCRYPTION_KEY.fromFile = cfg.apiEncryptionKeyFile;

                  SPARKY_FITNESS_FRONTEND_URL =
                    config.services.podman.containers.sparky-fitness-frontend.traefik.serviceUrl;

                  SPARKY_FITNESS_DISABLE_EMAIL_LOGIN = true;
                  SPARKY_FITNESS_OIDC_AUTH_ENABLED = true;
                  SPARKY_FITNESS_OIDC_ISSUER_URL = "https://auth.${config.nps.stacks.traefik.domain}";
                  SPARKY_FITNESS_OIDC_CLIENT_ID = "sparky-fitness";
                  SPARKY_FITNESS_OIDC_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
                  SPARKY_FITNESS_OIDC_PROVIDER_SLUG = "authelia";
                  SPARKY_FITNESS_OIDC_PROVIDER_NAME = "Authelia";
                  SPARKY_FITNESS_OIDC_AUTO_REGISTER = true;
                  SPARKY_FITNESS_OIDC_SCOPE = "openid groups email profile";
                  SPARKY_FITNESS_OIDC_ADMIN_GROUP = cfg.oidc.adminGroup;
                  SPARKY_FITNESS_OIDC_TOKEN_AUTH_METHOD = "client_secret_basic";
                }
                // cfg.extraEnv
              );
            };
          })
        ]
      );
    };
}
