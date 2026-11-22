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
                environment = {
                  DISABLE_PASSWORD_AUTH = "true";

                  # Auto-tagging through dafoltop's Ollama, over the LAN (its
                  # firewall lets dafpi alone in): text with the model norish
                  # already uses, images with a small vision model pulled for
                  # karakeep alone. Embeddings stay off: karakeep only
                  # enables them by default with OpenAI.
                  OLLAMA_BASE_URL = "http://192.168.0.10:11434";
                  INFERENCE_TEXT_MODEL = "qwen2.5:7b";
                  INFERENCE_IMAGE_MODEL = "qwen2.5vl:3b";
                  INFERENCE_LANG = "french";
                  # A 7B on the i7-8550U's CPU, plus the model load after
                  # Ollama's 5 min keep-alive: well past the 30 s default.
                  # Measured 2026-11-07: ~2 min 10 s per link, so a bulk
                  # re-tag of N bookmarks takes about 2·N minutes.
                  INFERENCE_JOB_TIMEOUT_SEC = "600";
                  # Default context is 2048 tokens: Ollama then silently drops
                  # the start of the prompt, i.e. the tagging rules, and the
                  # model answers with dozens of English tags. Rules + page
                  # need more room.
                  INFERENCE_CONTEXT_LENGTH = "4096";
                  # The tagging rules (categories, hints) are set by hand in
                  # the web UI (Settings → AI), not here: the UI caps each
                  # rule at 500 characters, so split long ones.
                };
              };

              # Meilisearch owns the search index on disk: keep it off the
              # unattended Sunday registry pull like every other database here
              # (see ./bar-assistant.nix), even though nps pins its tag.
              containers.karakeep-meilisearch.autoUpdate = "local";
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
