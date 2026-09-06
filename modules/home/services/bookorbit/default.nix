{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.bookorbit;

  name = "bookorbit";
  dbName = "${name}-db";

  storage = "${config.nps.storageBaseDir}/${name}";

  category = "Media & Downloads";
  description = "Reading Space";
  displayName = "BookOrbit";

  # nix-podman-stacks has no upstream BookOrbit stack, so the containers are
  # declared here directly on top of the nps podman extension (`traefik`,
  # `glance`, `homepage`, `stack`, `extraEnv`, `volumeMap`). Shape and naming
  # deliberately mirror `nps/modules/grimmory`, so this can be lifted upstream
  # as-is if a stack ever lands there.
  containerCfg = config.services.podman.containers.${name};

  dbEnv = config.services.podman.containers.${dbName}.extraEnv;

  bookDockPath = "/book-dock";

  # nps orders containers after nothing but the network, so a container whose
  # `extraEnv.*.fromFile` points into /home/daf/.config/sops-nix races its own
  # secrets. Already-running services never notice (sops-nix has long since
  # run by the time a rebuild restarts them), but a *first* start in the same
  # activation that creates the secrets loses: `create-extra-files` logs "No
  # such file or directory", the variable comes out empty, and -- for postgres
  # -- initdb aborts with "superuser password is not specified".
  #
  # Wants rather than Requires: all that is missing is the ordering edge, and
  # sops-nix is a `RemainAfterExit=no` oneshot, so there is no long-lived unit
  # for a hard requirement to bind to.
  secretsDep = [ "sops-nix.service" ];
in
{
  options.${namespace}.services.bookorbit = {
    enable = mkEnableOption "Whether or not to configure BookOrbit.";
    subDomain = mkOpt types.str "bookorbit" "The subdomain for the service.";
    expose = mkBoolOpt true ''
      Reachable from the internet (Traefik's `public` middleware chain) rather
      than from private ranges only. Matches how Grimmory is published; set it
      to `false` to keep BookOrbit LAN/tailnet-only.
    '';

    image = mkOpt types.str "ghcr.io/bookorbit/bookorbit:2.8.1" "Container image to run.";
    dbImage = mkOpt types.str "docker.io/pgvector/pgvector:pg18" ''
      Database image. BookOrbit needs the `uuid-ossp`, `pg_trgm` and `vector`
      extensions, which rules out a plain `postgres` image.
    '';

    libraries = mkOption {
      type = types.attrsOf types.str;
      default = {
        # Same trees Grimmory serves. Both apps get them read-write, so keep
        # metadata writeback (Settings => File naming) off in one of the two
        # unless you want them renaming each other's files.
        livres = "/mnt/grimmory/livres:/livres";
        books = "/mnt/grimmory/books:/books";
        audiobooks = "/mnt/audio/Audiobooks:/audiobooks";
      };
      description = ''
        Library bind mounts, as an attrset of `volumeMap` entries. These are the
        trees the admin can pick from when creating a library in the web UI.
      '';
    };

    libraryBrowseRoot = mkOpt types.str "/" ''
      Container path the library folder picker starts at. Defaults to `/` so
      every mount in {option}`libraries` is reachable; set it to a single mount
      to hide the rest of the container root.
    '';

    bookDock = mkOpt types.str "${storage}/book-dock" ''
      Host directory mounted as BookOrbit's book dock (its drop folder for
      files to be imported).
    '';

    trustProxy = mkOpt types.str "true" ''
      Value for `TRUST_PROXY`. The container port is never published to the
      host -- only Traefik can reach it over the stack network -- so trusting
      the proxy unconditionally is what gets real client IPs into the rate
      limiter and the audit log.
    '';

    nodeMaxOldSpaceSize = mkOpt types.str "auto" ''
      Node heap limit in MB, or `auto` to derive it from the cgroup limit.
      Raise it for very large (250k+ book) libraries.
    '';

    disableLocalAuth = mkBoolOpt false ''
      Reject username/password sign-in, leaving OIDC as the only way in.
      Only turn this on *after* an administrator account has been linked to
      the OIDC provider -- BookOrbit refuses to start otherwise -- and turn it
      back off to recover access if Authelia is down.
    '';

    oidc = {
      registerClient = mkBoolOpt true ''
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

      userGroup = mkOpt types.str "${name}_user" ''
        Users of this LLDAP group will be able to log in. BookOrbit itself has
        no way to refuse a user that is in no group, so the gating happens in
        the Authelia authorization policy.
      '';
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "bookorbit/db-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";
      "bookorbit/jwt-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";
      "bookorbit/setup-bootstrap-token".sopsFile = lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";

      # Encrypt-at-rest keys for credentials BookOrbit stores in its database
      # (SMTP, migration sources, download clients). They have to be in place
      # *before* the first credential is saved -- adding one later leaves the
      # already-stored secrets unreadable -- so all three are provisioned up
      # front even though the features are opt-in.
      "bookorbit/email-encryption-key".sopsFile = lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";
      "bookorbit/migration-encryption-key".sopsFile =
        lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";
      "bookorbit/book-request-encryption-key".sopsFile =
        lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";
    };

    nps.stacks.lldap.bootstrap.groups = mkIf cfg.oidc.registerClient {
      ${cfg.oidc.userGroup} = { };
    };

    nps.stacks.authelia = mkIf cfg.oidc.registerClient {
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
        inherit (cfg) image;

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
          POSTGRES_PASSWORD.fromFile = config.sops.secrets."bookorbit/db-password".path;

          JWT_SECRET.fromFile = config.sops.secrets."bookorbit/jwt-secret".path;
          SETUP_BOOTSTRAP_TOKEN.fromFile = config.sops.secrets."bookorbit/setup-bootstrap-token".path;
          EMAIL_ENCRYPTION_KEY.fromFile = config.sops.secrets."bookorbit/email-encryption-key".path;
          MIGRATION_ENCRYPTION_KEY.fromFile = config.sops.secrets."bookorbit/migration-encryption-key".path;
          BOOK_REQUEST_ENCRYPTION_KEY.fromFile =
            config.sops.secrets."bookorbit/book-request-encryption-key".path;

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
        wants = secretsDep;
        stack = name;

        port = 3000;
        inherit (cfg) expose;
        traefik = {
          inherit name;
          inherit (cfg) subDomain;
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
        image = cfg.dbImage;
        volumeMap.data = "${storage}/db:/var/lib/postgresql/data";

        extraEnv = {
          POSTGRES_DB = name;
          POSTGRES_USER = name;
          POSTGRES_PASSWORD.fromFile = config.sops.secrets."bookorbit/db-password".path;
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

        wants = secretsDep;
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
