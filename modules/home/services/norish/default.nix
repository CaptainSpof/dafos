{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkForce
    mkIf
    types
    ;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.norish;
in
{

  options.${namespace}.services.norish = {
    enable = mkEnableOption "Whether or not to configure norish.";
    subDomain = mkOpt types.str "norish" "The base url";

    ai = {
      enable = mkEnableOption "AI features, backed by an OpenAI-compatible or Ollama endpoint";
      provider = mkOpt (types.enum [
        "openai"
        "ollama"
        "lm-studio"
        "generic-openai"
      ]) "ollama" "Value for AI_PROVIDER.";
      endpoint =
        mkOpt types.str "http://host.containers.internal:11434"
          "Value for AI_ENDPOINT. The default points at the host `dafos.services.ollama`, which must therefore set `openFirewallForPodman` and a non-loopback `host`.";
      model = mkOpt types.str "qwen2.5:7b" "Value for AI_MODEL.";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "norish/master-key" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/norish.yaml";
      };
      "norish/db-password" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/norish.yaml";
      };
      "norish/authelia/client-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/norish.yaml";
      };
    };

    # Upstream botched the v0.22.0-beta publish (norish-recipes/norish#543).
    # The `v0.22.0-beta` tag on Docker Hub is a single arm64 manifest *and* it
    # isn't even 0.22 code -- it reports NORISH_VERSION_REPORT_JSON root
    # "0.21.0-beta" and has zero references to cookbooks, 0.22's headline
    # feature. On x86_64 it dies instantly with "exec container process
    # (missing dynamic library?) `/usr/local/bin/docker-entrypoint.sh`".
    #
    # `rc-v0.23.0-beta` is the only published multi-arch image that actually
    # carries the 0.22 feature set (526 cookbook references in dist-server; it
    # self-reports 0.23.0-beta because main was already bumped past the
    # release). Pinned by digest because upstream demonstrably re-pushes tags
    # in place. Drop this once nps points at a fixed v0.22.x/v0.23.0 tag.
    services.podman.containers.norish.image =
      mkForce "docker.io/norishapp/norish:rc-v0.23.0-beta@sha256:5661df97096659e5debf21535e651ffd7f408b9a4d334b72409b5885f9be320f";

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

    nps.stacks = {
      norish = {
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
      };
    };

  };
}
