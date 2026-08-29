# nps-style stack module for Bar Assistant, following the conventions of the
# stacks shipped by nix-podman-stacks (see e.g. its karakeep/norish modules).
#
# Mirrors the upstream reference compose file:
# <https://docs.barassistant.app/setup/>
{
  config,
  lib,
  inputs,
  ...
}:

let
  name = "bar-assistant";
  saltRimName = "${name}-salt-rim";
  meilisearchName = "${name}-meilisearch";
  redisName = "${name}-redis";

  storage = "${config.nps.storageBaseDir}/${name}";

  cfg = config.nps.stacks.${name};

  category = "General";
  displayName = "Bar Assistant";
  description = "Cocktail recipes and bar inventory";
in
{
  imports = import "${inputs.nix-podman-stacks}/modules/mkAliases.nix" config lib name [
    name
    saltRimName
    meilisearchName
    redisName
  ];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;

    meiliMasterKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the raw Meilisearch master key (no `KEY=` prefix).
        Used both as `MEILI_MASTER_KEY` for Meilisearch and as `MEILISEARCH_KEY`
        for the Bar Assistant server, which derives per-bar scoped search tokens
        from it.

        Generate one with `openssl rand -base64 32`.
      '';
    };

    allowRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether anyone reaching the instance may create an account.";
    };

    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en-US";
      description = "Locale Salt Rim starts in before a user picks their own.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.podman.containers = {
      # API server. Its entrypoint runs the Laravel migrations, (re)generates
      # the Meilisearch scoped tokens and publishes the starter media on every
      # start, so it must come up after Meilisearch is actually answering.
      ${name} = {
        # renovate: versioning=semver
        image = "docker.io/barassistant/server:6.5.0";

        # The SQLite database (`database.ba3.sqlite`) and the uploads live here.
        volumeMap.data = "${storage}/data:/var/www/cocktails/storage/bar-assistant";

        environment = {
          APP_URL = cfg.containers.${name}.traefik.serviceUrl;
          MEILISEARCH_HOST = "http://${meilisearchName}:7700";
          REDIS_HOST = redisName;
          CACHE_DRIVER = "redis";
          SESSION_DRIVER = "redis";
          ALLOW_REGISTRATION = lib.boolToString cfg.allowRegistration;
        };

        extraEnv = {
          MEILISEARCH_KEY.fromFile = cfg.meiliMasterKeyFile;
        };

        # serversideup/php:8.4-fpm-nginx is Debian based, so the image runs as
        # www-data = 33:33. Map the host user onto it so the bind-mounted
        # storage directory (owned by the host user) stays writable.
        extraConfig.Container.UserNS = "keep-id:uid=33,gid=33";

        dependsOnContainer = [
          meilisearchName
          redisName
        ];

        stack = name;
        port = 8080;
        traefik = {
          inherit name;
          subDomain = lib.mkDefault "bar-api";
        };
        glance = {
          inherit category;
          name = "API";
          parent = name;
          icon = "di:bar-assistant";
        };
      };

      # Web client. A static SPA: it talks to the API and to Meilisearch from
      # the browser, so both of those have to be reachable by the client too.
      ${saltRimName} = {
        # renovate: versioning=semver
        image = "docker.io/barassistant/salt-rim:5.4.0";

        environment = {
          API_URL = cfg.containers.${name}.traefik.serviceUrl;
          MEILISEARCH_URL = cfg.containers.${meilisearchName}.traefik.serviceUrl;
          DEFAULT_LOCALE = cfg.defaultLocale;
          ALLOW_REGISTRATION = lib.boolToString cfg.allowRegistration;
        };

        dependsOnContainer = [ name ];

        stack = name;
        port = 8080;
        traefik = {
          name = saltRimName;
          subDomain = lib.mkDefault "bar";
        };
        homepage = {
          inherit category;
          name = displayName;
          settings = {
            inherit description;
            icon = "bar-assistant";
          };
        };
        glance = {
          inherit category description;
          name = displayName;
          id = name;
          icon = "di:bar-assistant";
        };
      };

      ${meilisearchName} = {
        # renovate: versioning=semver
        # Pinned to the version the Bar Assistant docs deploy against.
        image = "docker.io/getmeili/meilisearch:v1.50.0";

        environment = {
          MEILI_ENV = "production";
          MEILI_NO_ANALYTICS = "true";
        };

        extraEnv = {
          MEILI_MASTER_KEY.fromFile = cfg.meiliMasterKeyFile;
        };

        volumeMap.data = "${storage}/meilisearch:/meili_data";

        # The server's entrypoint aborts if `bar:setup-meilisearch` cannot reach
        # Meilisearch, so gate its start on the health check rather than on the
        # process merely having been spawned.
        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "curl -fsS http://localhost:7700/health";
          HealthInterval = "10s";
          HealthTimeout = "10s";
          HealthRetries = 5;
          HealthStartPeriod = "10s";
          HealthOnFailure = "kill";
        };

        stack = name;
        port = 7700;
        traefik = {
          name = meilisearchName;
          subDomain = lib.mkDefault "bar-search";
        };
        glance = {
          inherit category;
          name = "Meilisearch";
          parent = name;
          icon = "di:meilisearch";
        };
      };

      # Cache and session store only — nothing here needs to survive a restart.
      ${redisName} = {
        image = "docker.io/redis:8";

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "redis-cli ping";
          HealthInterval = "10s";
          HealthTimeout = "10s";
          HealthRetries = 5;
          HealthStartPeriod = "10s";
          HealthOnFailure = "kill";
        };

        stack = name;
        glance = {
          inherit category;
          name = "Redis";
          parent = name;
          icon = "di:redis";
        };
      };
    };
  };
}
