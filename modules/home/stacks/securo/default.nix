# nps-style stack module for Securo, following the conventions of the stacks
# shipped by nix-podman-stacks. Shape and naming mirror `nps/modules/papra`
# (OIDC) and the local bookorbit stack (Postgres sidecar), so it can be lifted
# upstream as-is if a stack ever lands there.
#
# Securo is five processes from two images: the nginx frontend (serves the SPA
# and proxies `/api`), the FastAPI backend, a Celery worker and a Celery beat,
# plus Postgres and Redis. Only the frontend is routed by Traefik.
{
  config,
  lib,
  inputs,
  ...
}:

let
  name = "securo";
  backendName = "${name}-backend";
  workerName = "${name}-worker";
  beatName = "${name}-beat";
  dbName = "${name}-db";
  redisName = "${name}-redis";

  storage = "${config.nps.storageBaseDir}/${name}";

  cfg = config.nps.stacks.${name};

  category = "Finance";
  description = "Personal Finance Manager";
  displayName = "Securo";

  serviceUrl = config.services.podman.containers.${name}.traefik.serviceUrl;
  dbEnv = config.services.podman.containers.${dbName}.extraEnv;

  secretFileOpt =
    what:
    lib.mkOption {
      type = lib.types.path;
      description = "File containing ${what}. Keep it out of the nix store.";
    };

  # Mounted into the backend, worker and beat alike (the Celery tasks do the
  # bank syncs). The three share one image, so they share one env.
  backendEnv = {
    DATABASE_URL.fromTemplate = "postgresql+asyncpg://${dbEnv.POSTGRES_USER}:{{ file.Read `${cfg.dbPasswordFile}` }}@${dbName}:5432/${dbEnv.POSTGRES_DB}";
    REDIS_URL = "redis://${redisName}:6379/0";
    SECRET_KEY.fromFile = cfg.secretKeyFile;
    FRONTEND_URL = serviceUrl;

    # Traefik -> nginx frontend -> backend: two hops sit between the client and
    # the backend. Rate limiting keys on the client IP, and with too low a value
    # every client shares Traefik's bucket.
    TRUSTED_PROXY_HOPS = 2;

    TESOURO_DIRETO_ENABLED = lib.boolToString cfg.tesouroDireto;

    STORAGE_LOCAL_PATH = "/app/data/attachments";
    AGENTS_KNOWLEDGE_STORAGE_PATH = "/app/data/agent_knowledge";
    AGENTS_ENABLED = "false";
  }
  // lib.optionalAttrs (cfg.enableBanking.appId != null) {
    ENABLE_BANKING_APP_ID = cfg.enableBanking.appId;
    ENABLE_BANKING_PRIVATE_KEY_FILE = "/app/secrets/enable_banking_private.pem";
  }
  // lib.optionalAttrs cfg.oidc.enable {
    OIDC_ENABLED = "true";
    OIDC_PROVIDER_NAME = "Authelia";
    OIDC_DISCOVERY_URL = "${config.nps.containers.authelia.traefik.serviceUrl}/.well-known/openid-configuration";
    OIDC_CLIENT_ID = name;
    OIDC_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
    OIDC_SCOPES = "openid email profile";
    OIDC_AUTO_REGISTER = "true";
    LOCAL_AUTH_ENABLED = lib.boolToString (!cfg.oidc.disableLocalAuth);
  };

  backendVolumes = {
    attachments = "${storage}/attachments:/app/data/attachments";
    agentKnowledge = "${storage}/agent_knowledge:/app/data/agent_knowledge";
  }
  // lib.optionalAttrs (cfg.enableBanking.privateKeyFile != null) {
    enableBankingKey = "${cfg.enableBanking.privateKeyFile}:/app/secrets/enable_banking_private.pem:ro";
  };
in
{
  imports = import "${inputs.nix-podman-stacks}/modules/mkAliases.nix" config lib name [
    name
    backendName
    workerName
    beatName
    dbName
    redisName
  ];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;

    dbPasswordFile = secretFileOpt "the PostgreSQL password";
    secretKeyFile = secretFileOpt "the application secret key (signs sessions and encrypts stored bank credentials)";

    tesouroDireto = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Look up Brazilian Treasury bond prices. Upstream turns this on by default
        and pulls a CSV from a Brazilian government endpoint; it is off here
        because nothing in this fleet holds Tesouro Direto bonds.
      '';
    };

    enableBanking = {
      appId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Application ID of the Enable Banking app. Create a production
          application at <https://enablebanking.com> with `<serviceUrl>/oauth/callback`
          as the redirect URL. Leave null to run without PSD2 bank sync (CSV,
          OFX, QIF and CAMT imports still work).
        '';
      };
      privateKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          The PEM private key Enable Banking generated for the application.
          Required whenever {option}`appId` is set.
        '';
      };
    };

    oidc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable OIDC login with Authelia. This registers a confidential
          OIDC client in Authelia, creates its LLDAP group and turns on
          auto-registration, so a user of {option}`userGroup` gets an account on
          first login.
        '';
      };
      inherit ((import "${inputs.nix-podman-stacks}/modules/authelia/options.nix" lib)) clientSecretFile;
      clientSecretHash = (import "${inputs.nix-podman-stacks}/modules/authelia/options.nix" lib).derivableClientSecretHash cfg.oidc.clientSecretFile;
      userGroup = lib.mkOption {
        type = lib.types.str;
        default = "${name}_user";
        description = ''
          Users of this LLDAP group will be able to log in. Securo has no way to
          refuse a user that is in no group, so the gating happens in the Authelia
          authorization policy.
        '';
      };
      disableLocalAuth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Reject username/password sign-in, leaving OIDC as the only way in. Leave
          it off until an OIDC login has worked once, and turn it back off to
          recover access if Authelia is down.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.enableBanking.appId != null) == (cfg.enableBanking.privateKeyFile != null);
        message = "nps.stacks.securo.enableBanking: appId and privateKeyFile must be set together.";
      }
    ];

    nps.stacks.lldap.bootstrap.groups = lib.mkIf cfg.oidc.enable {
      ${cfg.oidc.userGroup} = { };
    };

    nps.stacks.authelia = lib.mkIf cfg.oidc.enable {
      oidc.clients.${name} = {
        client_name = displayName;
        client_secret = cfg.oidc.clientSecretHash;
        public = false;
        authorization_policy = name;
        require_pkce = true;
        pkce_challenge_method = "S256";
        # Securo posts `client_secret` in the token request body.
        token_endpoint_auth_method = "client_secret_post";
        pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
        redirect_uris = [ "${serviceUrl}/api/auth/oidc/callback" ];
        scopes = [
          "openid"
          "profile"
          "email"
        ];
      };

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
      # nginx: serves the SPA and proxies /api to the backend.
      ${name} = {
        # renovate: versioning=semver
        image = "ghcr.io/securo-finance/securo-frontend:0.16.2";

        extraEnv = {
          BACKEND_URL = "http://${backendName}:8000";
          FRONTEND_URL = serviceUrl;
        };

        dependsOnContainer = [ backendName ];
        stack = name;

        port = 8080;
        traefik.name = name;

        dashboard = {
          inherit category description;
          name = displayName;
          icon = "mdi:piggy-bank";
        };
      };

      ${backendName} = {
        # renovate: versioning=semver
        image = "ghcr.io/securo-finance/securo-backend:0.16.2";
        exec = ''sh -c "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"'';

        volumeMap = backendVolumes;
        extraEnv = backendEnv;

        dependsOnContainer = [
          dbName
          redisName
        ];
        stack = name;
        dashboard = {
          inherit category;
          name = "${displayName} API";
          icon = "mdi:piggy-bank";
          parent = name;
        };
      };

      ${workerName} = {
        # renovate: versioning=semver
        image = "ghcr.io/securo-finance/securo-backend:0.16.2";
        exec = "celery -A app.worker worker --loglevel=info --concurrency=2";

        volumeMap = backendVolumes;
        extraEnv = backendEnv;

        # The backend runs the migrations; a worker that starts first would hit
        # a schema that is not there yet.
        dependsOnContainer = [
          dbName
          redisName
          backendName
        ];
        stack = name;
        dashboard = {
          inherit category;
          name = "${displayName} Worker";
          icon = "mdi:piggy-bank";
          parent = name;
        };
      };

      ${beatName} = {
        # renovate: versioning=semver
        image = "ghcr.io/securo-finance/securo-backend:0.16.2";
        exec = "celery -A app.worker beat --loglevel=info";

        extraEnv = backendEnv;

        dependsOnContainer = [
          dbName
          redisName
          backendName
        ];
        stack = name;
        dashboard = {
          inherit category;
          name = "${displayName} Scheduler";
          icon = "mdi:piggy-bank";
          parent = name;
        };
      };

      ${dbName} = {
        # pgvector is a drop-in for postgres:16; the agents knowledge-base
        # migration needs the extension even with agents switched off.
        image = "docker.io/pgvector/pgvector:pg16";
        volumeMap.data = "${storage}/db:/var/lib/postgresql/data";

        # Keep the database off the unattended Sunday registry pull (see the
        # grimmory module for the full reasoning).
        autoUpdate = "local";

        extraEnv = {
          POSTGRES_DB = name;
          POSTGRES_USER = name;
          POSTGRES_PASSWORD.fromFile = cfg.dbPasswordFile;
          PGDATA = "/var/lib/postgresql/data/pgdata";
        };

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "pg_isready -U ${name} -d ${name}";
          HealthInterval = "10s";
          HealthTimeout = "5s";
          HealthRetries = 10;
          HealthStartPeriod = "20s";
          HealthOnFailure = "kill";
        };

        stack = name;
        dashboard = {
          inherit category;
          name = "PostgreSQL";
          icon = "si:postgresql";
          parent = name;
        };
      };

      ${redisName} = {
        image = "docker.io/library/redis:8-alpine";
        autoUpdate = "local";

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "redis-cli ping";
          HealthInterval = "10s";
          HealthTimeout = "5s";
          HealthRetries = 10;
          HealthOnFailure = "kill";
        };

        stack = name;
        dashboard = {
          inherit category;
          name = "Redis";
          icon = "si:redis";
          parent = name;
        };
      };
    };
  };
}
