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
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.bookorbit;

  storage = "${config.nps.storageBaseDir}/bookorbit";
  bookDockPath = "/book-dock";

  secret = key: config.sops.secrets."bookorbit/${key}".path;
  secretsDep = [ "sops-nix.service" ];
in
{
  options.${namespace}.services.bookorbit = {
    enable = mkEnableOption "Whether or not to configure BookOrbit.";
    subDomain = mkOpt types.str "book" "The subdomain for the service.";
    aliases = mkOpt (types.listOf types.str) [ "bookorbit" ] "Subdomains that redirect to `subDomain`.";
    expose = mkBoolOpt true ''
      Reachable from the internet (Traefik's `public` middleware chain) rather
      than from private ranges only. Matches how Grimmory is published; set it
      to `false` to keep BookOrbit LAN/tailnet-only.
    '';
  };

  config = mkIf cfg.enable {
    # BookOrbit builds APP_URL and its OIDC redirect URI from `subDomain`, so a
    # second hostname has to be a redirect rather than an extra router rule.
    ${namespace}.services.traefik.redirects = lib.genAttrs cfg.aliases (_: {
      to = cfg.subDomain;
      inherit (cfg) expose;
    });

    sops.secrets =
      lib.genAttrs
        [
          "bookorbit/db-password"
          "bookorbit/jwt-secret"
          "bookorbit/setup-bootstrap-token"
          "bookorbit/email-encryption-key"
          "bookorbit/migration-encryption-key"
          "bookorbit/book-request-encryption-key"
        ]
        (_: {
          sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/bookorbit.yaml";
        });

    # The stack is nps's; everything below the options is a delta that keeps
    # the deployment as it was under the former local stack (see README).
    nps.stacks.bookorbit = {
      enable = true;

      db.passwordFile = secret "db-password";
      jwtSecretFile = secret "jwt-secret";
      setupBootstrapTokenFile = secret "setup-bootstrap-token";

      # Registered as a public PKCE client: BookOrbit's provider is configured
      # without a secret. nps wants a confidential one, so its hash is a
      # placeholder that the `client_secret` override below discards.
      oidc.registerClient = true;
      oidc.clientSecretHash = "";

      extraEnv = {
        # Encrypt the credentials BookOrbit stores in its database. Dropping
        # one leaves what is already stored unreadable.
        EMAIL_ENCRYPTION_KEY.fromFile = secret "email-encryption-key";
        MIGRATION_ENCRYPTION_KEY.fromFile = secret "migration-encryption-key";
        BOOK_REQUEST_ENCRYPTION_KEY.fromFile = secret "book-request-encryption-key";

        # Libraries are stored in the database by container path, so the
        # picker starts at `/` to reach both mounts below.
        LIBRARY_BROWSE_ROOT = "/";
        BOOK_DOCK_PATH = bookDockPath;

        # The port is only reachable by Traefik over the stack network.
        TRUST_PROXY = "true";
        NODE_MAX_OLD_SPACE_SIZE = "auto";
        DISABLE_LOCAL_AUTH = "false";

        # Authelia resolves to a LAN address from inside the container, and
        # BookOrbit refuses private issuer/discovery URLs by default.
        OIDC_ALLOW_LOCAL_ISSUERS = "true";
      };

      containers = {
        bookorbit = {
          inherit (cfg) expose;
          traefik.subDomain = cfg.subDomain;
          wants = secretsDep;

          volumeMap = {
            books = mkForce "/mnt/bookorbit:/libraries";

            # Audiobooks stay shared with grimmory: they live on the local media
            # disk, and nothing in this fleet writes to them.
            audiobooks = "/mnt/data/Audio/Audiobooks:/audiobooks";
            bookDock = "${storage}/book-dock:${bookDockPath}";
          };

          # Upstream's own compose runs the app read-only: everything it writes
          # goes to /data or to $HOME, which its entrypoint points at /tmp.
          extraConfig.Container = {
            ReadOnly = true;
            Tmpfs = "/tmp";
            NoNewPrivileges = true;
          };
        };

        bookorbit-db = {
          wants = secretsDep;

          # The cluster predates the nps stack, which mounts the parent
          # directory and lets pg18 pick `18/docker` under it.
          volumeMap.data = mkForce "${storage}/db:/var/lib/postgresql/data";
          extraEnv.PGDATA = "/var/lib/postgresql/data/pgdata";

          # Off the unattended Sunday pull: `pg18` is a moving tag.
          autoUpdate = "local";
        };
      };
    };

    nps.stacks.authelia = {
      oidc.clients.bookorbit = {
        public = mkForce true;
        client_secret = mkForce null;

        # Refresh tokens, as the client was registered before.
        scopes = [ "offline_access" ];
        grant_types = [
          "authorization_code"
          "refresh_token"
        ];
        response_types = [ "code" ];
        claims_policy = "bookorbit";
      };

      # Group mappings are synced on every login; with `groups` in the id_token
      # that keeps working even when the /userinfo call fails.
      settings.identity_providers.oidc.claims_policies.bookorbit.id_token = [
        "email"
        "email_verified"
        "preferred_username"
        "name"
        "groups"
      ];
    };
  };
}
