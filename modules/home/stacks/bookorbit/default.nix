# nps-style stack module for BookOrbit, following the conventions of the
# stacks shipped by nix-podman-stacks. Shape and naming deliberately mirror
# `nps/modules/grimmory`, so this can be lifted upstream as-is if a stack ever
# lands there.
{
  config,
  lib,
  inputs,
  ...
}:

let
  name = "bookorbit";
  dbName = "${name}-db";

  storage = "${config.nps.storageBaseDir}/${name}";

  cfg = config.nps.stacks.${name};

  category = "Media & Downloads";
  description = "Reading Space";
  displayName = "BookOrbit";

  containerCfg = config.services.podman.containers.${name};

  dbEnv = config.services.podman.containers.${dbName}.extraEnv;

  bookDockPath = "/book-dock";

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
    jwtSecretFile = secretFileOpt "the JWT signing secret";
    setupBootstrapTokenFile = secretFileOpt "the first-run setup bootstrap token";

    # Encrypt-at-rest keys for credentials BookOrbit stores in its database
    # (SMTP, migration sources, download clients). They have to be in place
    # *before* the first credential is saved -- adding one later leaves the
    # already-stored secrets unreadable -- so all three are required up front
    # even though the features are opt-in.
    emailEncryptionKeyFile = secretFileOpt "the SMTP credentials encryption key";
    migrationEncryptionKeyFile = secretFileOpt "the migration sources encryption key";
    bookRequestEncryptionKeyFile = secretFileOpt "the download clients encryption key";

    libraries = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Library bind mounts, as an attrset of `volumeMap` entries. These are the
        trees the admin can pick from when creating a library in the web UI.
      '';
    };

    libraryBrowseRoot = lib.mkOption {
      type = lib.types.str;
      default = "/";
      description = ''
        Container path the library folder picker starts at. Defaults to `/` so
        every mount in {option}`libraries` is reachable; set it to a single mount
        to hide the rest of the container root.
      '';
    };

    bookDock = lib.mkOption {
      type = lib.types.str;
      default = "${storage}/book-dock";
      description = ''
        Host directory mounted as BookOrbit's book dock (its drop folder for
        files to be imported).
      '';
    };

    trustProxy = lib.mkOption {
      type = lib.types.str;
      default = "true";
      description = ''
        Value for `TRUST_PROXY`. The container port is never published to the
        host -- only Traefik can reach it over the stack network -- so trusting
        the proxy unconditionally is what gets real client IPs into the rate
        limiter and the audit log.
      '';
    };

    nodeMaxOldSpaceSize = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = ''
        Node heap limit in MB, or `auto` to derive it from the cgroup limit.
        Raise it for very large (250k+ book) libraries.
      '';
    };

    disableLocalAuth = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Reject username/password sign-in, leaving OIDC as the only way in.
        Only turn this on *after* an administrator account has been linked to
        the OIDC provider -- BookOrbit refuses to start otherwise -- and turn it
        back off to recover access if Authelia is down.
      '';
    };

    oidc = {
      registerClient = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to register a BookOrbit OIDC client in Authelia and create its
          LLDAP group.

          BookOrbit has no env-based OIDC configuration: the provider is created
          in the web UI under Settings => Admin => OIDC / SSO. Register the
          client here, then fill the UI in with:

          - Issuer URI: the Authelia base URL
          - Client ID: `bookorbit` (no client secret -- this is a public
            PKCE client)
          - Scopes: `openid profile email groups`

          The redirect URI BookOrbit sends is `<serviceUrl>/oauth2-callback`,
          which is what gets registered below.
        '';
      };

      userGroup = lib.mkOption {
        type = lib.types.str;
        default = "${name}_user";
        description = ''
          Users of this LLDAP group will be able to log in. BookOrbit itself has
          no way to refuse a user that is in no group, so the gating happens in
          the Authelia authorization policy.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nps.stacks.lldap.bootstrap.groups = lib.mkIf cfg.oidc.registerClient {
      ${cfg.oidc.userGroup} = { };
    };

    nps.stacks.authelia = lib.mkIf cfg.oidc.registerClient {
      oidc.clients.${name} = {
        client_name = displayName;

        # BookOrbit always sends an S256 challenge and omits `client_secret`
        # entirely when none is configured, so it is a textbook public client.
        public = true;
        require_pkce = true;
        pkce_challenge_method = "S256";

        authorization_policy = name;
        pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
        redirect_uris = [ "${containerCfg.traefik.serviceUrl}/oauth2-callback" ];
        scopes = [
          "openid"
          "offline_access"
          "profile"
          "email"
          "groups"
        ];
        claims_policy = name;
        response_types = [ "code" ];
        grant_types = [
          "authorization_code"
          "refresh_token"
        ];
      };

      # BookOrbit merges the id_token claims with whatever /userinfo returns,
      # so groups would arrive either way -- but the group mappings are synced
      # on every login, and putting `groups` in the id_token keeps that working
      # even when the userinfo call fails.
      settings.identity_providers.oidc.claims_policies.${name}.id_token = [
        "email"
        "email_verified"
        "preferred_username"
        "name"
        "groups"
      ];

      settings.identity_providers.oidc.authorization_policies.${name} = {
        default_policy = "deny";
        rules = [
          {
            policy = config.nps.stacks.authelia.defaultAllowPolicy;
            subject = [ "group:${cfg.oidc.userGroup}" ];
          }
        ];
      };
    };

    services.podman.containers = {
      ${name} = {
        image = "ghcr.io/bookorbit/bookorbit:3.1.0";

        volumeMap = cfg.libraries // {
          data = "${storage}/data:/data";
          bookDock = "${cfg.bookDock}:${bookDockPath}";
        };

        extraEnv = {
          PUID = config.nps.defaultUid;
          PGID = config.nps.defaultGid;

          APP_URL = containerCfg.traefik.serviceUrl;
          TRUST_PROXY = cfg.trustProxy;
          NODE_MAX_OLD_SPACE_SIZE = cfg.nodeMaxOldSpaceSize;

          POSTGRES_HOST = dbName;
          POSTGRES_PORT = 5432;
          inherit (dbEnv) POSTGRES_USER;
          inherit (dbEnv) POSTGRES_DB;
          POSTGRES_PASSWORD.fromFile = cfg.dbPasswordFile;

          JWT_SECRET.fromFile = cfg.jwtSecretFile;
          SETUP_BOOTSTRAP_TOKEN.fromFile = cfg.setupBootstrapTokenFile;
          EMAIL_ENCRYPTION_KEY.fromFile = cfg.emailEncryptionKeyFile;
          MIGRATION_ENCRYPTION_KEY.fromFile = cfg.migrationEncryptionKeyFile;
          BOOK_REQUEST_ENCRYPTION_KEY.fromFile = cfg.bookRequestEncryptionKeyFile;

          BOOK_DOCK_PATH = bookDockPath;
          LIBRARY_BROWSE_ROOT = cfg.libraryBrowseRoot;
          DISABLE_LOCAL_AUTH = lib.boolToString cfg.disableLocalAuth;
        }
        // lib.optionalAttrs cfg.oidc.registerClient {
          # Authelia resolves to a LAN address from inside the container, and
          # BookOrbit refuses private issuer/discovery URLs by default.
          OIDC_ALLOW_LOCAL_ISSUERS = "true";
        };

        dependsOnContainer = [ dbName ];
        stack = name;

        port = 3000;
        traefik = {
          inherit name;
          subDomain = lib.mkDefault name;
        };

        extraConfig.Container = {
          # Upstream's own compose runs the app read-only: everything it writes
          # goes to the /data bind mount or to $HOME, which its entrypoint
          # points at /tmp.
          ReadOnly = true;
          Tmpfs = "/tmp";
          NoNewPrivileges = true;
        };

        homepage = {
          inherit category;
          name = displayName;
          settings = {
            inherit description;
            icon = "sh-bookorbit";
          };
        };
        glance = {
          inherit category description;
          name = displayName;
          id = name;
          icon = "sh:bookorbit";
        };
      };

      ${dbName} = {
        # BookOrbit needs the `uuid-ossp`, `pg_trgm` and `vector` extensions,
        # which rules out a plain `postgres` image.
        image = "docker.io/pgvector/pgvector:pg18";
        volumeMap.data = "${storage}/db:/var/lib/postgresql/data";

        # Keep the database off the unattended Sunday registry pull (see the
        # grimmory module for the full reasoning): `pgvector:pg18` is a moving
        # tag, and this one also carries the pgvector extension build.
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
        glance = {
          parent = name;
          name = "PostgreSQL";
          icon = "si:postgresql";
          inherit category;
        };
      };
    };
  };
}
