# nps-style stack module for LiteLLM, an OpenAI-compatible proxy in front of
# any LLM backend, with a Postgres-backed request log and an admin UI (/ui).
# Shape follows nps's bookorbit stack (Postgres sidecar).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  name = "litellm";
  dbName = "${name}-db";

  storage = "${config.nps.storageBaseDir}/${name}";
  cfg = config.nps.stacks.${name};
  dbEnv = config.services.podman.containers.${dbName}.extraEnv;

  yaml = pkgs.formats.yaml { };

  secretFileOpt =
    what:
    lib.mkOption {
      type = lib.types.path;
      description = "File containing ${what}. Keep it out of the nix store.";
    };
in
{
  imports = import "${inputs.nix-podman-stacks}/modules/mkAliases.nix" config lib name [
    name
    dbName
  ];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;

    dbPasswordFile = secretFileOpt "the PostgreSQL password";
    masterKeyFile = secretFileOpt "the master key (`sk-…`), the API admin credential";

    settings = lib.mkOption {
      inherit (yaml) type;
      default = { };
      apply = settings: yaml.generate "config.yaml" settings;
      description = ''
        LiteLLM's `config.yaml` (model_list, litellm_settings, general_settings).
        The master key and database URL come from the environment.

        See <https://docs.litellm.ai/docs/proxy/configs>
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.podman.containers = {
      ${name} = {
        # renovate: versioning=semver
        image = "ghcr.io/berriai/litellm:1.110.3";
        exec = "--config /app/config.yaml --port 4000";
        port = 4000;

        volumeMap.config = "${cfg.settings}:/app/config.yaml:ro";

        extraEnv = {
          DATABASE_URL.fromTemplate = "postgresql://${dbEnv.POSTGRES_USER}:{{ file.Read `${cfg.dbPasswordFile}` }}@${dbName}:5432/${dbEnv.POSTGRES_DB}";
          LITELLM_MASTER_KEY.fromFile = cfg.masterKeyFile;
        };

        dependsOnContainer = [ dbName ];
        stack = name;

        traefik.name = name;

        dashboard = {
          category = "AI";
          name = "LiteLLM";
          description = "LLM proxy & request log";
          icon = "di:litellm";
        };
      };

      ${dbName} = {
        image = "docker.io/postgres:17";
        volumeMap.data = "${storage}/db:/var/lib/postgresql/data";

        # Keep the database off the unattended registry pull (see grimmory).
        autoUpdate = "local";

        extraEnv = {
          POSTGRES_DB = name;
          POSTGRES_USER = name;
          POSTGRES_PASSWORD.fromFile = cfg.dbPasswordFile;
        };

        stack = name;
        dashboard = {
          category = "AI";
          name = "LiteLLM DB";
          icon = "di:postgres";
          parent = name;
        };
      };
    };
  };
}
