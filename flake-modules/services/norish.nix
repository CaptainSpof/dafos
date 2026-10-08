# Norish (nps stack): recipes, OIDC through Authelia, public, AI recipe
# enrichment through the host's Ollama (flake-modules/services/ollama).
# Runs on dafpi: its OIDC client and lldap group are served by dafoltop's
# Authelia/lldap through authelia-peers, and the public route goes through
# dafoltop's Traefik (traefik peers).
{ inputs, ... }:
{
  flake.modules.homeManager.norish =
    { config, lib, ... }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
      opt =
        type: default: description:
        mkOption { inherit type default description; };

      cfg = config.dafos.services.norish;
      stack = config.nps.stacks.norish;
      secret = name: {
        "norish/${name}".sopsFile = inputs.self + "/secrets/dafoltop/norish.yaml";
      };
    in
    {
      options.dafos.services.norish = {
        enable = mkEnableOption "Whether or not to configure norish.";
        subDomain = opt types.str "recette" "The base url";
        aliases = opt (types.listOf types.str) [ "norish" ] "Subdomains that redirect to `subDomain`.";

        ai = {
          enable = mkEnableOption "AI features, backed by an OpenAI-compatible or Ollama endpoint";
          provider = opt (types.enum [
            "openai"
            "ollama"
            "lm-studio"
            "generic-openai"
          ]) "ollama" "Value for AI_PROVIDER.";
          endpoint =
            opt types.str "http://host.containers.internal:11434"
              "Value for AI_ENDPOINT. The default points at the host's `dafos.services.ollama`, which must therefore set `openFirewallForPodman` and a non-loopback `host`.";
          model = opt types.str "qwen2.5:7b" "Value for AI_MODEL.";
        };
      };

      config = mkIf cfg.enable (
        lib.mkMerge [
          {
            dafos.services.traefik.redirects = lib.genAttrs cfg.aliases (_: {
              to = cfg.subDomain;
              expose = true;
            });

            sops.secrets = lib.mkMerge [
              (secret "master-key")
              (secret "db-password")
              (secret "authelia/client-secret")
            ];

            # nps has no AI options, so the AI_* env is set on the container directly.
            #
            # CAREFUL: these are seeds, not settings. The live config is the Postgres
            # row `server_config/ai_config`; on boot `seedMissingConfigs()` inserts it
            # from AI_* only `if (!await configExists(key))`. Once the row exists the
            # env is ignored forever, so editing the options below (or in Settings =>
            # Admin, which writes the same row) diverges silently. To make a changed
            # option take effect, delete the row and restart the container:
            #
            #   podman exec norish-db psql -U norish -d norish \
            #     -c "delete from server_config where key = 'ai_config';"
            #   systemctl --user restart podman-norish.service
            services.podman.containers.norish.extraEnv = mkIf cfg.ai.enable {
              AI_ENABLED = true;
              AI_PROVIDER = cfg.ai.provider;
              AI_ENDPOINT = cfg.ai.endpoint;
              AI_MODEL = cfg.ai.model;
            };

            nps.stacks.norish = {
              enable = true;

              masterKeyFile = config.sops.secrets."norish/master-key".path;
              db.passwordFile = config.sops.secrets."norish/db-password".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."norish/authelia/client-secret".path;
              };

              containers.norish = {
                expose = true;
                traefik.subDomain = cfg.subDomain;
              };

              # Keep the stateful containers off the unattended Sunday registry pull
              # (see the grimmory module for the full reasoning): `postgres:18` and
              # `redis:8` are moving tags, so `registry` would restart the database
              # and cache on whatever upstream published that week.
              containers.norish-db.autoUpdate = "local";
              containers.norish-redis.autoUpdate = "local";
            };
          }

          # nps builds the issuer from the *local* authelia container, which
          # does not exist where Authelia is a peer's (see ./papra.nix). It is
          # a plain string, so overriding that one variable would still
          # evaluate it: the whole environment is restated instead (as in
          # ./kaneo.nix). Recheck it against nps's module after a bump.
          (mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.norish = {
              wantsContainer = lib.mkForce [ "norish-browser" ];
              extraEnv = lib.mkForce (
                {
                  AUTH_URL = config.services.podman.containers.norish.traefik.serviceUrl;
                  DATABASE_URL.fromTemplate = "postgres://${stack.db.username}:{{ file.Read `${stack.db.passwordFile}` }}@norish-db/norish?sslmode=disable";
                  MASTER_KEY.fromFile = stack.masterKeyFile;
                  REDIS_URL = "redis://norish-redis:6379";
                  OBSCURA_ENDPOINT = "ws://norish-browser:9222";

                  OIDC_NAME = "Authelia";
                  OIDC_ISSUER = "https://auth.${config.nps.stacks.traefik.domain}";
                  OIDC_CLIENT_ID = "norish";
                  OIDC_CLIENT_SECRET.fromFile = stack.oidc.clientSecretFile;

                  OIDC_CLAIM_MAPPING_ENABLED = true;
                  OIDC_SCOPES = "groups";
                  OIDC_GROUPS_CLAIM = "groups";
                  OIDC_ADMIN_GROUP = stack.oidc.adminGroup;
                }
                // lib.optionalAttrs cfg.ai.enable {
                  AI_ENABLED = true;
                  AI_PROVIDER = cfg.ai.provider;
                  AI_ENDPOINT = cfg.ai.endpoint;
                  AI_MODEL = cfg.ai.model;
                }
              );
            };
          })
        ]
      );
    };
}
