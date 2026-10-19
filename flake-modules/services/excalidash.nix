# ExcaliDash (nps stack): Excalidraw with a drawing library and live
# collaboration, OIDC through Authelia (enforced), private (LAN/tailnet).
# Runs on dafpi: its OIDC client and lldap groups are served by dafoltop's
# Authelia/lldap through authelia-peers, and the route goes through
# dafoltop's Traefik (traefik peers).
{ inputs, ... }:
{
  flake.modules.homeManager.excalidash =
    { config, lib, ... }:
    let
      cfg = config.nps.stacks.excalidash;
      secret = name: {
        "excalidash/${name}".sopsFile = inputs.self + "/secrets/dafoltop/excalidash.yaml";
      };
    in
    {
      options.dafos.services.excalidash.enable = lib.mkEnableOption "ExcaliDash";

      config = lib.mkIf config.dafos.services.excalidash.enable (
        lib.mkMerge [
          {
            sops.secrets = lib.mkMerge [
              (secret "jwt-secret")
              (secret "csrf-secret")
              (secret "authelia/client-secret")
            ];

            nps.stacks.excalidash = {
              enable = true;

              jwtSecretFile = config.sops.secrets."excalidash/jwt-secret".path;
              csrfSecretFile = config.sops.secrets."excalidash/csrf-secret".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."excalidash/authelia/client-secret".path;
              };
            };
          }

          # nps builds the issuer from the *local* authelia container, which
          # does not exist where Authelia is a peer's (see ./papra.nix). It is
          # a plain string, so the whole environment is restated instead (as in
          # ./kitchenowl.nix). Recheck it against nps's module after a bump.
          (lib.mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.excalidash-backend =
              let
                url = config.services.podman.containers.excalidash.traefik.serviceUrl;
              in
              {
                wantsContainer = lib.mkForce [ ];
                extraEnv = lib.mkForce {
                  NODE_ENV = "production";
                  DATABASE_PROVIDER = "sqlite";
                  DATABASE_URL = "file:/app/prisma/dev.db";
                  PORT = 8000;
                  TRUST_PROXY = 1;
                  FRONTEND_URL = url;
                  JWT_SECRET.fromFile = cfg.jwtSecretFile;
                  CSRF_SECRET.fromFile = cfg.csrfSecretFile;
                  AUTH_MODE = "oidc_enforced";
                  OIDC_ISSUER_URL = "https://auth.${config.nps.stacks.traefik.domain}";
                  OIDC_CLIENT_ID = "excalidash";
                  OIDC_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
                  OIDC_REDIRECT_URI = "${url}/api/auth/oidc/callback";
                  OIDC_ADMIN_GROUPS = cfg.oidc.adminGroup;
                  OIDC_SCOPES = "openid profile email groups";
                  OIDC_JIT_PROVISIONING = true;
                  OIDC_FIRST_USER_ADMIN = true;
                  OIDC_TOKEN_ENDPOINT_AUTH_METHOD = "client_secret_basic";
                };
              };
          })
        ]
      );
    };
}
