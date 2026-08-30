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

    enablePasswordLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the email/password login form is offered. Set to false to leave
        only the SSO buttons — do this after every account has been linked, or
        nobody can get in.
      '';
    };

    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en-US";
      description = "Locale Salt Rim starts in before a user picks their own.";
    };

    oidc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable OIDC login with Authelia. This will register an OIDC
          client in Authelia and set up the necessary configuration.

          Bar Assistant matches the SSO identity to a local account **by email
          address**, so an Authelia user whose email matches an existing account
          is linked to it rather than getting a second one.

          For details, see <https://docs.barassistant.app/setup/sso/>
        '';
      };

      inherit ((import "${inputs.nix-podman-stacks}/modules/authelia/options.nix" lib)) clientSecretFile;
      clientSecretHash = (import "${inputs.nix-podman-stacks}/modules/authelia/options.nix" lib).derivableClientSecretHash cfg.oidc.clientSecretFile;

      userGroup = lib.mkOption {
        type = lib.types.str;
        default = "${name}_user";
        description = "Users of this group will be able to log in";
      };

      redirectToSso = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Skip the Salt Rim login page and start the SSO flow immediately.
          Only takes effect when exactly one provider is configured.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nps.stacks.lldap.bootstrap.groups = lib.mkIf cfg.oidc.enable {
      ${cfg.oidc.userGroup} = { };
    };

    nps.stacks.authelia = lib.mkIf cfg.oidc.enable {
      oidc.clients.${name} = {
        client_name = displayName;
        client_secret = cfg.oidc.clientSecretHash;
        public = false;
        authorization_policy = name;
        # Laravel Socialite drives this flow: no PKCE, and it puts the client
        # credentials in the token request body rather than the Basic header.
        require_pkce = false;
        pkce_challenge_method = "";
        token_endpoint_auth_method = "client_secret_post";
        pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
        scopes = [
          "openid"
          "profile"
          "email"
          "groups"
        ];
        # Salt Rim owns the callback route: it pulls the `code` out of the URL
        # and hands it to the API, which does the token exchange.
        redirect_uris = [ "${cfg.containers.${saltRimName}.traefik.serviceUrl}/oauth/callback" ];
      };

      # Bar Assistant links accounts by email and has no group-based RBAC of its
      # own, so access is gated on the Authelia side.
      settings.identity_providers.oidc.authorization_policies.${name} = {
        default_policy = "deny";
        rules = [
          {
            policy = config.nps.stacks.authelia.defaultAllowPolicy;
            subject = "group:${cfg.oidc.userGroup}";
          }
        ];
      };
    };

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
          ENABLE_PASSWORD_LOGIN = lib.boolToString cfg.enablePasswordLogin;
        };

        extraEnv = {
          MEILISEARCH_KEY.fromFile = cfg.meiliMasterKeyFile;
        }
        // lib.optionalAttrs cfg.oidc.enable {
          # The API does the token exchange and the userinfo call server-side,
          # so it reaches Authelia the same way a browser would.
          AUTHELIA_BASE_URL = config.nps.containers.authelia.traefik.serviceUrl;
          AUTHELIA_CLIENT_ID = name;
          AUTHELIA_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
          AUTHELIA_REDIRECT_URI = "${cfg.containers.${saltRimName}.traefik.serviceUrl}/oauth/callback";
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
          REDIRECT_TO_SSO = lib.boolToString (cfg.oidc.enable && cfg.oidc.redirectToSso);
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
