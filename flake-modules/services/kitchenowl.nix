# KitchenOwl (nps stack): shopping lists and recipes, OIDC through Authelia,
# public (the shopping list is used from the shop, through the mobile app).
# Runs on dafpi: its OIDC client and lldap group are served by dafoltop's
# Authelia/lldap through authelia-peers, and the public route goes through
# dafoltop's Traefik (traefik peers).
{ inputs, ... }:
{
  flake.modules.homeManager.kitchenowl =
    { config, lib, ... }:
    let
      cfg = config.nps.stacks.kitchenowl;
      secret = name: {
        "kitchenowl/${name}".sopsFile = inputs.self + "/secrets/dafoltop/kitchenowl.yaml";
      };
    in
    {
      options.dafos.services.kitchenowl.enable = lib.mkEnableOption "KitchenOwl";

      config = lib.mkIf config.dafos.services.kitchenowl.enable (
        lib.mkMerge [
          {
            sops.secrets = lib.mkMerge [
              (secret "jwt-secret")
              (secret "authelia/client-secret")
            ];

            nps.stacks.kitchenowl = {
              enable = true;

              jwtSecretFile = config.sops.secrets."kitchenowl/jwt-secret".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."kitchenowl/authelia/client-secret".path;
              };

              # The OIDC redirect URI is derived from the web container's URL, so the
              # subdomain has to be set here rather than through an alias.
              containers.kitchenowl-web = {
                expose = true;
                traefik.subDomain = "course";
                # Upstream's displayName is misspelt "KitchwenOwl".
                dashboard.name = lib.mkForce "KitchenOwl";
              };
              containers.kitchenowl-backend.dashboard.name = lib.mkForce "KitchenOwl";
            };
          }

          # nps builds the issuer from the *local* authelia container, which
          # does not exist where Authelia is a peer's (see ./papra.nix). It is
          # a plain string, so overriding that one variable would still
          # evaluate it: the whole environment is restated instead (as in
          # ./kaneo.nix). Recheck it against nps's module after a bump.
          (lib.mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.kitchenowl-backend = {
              wantsContainer = lib.mkForce [ ];
              extraEnv = lib.mkForce {
                JWT_SECRET_KEY.fromFile = cfg.jwtSecretFile;
                FRONT_URL = config.services.podman.containers.kitchenowl-web.traefik.serviceUrl;
                OIDC_ISSUER = "https://auth.${config.nps.stacks.traefik.domain}";
                OIDC_CLIENT_ID = "kitchenowl";
                OIDC_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
              };
            };
          })
        ]
      );
    };
}
