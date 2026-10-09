# Karakeep (nps stack): bookmarks, notes and web archives, OIDC through
# Authelia, public (browser extension and mobile app away from home).
# Runs on dafpi: its OIDC client and lldap group are served by dafoltop's
# Authelia/lldap through authelia-peers, and the public route goes through
# dafoltop's Traefik (traefik peers).
#
# Its SQLite database (data/db.db) is picked up by backup-dumps; the
# Meilisearch index is rebuilt from it (admin settings → reindex).
{ inputs, ... }:
{
  flake.modules.homeManager.karakeep =
    { config, lib, ... }:
    let
      cfg = config.nps.stacks.karakeep;
      secret = name: {
        "karakeep/${name}".sopsFile = inputs.self + "/secrets/dafoltop/karakeep.yaml";
      };
    in
    {
      options.dafos.services.karakeep.enable = lib.mkEnableOption "Karakeep";

      config = lib.mkIf config.dafos.services.karakeep.enable (
        lib.mkMerge [
          {
            sops.secrets = lib.mkMerge [
              (secret "nextauth-secret")
              (secret "meili-master-key")
              (secret "authelia/client-secret")
            ];

            nps.stacks.karakeep = {
              enable = true;

              nextauthSecretFile = config.sops.secrets."karakeep/nextauth-secret".path;
              meiliMasterKeyFile = config.sops.secrets."karakeep/meili-master-key".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."karakeep/authelia/client-secret".path;
              };

              containers.karakeep = {
                expose = true;
                # Authelia's karakeep_user group is the gate, so OIDC signups
                # stay open (the first account becomes admin). The mobile app
                # logs in with an API key from the web settings.
                environment.DISABLE_PASSWORD_AUTH = "true";
              };
            };
          }

          # nps builds the well-known URL from the *local* authelia container,
          # which does not exist where Authelia is a peer's (see ./papra.nix).
          # It is a plain string, so the whole environment is restated (as in
          # ./kitchenowl.nix). Recheck it against nps's module after a bump.
          (lib.mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.karakeep = {
              wantsContainer = lib.mkForce [ ];
              extraEnv = lib.mkForce {
                NEXTAUTH_SECRET.fromFile = cfg.nextauthSecretFile;
                MEILI_MASTER_KEY.fromFile = cfg.meiliMasterKeyFile;
                OAUTH_WELLKNOWN_URL = "https://auth.${config.nps.stacks.traefik.domain}/.well-known/openid-configuration";
                OAUTH_CLIENT_ID = "karakeep";
                OAUTH_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
                OAUTH_PROVIDER_NAME = "Authelia";
              };
            };
          })
        ]
      );
    };
}
